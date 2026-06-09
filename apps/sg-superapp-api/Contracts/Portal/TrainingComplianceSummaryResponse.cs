namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record TrainingComplianceSummaryResponse(
    long EmployeeId,
    string IdentificationNumber,
    string FullName,
    string EmploymentStatus,
    string JobTitle,
    string? CurrentPositionName,
    string ServiceEnablementStatus,
    int BlockingExpiredRequirementsCount,
    string WorstComplianceStatus,
    int ActiveRequirementsCount,
    DateTimeOffset CalculatedAt);
