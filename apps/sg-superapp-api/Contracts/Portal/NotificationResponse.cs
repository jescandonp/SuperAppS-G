namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record NotificationResponse(
    long Id,
    string TargetType,
    string TargetKey,
    string Title,
    string Body,
    string Status,
    string SourceModule,
    string Severity,
    string SourceType,
    string? SourceId,
    string? ActionUrl,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ReadAt,
    DateTimeOffset? ArchivedAt,
    DateTimeOffset? ManagedAt,
    string? ManagedBy);
