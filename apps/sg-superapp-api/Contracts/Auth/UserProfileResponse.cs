namespace Sg.SuperApp.Api.Contracts.Auth;

public sealed record UserProfileResponse(
    long Id,
    string FullName,
    string Username,
    string Role,
    bool IsActive,
    DateTimeOffset? LastLoginAt);

