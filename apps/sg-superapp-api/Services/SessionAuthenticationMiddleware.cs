namespace Sg.SuperApp.Api.Services;

public sealed class SessionAuthenticationMiddleware
{
    private readonly RequestDelegate _next;

    public SessionAuthenticationMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(
        HttpContext context,
        RequestUserContext userContext,
        PostgresPortalRepository repository)
    {
        var authorization = context.Request.Headers.Authorization.FirstOrDefault();
        if (authorization?.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) == true)
        {
            var token = authorization["Bearer ".Length..].Trim();
            userContext.User = await repository.GetSessionUserAsync(token, context.RequestAborted);
        }

        await _next(context);
    }
}
