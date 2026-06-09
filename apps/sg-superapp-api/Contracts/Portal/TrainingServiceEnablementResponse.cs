namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record TrainingServiceEnablementResponse(
    long EmployeeId,
    string ServiceEnablementStatus,
    int BlockingExpiredRequirementsCount,
    DateTimeOffset CalculatedAt);
