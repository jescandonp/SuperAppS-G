namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record PositionAssignmentResponse(
    long Id,
    long EmployeeId,
    long PositionId,
    string PositionName,
    string? PositionCode,
    string? ClientText,
    string StartDate,
    string? EndDate,
    string Status,
    string? ChangeReason,
    string? Notes,
    string? CreatedBy,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
