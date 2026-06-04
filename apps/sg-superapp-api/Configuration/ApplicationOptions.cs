namespace Sg.SuperApp.Api.Configuration;

public sealed class ApplicationOptions
{
    public string Name { get; init; } = "S&G Super App API";
    public string BasePath { get; init; } = "/api";
    public int SessionTimeoutMinutes { get; init; } = 30;
}

