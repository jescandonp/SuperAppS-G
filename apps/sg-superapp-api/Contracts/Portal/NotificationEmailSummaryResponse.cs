namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record NotificationEmailSummaryResponse(
    bool EmailAttempted,
    bool SmtpAvailable,
    bool FallbackAvailable,
    int MatchedNotifications,
    string Status,
    string Message);
