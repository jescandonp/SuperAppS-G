namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record AuditEventResponse(
    long Id,
    DateTimeOffset OccurredAt,
    string ActorUsername,
    string? ActorRole,
    string Module,
    string Action,
    string EntityType,
    string? EntityId,
    string Summary,
    IReadOnlyDictionary<string, object?> Detail);
