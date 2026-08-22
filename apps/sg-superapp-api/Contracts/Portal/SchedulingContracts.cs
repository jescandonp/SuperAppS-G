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

public sealed record SchedulingClientResponse(long Id, string Code, string Name, string Status);
public sealed record SchedulingProjectResponse(long Id, long ClientId, string Code, string Name, string EffectiveFrom, string? EffectiveTo, string Status);
public sealed record CoverageRuleResponse(long Id, long PositionId, long TemplateId, string WeekdayScope, string StartsAt, string EndsAt, int RequiredGuards, string EffectiveFrom, string? EffectiveTo, string Status);
public sealed record AvailabilityExceptionResponse(long Id, long EmployeeId, string From, string To, string Kind, bool Blocking, string Reason, string Status);
public sealed record PositionRequirementResponse(long Id, long PositionId, long RequirementTypeId, string Severity, string? ResolutionDueDate, string Status);

public sealed record CreateScheduleProposalRequest(string PeriodStart, string PeriodEnd, bool AcceptedVacancy = false);
public sealed record UpdateScheduleAssignmentRequest(long? EmployeeId, string Status, IReadOnlyList<string>? Reasons, int ExpectedVersion);
public sealed record CreateScheduleExceptionRequest(
    long? AssignmentId,
    long EvaluationId,
    string RuleCode,
    string MotiveCode,
    string Reason,
    string Responsible,
    string ResolutionDate,
    int ExpectedVersion);
public sealed record ScheduleTransitionRequest(int ExpectedVersion);

public sealed record PersistedSchedulingRuleEvaluationResponse(
    long EvaluationId,
    string RuleCode,
    string Outcome,
    string Severity,
    string MessageCode,
    string Explanation,
    string ScopeHash,
    bool ExceptionAllowed);

public sealed record PersistedSchedulingRuleBatchResponse(
    long RuleProfileId,
    int ProfileVersion,
    bool Simulated,
    IReadOnlyList<PersistedSchedulingRuleEvaluationResponse> Evaluations,
    SchedulingRuleSummaryResponse Summary);

public sealed record ScheduleWorkflowResponse(
    long VersionId, long ScheduleId, long ProjectId, int VersionNumber, string Status,
    string PeriodStart, string PeriodEnd, decimal CoveragePercent, int VacancyCount,
    int ExceptionCount, bool AcceptedVacancy, string CreatedBy, string? ApprovedBy,
    string? PublishedBy, bool SelfManaged);

public sealed record ScheduleAuditResponse(
    long Id, string EventType, string ActorUsername, string CreatedAt, string Detail);
