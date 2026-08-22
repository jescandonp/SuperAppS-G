using System.Text.Json;
using System.Text.RegularExpressions;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class SchedulingEligibilityService
{
    private static readonly Regex ScopeHashPattern = new("^[0-9a-f]{64}$", RegexOptions.CultureInvariant);
    private readonly SchedulingRuleEvaluator _evaluator;

    public SchedulingEligibilityService(SchedulingRuleEvaluator evaluator) =>
        _evaluator = evaluator ?? throw new ArgumentNullException(nameof(evaluator));

    // Generation path: evaluate the versioned rules here and project the result, instead of
    // trusting a caller to report its own verdicts.
    public EligibilityResult EvaluateAgainstRules(
        SchedulingRuleProfile profile,
        string projectCode,
        DateOnly period,
        JsonElement facts,
        bool active,
        IReadOnlyList<EligibilityReason>? requirementReasons = null)
    {
        var batch = _evaluator.Evaluate(profile, projectCode, period, facts);
        return Evaluate(new GuardSchedulingFacts(
            active, batch.RuleProfileId, batch.ProfileVersion, batch.Simulated,
            ToReferences(batch), requirementReasons));
    }

    public static IReadOnlyList<RuleEvaluationReference> ToReferences(SchedulingRuleEvaluationBatch batch)
    {
        ArgumentNullException.ThrowIfNull(batch);
        return batch.Evaluations.Select(evaluation => new RuleEvaluationReference(
            evaluation.RuleCode, evaluation.ProfileVersion, evaluation.Outcome.ToString(),
            evaluation.Severity.ToString(), evaluation.MessageCode, evaluation.Explanation,
            evaluation.ScopeHash, evaluation.ExceptionAllowed)).ToArray();
    }

    // Eligibility is a projection of the versioned evaluation produced by SchedulingRuleEvaluator,
    // never a second opinion. Isolated booleans used to travel beside it and could contradict the
    // rules outright: a caller could deny a shift crossing while I9-R03 blocked on it. They are
    // gone; when the versioned evaluation is absent the guard is blocked, never presumed compliant.
    public EligibilityResult Evaluate(GuardSchedulingFacts facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        var reasons = new List<EligibilityReason>();

        if (!facts.Active)
            reasons.Add(new("EMPLOYEE_INACTIVE", "BLOCKING", "Guarda inactivo."));

        if (facts.RuleProfileId <= 0 || facts.RuleProfileVersion <= 0)
            reasons.Add(new("RULE_PROFILE_MISSING", "BLOCKING",
                "La decision no declara el perfil de reglas versionado que la respalda."));

        var evaluations = facts.RuleEvaluations ?? Array.Empty<RuleEvaluationReference>();
        if (evaluations.Count == 0)
            reasons.Add(new("RULE_EVALUATION_MISSING", "BLOCKING",
                "No hay evaluacion versionada vigente; no se presume cumplimiento."));

        foreach (var evaluation in evaluations.OrderBy(item => item.RuleCode, StringComparer.Ordinal))
            reasons.AddRange(Project(evaluation, facts.RuleProfileVersion));

        foreach (var reason in facts.RequirementReasons ?? Array.Empty<EligibilityReason>())
        {
            if (string.IsNullOrWhiteSpace(reason.Code) || string.IsNullOrWhiteSpace(reason.Message))
                throw new ArgumentException("Cada razon de requisito debe incluir codigo y mensaje.");

            reasons.Add(new EligibilityReason(reason.Code.Trim(), NormalizeSeverity(reason.Severity), reason.Message.Trim()));
        }

        var blocked = reasons.Any(reason => reason.Severity == "BLOCKING");
        var requiresException = reasons.Any(reason => reason.Severity == "SUBSANABLE");
        return new EligibilityResult(!blocked, requiresException, reasons);
    }

    private static IEnumerable<EligibilityReason> Project(RuleEvaluationReference evaluation, int profileVersion)
    {
        if (evaluation is null || string.IsNullOrWhiteSpace(evaluation.RuleCode) ||
            string.IsNullOrWhiteSpace(evaluation.MessageCode) || string.IsNullOrWhiteSpace(evaluation.Explanation) ||
            !ScopeHashPattern.IsMatch(evaluation.ScopeHash ?? string.Empty) ||
            evaluation.RuleProfileVersion != profileVersion)
        {
            // An evaluation that does not identify its rule, its message, its scope or the exact
            // profile version it came from cannot be trusted to describe anything.
            yield return new EligibilityReason("RULE_EVALUATION_UNTRUSTED", "BLOCKING",
                "Una evaluacion versionada no declara regla, mensaje, alcance o version coherentes.");
            yield break;
        }

        switch (evaluation.Outcome)
        {
            case "COMPLIANT":
            case "NOT_APPLICABLE":
                break;
            case "EXCEPTION_REQUIRED":
                yield return new EligibilityReason(evaluation.MessageCode, "SUBSANABLE", evaluation.Explanation);
                break;
            case "BLOCKED":
                yield return new EligibilityReason(evaluation.MessageCode, "BLOCKING", evaluation.Explanation);
                break;
            case "WARNING":
                // An unverified rule accredits nothing. Assigning a candidate under it would mean
                // choosing without knowing whether the rule is satisfied, which is the presumption
                // the MVP forbids.
                yield return new EligibilityReason(evaluation.MessageCode, "BLOCKING", evaluation.Explanation);
                break;
            default:
                yield return new EligibilityReason("RULE_EVALUATION_UNTRUSTED", "BLOCKING",
                    "Una evaluacion versionada declara un resultado fuera del contrato.");
                break;
        }
    }

    private static string NormalizeSeverity(string severity) => severity?.Trim().ToUpperInvariant() switch
    {
        "BLOQUEANTE" or "BLOCKING" => "BLOCKING",
        "SUBSANABLE" => "SUBSANABLE",
        "INFORMATIVA" => "INFORMATIVA",
        _ => throw new ArgumentException("La severidad debe ser BLOQUEANTE, SUBSANABLE o INFORMATIVA.")
    };
}
