using Sg.SuperApp.Api.Contracts.Auth;

namespace Sg.SuperApp.Api.Services;

public sealed class RequestUserContext
{
    public UserProfileResponse? User { get; set; }
}
