namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record NotificationEmailSummaryRequest(
    string? Status,
    string? Severity,
    string? SourceModule,
    string? Recipient);
