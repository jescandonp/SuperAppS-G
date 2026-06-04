using Sg.SuperApp.Api.Contracts.Portal;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class MockPortalQueryService
{
    public IReadOnlyList<PortalModuleResponse> GetModules(RoleCode role)
    {
        var modules = new List<PortalModule>
        {
            new("dashboard", "Dashboard", "Vista inicial del piloto.", true, "Disponible"),
            new("employees", "Empleados / Guardas", "Consulta inicial del maestro de empleados I2.", true, "Disponible"),
            new("positions", "Puestos de Servicio", "Pendiente implementacion en I3.", true, "Pendiente"),
            new("courses", "Cursos y Acreditaciones", "Pendiente implementacion en I5.", true, "Pendiente"),
            new("certifications", "Certificaciones", "Pendiente implementacion en I4.", role is not RoleCode.Operaciones, "Pendiente"),
            new("alerts", "Alertas", "Pendiente implementacion en I6.", true, "Pendiente"),
            new("notifications", "Notificaciones", "Bandeja shell de I1.", true, "Disponible"),
            new("imports", "Cargas de Datos", "Historial y prevalidacion CSV inicial I2.", role is RoleCode.Admin or RoleCode.TalentoHumano, "Disponible"),
            new("settings", "Configuracion", "Administracion base del piloto.", role is RoleCode.Admin, "Disponible")
        };

        return modules
            .Where(module => module.Enabled)
            .Select(module => new PortalModuleResponse(module.Code, module.Label, module.Description, module.Enabled, module.Status))
            .ToList();
    }

    public IReadOnlyList<NotificationResponse> GetNotifications(string username)
    {
        return new List<NotificationResponse>
        {
            new(1, "USER", username, "Portal base activo", "El shell I1 esta disponible para pruebas internas.", "UNREAD", DateTimeOffset.UtcNow.AddMinutes(-30)),
            new(2, "ROLE", "ADMIN", "Pendiente backend real", "Se requiere conectar autenticacion y persistencia PostgreSQL.", "UNREAD", DateTimeOffset.UtcNow.AddMinutes(-10))
        };
    }
}
