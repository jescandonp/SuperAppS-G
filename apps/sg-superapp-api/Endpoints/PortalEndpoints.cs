using Sg.SuperApp.Api.Domain;
using Sg.SuperApp.Api.Services;
using Sg.SuperApp.Api.Contracts.Portal;
using System.Text;
using Npgsql;

namespace Sg.SuperApp.Api.Endpoints;

public static class PortalEndpoints
{
    public static IEndpointRouteBuilder MapPortalEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/portal/scheduling/cycles/project", async (
            ShiftCycleProjectionRequest request,
            ShiftCycleProjector projector,
            PortalAuthorizationService authorization,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "GENERATE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!DateOnly.TryParse(request.AnchorDate, out var anchorDate)
                || !DateOnly.TryParse(request.From, out var from)
                || !DateOnly.TryParse(request.To, out var to))
            {
                return Results.BadRequest(new { message = "Las fechas del ciclo no son validas." });
            }

            try
            {
                var result = projector.Project(new ShiftCycleRequest(
                    request.Sequence ?? Array.Empty<string>(),
                    anchorDate,
                    from,
                    to,
                    request.PhaseOffset));

                return Results.Ok(new
                {
                    days = result.Select(day => new
                    {
                        date = day.Date.ToString("yyyy-MM-dd"),
                        day.ShiftCode,
                        day.StepIndex
                    })
                });
            }
            catch (ArgumentException exception)
            {
                return Results.BadRequest(new { message = exception.Message });
            }
        });

        app.MapPost("/api/portal/scheduling/eligibility/evaluate", async (
            GuardSchedulingFacts facts,
            SchedulingEligibilityService eligibilityService,
            PortalAuthorizationService authorization,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "GENERATE", cancellationToken);
            if (denied is not null) return denied;

            try
            {
                return Results.Ok(eligibilityService.Evaluate(facts));
            }
            catch (ArgumentException exception)
            {
                return Results.BadRequest(new { message = exception.Message });
            }
        });

        app.MapGet("/api/portal/scheduling/capabilities", async (PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken ct) =>
        {
            if (userContext.User is null) return Results.Unauthorized();
            var userId = userContext.User.Id;
            return Results.Ok(new
            {
                view = await repository.HasPermissionAsync(userId, "SCHEDULING", "VIEW", ct),
                configure = await repository.HasPermissionAsync(userId, "SCHEDULING", "CONFIGURE", ct),
                generate = await repository.HasPermissionAsync(userId, "SCHEDULING", "GENERATE", ct),
                approveException = await repository.HasPermissionAsync(userId, "SCHEDULING", "APPROVE_EXCEPTION", ct),
                approve = await repository.HasPermissionAsync(userId, "SCHEDULING", "APPROVE", ct),
                publish = await repository.HasPermissionAsync(userId, "SCHEDULING", "PUBLISH", ct),
                export = await repository.HasPermissionAsync(userId, "SCHEDULING", "EXPORT", ct)
            });
        });

        app.MapPost("/api/portal/scheduling/projects/{projectId:long}/proposals", async (long projectId, CreateScheduleProposalRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken ct) =>
        {
            var denied=await authorization.RequireAsync("SCHEDULING","GENERATE",ct);if(denied is not null)return denied;
            if(!DateOnly.TryParse(request.PeriodStart,out var from)||!DateOnly.TryParse(request.PeriodEnd,out var to)||to<from)return Results.BadRequest(new{message="El periodo no es valido."});
            return Results.Created($"/api/portal/scheduling/projects/{projectId}/schedules/{request.PeriodStart}",await repository.CreateScheduleProposalAsync(projectId,from,to,request.AcceptedVacancy,userContext.User!.Id,userContext.User.Username,ct));
        });
        app.MapGet("/api/portal/scheduling/projects/{projectId:long}/schedules/{period}",async(long projectId,string period,PortalAuthorizationService authorization,PostgresPortalRepository repository,CancellationToken ct)=>
        {var denied=await authorization.RequireAsync("SCHEDULING","VIEW",ct);if(denied is not null)return denied;if(!DateOnly.TryParse(period,out var date))return Results.BadRequest(new{message="El periodo no es valido."});var item=await repository.GetScheduleByProjectPeriodAsync(projectId,date,ct);return item is null?Results.NotFound():Results.Ok(item);});
        app.MapGet("/api/portal/scheduling/proposals/{versionId:long}",async(long versionId,PortalAuthorizationService authorization,PostgresPortalRepository repository,CancellationToken ct)=>
        {var denied=await authorization.RequireAsync("SCHEDULING","VIEW",ct);if(denied is not null)return denied;var item=await repository.GetScheduleVersionAsync(versionId,ct);return item is null?Results.NotFound():Results.Ok(item);});
        app.MapPut("/api/portal/scheduling/proposals/{versionId:long}/assignments/{assignmentId:long}",async(long versionId,long assignmentId,UpdateScheduleAssignmentRequest request,PortalAuthorizationService authorization,PostgresPortalRepository repository,RequestUserContext userContext,CancellationToken ct)=>
        {var denied=await authorization.RequireAsync("SCHEDULING","GENERATE",ct);if(denied is not null)return denied;var status=request.Status.Trim().ToUpperInvariant();if(status is not("ASIGNADA" or "VACANTE")||(status=="ASIGNADA")!=request.EmployeeId.HasValue)return Results.BadRequest(new{message="Asignacion o vacante invalida."});try{return Results.Ok(await repository.UpdateScheduleAssignmentAsync(versionId,assignmentId,request,userContext.User!.Id,userContext.User.Username,ct));}catch(Exception ex)when(ex is InvalidOperationException or System.Data.DBConcurrencyException){return Results.Conflict(new{message=ex.Message});}catch(KeyNotFoundException){return Results.NotFound();}});
        app.MapPost("/api/portal/scheduling/proposals/{versionId:long}/exceptions",async(long versionId,CreateScheduleExceptionRequest request,PortalAuthorizationService authorization,PostgresPortalRepository repository,RequestUserContext userContext,CancellationToken ct)=>
        {var denied=await authorization.RequireAsync("SCHEDULING","APPROVE_EXCEPTION",ct);if(denied is not null&&userContext.User is not null)await repository.AuditScheduleExceptionDenialAsync(versionId,userContext.User.Id,userContext.User.Username,ct);if(denied is not null)return denied;if(request.ScopeHash is null||!System.Text.RegularExpressions.Regex.IsMatch(request.ScopeHash.Trim(),"^[0-9a-f]{64}$"))return InvalidScopeHashProblem();if(request.EvaluationId<=0||request.RuleCode is null||!System.Text.RegularExpressions.Regex.IsMatch(request.RuleCode,"^I9-R0[1-7]$")||string.IsNullOrWhiteSpace(request.MotiveCode)||request.MotiveCode.Length>50||!System.Text.RegularExpressions.Regex.IsMatch(request.MotiveCode,"^[A-Z0-9_]+$")||string.IsNullOrWhiteSpace(request.Reason)||string.IsNullOrWhiteSpace(request.Responsible)||!DateOnly.TryParse(request.ResolutionDate,out var date))return Results.BadRequest(new{message="Evaluacion, regla, motivo, responsable y fecha son obligatorios."});try{return Results.Ok(await repository.CreateScheduleExceptionAsync(versionId,request,date,userContext.User!.Id,userContext.User.Username,ct));}catch(SchedulingScopeHashMismatchException){return StaleScopeHashProblem();}catch(Exception ex)when(ex is InvalidOperationException or System.Data.DBConcurrencyException){return Results.Conflict(new{message=ex.Message});}catch(KeyNotFoundException){return Results.NotFound();}});
        app.MapPost("/api/portal/scheduling/proposals/{versionId:long}/approve",async(long versionId,ScheduleTransitionRequest request,PortalAuthorizationService authorization,PostgresPortalRepository repository,RequestUserContext userContext,CancellationToken ct)=>
        {var denied=await authorization.RequireAsync("SCHEDULING","APPROVE",ct);if(denied is not null)return denied;try{return Results.Ok(await repository.ApproveScheduleAsync(versionId,request.ExpectedVersion,userContext.User!.Id,userContext.User.Username,ct));}catch(Exception ex)when(ex is InvalidOperationException or System.Data.DBConcurrencyException){return Results.Conflict(new{message=ex.Message});}catch(KeyNotFoundException){return Results.NotFound();}});
        app.MapPost("/api/portal/scheduling/proposals/{versionId:long}/publish",async(long versionId,ScheduleTransitionRequest request,PortalAuthorizationService authorization,PostgresPortalRepository repository,RequestUserContext userContext,CancellationToken ct)=>
        {var denied=await authorization.RequireAsync("SCHEDULING","PUBLISH",ct);if(denied is not null)return denied;try{return Results.Ok(await repository.PublishScheduleAsync(versionId,request.ExpectedVersion,userContext.User!.Id,userContext.User.Username,ct));}catch(Exception ex)when(ex is InvalidOperationException or System.Data.DBConcurrencyException){return Results.Conflict(new{message=ex.Message});}catch(KeyNotFoundException){return Results.NotFound();}});
        app.MapGet("/api/portal/scheduling/versions/{versionId:long}/audit",async(long versionId,PortalAuthorizationService authorization,PostgresPortalRepository repository,CancellationToken ct)=>
        {var denied=await authorization.RequireAsync("SCHEDULING","AUDIT",ct);if(denied is not null)return denied;return Results.Ok(await repository.GetScheduleAuditAsync(versionId,ct));});
        app.MapPost("/api/portal/scheduling/versions/{versionId:long}/replan",async(long versionId,ScheduleReplanningRequest request,PortalAuthorizationService authorization,PostgresPortalRepository repository,SchedulingRecommendationEngine engine,RequestUserContext userContext,CancellationToken ct)=>
        {var denied=await authorization.RequireAsync("SCHEDULING","GENERATE",ct);if(denied is not null)return denied;try{return Results.Ok(await repository.ReplanScheduleAsync(versionId,request,engine,userContext.User!.Id,userContext.User.Username,ct));}catch(ArgumentException ex){return Results.BadRequest(new{message=ex.Message});}catch(InvalidOperationException ex){return Results.Conflict(new{message=ex.Message});}});
        app.MapGet("/api/portal/scheduling/versions/{versionId:long}/export.pdf",async(long versionId,long? positionId,long? employeeId,PortalAuthorizationService authorization,SchedulingExportService exporter,RequestUserContext userContext,CancellationToken ct)=>await ExportScheduleAsync(versionId,"pdf",positionId,employeeId,authorization,exporter,userContext,ct));
        app.MapGet("/api/portal/scheduling/versions/{versionId:long}/export.xlsx",async(long versionId,long? positionId,long? employeeId,PortalAuthorizationService authorization,SchedulingExportService exporter,RequestUserContext userContext,CancellationToken ct)=>await ExportScheduleAsync(versionId,"xlsx",positionId,employeeId,authorization,exporter,userContext,ct));

        app.MapPost("/api/portal/scheduling/clients", async (UpsertSchedulingClientRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository,
            RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            if (string.IsNullOrWhiteSpace(request.Code) || string.IsNullOrWhiteSpace(request.Name) || !IsActiveStatus(request.Status))
                return Results.BadRequest(new { message = "Codigo, nombre y estado ACTIVO/INACTIVO son obligatorios." });
            return await CreateSchedulingResultAsync(
                () => repository.CreateSchedulingClientAsync(request, userContext.User!.Id, userContext.User.Username, cancellationToken));
        });

        app.MapGet("/api/portal/scheduling/clients/{id:long}", async (long id, PortalAuthorizationService authorization,
            PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            var item = await repository.GetSchedulingClientAsync(id, cancellationToken);
            return item is null ? Results.NotFound() : Results.Ok(item);
        });

        app.MapPut("/api/portal/scheduling/clients/{id:long}", async (long id, UpsertSchedulingClientRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            if (string.IsNullOrWhiteSpace(request.Code) || string.IsNullOrWhiteSpace(request.Name) || !IsActiveStatus(request.Status))
                return Results.BadRequest(new { message = "Codigo, nombre y estado ACTIVO/INACTIVO son obligatorios." });
            var updated = await repository.UpdateSchedulingClientAsync(id, request, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return updated ? Results.Ok(await repository.GetSchedulingClientAsync(id, cancellationToken)) : Results.NotFound();
        });

        app.MapPost("/api/portal/scheduling/clients/{id:long}/inactivate", async (long id,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            var updated = await repository.InactivateSchedulingClientAsync(id, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return updated ? Results.Ok(await repository.GetSchedulingClientAsync(id, cancellationToken)) : Results.NotFound();
        });

        app.MapPost("/api/portal/scheduling/projects", async (UpsertSchedulingProjectRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository,
            RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            if (request.ClientId <= 0 || string.IsNullOrWhiteSpace(request.Code) || string.IsNullOrWhiteSpace(request.Name)
                || !IsActiveStatus(request.Status) || !DateOnly.TryParse(request.EffectiveFrom, out var effectiveFrom)
                || (!string.IsNullOrWhiteSpace(request.EffectiveTo) && !DateOnly.TryParse(request.EffectiveTo, out _)))
                return Results.BadRequest(new { message = "Los datos y la vigencia del proyecto no son validos." });
            DateOnly? effectiveTo = string.IsNullOrWhiteSpace(request.EffectiveTo) ? null : DateOnly.Parse(request.EffectiveTo);
            if (effectiveTo < effectiveFrom) return Results.BadRequest(new { message = "La vigencia final no puede ser anterior a la inicial." });
            return await CreateSchedulingResultAsync(
                () => repository.CreateSchedulingProjectAsync(request, effectiveFrom, effectiveTo, userContext.User!.Id, userContext.User.Username, cancellationToken));
        });

        app.MapGet("/api/portal/scheduling/projects/{id:long}", async (long id, PortalAuthorizationService authorization,
            PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            var item = await repository.GetSchedulingProjectAsync(id, cancellationToken);
            return item is null ? Results.NotFound() : Results.Ok(item);
        });

        app.MapPut("/api/portal/scheduling/projects/{id:long}", async (long id, UpsertSchedulingProjectRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            if (request.ClientId <= 0 || string.IsNullOrWhiteSpace(request.Code) || string.IsNullOrWhiteSpace(request.Name)
                || !IsActiveStatus(request.Status) || !DateOnly.TryParse(request.EffectiveFrom, out var effectiveFrom)
                || (!string.IsNullOrWhiteSpace(request.EffectiveTo) && !DateOnly.TryParse(request.EffectiveTo, out _)))
                return Results.BadRequest(new { message = "Los datos y la vigencia del proyecto no son validos." });
            DateOnly? effectiveTo = string.IsNullOrWhiteSpace(request.EffectiveTo) ? null : DateOnly.Parse(request.EffectiveTo);
            if (effectiveTo < effectiveFrom) return Results.BadRequest(new { message = "La vigencia final no puede ser anterior a la inicial." });
            var updated = await repository.UpdateSchedulingProjectAsync(id, request, effectiveFrom, effectiveTo, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return updated ? Results.Ok(await repository.GetSchedulingProjectAsync(id, cancellationToken)) : Results.NotFound();
        });

        app.MapPost("/api/portal/scheduling/projects/{id:long}/inactivate", async (long id,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            var updated = await repository.InactivateSchedulingProjectAsync(id, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return updated ? Results.Ok(await repository.GetSchedulingProjectAsync(id, cancellationToken)) : Results.NotFound();
        });

        app.MapPost("/api/portal/scheduling/coverage-rules", async (UpsertCoverageRuleRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository,
            RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            if (request.PositionId <= 0 || request.TemplateId <= 0 || request.RequiredGuards <= 0
                || string.IsNullOrWhiteSpace(request.WeekdayScope) || !IsActiveStatus(request.Status)
                || !TimeOnly.TryParse(request.StartsAt, out var startsAt) || !TimeOnly.TryParse(request.EndsAt, out var endsAt)
                || startsAt == endsAt || !DateOnly.TryParse(request.EffectiveFrom, out var effectiveFrom)
                || (!string.IsNullOrWhiteSpace(request.EffectiveTo) && !DateOnly.TryParse(request.EffectiveTo, out _)))
                return Results.BadRequest(new { message = "La cobertura, franja o vigencia no es valida." });
            DateOnly? effectiveTo = string.IsNullOrWhiteSpace(request.EffectiveTo) ? null : DateOnly.Parse(request.EffectiveTo);
            if (effectiveTo < effectiveFrom) return Results.BadRequest(new { message = "La vigencia final no puede ser anterior a la inicial." });
            return await CreateSchedulingResultAsync(
                () => repository.CreateCoverageRuleAsync(request, startsAt, endsAt, effectiveFrom, effectiveTo, userContext.User!.Id, userContext.User.Username, cancellationToken));
        });

        app.MapGet("/api/portal/scheduling/coverage-rules/{id:long}", async (long id, PortalAuthorizationService authorization,
            PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            var item = await repository.GetCoverageRuleAsync(id, cancellationToken);
            return item is null ? Results.NotFound() : Results.Ok(item);
        });

        app.MapPut("/api/portal/scheduling/coverage-rules/{id:long}", async (long id, UpsertCoverageRuleRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            if (request.PositionId <= 0 || request.TemplateId <= 0 || request.RequiredGuards <= 0
                || string.IsNullOrWhiteSpace(request.WeekdayScope) || !IsActiveStatus(request.Status)
                || !TimeOnly.TryParse(request.StartsAt, out var startsAt) || !TimeOnly.TryParse(request.EndsAt, out var endsAt)
                || startsAt == endsAt || !DateOnly.TryParse(request.EffectiveFrom, out var effectiveFrom)
                || (!string.IsNullOrWhiteSpace(request.EffectiveTo) && !DateOnly.TryParse(request.EffectiveTo, out _)))
                return Results.BadRequest(new { message = "La cobertura, franja o vigencia no es valida." });
            DateOnly? effectiveTo = string.IsNullOrWhiteSpace(request.EffectiveTo) ? null : DateOnly.Parse(request.EffectiveTo);
            if (effectiveTo < effectiveFrom) return Results.BadRequest(new { message = "La vigencia final no puede ser anterior a la inicial." });
            var updated = await repository.UpdateCoverageRuleAsync(id, request, startsAt, endsAt, effectiveFrom, effectiveTo, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return updated ? Results.Ok(await repository.GetCoverageRuleAsync(id, cancellationToken)) : Results.NotFound();
        });

        app.MapPost("/api/portal/scheduling/coverage-rules/{id:long}/inactivate", async (long id,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            var updated = await repository.InactivateCoverageRuleAsync(id, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return updated ? Results.Ok(await repository.GetCoverageRuleAsync(id, cancellationToken)) : Results.NotFound();
        });

        app.MapPost("/api/portal/scheduling/availability-exceptions", async (UpsertAvailabilityExceptionRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository,
            RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "APPROVE_EXCEPTION", cancellationToken);
            if (denied is not null) return denied;
            if (request.EmployeeId <= 0 || string.IsNullOrWhiteSpace(request.Kind) || string.IsNullOrWhiteSpace(request.Reason)
                || !DateTimeOffset.TryParse(request.From, out var from) || !DateTimeOffset.TryParse(request.To, out var to) || to <= from)
                return Results.BadRequest(new { message = "La excepcion de disponibilidad no es valida." });
            return await CreateSchedulingResultAsync(
                () => repository.CreateAvailabilityExceptionAsync(request, from, to, userContext.User!.Id, userContext.User.Username, cancellationToken));
        });

        app.MapGet("/api/portal/scheduling/availability-exceptions/{id:long}", async (long id,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "APPROVE_EXCEPTION", cancellationToken);
            if (denied is not null) return denied;
            var item = await repository.GetAvailabilityExceptionAsync(id, cancellationToken);
            return item is null ? Results.NotFound() : Results.Ok(item);
        });

        app.MapPut("/api/portal/scheduling/availability-exceptions/{id:long}", async (long id, UpsertAvailabilityExceptionRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "APPROVE_EXCEPTION", cancellationToken);
            if (denied is not null) return denied;
            if (request.EmployeeId <= 0 || string.IsNullOrWhiteSpace(request.Kind) || string.IsNullOrWhiteSpace(request.Reason)
                || !DateTimeOffset.TryParse(request.From, out var from) || !DateTimeOffset.TryParse(request.To, out var to) || to <= from)
                return Results.BadRequest(new { message = "La excepcion de disponibilidad no es valida." });
            var updated = await repository.UpdateAvailabilityExceptionAsync(id, request, from, to, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return updated ? Results.Ok(await repository.GetAvailabilityExceptionAsync(id, cancellationToken)) : Results.NotFound();
        });

        app.MapPost("/api/portal/scheduling/availability-exceptions/{id:long}/inactivate", async (long id,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("SCHEDULING", "APPROVE_EXCEPTION", cancellationToken);
            if (denied is not null) return denied;
            var updated = await repository.InactivateAvailabilityExceptionAsync(id, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return updated ? Results.Ok(await repository.GetAvailabilityExceptionAsync(id, cancellationToken)) : Results.NotFound();
        });

        app.MapPost("/api/portal/scheduling/position-requirements", async (UpsertPositionRequirementRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository,
            RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            var severity = request.Severity?.Trim().ToUpperInvariant();
            if (request.PositionId <= 0 || request.RequirementTypeId <= 0
                || severity is not ("BLOQUEANTE" or "SUBSANABLE" or "INFORMATIVA")
                || (!string.IsNullOrWhiteSpace(request.ResolutionDueDate) && !DateOnly.TryParse(request.ResolutionDueDate, out _)))
                return Results.BadRequest(new { message = "El requisito o su severidad no es valido." });
            DateOnly? dueDate = string.IsNullOrWhiteSpace(request.ResolutionDueDate) ? null : DateOnly.Parse(request.ResolutionDueDate);
            return await CreateSchedulingResultAsync(
                () => repository.CreatePositionRequirementAsync(request, dueDate, userContext.User!.Id, userContext.User.Username, cancellationToken));
        });

        app.MapGet("/api/portal/scheduling/position-requirements/{id:long}", async (long id,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            var item = await repository.GetPositionRequirementAsync(id, cancellationToken);
            return item is null ? Results.NotFound() : Results.Ok(item);
        });

        app.MapPut("/api/portal/scheduling/position-requirements/{id:long}", async (long id, UpsertPositionRequirementRequest request,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            var severity = request.Severity?.Trim().ToUpperInvariant();
            if (request.PositionId <= 0 || request.RequirementTypeId <= 0
                || severity is not ("BLOQUEANTE" or "SUBSANABLE" or "INFORMATIVA")
                || (!string.IsNullOrWhiteSpace(request.ResolutionDueDate) && !DateOnly.TryParse(request.ResolutionDueDate, out _)))
                return Results.BadRequest(new { message = "El requisito o su severidad no es valido." });
            DateOnly? dueDate = string.IsNullOrWhiteSpace(request.ResolutionDueDate) ? null : DateOnly.Parse(request.ResolutionDueDate);
            var updated = await repository.UpdatePositionRequirementAsync(id, request, dueDate, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return updated ? Results.Ok(await repository.GetPositionRequirementAsync(id, cancellationToken)) : Results.NotFound();
        });

        app.MapPost("/api/portal/scheduling/position-requirements/{id:long}/inactivate", async (long id,
            PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await RequireSchedulingConfigurationAsync(authorization, userContext, cancellationToken);
            if (denied is not null) return denied;
            var updated = await repository.InactivatePositionRequirementAsync(id, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return updated ? Results.Ok(await repository.GetPositionRequirementAsync(id, cancellationToken)) : Results.NotFound();
        });

        app.MapGet("/api/portal/modules/{role}", async (string role, MockPortalQueryService portalService, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            if (!TryParseRole(role, out var parsedRole))
            {
                return Results.BadRequest(new { message = "Rol no soportado." });
            }

            var modules = await repository.CanConnectAsync(cancellationToken)
                ? await repository.GetModulesAsync(role, cancellationToken)
                : portalService.GetModules(parsedRole);

            return Results.Ok(modules);
        });

        app.MapGet("/api/portal/notifications/{username}", async (string username, MockPortalQueryService portalService, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var notifications = await repository.CanConnectAsync(cancellationToken)
                ? await repository.GetNotificationsAsync(username, cancellationToken)
                : portalService.GetNotifications(username);

            return Results.Ok(notifications);
        });

        app.MapGet("/api/portal/employees", async (string? search, string? status, string? jobTitle, string? completeness, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("EMPLOYEES", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!await repository.CanConnectAsync(cancellationToken))
            {
                return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
            }

            var includeSalary = await repository.HasPermissionAsync(userContext.User!.Id, "EMPLOYEES", "VIEW_SALARY", cancellationToken);
            var employees = await repository.GetEmployeesAsync(search, status, jobTitle, completeness, includeSalary, cancellationToken);
            return Results.Ok(employees);
        });

        app.MapGet("/api/portal/employees/{employeeId:long}", async (long employeeId, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("EMPLOYEES", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!await repository.CanConnectAsync(cancellationToken))
            {
                return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
            }

            var includeSalary = await repository.HasPermissionAsync(userContext.User!.Id, "EMPLOYEES", "VIEW_SALARY", cancellationToken);
            var employee = await repository.GetEmployeeByIdAsync(employeeId, includeSalary, cancellationToken);
            return employee is null ? Results.NotFound() : Results.Ok(employee);
        });

        app.MapPut("/api/portal/employees/{employeeId:long}", async (long employeeId, UpdateEmployeeRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("EMPLOYEES", "EDIT", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (string.IsNullOrWhiteSpace(request.FullName)
                || string.IsNullOrWhiteSpace(request.JobTitle)
                || !DateOnly.TryParse(request.HireDate, out _)
                || request.EmploymentStatus is not ("ACTIVO" or "RETIRADO")
                || (request.EmploymentStatus == "RETIRADO" && (!DateOnly.TryParse(request.TerminationDate, out _) || string.IsNullOrWhiteSpace(request.TerminationReason)))
                || (request.CurrentBaseSalary.HasValue && (request.CurrentBaseSalary < 0 || !DateOnly.TryParse(request.SalaryEffectiveFrom, out _))))
            {
                return Results.BadRequest(new { message = "Los datos laborales o salariales enviados no son validos." });
            }

            try
            {
                var updated = await repository.UpdateEmployeeAsync(employeeId, request, userContext.User!.Username, cancellationToken);
                return updated ? Results.Ok() : Results.NotFound();
            }
            catch (ArgumentException exception)
            {
                return Results.BadRequest(new { message = exception.Message });
            }
        });

        app.MapGet("/api/portal/positions", async (string? search, string? status, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("POSITIONS", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!await repository.CanConnectAsync(cancellationToken))
            {
                return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
            }

            var normalizedStatus = status?.Trim().ToUpperInvariant();
            if (normalizedStatus is not null && normalizedStatus is not ("ACTIVO" or "INACTIVO"))
            {
                return Results.BadRequest(new { message = "El estado de puesto no es valido." });
            }

            var positions = await repository.GetServicePositionsAsync(search, normalizedStatus, cancellationToken);
            return Results.Ok(positions);
        });

        app.MapGet("/api/portal/positions/{positionId:long}", async (long positionId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("POSITIONS", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var position = await repository.GetServicePositionByIdAsync(positionId, cancellationToken);
            return position is null ? Results.NotFound() : Results.Ok(position);
        });

        app.MapGet("/api/portal/positions/{positionId:long}/assignments", async (long positionId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("POSITION_ASSIGNMENTS", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var assignments = await repository.GetPositionAssignmentsAsync(positionId, cancellationToken);
            return Results.Ok(assignments);
        });

        app.MapPost("/api/portal/positions", async (UpsertServicePositionRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("POSITIONS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (string.IsNullOrWhiteSpace(request.Name))
            {
                return Results.BadRequest(new { message = "El nombre del puesto es obligatorio." });
            }

            try
            {
                var position = await repository.CreateServicePositionAsync(request, userContext.User!.Id, userContext.User.Username, cancellationToken);
                return Results.Ok(position);
            }
            catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
            {
                return Results.Conflict(new { message = "Ya existe un puesto con ese codigo." });
            }
        });

        app.MapPut("/api/portal/positions/{positionId:long}", async (long positionId, UpsertServicePositionRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("POSITIONS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (string.IsNullOrWhiteSpace(request.Name))
            {
                return Results.BadRequest(new { message = "El nombre del puesto es obligatorio." });
            }

            try
            {
                var position = await repository.UpdateServicePositionAsync(positionId, request, userContext.User!.Id, userContext.User.Username, cancellationToken);
                return position is null ? Results.NotFound() : Results.Ok(position);
            }
            catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
            {
                return Results.Conflict(new { message = "Ya existe un puesto con ese codigo." });
            }
        });

        app.MapPost("/api/portal/positions/{positionId:long}/inactivate", async (long positionId, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("POSITIONS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var position = await repository.InactivateServicePositionAsync(positionId, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return position is null ? Results.NotFound() : Results.Ok(position);
        });

        app.MapGet("/api/portal/training-types", async (string? search, string? status, string? category, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("TRAINING_TYPES", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var normalizedStatus = status?.Trim().ToUpperInvariant();
            var normalizedCategory = category?.Trim().ToUpperInvariant();
            if ((normalizedStatus is not null && normalizedStatus is not ("ACTIVO" or "INACTIVO"))
                || (normalizedCategory is not null && normalizedCategory is not ("CURSO" or "ACREDITACION")))
            {
                return Results.BadRequest(new { message = "Filtros de tipos de curso/acreditacion no validos." });
            }

            return Results.Ok(await repository.GetTrainingRequirementTypesAsync(search, normalizedStatus, normalizedCategory, cancellationToken));
        });

        app.MapGet("/api/portal/training-types/{typeId:long}", async (long typeId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("TRAINING_TYPES", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var type = await repository.GetTrainingRequirementTypeByIdAsync(typeId, cancellationToken);
            return type is null ? Results.NotFound() : Results.Ok(type);
        });

        app.MapPost("/api/portal/training-types", async (UpsertTrainingRequirementTypeRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("TRAINING_TYPES", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!IsValidTrainingRequirementTypeRequest(request))
            {
                return Results.BadRequest(new { message = "Los datos del tipo de curso/acreditacion no son validos." });
            }

            try
            {
                var type = await repository.CreateTrainingRequirementTypeAsync(request, userContext.User!.Id, userContext.User.Username, cancellationToken);
                return Results.Ok(type);
            }
            catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
            {
                return Results.Conflict(new { message = "Ya existe un tipo de curso/acreditacion con ese codigo." });
            }
        });

        app.MapPut("/api/portal/training-types/{typeId:long}", async (long typeId, UpsertTrainingRequirementTypeRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("TRAINING_TYPES", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!IsValidTrainingRequirementTypeRequest(request))
            {
                return Results.BadRequest(new { message = "Los datos del tipo de curso/acreditacion no son validos." });
            }

            try
            {
                var type = await repository.UpdateTrainingRequirementTypeAsync(typeId, request, userContext.User!.Id, userContext.User.Username, cancellationToken);
                return type is null ? Results.NotFound() : Results.Ok(type);
            }
            catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
            {
                return Results.Conflict(new { message = "Ya existe un tipo de curso/acreditacion con ese codigo." });
            }
        });

        app.MapPost("/api/portal/training-types/{typeId:long}/inactivate", async (long typeId, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("TRAINING_TYPES", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var type = await repository.InactivateTrainingRequirementTypeAsync(typeId, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return type is null ? Results.NotFound() : Results.Ok(type);
        });

        app.MapGet("/api/portal/training-compliance", async (string? search, long? typeId, string? complianceStatus, string? enablementStatus, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("TRAINING_RECORDS", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            return Results.Ok(await repository.GetTrainingComplianceSummariesAsync(search, typeId, complianceStatus, enablementStatus, cancellationToken));
        });

        app.MapGet("/api/portal/employees/{employeeId:long}/training/enablement", async (long employeeId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("TRAINING_SERVICE_ENABLEMENT", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var enablement = await repository.GetTrainingServiceEnablementAsync(employeeId, cancellationToken);
            return enablement is null ? Results.NotFound(new { message = "Empleado no encontrado." }) : Results.Ok(enablement);
        });

        app.MapGet("/api/portal/employees/{employeeId:long}/training-compliance", async (long employeeId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("TRAINING_RECORDS", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var detail = await repository.GetTrainingComplianceDetailAsync(employeeId, cancellationToken);
            return detail is null ? Results.NotFound(new { message = "Empleado no encontrado." }) : Results.Ok(detail);
        });

        app.MapPost("/api/portal/employees/{employeeId:long}/training", async (long employeeId, CreateTrainingRecordRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("TRAINING_RECORDS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (request.RequirementTypeId <= 0 || !DateOnly.TryParse(request.CompletedAt, out _))
            {
                return Results.BadRequest(new { message = "La renovacion enviada no es valida." });
            }

            var result = await repository.CreateEmployeeTrainingRecordAsync(employeeId, request, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return result.Code switch
            {
                "CREATED" => Results.Ok(result.Record),
                "EMPLOYEE_NOT_FOUND" => Results.NotFound(new { message = "Empleado no encontrado." }),
                "TYPE_NOT_FOUND" => Results.NotFound(new { message = "Tipo de curso/acreditacion no encontrado." }),
                "INACTIVE_TYPE" => Results.Conflict(new { message = "No se puede registrar renovacion sobre un tipo inactivo." }),
                "MISSING_EXPIRY" => Results.BadRequest(new { message = "La fecha de vencimiento es obligatoria para tipos sin vigencia." }),
                "INVALID_DATE" => Results.BadRequest(new { message = "La fecha de vencimiento no puede ser anterior a la realizacion." }),
                _ => Results.BadRequest(new { message = "La renovacion enviada no es valida." })
            };
        });

        app.MapPost("/api/portal/training/{recordId:long}/inactivate", async (long recordId, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("TRAINING_RECORDS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var record = await repository.InactivateEmployeeTrainingRecordAsync(recordId, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return record is null ? Results.NotFound() : Results.Ok(record);
        });

        app.MapGet("/api/portal/certificate-signers", async (string? status, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATE_SIGNERS", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var normalizedStatus = status?.Trim().ToUpperInvariant();
            if (normalizedStatus is not null && normalizedStatus is not ("ACTIVO" or "INACTIVO"))
            {
                return Results.BadRequest(new { message = "El estado del firmante no es valido." });
            }

            return Results.Ok(await repository.GetCertificateSignersAsync(normalizedStatus, cancellationToken));
        });

        app.MapGet("/api/portal/certificate-signers/{signerId:long}", async (long signerId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATE_SIGNERS", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var signer = await repository.GetCertificateSignerByIdAsync(signerId, cancellationToken);
            return signer is null ? Results.NotFound() : Results.Ok(signer);
        });

        app.MapPost("/api/portal/certificate-signers", async (UpsertCertificateSignerRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATE_SIGNERS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!IsValidSignerRequest(request))
            {
                return Results.BadRequest(new { message = "Los datos del firmante no son validos." });
            }

            var signer = await repository.CreateCertificateSignerAsync(request, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return Results.Ok(signer);
        });

        app.MapPut("/api/portal/certificate-signers/{signerId:long}", async (long signerId, UpsertCertificateSignerRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATE_SIGNERS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!IsValidSignerRequest(request))
            {
                return Results.BadRequest(new { message = "Los datos del firmante no son validos." });
            }

            var signer = await repository.UpdateCertificateSignerAsync(signerId, request, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return signer is null ? Results.NotFound() : Results.Ok(signer);
        });

        app.MapPost("/api/portal/certificate-signers/{signerId:long}/inactivate", async (long signerId, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATE_SIGNERS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var signer = await repository.InactivateCertificateSignerAsync(signerId, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return signer is null ? Results.NotFound() : Results.Ok(signer);
        });

        app.MapPost("/api/portal/certificates/preview", async (CertificatePreviewRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATES", "PREVIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!IsValidCertificatePreviewRequest(request))
            {
                return Results.BadRequest(new { message = "La solicitud de previsualizacion no es valida." });
            }

            var result = await repository.BuildCertificatePreviewAsync(request, cancellationToken);
            return result switch
            {
                null => Results.NotFound(new { message = "Empleado no encontrado." }),
                { CertificateType: "EMPLOYEE_NOT_ACTIVE" } => Results.Conflict(new { message = "El empleado no esta activo." }),
                { CertificateType: "MISSING_BASE_SALARY" } => Results.Conflict(new { message = "El empleado activo no tiene salario base vigente." }),
                { CertificateType: "MISSING_TERMINATION_DATE" } => Results.Conflict(new { message = "El empleado retirado no tiene fecha de retiro." }),
                { CertificateType: "MISSING_TERMINATION_REASON" } => Results.Conflict(new { message = "El empleado retirado no tiene motivo de retiro." }),
                { CertificateType: "MISSING_ACTIVE_SIGNER" } => Results.Conflict(new { message = "No existe firmante activo y vigente para la fecha de expedicion." }),
                _ => Results.Ok(result)
            };
        });

        app.MapGet("/api/portal/certificates", async (long? employeeId, string? type, string? status, string? from, string? to, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATES", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if ((!string.IsNullOrWhiteSpace(type) && type is not ("ACTIVO" or "RETIRADO"))
                || (!string.IsNullOrWhiteSpace(status) && status is not ("BORRADOR" or "PREVISUALIZADA" or "APROBADA" or "GENERADA" or "ANULADA"))
                || (!string.IsNullOrWhiteSpace(from) && !DateOnly.TryParse(from, out _))
                || (!string.IsNullOrWhiteSpace(to) && !DateOnly.TryParse(to, out _)))
            {
                return Results.BadRequest(new { message = "Filtros de certificados no validos." });
            }

            return Results.Ok(await repository.GetCertificatesAsync(employeeId, type, status, from, to, cancellationToken));
        });

        app.MapGet("/api/portal/certificates/{certificateId:long}", async (long certificateId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATES", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var certificate = await repository.GetCertificateByIdAsync(certificateId, cancellationToken);
            return certificate is null ? Results.NotFound(new { message = "Certificado no encontrado." }) : Results.Ok(certificate);
        });

        app.MapPost("/api/portal/certificates/approve-generate", async (CertificatePreviewRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATES", "GENERATE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!IsValidCertificatePreviewRequest(request))
            {
                return Results.BadRequest(new { message = "La solicitud de generacion no es valida." });
            }

            var preview = await repository.BuildCertificatePreviewAsync(request, cancellationToken);
            var previewError = MapCertificatePreviewError(preview);
            if (previewError is not null)
            {
                return previewError;
            }

            var certificate = await repository.PersistGeneratedCertificateAsync(preview!, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return Results.Ok(certificate);
        });

        app.MapGet("/api/portal/certificates/{certificateId:long}/download", async (long certificateId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATES", "DOWNLOAD", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var download = await repository.GetCertificateDownloadAsync(certificateId, cancellationToken);
            if (download is null || !File.Exists(download.Value.FilePath))
            {
                return Results.NotFound(new { message = "PDF de certificado no encontrado." });
            }

            return Results.File(await File.ReadAllBytesAsync(download.Value.FilePath, cancellationToken), "application/pdf", download.Value.FileName);
        });

        app.MapPost("/api/portal/certificates/{certificateId:long}/annul", async (long certificateId, AnnulCertificateRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATES", "ANNUL", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (string.IsNullOrWhiteSpace(request.Reason))
            {
                return Results.BadRequest(new { message = "El motivo de anulacion es obligatorio." });
            }

            var certificate = await repository.AnnulCertificateAsync(certificateId, request.Reason, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return certificate is null
                ? Results.NotFound(new { message = "Certificado generado no encontrado." })
                : Results.Ok(certificate);
        });

        app.MapGet("/api/portal/certificates/{certificateId:long}/history", async (long certificateId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("CERTIFICATES", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            return Results.Ok(await repository.GetCertificateHistoryAsync(certificateId, cancellationToken));
        });

        app.MapGet("/api/portal/employees/{employeeId:long}/position-assignments", async (long employeeId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("POSITION_ASSIGNMENTS", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var assignments = await repository.GetEmployeePositionAssignmentsAsync(employeeId, cancellationToken);
            return Results.Ok(assignments);
        });

        app.MapPost("/api/portal/employees/{employeeId:long}/position-assignments", async (long employeeId, CreatePositionAssignmentRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("POSITION_ASSIGNMENTS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (request.PositionId <= 0 || !DateOnly.TryParse(request.StartDate, out _))
            {
                return Results.BadRequest(new { message = "La asignacion enviada no es valida." });
            }

            var result = await repository.CreatePositionAssignmentAsync(employeeId, request, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return result switch
            {
                "EMPLOYEE_NOT_FOUND" => Results.NotFound(new { message = "Empleado no encontrado." }),
                "POSITION_NOT_FOUND" => Results.NotFound(new { message = "Puesto no encontrado." }),
                "INACTIVE_POSITION" => Results.Conflict(new { message = "No se puede asignar a un puesto inactivo." }),
                "ACTIVE_ASSIGNMENT_EXISTS" => Results.Conflict(new { message = "El empleado ya tiene una asignacion vigente." }),
                _ => Results.Ok(await repository.GetPositionAssignmentByIdAsync(long.Parse(result), cancellationToken))
            };
        });

        app.MapPost("/api/portal/position-assignments/{assignmentId:long}/finalize", async (long assignmentId, FinalizePositionAssignmentRequest request, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("POSITION_ASSIGNMENTS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!DateOnly.TryParse(request.EndDate, out _))
            {
                return Results.BadRequest(new { message = "La fecha fin no es valida." });
            }

            var result = await repository.FinalizePositionAssignmentAsync(assignmentId, request, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return result switch
            {
                "FINALIZED" => Results.Ok(await repository.GetPositionAssignmentByIdAsync(assignmentId, cancellationToken)),
                "NOT_FOUND" => Results.NotFound(),
                "INVALID_DATE" => Results.BadRequest(new { message = "La fecha fin no puede ser anterior al inicio." }),
                _ => Results.Conflict(new { message = "La asignacion no puede finalizarse en su estado actual." })
            };
        });

        app.MapGet("/api/portal/imports", async (PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("IMPORTS", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!await repository.CanConnectAsync(cancellationToken))
            {
                return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
            }

            var imports = await repository.GetImportBatchesAsync(cancellationToken);
            return Results.Ok(imports);
        });

        app.MapGet("/api/portal/imports/{batchId:long}/errors", async (long batchId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("IMPORTS", "VIEW_ERRORS", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!await repository.CanConnectAsync(cancellationToken))
            {
                return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
            }

            var errors = await repository.GetImportBatchErrorsAsync(batchId, cancellationToken);
            return Results.Ok(errors);
        });

        app.MapGet("/api/portal/imports/{batchId:long}/errors/export", async (long batchId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("IMPORTS", "VIEW_ERRORS", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var errors = await repository.GetImportBatchErrorsAsync(batchId, cancellationToken);
            var csv = new StringBuilder("fila,campo,tipo_error,mensaje,valor_original\r\n");
            foreach (var error in errors)
            {
                csv.Append(error.RowNumber).Append(',')
                    .Append(EscapeCsv(error.FieldName)).Append(',')
                    .Append(EscapeCsv(error.ErrorType)).Append(',')
                    .Append(EscapeCsv(error.Message)).Append(',')
                    .Append(EscapeCsv(error.OriginalValue))
                    .Append("\r\n");
            }

            return Results.File(
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: true).GetBytes(csv.ToString()),
                "text/csv; charset=utf-8",
                $"import-errors-{batchId}.csv");
        });

        app.MapGet("/api/portal/imports/{batchId:long}/rows", async (long batchId, string? classification, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("IMPORTS", "VIEW_ERRORS", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var normalizedClassification = classification?.Trim().ToUpperInvariant();
            if (normalizedClassification is not null && normalizedClassification is not ("VALIDO" or "INCOMPLETO" or "DUPLICADO" or "ERRONEO"))
            {
                return Results.BadRequest(new { message = "La clasificacion solicitada no es valida." });
            }

            var rows = await repository.GetImportBatchRowsAsync(batchId, normalizedClassification, cancellationToken);
            return Results.Ok(rows);
        });

        app.MapGet("/api/portal/imports/{batchId:long}/mappings", async (long batchId, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("IMPORTS", "VIEW_ERRORS", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var mappings = await repository.GetImportColumnMappingsAsync(batchId, cancellationToken);
            return Results.Ok(mappings);
        });

        app.MapPost("/api/portal/imports/{batchId:long}/cancel", async (long batchId, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("IMPORTS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var result = await repository.CancelImportBatchAsync(batchId, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return result switch
            {
                "CANCELLED" => Results.Ok(new { batchId, status = "CANCELADA" }),
                "NOT_FOUND" => Results.NotFound(),
                _ => Results.Conflict(new { message = "El lote no puede cancelarse en su estado actual." })
            };
        });

        app.MapPost("/api/portal/imports/{batchId:long}/confirm", async (long batchId, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("IMPORTS", "MANAGE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            var result = await repository.ConfirmImportBatchAsync(batchId, userContext.User!.Id, userContext.User.Username, cancellationToken);
            return result switch
            {
                "IMPORTED" => Results.Ok(new { batchId, status = "IMPORTADA" }),
                "NOT_FOUND" => Results.NotFound(),
                _ => Results.Conflict(new { message = "El lote no puede confirmarse en su estado actual." })
            };
        });

        app.MapPost("/api/portal/imports/prevalidate", async (
            HttpRequest request,
            PortalAuthorizationService authorization,
            EmployeeCsvPrevalidationService prevalidationService,
            EmployeeXlsxPrevalidationService xlsxPrevalidationService,
            PostgresPortalRepository repository,
            RequestUserContext userContext,
            CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("IMPORTS", "PREVALIDATE", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!await repository.CanConnectAsync(cancellationToken))
            {
                return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
            }

            if (!request.HasFormContentType)
            {
                return Results.BadRequest(new { message = "La solicitud debe enviar un archivo CSV multipart/form-data." });
            }

            var form = await request.ReadFormAsync(cancellationToken);
            var file = form.Files.GetFile("file");

            if (file is null || file.Length == 0)
            {
                return Results.BadRequest(new { message = "Debe seleccionar un archivo CSV con contenido." });
            }

            var extension = Path.GetExtension(file.FileName);
            if (!extension.Equals(".csv", StringComparison.OrdinalIgnoreCase)
                && !extension.Equals(".xlsx", StringComparison.OrdinalIgnoreCase))
            {
                return Results.BadRequest(new { message = "La prevalidacion soporta archivos CSV y XLSX." });
            }

            if (file.Length > 10 * 1024 * 1024)
            {
                return Results.BadRequest(new { message = "El archivo supera el limite de 10 MB." });
            }

            var existingIdentificationKeys = await repository.GetExistingIdentificationKeysAsync(cancellationToken);
            await using var stream = file.OpenReadStream();
            ImportPrevalidationResult result;
            try
            {
                result = extension.Equals(".xlsx", StringComparison.OrdinalIgnoreCase)
                    ? xlsxPrevalidationService.Prevalidate(stream, Path.GetFileName(file.FileName), existingIdentificationKeys)
                    : prevalidationService.Prevalidate(stream, Path.GetFileName(file.FileName), existingIdentificationKeys);
            }
            catch (InvalidDataException exception)
            {
                return Results.BadRequest(new { message = exception.Message });
            }
            catch (Exception) when (extension.Equals(".xlsx", StringComparison.OrdinalIgnoreCase))
            {
                return Results.BadRequest(new { message = "El archivo XLSX no contiene una estructura valida." });
            }

            if (result.TotalRecords == 0)
            {
                return Results.BadRequest(new { message = "El archivo CSV no contiene registros para prevalidar." });
            }

            var response = await repository.SaveImportPrevalidationAsync(result, userContext.User!.Username, cancellationToken);
            return Results.Ok(response);
        });

        return app;
    }

    private static async Task<IResult?> RequireSchedulingConfigurationAsync(
        PortalAuthorizationService authorization,
        RequestUserContext userContext,
        CancellationToken cancellationToken)
    {
        if (userContext.User is null) return Results.Unauthorized();
        var action = userContext.User.Role.Equals("ADMIN", StringComparison.OrdinalIgnoreCase) ? "CONFIGURE" : "GENERATE";
        return await authorization.RequireAsync("SCHEDULING", action, cancellationToken);
    }

    private static bool IsActiveStatus(string? status) =>
        status?.Trim().ToUpperInvariant() is "ACTIVO" or "INACTIVO";

    private static async Task<IResult> CreateSchedulingResultAsync(Func<Task<long>> create)
    {
        try
        {
            var id = await create();
            return Results.Created($"/api/portal/scheduling/configuration/{id}", new SchedulingConfigurationResponse(id, "ACTIVO"));
        }
        catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            return Results.Conflict(new { message = "La configuracion ya existe." });
        }
        catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.ForeignKeyViolation)
        {
            return Results.BadRequest(new { message = "La configuracion referencia un registro inexistente." });
        }
    }

    private static bool TryParseRole(string role, out RoleCode parsedRole)
    {
        switch (role.ToUpperInvariant())
        {
            case "ADMIN":
                parsedRole = RoleCode.Admin;
                return true;
            case "TH":
                parsedRole = RoleCode.TalentoHumano;
                return true;
            case "GERENCIA":
                parsedRole = RoleCode.Gerencia;
                return true;
            case "OPERACIONES":
                parsedRole = RoleCode.Operaciones;
                return true;
            default:
                parsedRole = default;
                return false;
        }
    }

    private static string EscapeCsv(string? value)
    {
        var text = value ?? string.Empty;
        return text.IndexOfAny(new[] { ',', '"', '\r', '\n' }) >= 0
            ? $"\"{text.Replace("\"", "\"\"")}\""
            : text;
    }

    private static bool IsValidSignerRequest(UpsertCertificateSignerRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.FullName)
            || string.IsNullOrWhiteSpace(request.JobTitle)
            || !DateOnly.TryParse(request.ValidFrom, out var validFrom))
        {
            return false;
        }

        if (!string.IsNullOrWhiteSpace(request.ValidTo)
            && (!DateOnly.TryParse(request.ValidTo, out var validTo) || validTo < validFrom))
        {
            return false;
        }

        return true;
    }

    private static bool IsValidTrainingRequirementTypeRequest(UpsertTrainingRequirementTypeRequest request)
    {
        return !string.IsNullOrWhiteSpace(request.Name)
            && request.Category.Trim().ToUpperInvariant() is ("CURSO" or "ACREDITACION")
            && (!request.ValidityDays.HasValue || request.ValidityDays > 0);
    }

    private static bool IsValidCertificatePreviewRequest(CertificatePreviewRequest request)
    {
        if (request.EmployeeId <= 0
            || !DateOnly.TryParse(request.IssueDate, out _)
            || request.Purpose.Trim().ToUpperInvariant() is not ("ENTIDAD_FINANCIERA" or "CESANTIAS" or "CLIENTE" or "TRAMITE_GENERAL" or "INTERESADO"))
        {
            return false;
        }

        foreach (var variable in request.Variables)
        {
            if (string.IsNullOrWhiteSpace(variable.ConceptCode)
                || string.IsNullOrWhiteSpace(variable.ConceptLabel)
                || variable.Amount < 0)
            {
                return false;
            }
        }

        return true;
    }

    private static IResult InvalidScopeHashProblem() => Results.Problem(
        title: "Alcance de evaluacion invalido",
        detail: "La decision debe declarar el scopeHash exacto de la evaluacion persistida.",
        statusCode: StatusCodes.Status400BadRequest);

    private static IResult StaleScopeHashProblem() => Results.Problem(
        title: "Alcance de evaluacion obsoleto",
        detail: "El scopeHash declarado no corresponde al snapshot evaluado vigente.",
        statusCode: StatusCodes.Status409Conflict);

    private static IResult? MapCertificatePreviewError(CertificatePreviewResponse? result)
    {
        return result switch
        {
            null => Results.NotFound(new { message = "Empleado no encontrado." }),
            { CertificateType: "EMPLOYEE_NOT_ACTIVE" } => Results.Conflict(new { message = "El empleado no esta activo." }),
            { CertificateType: "MISSING_BASE_SALARY" } => Results.Conflict(new { message = "El empleado activo no tiene salario base vigente." }),
            { CertificateType: "MISSING_TERMINATION_DATE" } => Results.Conflict(new { message = "El empleado retirado no tiene fecha de retiro." }),
            { CertificateType: "MISSING_TERMINATION_REASON" } => Results.Conflict(new { message = "El empleado retirado no tiene motivo de retiro." }),
            { CertificateType: "MISSING_ACTIVE_SIGNER" } => Results.Conflict(new { message = "No existe firmante activo y vigente para la fecha de expedicion." }),
            _ => null
        };
    }

    private static async Task<IResult> ExportScheduleAsync(long versionId,string format,long? positionId,long? employeeId,PortalAuthorizationService authorization,SchedulingExportService exporter,RequestUserContext userContext,CancellationToken ct)
    {
        var denied=await authorization.RequireAsync("SCHEDULING","EXPORT",ct);if(denied is not null)return denied;
        var model=await exporter.LoadAsync(versionId,positionId,employeeId,userContext.User!.Username,ct);if(model is null)return Results.NotFound();
        var bytes=format=="pdf"?exporter.BuildPdf(model):exporter.BuildXlsx(model);await exporter.AuditAsync(versionId,userContext.User.Username,format,positionId,employeeId,ct);
        var safe=new string(model.Project.ToLowerInvariant().Select(c=>char.IsLetterOrDigit(c)?c:'-').ToArray()).Trim('-');
        return Results.File(bytes,format=="pdf"?"application/pdf":"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",$"programacion-{safe}-{model.Period[..10]}-v{model.VersionNumber}.{format}");
    }
}
