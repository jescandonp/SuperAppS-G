namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record UpsertServicePositionRequest(
    string? Code,
    string Name,
    string? ClientText,
    string? LocationText,
    string? Notes);
