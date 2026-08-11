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
