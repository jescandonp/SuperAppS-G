namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record ImportBatchRowResponse(
    long Id,
    int RowNumber,
    string Classification,
    string IdentificationType,
    string? IdentificationNumber,
    IReadOnlyDictionary<string, string?> NormalizedPayload,
    IReadOnlyDictionary<string, string?> SourcePayload);
