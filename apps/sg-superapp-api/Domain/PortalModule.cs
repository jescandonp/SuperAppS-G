namespace Sg.SuperApp.Api.Domain;

public sealed record PortalModule(
    string Code,
    string Label,
    string Description,
    bool Enabled,
    string Status);

