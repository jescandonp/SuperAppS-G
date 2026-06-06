namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record LaborCertificateHistoryResponse(
    string EventType,
    string ActorUsername,
    DateTimeOffset CreatedAt,
    IReadOnlyDictionary<string, object?> Detail);

