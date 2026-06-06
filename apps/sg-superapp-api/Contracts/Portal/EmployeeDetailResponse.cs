namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record EmployeeDetailResponse(
    long Id,
    string IdentificationType,
    string IdentificationNumber,
    string FullName,
    string EmploymentStatus,
    string JobTitle,
    string? HireDate,
    string? TerminationDate,
    string? TerminationReason,
    string? ContractType,
    string? CurrentServicePositionText,
    long? CurrentServicePositionId,
    string? CurrentServicePositionName,
    string? Notes,
    string RecordStatus,
    decimal? CurrentBaseSalary,
    string? SalaryEffectiveFrom,
    string? SalaryEffectiveTo,
    string SalarySource,
    IReadOnlyList<EmployeeChangeResponse> ChangeHistory);
