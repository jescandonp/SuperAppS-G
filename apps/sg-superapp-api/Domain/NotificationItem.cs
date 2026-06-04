namespace Sg.SuperApp.Api.Domain;

public sealed record NotificationItem(
    long Id,
    string TargetType,
    string TargetKey,
    string Title,
    string Body,
    string Status,
    DateTimeOffset CreatedAt);

