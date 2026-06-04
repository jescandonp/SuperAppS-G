namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record EmployeeSummaryResponse(
    long Id,
    string IdentificationType,
    string IdentificationNumber,
    string FullName,
    string EmploymentStatus,
    string JobTitle,
    string RecordStatus,
    decimal? CurrentBaseSalary,
    string? CurrentServicePositionText);
