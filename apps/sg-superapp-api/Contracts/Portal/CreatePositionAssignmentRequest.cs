namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record CreatePositionAssignmentRequest(
    long PositionId,
    string StartDate,
    string? ChangeReason,
    string? Notes);
