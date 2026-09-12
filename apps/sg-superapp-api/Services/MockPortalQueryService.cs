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
            new("positions", "Puestos de Servicio", "Listado, detalle y asignaciones I3.", true, "Disponible"),
            new("courses", "Cursos y Acreditaciones", "Tipos de curso, cumplimiento y registros I5.", true, "Disponible"),
            new("certifications", "Certificaciones", "Firmantes y certificados laborales I4.", role is not RoleCode.Operaciones, "Disponible"),
            new("alerts", "Alertas", "Generadores, exportacion y fallback de correo I6.", true, "Disponible"),
            new("notifications", "Notificaciones", "Bandeja shell de I1.", true, "Disponible"),
            new("imports", "Cargas de Datos", "Historial y prevalidacion CSV inicial I2.", role is RoleCode.Admin or RoleCode.TalentoHumano, "Disponible"),
            new("audit", "Auditoria", "Consulta transversal de eventos I7.", true, "Disponible"),
            new("settings", "Configuracion", "Proximamente / En diseno para incrementos futuros.", role is RoleCode.Admin, "Pendiente")
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
            new(1, "USER", username, "Portal base activo", "El shell I1 esta disponible para pruebas internas.", "UNREAD", "SYSTEM", "INFO", "SYSTEM", null, null, DateTimeOffset.UtcNow.AddMinutes(-30), null, null, null, null),
            new(2, "ROLE", "ADMIN", "Pendiente backend real", "Se requiere conectar autenticacion y persistencia PostgreSQL.", "UNREAD", "SYSTEM", "INFO", "SYSTEM", null, null, DateTimeOffset.UtcNow.AddMinutes(-10), null, null, null, null)
        };
    }
}
