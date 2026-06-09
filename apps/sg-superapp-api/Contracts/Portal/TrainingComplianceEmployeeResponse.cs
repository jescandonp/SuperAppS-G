namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record TrainingComplianceEmployeeResponse(
    long EmployeeId,
    string IdentificationType,
    string IdentificationNumber,
    string FullName,
    string EmploymentStatus,
    string JobTitle);
