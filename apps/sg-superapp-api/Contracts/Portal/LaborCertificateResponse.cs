namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record LaborCertificateResponse(
    long Id,
    string CertificateNumber,
    long EmployeeId,
    long SignerId,
    string CertificateType,
    string Purpose,
    string Status,
    string IssueDate,
    string EmployeeFullName,
    string SignerFullName,
    string PreviewContent,
    string PdfFileName,
    string TemplateVersion,
    string CreatedBy,
    string? ApprovedBy,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ApprovedAt,
    DateTimeOffset? GeneratedAt,
    IReadOnlyDictionary<string, object?> Snapshot);

