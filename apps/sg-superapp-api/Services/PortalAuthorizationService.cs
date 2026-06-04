namespace Sg.SuperApp.Api.Services;

public sealed class PortalAuthorizationService
{
    private readonly RequestUserContext _userContext;
    private readonly PostgresPortalRepository _repository;

    public PortalAuthorizationService(RequestUserContext userContext, PostgresPortalRepository repository)
    {
        _userContext = userContext;
        _repository = repository;
    }

    public async Task<IResult?> RequireAsync(string moduleCode, string actionCode, CancellationToken cancellationToken)
    {
        if (_userContext.User is null)
        {
            return Results.Unauthorized();
        }

        var allowed = await _repository.HasPermissionAsync(_userContext.User.Id, moduleCode, actionCode, cancellationToken);
        return allowed ? null : Results.StatusCode(StatusCodes.Status403Forbidden);
    }
}
