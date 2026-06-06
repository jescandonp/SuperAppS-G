namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record CertificateSignerResponse(
    long Id,
    string FullName,
    string JobTitle,
    string? SignaturePath,
    string ValidFrom,
    string? ValidTo,
    string Status,
    string? Notes,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
