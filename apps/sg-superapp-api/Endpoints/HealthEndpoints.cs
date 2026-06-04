namespace Sg.SuperApp.Api.Endpoints;

public static class HealthEndpoints
{
    public static IEndpointRouteBuilder MapHealthEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/health", () => Results.Ok(new
        {
            status = "ok",
            service = "sg-superapp-api",
            timestamp = DateTimeOffset.UtcNow
        }));

        return app;
    }
}
