namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record UpsertCertificateSignerRequest(
    string FullName,
    string JobTitle,
    string? SignaturePath,
    string ValidFrom,
    string? ValidTo,
    string? Notes);
