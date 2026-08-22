using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed record TemplateDeviationRuleDecision(
    SchedulingRuleOutcome Outcome,
    SchedulingRuleSeverity Severity,
    string MessageCode,
    string Explanation,
    bool ExceptionAllowed);

public static class SchedulingTemplateDeviationRule
{
    // Rule identity, as persisted in scheduling_rule_profile_entries.rule_code and dispatched
    // by SchedulingRuleEvaluator.
    public const string RuleCode = "I9-R07";
    private const string CompliantCode = "I9_R07_COMPLIANT";
    private const string DeviationCode = "I9_R07_DEVIATION";
    private const string MixedGuardsCode = "I9_R07_MIXED_GUARDS";
    private const string TemplateUnavailableCode = "I9_R07_TEMPLATE_UNAVAILABLE";
    private const string InvalidInputCode = "I9_R07_INVALID_INPUT";
    private const int MaximumEnumeratedCells = 5;
    private const string MissingShift = "AUSENTE";
    // Changing any of these keys changes the scopeHash the evaluator derives, which is what
    // forces an earlier approval to be revalidated instead of reused.
    private static readonly string[] ScopeHashComparisonKeys = { "templateVersion", "anchor", "cell" };
    private static readonly Regex AnonymousCode = new("^[A-Za-z0-9._:/-]{1,80}$", RegexOptions.CultureInvariant);

    // A decision is only ever valid for the scopeHash the evaluator derives from this exact
    // template, version, anchor and cell set. Any change yields a different scopeHash, so an
    // earlier approval is never reused: it is revalidated. The rule compares the proposed cells
    // against the expected sequence it receives and never infers a different template or anchor
    // in order to make a deviation disappear.
    public static TemplateDeviationRuleDecision EvaluateR07(JsonElement parameters, JsonElement catalogSnapshot, JsonElement facts)
    {
        if (!HasContract(parameters))
            return Blocked(InvalidInputCode, "La configuracion versionada de la regla de plantillas no es valida.");
        if (!TryReadCode(facts, "assignmentId", out _) || !TryReadCode(facts, "scheduleVersionId", out _) ||
            !TryReadCode(facts, "templateCode", out var templateCode) ||
            !TryReadCode(facts, "templateVersion", out var templateVersion) ||
            !TryReadDate(facts, "anchorDate", out _) ||
            !TryReadCells(facts, "expectedCells", out var expected) ||
            !TryReadCells(facts, "proposedCells", out var proposed))
            return Blocked(InvalidInputCode, "El alcance anonimo de plantilla, anclaje y celdas no es valido.");

        var guards = expected.Select(cell => cell.EmployeeId)
            .Concat(proposed.Select(cell => cell.EmployeeId))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        if (guards.Length > 1)
            return Blocked(MixedGuardsCode,
                "Un mismo alcance no puede agrupar celdas de guardas distintos; cada guarda exige su propia decision.");

        if (!CatalogAllowsTemplate(catalogSnapshot, templateCode) || expected.Count == 0)
            return Unavailable(TemplateUnavailableCode,
                "No existe una plantilla vigente y aprobada para comparar; no se presume cumplimiento.");

        var deviations = BuildDeviations(expected, proposed);
        if (deviations.Count == 0)
            return Compliant(CompliantCode,
                $"La secuencia coincide con la plantilla {templateCode} version {templateVersion} y su anclaje.");

        return ExceptionRequired(DeviationCode, Describe(templateCode, templateVersion, deviations));
    }

    private static bool HasContract(JsonElement parameters)
    {
        if (parameters.ValueKind != JsonValueKind.Object ||
            !parameters.TryGetProperty("changeInvalidatesApproval", out var invalidates) ||
            invalidates.ValueKind != JsonValueKind.True ||
            !parameters.TryGetProperty("compareBy", out var compareBy) || compareBy.ValueKind != JsonValueKind.Array)
            return false;
        var declared = compareBy.EnumerateArray()
            .Where(item => item.ValueKind == JsonValueKind.String)
            .Select(item => item.GetString() ?? string.Empty)
            .ToArray();
        return ScopeHashComparisonKeys.All(key => declared.Contains(key, StringComparer.Ordinal));
    }

    private static bool CatalogAllowsTemplate(JsonElement catalogSnapshot, string templateCode) =>
        catalogSnapshot.ValueKind == JsonValueKind.Object &&
        catalogSnapshot.TryGetProperty("templateCodes", out var codes) && codes.ValueKind == JsonValueKind.Array &&
        codes.EnumerateArray().Any(item => item.ValueKind == JsonValueKind.String &&
                                           string.Equals(item.GetString(), templateCode, StringComparison.Ordinal));

    private static IReadOnlyList<TemplateDeviation> BuildDeviations(
        IReadOnlyList<TemplateCell> expected, IReadOnlyList<TemplateCell> proposed)
    {
        var expectedByKey = expected.ToDictionary(cell => cell.Key, cell => cell, StringComparer.Ordinal);
        var proposedByKey = proposed.ToDictionary(cell => cell.Key, cell => cell, StringComparer.Ordinal);
        var deviations = new List<TemplateDeviation>();
        foreach (var key in expectedByKey.Keys.Concat(proposedByKey.Keys).Distinct(StringComparer.Ordinal))
        {
            var expectedShift = expectedByKey.TryGetValue(key, out var expectedCell) ? expectedCell.ShiftCode : MissingShift;
            var proposedShift = proposedByKey.TryGetValue(key, out var proposedCell) ? proposedCell.ShiftCode : MissingShift;
            if (string.Equals(expectedShift, proposedShift, StringComparison.Ordinal)) continue;
            var reference = expectedByKey.TryGetValue(key, out var anchor) ? anchor : proposedByKey[key];
            deviations.Add(new TemplateDeviation(reference.Date, reference.Cell, expectedShift, proposedShift));
        }
        return deviations
            .OrderBy(deviation => deviation.Date, StringComparer.Ordinal)
            .ThenBy(deviation => deviation.Cell, StringComparer.Ordinal)
            .ToArray();
    }

    private static string Describe(string templateCode, string templateVersion, IReadOnlyList<TemplateDeviation> deviations)
    {
        var enumerated = deviations.Take(MaximumEnumeratedCells)
            .Select(deviation => $"la celda {deviation.Cell} del {deviation.Date} esperaba {deviation.Expected} y propone {deviation.Proposed}");
        var remaining = deviations.Count - MaximumEnumeratedCells;
        var tail = remaining > 0
            ? $"; y {remaining.ToString(CultureInfo.InvariantCulture)} celdas mas requieren la misma decision."
            : ".";
        return $"La asignacion se aparta de la plantilla obligatoria {templateCode} version {templateVersion}: " +
               string.Join("; ", enumerated) + tail;
    }

    private static bool TryReadCells(JsonElement facts, string name, out IReadOnlyList<TemplateCell> cells)
    {
        cells = Array.Empty<TemplateCell>();
        if (facts.ValueKind != JsonValueKind.Object || !facts.TryGetProperty(name, out var raw) ||
            raw.ValueKind != JsonValueKind.Array) return false;
        var parsed = new List<TemplateCell>();
        var keys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var item in raw.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object ||
                !TryReadCode(item, "employeeId", out var employeeId) ||
                !TryReadDate(item, "date", out var date) ||
                !TryReadCode(item, "cell", out var cell) ||
                !TryReadCode(item, "shiftCode", out var shiftCode)) return false;
            var candidate = new TemplateCell(employeeId, date, cell, shiftCode);
            // A repeated coordinate would make the comparison ambiguous instead of deterministic.
            if (!keys.Add(candidate.Key)) return false;
            parsed.Add(candidate);
        }
        cells = parsed;
        return true;
    }

    private static bool TryReadCode(JsonElement source, string name, out string value)
    {
        value = string.Empty;
        if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty(name, out var property) ||
            property.ValueKind != JsonValueKind.String) return false;
        var text = property.GetString() ?? string.Empty;
        if (!AnonymousCode.IsMatch(text)) return false;
        value = text;
        return true;
    }

    private static bool TryReadDate(JsonElement source, string name, out string value)
    {
        value = string.Empty;
        if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty(name, out var property) ||
            property.ValueKind != JsonValueKind.String) return false;
        var text = property.GetString() ?? string.Empty;
        if (!DateOnly.TryParseExact(text, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
            return false;
        value = parsed.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        return true;
    }

    private static TemplateDeviationRuleDecision Compliant(string code, string explanation) =>
        new(SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO, code, explanation, false);

    private static TemplateDeviationRuleDecision Blocked(string code, string explanation) =>
        new(SchedulingRuleOutcome.BLOCKED, SchedulingRuleSeverity.BLOCKING, code, explanation, false);

    private static TemplateDeviationRuleDecision Unavailable(string code, string explanation) =>
        new(SchedulingRuleOutcome.WARNING, SchedulingRuleSeverity.ERROR, code, explanation, false);

    private static TemplateDeviationRuleDecision ExceptionRequired(string code, string explanation) =>
        new(SchedulingRuleOutcome.EXCEPTION_REQUIRED, SchedulingRuleSeverity.WARNING, code, explanation, true);

    private sealed record TemplateCell(string EmployeeId, string Date, string Cell, string ShiftCode)
    {
        public string Key => EmployeeId + "" + Date + "" + Cell;
    }

    private sealed record TemplateDeviation(string Date, string Cell, string Expected, string Proposed);
}
