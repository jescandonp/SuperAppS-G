namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record TrainingRequirementTypeResponse(
    long Id,
    string? Code,
    string Name,
    string Category,
    int? ValidityDays,
    bool IsServiceRequired,
    string Status,
    string? Notes,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
