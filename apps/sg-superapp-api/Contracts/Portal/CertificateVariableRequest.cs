namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record CertificateVariableRequest(
    string ConceptCode,
    string ConceptLabel,
    decimal Amount,
    string? Notes);
