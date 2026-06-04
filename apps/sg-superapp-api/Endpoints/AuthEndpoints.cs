using Sg.SuperApp.Api.Contracts.Auth;
using Sg.SuperApp.Api.Services;

namespace Sg.SuperApp.Api.Endpoints;

public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/auth/login", async (LoginRequest request, MockIdentityService identityService, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            LoginResponse response;
            if (await repository.CanConnectAsync(cancellationToken))
            {
                response = await repository.AuthenticateAsync(request, cancellationToken)
                    ?? new LoginResponse(false, "Usuario o contrasena incorrectos.", null, null);
            }
            else
            {
                response = identityService.Authenticate(request);
            }

            return response.Authenticated ? Results.Ok(response) : Results.BadRequest(response);
        });

        app.MapGet("/api/auth/me", (RequestUserContext userContext) =>
        {
            return userContext.User is null ? Results.Unauthorized() : Results.Ok(userContext.User);
        });

        return app;
    }
}
