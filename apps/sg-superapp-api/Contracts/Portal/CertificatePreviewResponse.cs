namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record CertificatePreviewResponse(
    long EmployeeId,
    string CertificateType,
    string Purpose,
    string IssueDate,
    string EmployeeFullName,
    string IdentificationType,
    string IdentificationNumber,
    string HireDate,
    string? TerminationDate,
    string? TerminationReason,
    string JobTitle,
    string? ContractType,
    decimal? BaseSalary,
    long SignerId,
    string SignerFullName,
    string SignerJobTitle,
    IReadOnlyList<CertificateVariableResponse> Variables,
    string PreviewContent,
    IReadOnlyDictionary<string, object?> Snapshot);
