namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record UpdateEmployeeRequest(
    string FullName,
    string EmploymentStatus,
    string JobTitle,
    string HireDate,
    string? TerminationDate,
    string? TerminationReason,
    string? ContractType,
    string? Notes,
    decimal? CurrentBaseSalary,
    string? SalaryEffectiveFrom);
