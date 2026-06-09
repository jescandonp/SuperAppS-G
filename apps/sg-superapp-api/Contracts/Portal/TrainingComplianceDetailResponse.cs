namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record TrainingComplianceDetailResponse(
    TrainingComplianceEmployeeResponse Employee,
    TrainingCurrentPositionResponse? CurrentPosition,
    TrainingServiceEnablementResponse ServiceEnablement,
    IReadOnlyList<TrainingRecordResponse> CurrentRequirements,
    IReadOnlyList<TrainingRecordResponse> TrainingHistory);
