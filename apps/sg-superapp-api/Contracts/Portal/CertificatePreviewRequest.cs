namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record CertificatePreviewRequest(
    long EmployeeId,
    string Purpose,
    string IssueDate,
    IReadOnlyList<CertificateVariableRequest> Variables);
