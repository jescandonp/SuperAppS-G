using System.Text.Json;
using System.Globalization;
using Npgsql;
using Sg.SuperApp.Api.Contracts.Portal;
using Sg.SuperApp.Api.Domain;
using Sg.SuperApp.Api.Services;

namespace Sg.SuperApp.Api.Endpoints;

public static class SchedulingRuleEndpoints
{
    public static IEndpointRouteBuilder MapSchedulingRuleEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/portal/scheduling/rule-profiles", async (
            CreateSchedulingRuleProfileRequest request,
            PortalAuthorizationService authorization,
            RequestUserContext userContext,
            SchedulingRuleProfileValidator validator,
            SchedulingRuleProfileRepository repository,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "CONFIGURE", cancellationToken);
            if (denied is not null) return denied;
            try
            {
                if (!TryParseCreateRequest(request, out var profile)) return InvalidCreateRequestProblem();
                var checksum = validator.ComputeChecksum(profile!);
                var created = await repository.CreateDraftAsync(profile! with { Checksum = checksum },
                    userContext.User!.Username, cancellationToken);
                return Results.Created($"/api/portal/scheduling/rule-profiles/{created.Id}", ToProfileResponse(created));
            }
            catch (ArgumentException) { return InvalidCreateRequestProblem(); }
            catch (InvalidOperationException) { return InvalidCreateRequestProblem(); }
            catch (JsonException) { return InvalidCreateRequestProblem(); }
            catch (PostgresException exception) when (exception.SqlState is PostgresErrorCodes.UniqueViolation or PostgresErrorCodes.CheckViolation or "23000")
            { return Results.Conflict(new { message = "El perfil entra en conflicto con una version existente." }); }
            catch (NpgsqlException) { return DatabaseUnavailable(); }
        });

        app.MapGet("/api/portal/scheduling/rule-profiles", async (
            string projectCode,
            string period,
            string environmentScope,
            PortalAuthorizationService authorization,
            SchedulingRuleHttpRepository httpRepository,
            SchedulingRuleProfileValidator validator,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "VIEW", cancellationToken);
            if (denied is not null) return denied;
            if (!TryParseScope(period, environmentScope, out var parsedPeriod, out var environment))
                return Results.BadRequest(new { message = "El periodo o ambiente solicitado no es valido." });
            try
            {
                var profiles = await httpRepository.LoadProfilesAsync(projectCode, parsedPeriod, environment, cancellationToken);
                foreach (var profile in profiles) validator.Validate(profile, environment);
                return Results.Ok(profiles.Select(ToProfileResponse));
            }
            catch (SchedulingRuleContractException) { return ContractProblem(); }
            catch (InvalidOperationException) { return ContractProblem(); }
            catch (ArgumentException) { return Results.Conflict(new { message = "La configuracion solicitada no cumple el contrato del MVP." }); }
            catch (JsonException) { return Results.Conflict(new { message = "La configuracion solicitada no cumple el contrato del MVP." }); }
            catch (NpgsqlException) { return DatabaseUnavailable(); }
        });

        app.MapGet("/api/portal/scheduling/rule-profiles/{id:long}", async (
            long id,
            PortalAuthorizationService authorization,
            SchedulingRuleHttpRepository httpRepository,
            SchedulingRuleProfileValidator validator,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "VIEW", cancellationToken);
            if (denied is not null) return denied;
            try
            {
                var profile = await httpRepository.LoadProfileByIdAsync(id, cancellationToken);
                if (profile is null) return Results.NotFound();
                validator.Validate(profile, profile.EnvironmentScope);
                return Results.Ok(ToProfileResponse(profile));
            }
            catch (SchedulingRuleContractException) { return ContractProblem(); }
            catch (InvalidOperationException) { return ContractProblem(); }
            catch (ArgumentException) { return Results.Conflict(new { message = "La configuracion solicitada no cumple el contrato del MVP." }); }
            catch (JsonException) { return Results.Conflict(new { message = "La configuracion solicitada no cumple el contrato del MVP." }); }
            catch (NpgsqlException) { return DatabaseUnavailable(); }
        });

        app.MapGet("/api/portal/scheduling/rules/evaluations", async (
            long scheduleVersionId,
            PortalAuthorizationService authorization,
            SchedulingRuleHttpRepository httpRepository,
            SchedulingRuleProfileValidator validator,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "VIEW", cancellationToken);
            if (denied is not null) return denied;
            if (scheduleVersionId <= 0) return Results.BadRequest(new { message = "La version solicitada no es valida." });
            try
            {
                var profiles = await httpRepository.LoadProfilesForEvaluationsAsync(scheduleVersionId, cancellationToken);
                foreach (var profile in profiles) validator.Validate(profile, profile.EnvironmentScope);
                return Results.Ok((await httpRepository.LoadEvaluationsAsync(scheduleVersionId, cancellationToken)).Select(ToEvaluationResponse));
            }
            catch (SchedulingRuleContractException) { return ContractProblem(); }
            catch (InvalidOperationException) { return ContractProblem(); }
            catch (JsonException) { return Results.Conflict(new { message = "El historial de evaluacion no cumple el contrato seguro." }); }
            catch (NpgsqlException) { return DatabaseUnavailable(); }
        });

        app.MapPost("/api/portal/scheduling/rule-profiles/{id:long}/activate", async (
            long id,
            ActivateSchedulingRuleProfileRequest request,
            PortalAuthorizationService authorization,
            RequestUserContext userContext,
            SchedulingRuleProfileValidator validator,
            SchedulingRuleProfileRepository repository,
            SchedulingRuleHttpRepository httpRepository,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "CONFIGURE", cancellationToken);
            if (denied is not null) return denied;
            if (!TryParseScope(request.Period, request.EnvironmentScope, out var period, out var environment) ||
                string.IsNullOrWhiteSpace(request.ProjectCode))
                return Results.BadRequest(new { message = "La activacion solicitada no es valida." });
            if (environment == SchedulingEnvironmentScope.PRODUCTION)
                return Results.Conflict(new { message = "La activacion productiva no esta habilitada en este MVP." });
            try
            {
                var profile = await httpRepository.LoadProfileByIdAsync(id, cancellationToken);
                if (profile is null) return Results.NotFound();
                if (!string.Equals(profile.ScopeCode, request.ProjectCode.Trim(), StringComparison.Ordinal) ||
                    period < profile.EffectiveFrom || profile.EffectiveTo is { } effectiveTo && period > effectiveTo)
                    return Results.Conflict(new { message = "El perfil no corresponde al proyecto y periodo solicitados." });
                validator.Validate(profile, environment);
                if (!await httpRepository.ActivateProfileAsync(id, profile.Checksum, userContext.User!.Username, cancellationToken))
                    return Results.Conflict(new { message = "Solo un perfil borrador valido puede activarse." });
                var active = await repository.LoadActiveAsync(request.ProjectCode.Trim(), period, environment, cancellationToken);
                if (active.Id != id) return Results.Conflict(new { message = "No fue posible confirmar el perfil activo solicitado." });
                return Results.Ok(ToProfileResponse(active));
            }
            catch (SchedulingRuleContractException) { return ContractProblem(); }
            catch (InvalidOperationException) { return Results.Conflict(new { message = "El perfil no cumple el contrato de activacion del MVP." }); }
            catch (JsonException) { return Results.Conflict(new { message = "El perfil no cumple el contrato de activacion del MVP." }); }
            catch (PostgresException exception) when (exception.SqlState is "23000" or PostgresErrorCodes.UniqueViolation or PostgresErrorCodes.CheckViolation)
            { return Results.Conflict(new { message = "El perfil entra en conflicto con la configuracion activa." }); }
            catch (NpgsqlException) { return DatabaseUnavailable(); }
        });

        app.MapPost("/api/portal/scheduling/rule-profiles/{id:long}/retire", async (
            long id,
            PortalAuthorizationService authorization,
            SchedulingRuleHttpRepository httpRepository,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "CONFIGURE", cancellationToken);
            if (denied is not null) return denied;
            try
            {
                var retired = await httpRepository.RetireProfileAsync(id, cancellationToken);
                return retired ? Results.Ok(new { id, status = "RETIRED" }) : Results.Conflict(new { message = "El perfil no puede retirarse en su estado actual." });
            }
            catch (NpgsqlException) { return DatabaseUnavailable(); }
        });

        app.MapPost("/api/portal/scheduling/rules/evaluate", async (
            PreEvaluateSchedulingRulesRequest request,
            PortalAuthorizationService authorization,
            SchedulingRuleProfileValidator validator,
            SchedulingRuleProfileRepository repository,
            SchedulingRuleEvaluator evaluator,
            SchedulingRuleHttpRepository httpRepository,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "GENERATE", cancellationToken);
            if (denied is not null) return denied;
            if (request.RuleProfileId <= 0 || string.IsNullOrWhiteSpace(request.ProjectCode) ||
                request.Facts.ValueKind != JsonValueKind.Object ||
                !TryParseScope(request.Period, request.EnvironmentScope, out var period, out var environment))
                return Results.BadRequest(new { message = "Los datos para preevaluar reglas no son validos." });
            try
            {
                var profile = await httpRepository.LoadProfileByIdAsync(request.RuleProfileId, cancellationToken);
                if (profile is null) return Results.NotFound();
                validator.Validate(profile, environment);
                if (profile.Status != SchedulingRuleProfileStatus.ACTIVE)
                    return Results.Conflict(new { message = "La preevaluacion exige un perfil activo." });
                var active = await repository.LoadActiveAsync(request.ProjectCode.Trim(), period, environment, cancellationToken);
                if (active.Id != profile.Id)
                    return Results.Conflict(new { message = "El perfil no es el activo para el alcance solicitado." });
                return Results.Ok(ToEvaluationBatchResponse(evaluator.Evaluate(active, request.ProjectCode, period, request.Facts)));
            }
            catch (SchedulingRuleContractException) { return ContractProblem(); }
            catch (ArgumentException) { return Results.BadRequest(new { message = "Los datos para preevaluar reglas no son validos." }); }
            catch (InvalidOperationException) { return Results.Conflict(new { message = "No existe una configuracion activa y valida para preevaluar." }); }
            catch (JsonException) { return Results.Conflict(new { message = "El perfil activo no cumple el contrato seguro." }); }
            catch (NpgsqlException) { return DatabaseUnavailable(); }
        });

        return app;
    }

    private static bool TryParseScope(string period, string environmentScope, out DateOnly parsedPeriod,
        out SchedulingEnvironmentScope environment) =>
        DateOnly.TryParseExact(period, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out parsedPeriod) &&
        Enum.GetNames<SchedulingEnvironmentScope>().Contains(environmentScope?.Trim(), StringComparer.OrdinalIgnoreCase) &&
        Enum.TryParse(environmentScope, true, out environment) &&
        Enum.IsDefined(typeof(SchedulingEnvironmentScope), environment);

    private static bool TryParseCreateRequest(CreateSchedulingRuleProfileRequest request,
        out SchedulingRuleProfile? profile)
    {
        profile = null;
        if (request is null || string.IsNullOrWhiteSpace(request.ProfileCode) || string.IsNullOrWhiteSpace(request.ScopeCode) ||
            request.Entries is null || request.Entries.Any(entry => entry is null) || request.Version <= 0 ||
            !TryParseNamedEnum(request.Origin, out SchedulingRuleOrigin origin) ||
            !TryParseNamedEnum(request.EnvironmentScope, out SchedulingEnvironmentScope environment) ||
            !DateOnly.TryParseExact(request.EffectiveFrom, "yyyy-MM-dd", CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var effectiveFrom)) return false;
        DateOnly? effectiveTo = null;
        if (!string.IsNullOrWhiteSpace(request.EffectiveTo))
        {
            if (!DateOnly.TryParseExact(request.EffectiveTo, "yyyy-MM-dd", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out var parsedEffectiveTo)) return false;
            effectiveTo = parsedEffectiveTo;
        }
        profile = new SchedulingRuleProfile(0, request.ProfileCode.Trim(), request.Version, origin, environment,
            request.ScopeCode.Trim(), effectiveFrom, effectiveTo, SchedulingRuleProfileStatus.DRAFT,
            new string('0', 64), request.Entries.Select(entry => new SchedulingRuleProfileEntry(
                entry!.RuleCode?.Trim() ?? string.Empty, entry.Parameters.Clone(), entry.CatalogSnapshot.Clone(), entry.Enabled)).ToArray());
        return true;
    }

    private static bool TryParseNamedEnum<T>(string value, out T parsed) where T : struct, Enum
    {
        if (value is not null && Enum.GetNames<T>().Contains(value.Trim(), StringComparer.Ordinal) &&
            Enum.TryParse(value.Trim(), out parsed)) return true;
        parsed = default;
        return false;
    }

    private static IResult DatabaseUnavailable() =>
        Results.Problem("No fue posible acceder a la configuracion de reglas.", statusCode: StatusCodes.Status503ServiceUnavailable);

    private static IResult ContractProblem() => Results.Problem(
        title: "Configuracion de reglas invalida",
        detail: "Los datos persistidos no cumplen el contrato seguro del MVP.",
        statusCode: StatusCodes.Status409Conflict);

    private static IResult InvalidCreateRequestProblem() => Results.Problem(
        title: "Perfil de reglas invalido",
        detail: "La solicitud no cumple el contrato de creacion del MVP.",
        statusCode: StatusCodes.Status400BadRequest);

    private static SchedulingRuleProfileResponse ToProfileResponse(SchedulingRuleProfile profile) => new(
        profile.Id, profile.ProfileCode, profile.Version, profile.Origin.ToString(), profile.EnvironmentScope.ToString(),
        profile.ScopeCode, profile.EffectiveFrom.ToString("yyyy-MM-dd"), profile.EffectiveTo?.ToString("yyyy-MM-dd"),
        profile.Status.ToString(), profile.Checksum, profile.Origin == SchedulingRuleOrigin.SIMULATED,
        profile.Entries.Select(entry => new SchedulingRuleProfileEntryResponse(
            entry.RuleCode, entry.Parameters, entry.CatalogSnapshot, entry.Enabled)).ToArray());

    private static SchedulingRuleEvaluationBatchResponse ToEvaluationBatchResponse(SchedulingRuleEvaluationBatch batch) => new(
        batch.RuleProfileId, batch.ProfileCode, batch.ProfileVersion, batch.Simulated,
        batch.Evaluations.Select(ToEvaluationResponse).ToArray(),
        new SchedulingRuleSummaryResponse(batch.Summary.Total, batch.Summary.Compliant, batch.Summary.Blocked,
            batch.Summary.ExceptionRequired, batch.Summary.Warning, batch.Summary.NotApplicable,
            batch.Summary.CanApproveOrPublish));

    private static SchedulingRuleEvaluationResponse ToEvaluationResponse(RuleEvaluation evaluation) => new(
        evaluation.RuleCode, evaluation.ProfileVersion, evaluation.Outcome.ToString(), evaluation.Severity.ToString(),
        evaluation.MessageCode, evaluation.Explanation, evaluation.ScopeHash, evaluation.ParametersSnapshot,
        evaluation.FactsSnapshot, evaluation.ExceptionAllowed);

}
