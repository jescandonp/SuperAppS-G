namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record CertificateVariableResponse(
    string ConceptCode,
    string ConceptLabel,
    decimal Amount,
    string? Notes);
