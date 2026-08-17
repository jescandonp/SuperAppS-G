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
        app.MapGet("/api/portal/scheduling/rule-profiles", async (
            string projectCode,
            string period,
            string environmentScope,
            PortalAuthorizationService authorization,
            SchedulingRuleHttpRepository httpRepository,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "VIEW", cancellationToken);
            if (denied is not null) return denied;
            if (!TryParseScope(period, environmentScope, out var parsedPeriod, out var environment))
                return Results.BadRequest(new { message = "El periodo o ambiente solicitado no es valido." });
            try
            {
                var profiles = await httpRepository.LoadProfilesAsync(projectCode, parsedPeriod, environment, cancellationToken);
                return Results.Ok(profiles.Select(ToProfileResponse));
            }
            catch (InvalidOperationException) { return Results.Conflict(new { message = "La configuracion solicitada no cumple los limites seguros del MVP." }); }
            catch (ArgumentException) { return Results.Conflict(new { message = "La configuracion solicitada no cumple el contrato del MVP." }); }
            catch (JsonException) { return Results.Conflict(new { message = "La configuracion solicitada no cumple el contrato del MVP." }); }
            catch (NpgsqlException) { return DatabaseUnavailable(); }
        });

        app.MapGet("/api/portal/scheduling/rule-profiles/{id:long}", async (
            long id,
            PortalAuthorizationService authorization,
            SchedulingRuleHttpRepository httpRepository,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "VIEW", cancellationToken);
            if (denied is not null) return denied;
            try
            {
                var profile = await httpRepository.LoadProfileByIdAsync(id, cancellationToken);
                return profile is null ? Results.NotFound() : Results.Ok(ToProfileResponse(profile));
            }
            catch (InvalidOperationException) { return Results.Conflict(new { message = "La configuracion solicitada no cumple los limites seguros del MVP." }); }
            catch (ArgumentException) { return Results.Conflict(new { message = "La configuracion solicitada no cumple el contrato del MVP." }); }
            catch (JsonException) { return Results.Conflict(new { message = "La configuracion solicitada no cumple el contrato del MVP." }); }
            catch (NpgsqlException) { return DatabaseUnavailable(); }
        });

        app.MapGet("/api/portal/scheduling/rules/evaluations", async (
            long scheduleVersionId,
            PortalAuthorizationService authorization,
            SchedulingRuleHttpRepository httpRepository,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "VIEW", cancellationToken);
            if (denied is not null) return denied;
            if (scheduleVersionId <= 0) return Results.BadRequest(new { message = "La version solicitada no es valida." });
            try { return Results.Ok((await httpRepository.LoadEvaluationsAsync(scheduleVersionId, cancellationToken)).Select(ToEvaluationResponse)); }
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

    private static IResult DatabaseUnavailable() =>
        Results.Problem("No fue posible acceder a la configuracion de reglas.", statusCode: StatusCodes.Status503ServiceUnavailable);

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
