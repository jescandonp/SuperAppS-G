using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class SchedulingEligibilityService
{
    public EligibilityResult Evaluate(GuardSchedulingFacts facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        var reasons = new List<EligibilityReason>();

        if (!facts.Active)
            reasons.Add(new("EMPLOYEE_INACTIVE", "BLOCKING", "Guarda inactivo."));
        if (facts.HasBlockingAbsence)
            reasons.Add(new("BLOCKING_ABSENCE", "BLOCKING", "Novedad bloqueante vigente."));
        if (facts.HasOverlap)
            reasons.Add(new("SHIFT_OVERLAP", "BLOCKING", "Cruce con otro turno."));
        if (!facts.RestRuleSatisfied)
            reasons.Add(new("MINIMUM_REST", "BLOCKING", "Descanso minimo incumplido."));
        if (facts.HasBlockingLocationMismatch)
            reasons.Add(new("LOCATION_RULE", "BLOCKING", "Regla versionada de ubicacion incumplida."));

        foreach (var reason in facts.RequirementReasons ?? Array.Empty<EligibilityReason>())
        {
            if (string.IsNullOrWhiteSpace(reason.Code) || string.IsNullOrWhiteSpace(reason.Message))
                throw new ArgumentException("Cada razon de requisito debe incluir codigo y mensaje.");

            var severity = NormalizeSeverity(reason.Severity);
            reasons.Add(new EligibilityReason(reason.Code.Trim(), severity, reason.Message.Trim()));
        }

        var blocked = reasons.Any(reason => reason.Severity == "BLOCKING");
        var requiresException = reasons.Any(reason => reason.Severity == "SUBSANABLE");
        return new EligibilityResult(!blocked, requiresException, reasons);
    }

    private static string NormalizeSeverity(string severity) => severity?.Trim().ToUpperInvariant() switch
    {
        "BLOQUEANTE" or "BLOCKING" => "BLOCKING",
        "SUBSANABLE" => "SUBSANABLE",
        "INFORMATIVA" => "INFORMATIVA",
        _ => throw new ArgumentException("La severidad debe ser BLOQUEANTE, SUBSANABLE o INFORMATIVA.")
    };
}
