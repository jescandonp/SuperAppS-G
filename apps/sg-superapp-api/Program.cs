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

app.MapHealthEndpoints();
app.MapAuthEndpoints();
app.MapPortalEndpoints();

app.Run();
