namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record CreateTrainingRecordRequest(
    long RequirementTypeId,
    string CompletedAt,
    string? ExpiresAt,
    string? SupportPath,
    string? Notes);
