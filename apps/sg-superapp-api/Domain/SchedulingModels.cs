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

public sealed record GuardSchedulingFacts(
    bool Active,
    bool HasBlockingAbsence,
    bool HasOverlap,
    bool RestRuleSatisfied,
    bool HasBlockingLocationMismatch,
    IReadOnlyList<EligibilityReason>? RequirementReasons);

public sealed record EligibilityResult(
    bool Eligible,
    bool RequiresException,
    IReadOnlyList<EligibilityReason> Reasons);
