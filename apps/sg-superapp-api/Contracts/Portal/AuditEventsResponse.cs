namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record AuditEventsResponse(IReadOnlyList<AuditEventResponse> Events);
