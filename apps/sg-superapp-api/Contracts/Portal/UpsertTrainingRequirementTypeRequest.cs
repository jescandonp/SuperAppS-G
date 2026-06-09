namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record UpsertTrainingRequirementTypeRequest(
    string? Code,
    string Name,
    string Category,
    int? ValidityDays,
    bool IsServiceRequired,
    string? Notes);
