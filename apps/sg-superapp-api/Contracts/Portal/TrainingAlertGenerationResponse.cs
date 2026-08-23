namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record TrainingAlertGenerationResponse(
    int GeneratedCount,
    int ActiveAlertsCount,
    int SkippedCurrentCount);
