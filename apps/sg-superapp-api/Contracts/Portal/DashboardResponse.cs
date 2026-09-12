namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record DashboardResponse(
    string Role,
    DateTimeOffset GeneratedAt,
    IReadOnlyList<DashboardWidgetResponse> Widgets);
