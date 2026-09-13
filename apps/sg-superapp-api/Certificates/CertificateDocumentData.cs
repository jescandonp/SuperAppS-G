using Sg.SuperApp.Api.Contracts.Portal;

namespace Sg.SuperApp.Api.Certificates;

public sealed record CertificateDocumentData(
    string CertificateNumber,
    string CertificateType,
    string Purpose,
    DateOnly IssueDate,
    string EmployeeFullName,
    string IdentificationType,
    string IdentificationNumber,
    DateOnly HireDate,
    DateOnly? TerminationDate,
    string? TerminationReason,
    string JobTitle,
    string? ContractType,
    decimal? BaseSalary,
    string? AddressedTo,
    IReadOnlyList<CertificateVariableResponse> Variables,
    string SignerFullName,
    string SignerJobTitle,
    string? SignerSignaturePath,
    string PreparedByFullName);
