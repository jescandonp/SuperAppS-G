namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record NotificationResponse(
    long Id,
    string TargetType,
    string TargetKey,
    string Title,
    string Body,
    string Status,
    DateTimeOffset CreatedAt);

