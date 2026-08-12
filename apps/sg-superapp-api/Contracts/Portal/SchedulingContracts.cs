namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record UpsertSchedulingClientRequest(string Code, string Name, string Status);

public sealed record UpsertSchedulingProjectRequest(
    long ClientId, string Code, string Name, string EffectiveFrom, string? EffectiveTo, string Status);

public sealed record UpsertCoverageRuleRequest(
    long PositionId, long TemplateId, string WeekdayScope, string StartsAt, string EndsAt,
    int RequiredGuards, string EffectiveFrom, string? EffectiveTo, string Status);

public sealed record UpsertAvailabilityExceptionRequest(
    long EmployeeId, string From, string To, string Kind, bool Blocking, string Reason);

public sealed record UpsertPositionRequirementRequest(
    long PositionId, long RequirementTypeId, string Severity, string? ResolutionDueDate);

public sealed record SchedulingConfigurationResponse(long Id, string Status);
