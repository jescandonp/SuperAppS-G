namespace Sg.SuperApp.Api.Domain;

public sealed record PortalUser(
    long Id,
    string FullName,
    string Username,
    string PasswordHash,
    RoleCode Role,
    bool IsActive,
    DateTimeOffset? LastLoginAt);

