namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record PortalModuleResponse(
    string Code,
    string Label,
    string Description,
    bool Enabled,
    string Status);

