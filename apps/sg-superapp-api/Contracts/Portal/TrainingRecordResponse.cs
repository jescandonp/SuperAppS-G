namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record TrainingRecordResponse(
    long Id,
    long EmployeeId,
    long RequirementTypeId,
    string RequirementTypeName,
    string RequirementCategory,
    string CompletedAt,
    string ExpiresAt,
    string ComplianceStatus,
    int DaysUntilExpiry,
    string? SupportPath,
    string? Notes,
    string Status,
    string CreatedBy,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
