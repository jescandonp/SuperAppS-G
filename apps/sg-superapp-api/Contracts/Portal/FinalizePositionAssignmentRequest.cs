namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record FinalizePositionAssignmentRequest(
    string EndDate,
    string? ChangeReason,
    string? Notes);
