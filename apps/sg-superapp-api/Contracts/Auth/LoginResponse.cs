namespace Sg.SuperApp.Api.Contracts.Auth;

public sealed record LoginResponse(
    bool Authenticated,
    string Message,
    string? SessionToken,
    UserProfileResponse? User);

