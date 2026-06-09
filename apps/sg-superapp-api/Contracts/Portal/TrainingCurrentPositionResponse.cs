namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record TrainingCurrentPositionResponse(
    long Id,
    string Name,
    string? Code,
    string? ClientText,
    string StartDate);
