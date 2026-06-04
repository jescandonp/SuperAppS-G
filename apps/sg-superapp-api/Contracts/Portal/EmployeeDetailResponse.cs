namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record EmployeeDetailResponse(
    long Id,
    string IdentificationType,
    string IdentificationNumber,
    string FullName,
    string EmploymentStatus,
    string JobTitle,
    DateOnly? HireDate,
    DateOnly? TerminationDate,
    string? TerminationReason,
    string? ContractType,
    string? CurrentServicePositionText,
    string? Notes,
    string RecordStatus,
    decimal? CurrentBaseSalary,
    DateOnly? SalaryEffectiveFrom,
    DateOnly? SalaryEffectiveTo,
    string SalarySource);
