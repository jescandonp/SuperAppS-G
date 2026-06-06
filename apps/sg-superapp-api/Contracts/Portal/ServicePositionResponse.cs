namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record ServicePositionResponse(
    long Id,
    string? Code,
    string Name,
    string? ClientText,
    string? LocationText,
    string Status,
    string? Notes,
    int ActiveAssignmentsCount,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
