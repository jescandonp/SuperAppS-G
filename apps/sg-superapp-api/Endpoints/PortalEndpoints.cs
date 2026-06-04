using Sg.SuperApp.Api.Domain;
using Sg.SuperApp.Api.Services;

namespace Sg.SuperApp.Api.Endpoints;

public static class PortalEndpoints
{
    public static IEndpointRouteBuilder MapPortalEndpoints(this IEndpointRouteBuilder app)
    {
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

        app.MapGet("/api/portal/employees", async (string? search, string? status, string? jobTitle, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
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
            var employees = await repository.GetEmployeesAsync(search, status, jobTitle, includeSalary, cancellationToken);
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

        app.MapPost("/api/portal/imports/prevalidate", async (
            HttpRequest request,
            PortalAuthorizationService authorization,
            EmployeeCsvPrevalidationService prevalidationService,
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

            if (!Path.GetExtension(file.FileName).Equals(".csv", StringComparison.OrdinalIgnoreCase))
            {
                return Results.BadRequest(new { message = "La prevalidacion inicial soporta archivos CSV. Excel se habilitara en un bloque posterior." });
            }

            if (file.Length > 5 * 1024 * 1024)
            {
                return Results.BadRequest(new { message = "El archivo supera el limite inicial de 5 MB." });
            }

            var existingIdentifications = await repository.GetExistingIdentificationNumbersAsync(cancellationToken);
            await using var stream = file.OpenReadStream();
            var result = prevalidationService.Prevalidate(stream, Path.GetFileName(file.FileName), existingIdentifications);

            if (result.TotalRecords == 0)
            {
                return Results.BadRequest(new { message = "El archivo CSV no contiene registros para prevalidar." });
            }

            var response = await repository.SaveImportPrevalidationAsync(result, userContext.User!.Username, cancellationToken);
            return Results.Ok(response);
        });

        return app;
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
}
