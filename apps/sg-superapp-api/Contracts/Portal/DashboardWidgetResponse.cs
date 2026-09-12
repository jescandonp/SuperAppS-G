namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record DashboardWidgetResponse(
    string Id,
    string Title,
    string Scope,
    string Metric,
    string? Trend,
    string Severity,
    string? ActionUrl);
