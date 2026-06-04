using Sg.SuperApp.Api.Contracts.Auth;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class MockIdentityService
{
    private static readonly PortalUser AdminUser = new(
        1,
        "Administrador S&G",
        "admin.sg",
        "HASH_PENDING",
        RoleCode.Admin,
        true,
        null);

    public LoginResponse Authenticate(LoginRequest request)
    {
        if (!string.Equals(request.Username, AdminUser.Username, StringComparison.OrdinalIgnoreCase) ||
            request.Password != "Admin123")
        {
            return new LoginResponse(false, "Usuario o contrasena incorrectos.", null, null);
        }

        if (!AdminUser.IsActive)
        {
            return new LoginResponse(false, "El usuario no se encuentra activo. Contacte al administrador.", null, null);
        }

        return new LoginResponse(
            true,
            "Autenticado.",
            "session-token-pending",
            ToProfile(AdminUser));
    }

    public UserProfileResponse GetCurrentUser() => ToProfile(AdminUser);

    private static UserProfileResponse ToProfile(PortalUser user) =>
        new(user.Id, user.FullName, user.Username, ToContractRole(user.Role), user.IsActive, user.LastLoginAt);

    private static string ToContractRole(RoleCode role) =>
        role switch
        {
            RoleCode.Admin => "ADMIN",
            RoleCode.TalentoHumano => "TH",
            RoleCode.Gerencia => "GERENCIA",
            RoleCode.Operaciones => "OPERACIONES",
            _ => "ADMIN"
        };
}
