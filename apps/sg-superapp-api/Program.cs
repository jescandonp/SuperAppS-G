using Sg.SuperApp.Api.Configuration;
using Sg.SuperApp.Api.Endpoints;
using Sg.SuperApp.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ApplicationOptions>(builder.Configuration.GetSection("Application"));
builder.Services.AddSingleton<MockIdentityService>();
builder.Services.AddSingleton<MockPortalQueryService>();
builder.Services.AddSingleton<PostgresPortalRepository>();
builder.Services.AddSingleton<EmployeeCsvPrevalidationService>();
builder.Services.AddSingleton<EmployeeXlsxPrevalidationService>();
builder.Services.AddSingleton<ShiftCycleProjector>();
builder.Services.AddSingleton<SchedulingEligibilityService>();
builder.Services.AddSingleton<SchedulingRecommendationEngine>();
builder.Services.AddSingleton<SchedulingExportService>();
builder.Services.AddSingleton<SchedulingRuleProfileValidator>();
builder.Services.AddSingleton<SchedulingRuleProfileRepository>();
builder.Services.AddSingleton<SchedulingRuleEvaluator>();
builder.Services.AddSingleton<SchedulingRuleHttpRepository>();
builder.Services.AddScoped<RequestUserContext>();
builder.Services.AddScoped<PortalAuthorizationService>();
builder.Services.AddCors(options =>
{
    options.AddPolicy("LocalFrontend", policy =>
    {
        policy
            .WithOrigins("http://localhost:3000", "http://127.0.0.1:3000")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

app.UseCors("LocalFrontend");
app.UseMiddleware<SessionAuthenticationMiddleware>();

app.MapGet("/", () => Results.Redirect("/api/health"));

app.MapPost("/api/portal/scheduling/recommendations/generate", async (
    Sg.SuperApp.Api.Domain.ScheduleRecommendationRequest request,
    SchedulingRecommendationEngine engine,
    PostgresPortalRepository repository,
    PortalAuthorizationService authorization,
    CancellationToken cancellationToken) =>
{
    var denied = await authorization.RequireAsync("SCHEDULING", "GENERATE", cancellationToken);
    if (denied is not null) return denied;
    try
    {
        var recommendation = engine.Generate(request);
        if (request.ScheduleVersionId is null) return Results.Ok(recommendation);
        var runId = await repository.PersistScheduleRecommendationAsync(request, recommendation, cancellationToken);
        return Results.Ok(recommendation with { RunId = runId });
    }
    catch (ArgumentException exception)
    {
        return Results.BadRequest(new { message = exception.Message });
    }
});

app.MapHealthEndpoints();
app.MapAuthEndpoints();
app.MapPortalEndpoints();
app.MapSchedulingRuleEndpoints();

app.Run();
