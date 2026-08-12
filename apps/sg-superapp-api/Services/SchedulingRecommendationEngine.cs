using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class SchedulingRecommendationEngine
{
    public ScheduleRecommendationResult Generate(ScheduleRecommendationRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (string.IsNullOrWhiteSpace(request.IdempotencyKey))
            throw new ArgumentException("La clave de idempotencia es obligatoria.");
        if (request.Shifts is null || request.Shifts.Count == 0)
            throw new ArgumentException("Debe existir al menos un turno requerido.");

        var assignedCounts = new Dictionary<long, int>();
        var assignments = new List<ScheduleAssignmentRecommendation>();
        foreach (var shift in request.Shifts
                     .OrderBy(ParseDate)
                     .ThenBy(ParseTime)
                     .ThenBy(x => x.PositionId)
                     .ThenBy(x => x.RequiredShiftId))
        {
            var candidates = shift.Candidates ?? Array.Empty<EligibleCandidate>();
            var ranked = candidates
                .Where(x => x.Eligibility is not null && x.Eligibility.Eligible)
                .Select(candidate => new
                {
                    Candidate = candidate,
                    Score = Score(candidate, request.Weights, assignedCounts.GetValueOrDefault(candidate.EmployeeId))
                })
                .OrderByDescending(x => x.Score)
                .ThenBy(x => x.Candidate.EmployeeId)
                .ToArray();

            var selected = ranked.FirstOrDefault();
            if (selected is null)
            {
                var reasons = candidates
                    .SelectMany(x => x.Eligibility?.Reasons ?? Array.Empty<EligibilityReason>())
                    .OrderBy(x => x.Code, StringComparer.Ordinal)
                    .Select(x => $"{x.Code}: {x.Message}")
                    .Distinct(StringComparer.Ordinal)
                    .ToArray();
                assignments.Add(new(shift.RequiredShiftId, shift.PositionId, shift.Date, shift.StartsAt,
                    null, "VACANTE", null, reasons.Length == 0 ? new[] { "NO_ELIGIBLE_CANDIDATES" } : reasons));
                continue;
            }

            assignedCounts[selected.Candidate.EmployeeId] =
                assignedCounts.GetValueOrDefault(selected.Candidate.EmployeeId) + 1;
            var explanation = new List<string>
            {
                $"SCORE={selected.Score:0.####}",
                $"CONTINUITY={selected.Candidate.Continuity:0.####}",
                $"EQUITY={selected.Candidate.Equity:0.####}",
                $"ACCUMULATED_ASSIGNMENTS={assignedCounts[selected.Candidate.EmployeeId] - 1}"
            };
            explanation.AddRange(selected.Candidate.Eligibility.Reasons.Select(x => $"{x.Code}: {x.Message}"));
            assignments.Add(new(shift.RequiredShiftId, shift.PositionId, shift.Date, shift.StartsAt,
                selected.Candidate.EmployeeId, "ASIGNADA", selected.Score, explanation));
        }

        var status = assignments.Any(x => x.Status == "VACANTE") ? "COMPLETADO_CON_VACANTES" : "COMPLETADO";
        return new(null, request.IdempotencyKey.Trim(), status, assignments);
    }

    private static decimal Score(EligibleCandidate candidate, SchedulingWeights weights, int accumulatedAssignments) =>
        candidate.Continuity * weights.Continuity
        + candidate.Equity * weights.Equity
        - (candidate.AdditionalHours + accumulatedAssignments) * weights.AdditionalHoursPenalty
        - candidate.DistancePenalty * weights.DistancePenalty
        - (candidate.Eligibility.RequiresException ? weights.ExceptionPenalty : 0m)
        - candidate.PublishedScheduleChange * weights.StabilityPenalty;

    private static DateOnly ParseDate(RequiredShiftRecommendationInput shift) =>
        DateOnly.TryParse(shift.Date, out var value) ? value : throw new ArgumentException($"Fecha invalida para turno {shift.RequiredShiftId}.");

    private static TimeOnly ParseTime(RequiredShiftRecommendationInput shift) =>
        TimeOnly.TryParse(shift.StartsAt, out var value) ? value : throw new ArgumentException($"Hora invalida para turno {shift.RequiredShiftId}.");
}
