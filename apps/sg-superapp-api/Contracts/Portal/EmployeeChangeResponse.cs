namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record EmployeeChangeResponse(
    long Id,
    string ActorUsername,
    string FieldName,
    string? PreviousValue,
    string? NewValue,
    DateTimeOffset ChangedAt);
