namespace Sg.SuperApp.Api.Domain;

public sealed record ShiftCycleProjectionRequest(
    IReadOnlyList<string> Sequence,
    string AnchorDate,
    string From,
    string To,
    int PhaseOffset);

public sealed record ShiftCycleRequest(
    IReadOnlyList<string> Sequence,
    DateOnly AnchorDate,
    DateOnly From,
    DateOnly To,
    int PhaseOffset);

public sealed record ProjectedShiftDay(DateOnly Date, string ShiftCode, int StepIndex);

public sealed record EligibilityReason(string Code, string Severity, string Message);

// One persisted rule verdict, carrying the profile version and scope it was decided under so
// it can never be re-read against a different snapshot.
public sealed record RuleEvaluationReference(
    string RuleCode,
    int RuleProfileVersion,
    string Outcome,
    string Severity,
    string MessageCode,
    string Explanation,
    string ScopeHash,
    bool ExceptionAllowed);

// The rule verdicts are the facts. Isolated booleans used to live here, duplicating what I9-R02
// through I9-R05 already decide, which let a caller contradict the rules outright.
public sealed record GuardSchedulingFacts(
    bool Active,
    long RuleProfileId,
    int RuleProfileVersion,
    bool Simulated,
    IReadOnlyList<RuleEvaluationReference>? RuleEvaluations,
    IReadOnlyList<EligibilityReason>? RequirementReasons);

public sealed record EligibilityResult(
    bool Eligible,
    bool RequiresException,
    IReadOnlyList<EligibilityReason> Reasons);

public sealed record SchedulingWeights(
    decimal Continuity,
    decimal Equity,
    decimal AdditionalHoursPenalty,
    decimal DistancePenalty,
    decimal ExceptionPenalty,
    decimal StabilityPenalty);

public sealed record EligibleCandidate(
    long EmployeeId,
    EligibilityResult Eligibility,
    decimal Continuity,
    decimal Equity,
    decimal AdditionalHours,
    decimal DistancePenalty,
    decimal PublishedScheduleChange,
    IReadOnlyList<RuleEvaluationReference>? RuleEvaluations = null);

public sealed record RequiredShiftRecommendationInput(
    long RequiredShiftId,
    long PositionId,
    string Date,
    string StartsAt,
    IReadOnlyList<EligibleCandidate> Candidates);

public sealed record ScheduleRecommendationRequest(
    long? ScheduleVersionId,
    string IdempotencyKey,
    SchedulingWeights Weights,
    IReadOnlyList<RequiredShiftRecommendationInput> Shifts);

public sealed record ScheduleAssignmentRecommendation(
    long RequiredShiftId,
    long PositionId,
    string Date,
    string StartsAt,
    long? EmployeeId,
    string Status,
    decimal? Score,
    IReadOnlyList<string> RankingReasons);

public sealed record ScheduleRecommendationResult(
    long? RunId,
    string IdempotencyKey,
    string Status,
    IReadOnlyList<ScheduleAssignmentRecommendation> Assignments);
