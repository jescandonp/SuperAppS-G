namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record ImportPrevalidationRow(
    int RowNumber,
    string Classification,
    string IdentificationType,
    string? IdentificationNumber,
    IReadOnlyDictionary<string, string?> NormalizedPayload,
    IReadOnlyDictionary<string, string?> SourcePayload);
