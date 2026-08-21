using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed record NoveltyRequirementRuleDecision(
    SchedulingRuleOutcome Outcome,
    SchedulingRuleSeverity Severity,
    string MessageCode,
    string Explanation,
    bool ExceptionAllowed);

public static class SchedulingNoveltyRequirementRules
{
    private const string R04 = "I9_R04";
    private const string R06 = "I9_R06";
    private static readonly Regex Code = new("^[A-Za-z0-9._:/-]{1,80}$", RegexOptions.CultureInvariant);
    private static readonly HashSet<string> NoveltyCategories = new(StringComparer.Ordinal)
    {
        "INCAPACITY_ACTIVE", "VACATION_ACTIVE", "ABSENCE_CONFIRMED", "ABSENCE_PENDING",
        "TEMPORARY_ASSIGNMENT", "AVAILABLE", "ADMINISTRATIVE_EVENT", "EXPIRED_OR_CANCELLED", "UNKNOWN"
    };
    private static readonly HashSet<string> RequirementCategories = new(StringComparer.Ordinal)
    {
        "COURSE", "ACCREDITATION", "CERTIFICATION", "LICENSE_OR_PERMIT", "OTHER_REQUIREMENT"
    };

    public static NoveltyRequirementRuleDecision EvaluateR04(
        JsonElement parameters, JsonElement catalogSnapshot, JsonElement facts)
    {
        if (!HasR04Contract(parameters) || !TryReadCode(facts, "employeeId", out _) ||
            !TryReadCode(facts, "assignmentId", out _) || !TryReadCode(facts, "shiftId", out _) ||
            !TryReadTimestamp(facts, "shiftStart", out var shiftStart) ||
            !TryReadTimestamp(facts, "shiftEnd", out var shiftEnd) || shiftStart >= shiftEnd ||
            !facts.TryGetProperty("noveltyEvaluations", out var evaluations) || evaluations.ValueKind != JsonValueKind.Array)
            return R04Warning("_UNVERIFIED", "La frontera anonima R04 esta incompleta; no se presume disponibilidad.");

        var catalogState = ReadNoveltyCatalog(catalogSnapshot, out var catalog);
        if (catalogState == CatalogState.Invalid)
            return R04Blocked("_INVALID_CATALOG", "El catalogo canonico R04 es ambiguo o invalido.");
        if (catalogState == CatalogState.Missing || evaluations.GetArrayLength() == 0)
            return R04Warning("_UNVERIFIED", "No existe catalogo o evaluacion de novedades suficiente para acreditar disponibilidad.");

        var decisions = new List<NoveltyRequirementRuleDecision>();
        foreach (var item in evaluations.EnumerateArray())
        {
            if (!TryReadCode(item, "noveltyId", out _) || !TryReadCode(item, "sourceSystem", out var sourceSystem) ||
                !TryReadCode(item, "sourceCode", out var sourceCode) || !TryReadCode(item, "sourceStatus", out var sourceStatus) ||
                !TryReadCode(item, "semanticCategory", out var category) || !TryReadCode(item, "mappingVersion", out var mappingVersion) ||
                !TryReadTimestamp(item, "validFrom", out var validFrom) || !TryReadTimestamp(item, "validTo", out var validTo) ||
                validFrom >= validTo || !NoveltyCategories.Contains(category))
            {
                decisions.Add(R04Warning("_UNVERIFIED", "La novedad no contiene identidad, origen, estado, categoria, version y vigencia exactos."));
                continue;
            }

            if (sourceCode is "D" or "N" or "X")
            {
                decisions.Add(R04Warning("_NON_NOVELTY_CODE", "D, N y X son codigos de programacion y se rechazan como novedades."));
                continue;
            }

            var activeMappings = catalog.Where(row =>
                string.Equals(row.SourceSystem, sourceSystem, StringComparison.Ordinal) &&
                string.Equals(row.SourceCode, sourceCode, StringComparison.Ordinal) &&
                string.Equals(row.SourceStatus, sourceStatus, StringComparison.Ordinal) &&
                Covers(row.EffectiveFrom, row.EffectiveTo, shiftStart, shiftEnd)).ToArray();
            if (activeMappings.Length > 1)
            {
                decisions.Add(R04Blocked("_AMBIGUOUS_MAPPING", "Mas de un mapeo canonico vigente coincide con la novedad."));
                continue;
            }
            if (activeMappings.Length != 1 ||
                !string.Equals(activeMappings[0].SemanticCategory, category, StringComparison.Ordinal) ||
                !string.Equals(activeMappings[0].MappingVersion, mappingVersion, StringComparison.Ordinal))
            {
                decisions.Add(R04Warning("_UNVERIFIED", "El origen no tiene un mapeo canonico exacto y vigente; no se aproxima por texto."));
                continue;
            }

            if (category == "EXPIRED_OR_CANCELLED" || validTo <= shiftStart || validFrom >= shiftEnd)
            {
                decisions.Add(new(SchedulingRuleOutcome.NOT_APPLICABLE, SchedulingRuleSeverity.INFO,
                    R04 + "_NO_CURRENT_EFFECT", "La novedad expiro, fue cancelada o no coincide con el turno.", false));
                continue;
            }

            decisions.Add(category switch
            {
                "INCAPACITY_ACTIVE" => R04Blocked("_INCAPACITY_ACTIVE", "Existe incapacidad vigente durante el turno."),
                "VACATION_ACTIVE" => R04Blocked("_VACATION_ACTIVE", "Existe vacacion aprobada y vigente durante el turno."),
                "ABSENCE_CONFIRMED" => R04Blocked("_ABSENCE_CONFIRMED", "Existe ausencia confirmada durante el turno."),
                "ABSENCE_PENDING" => R04Exception("_ABSENCE_PENDING", "La ausencia pendiente exige excepcion ligada al alcance."),
                "TEMPORARY_ASSIGNMENT" => R04Exception("_TEMPORARY_ASSIGNMENT", "La asignacion temporal vigente exige excepcion sin reemplazar R01/R02."),
                "AVAILABLE" => new(SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO,
                    R04 + "_AVAILABLE", "El mapeo canonico exacto acredita disponibilidad para R04.", false),
                "ADMINISTRATIVE_EVENT" => new(SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO,
                    R04 + "_ADMINISTRATIVE_EVENT", "El evento administrativo es informativo segun el mapeo canonico.", false),
                _ => R04Warning("_UNVERIFIED", "La categoria canonica no acredita disponibilidad.")
            });
        }

        return decisions.OrderByDescending(R04Rank).FirstOrDefault()
            ?? R04Warning("_UNVERIFIED", "No se obtuvo una decision R04 verificable.");
    }

    public static NoveltyRequirementRuleDecision EvaluateR06(
        JsonElement parameters, JsonElement catalogSnapshot, JsonElement facts, string projectCode)
    {
        if (!HasR06Contract(parameters) || !Code.IsMatch(projectCode) ||
            !TryReadCode(facts, "employeeId", out _) || !TryReadCode(facts, "assignmentId", out _) ||
            !TryReadCode(facts, "shiftId", out _) || !TryReadCode(facts, "positionCode", out var positionCode) ||
            !TryReadTimestamp(facts, "shiftStart", out var shiftStart) ||
            !TryReadTimestamp(facts, "shiftEnd", out var shiftEnd) || shiftStart >= shiftEnd ||
            !facts.TryGetProperty("requirementEvaluations", out var evaluations) || evaluations.ValueKind != JsonValueKind.Array)
            return R06Exception("_UNVERIFIED", "La frontera anonima R06 esta incompleta.", false);

        var hrValidated = TryReadBoolean(facts, "hrValidated", out var validated) && validated;
        var catalogState = ReadRequirementCatalog(catalogSnapshot, out var catalog);
        if (catalogState == CatalogState.Invalid || HasOverlappingRequirements(catalog))
            return R06Exception("_INVALID_CATALOG", "Las versiones del catalogo R06 son invalidas o se solapan.", false);
        if (catalogState == CatalogState.Missing)
            return R06Warning("_CATALOG_INCOMPLETE", "No hay requisitos configurados; no se acredita cumplimiento.");

        var required = catalog.Where(row =>
            string.Equals(row.ProjectCode, projectCode, StringComparison.Ordinal) &&
            string.Equals(row.PositionCode, positionCode, StringComparison.Ordinal) &&
            Covers(row.EffectiveFrom, row.EffectiveTo, shiftStart, shiftEnd)).ToArray();
        if (required.Length == 0)
            return R06Warning("_CATALOG_INCOMPLETE", "No hay requisito versionado aplicable al proyecto, puesto y turno.");

        var supplied = evaluations.EnumerateArray().ToArray();
        var decisions = new List<NoveltyRequirementRuleDecision>();
        foreach (var requirement in required)
        {
            var matching = supplied.Where(item =>
                TryReadCode(item, "requirementCode", out var requirementCode) &&
                string.Equals(requirementCode, requirement.RequirementCode, StringComparison.Ordinal)).ToArray();
            if (matching.Length > 1)
            {
                decisions.Add(R06Exception("_UNVERIFIED", "Hay evidencia duplicada para un requisito.", false));
                continue;
            }
            if (matching.Length == 0)
            {
                decisions.Add(R06Exception("_MISSING", "Falta evidencia para un requisito obligatorio.", hrValidated));
                continue;
            }

            var item = matching[0];
            if (!TryReadCode(item, "category", out var category) ||
                !TryReadCode(item, "catalogVersion", out var catalogVersion) ||
                !TryReadCode(item, "evidenceState", out var evidenceState) ||
                !RequirementCategories.Contains(category) ||
                !string.Equals(category, requirement.Category, StringComparison.Ordinal) ||
                !string.Equals(catalogVersion, requirement.CatalogVersion, StringComparison.Ordinal))
            {
                decisions.Add(R06Exception("_UNVERIFIED", "La evidencia no coincide exactamente con categoria y version del catalogo.", false));
                continue;
            }

            if (evidenceState == "VERIFIED")
            {
                if (!TryReadTimestamp(item, "validFrom", out var validFrom) || !TryReadTimestamp(item, "validTo", out var validTo))
                    decisions.Add(R06Exception("_UNVERIFIED", "La evidencia verificada carece de vigencia completa.", false));
                else if (validFrom > shiftStart || validTo < shiftEnd)
                    decisions.Add(R06Exception("_EXPIRED_OR_PARTIAL", "La evidencia no permanece vigente durante todo el turno.", hrValidated));
                else decisions.Add(new(SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO,
                    R06 + "_COMPLIANT", "El requisito esta verificado y vigente durante todo el turno.", false));
                continue;
            }

            if (evidenceState == "MISSING" && requirement.InformativeRemediable &&
                TryReadBoolean(item, "informativeRemediable", out var explicitRemedial) && explicitRemedial)
            {
                var hasOwner = TryReadCode(item, "remediationOwnerRole", out _) &&
                               TryReadCode(item, "remediationOwnerKey", out _);
                var hasDueDate = TryReadDate(item, "dueDate", out _);
                decisions.Add(hasOwner && hasDueDate
                    ? R06Warning("_INFORMATIVE_REMEDIABLE", "La brecha informativa tiene responsable anonimo y fecha limite trazables.")
                    : R06Exception("_UNVERIFIED_REMEDIATION", "La remediacion informativa exige responsable anonimo y fecha limite.", false));
                continue;
            }

            decisions.Add(evidenceState switch
            {
                "MISSING" => R06Exception("_MISSING", "Falta evidencia para un requisito obligatorio.", hrValidated),
                "EXPIRED" => R06Exception("_EXPIRED_OR_PARTIAL", "La evidencia esta vencida.", hrValidated),
                "UNVERIFIED" or "UNKNOWN" => R06Exception("_UNVERIFIED", "La evidencia no esta verificada y no se aproxima.", hrValidated),
                _ => R06Exception("_UNVERIFIED", "El estado de evidencia no pertenece al contrato R06.", false)
            });
        }

        if (decisions.Any(decision => decision.Outcome == SchedulingRuleOutcome.EXCEPTION_REQUIRED))
            return decisions.First(decision => decision.Outcome == SchedulingRuleOutcome.EXCEPTION_REQUIRED);
        if (decisions.Any(decision => decision.Outcome == SchedulingRuleOutcome.WARNING))
            return decisions.First(decision => decision.Outcome == SchedulingRuleOutcome.WARNING);
        return new(SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO, R06 + "_COMPLIANT",
            "Todos los requisitos configurados estan vigentes durante todo el turno.", false);
    }

    private static bool HasR04Contract(JsonElement parameters) =>
        TryReadCode(parameters, "unknownOutcome", out var unknown) && unknown == "UNVERIFIED" &&
        TryReadBoolean(parameters, "unknownApprovalBlocked", out var blocked) && blocked;

    private static bool HasR06Contract(JsonElement parameters) =>
        TryReadBoolean(parameters, "validForEntireShift", out var entire) && entire &&
        TryReadCode(parameters, "unverifiedOutcome", out var unverified) && unverified == "EXCEPTION_REQUIRED" &&
        TryReadBoolean(parameters, "informativeRequiresOwnerAndDueDate", out var informative) && informative;

    private static CatalogState ReadNoveltyCatalog(JsonElement snapshot, out IReadOnlyList<NoveltyMapping> rows)
    {
        rows = Array.Empty<NoveltyMapping>();
        if (snapshot.ValueKind != JsonValueKind.Object || !snapshot.TryGetProperty("mappingDemo", out var raw))
            return CatalogState.Missing;
        if (raw.ValueKind != JsonValueKind.Array) return CatalogState.Invalid;
        var parsed = new List<NoveltyMapping>();
        foreach (var item in raw.EnumerateArray())
        {
            if (!TryReadCode(item, "sourceSystem", out var sourceSystem) ||
                !TryReadCode(item, "sourceCode", out var sourceCode) ||
                !TryReadCode(item, "sourceStatus", out var sourceStatus) ||
                !TryReadCode(item, "semanticCategory", out var category) || !NoveltyCategories.Contains(category) ||
                !TryReadCode(item, "mappingVersion", out var version) ||
                !TryReadTimestamp(item, "effectiveFrom", out var effectiveFrom) ||
                !TryReadOptionalTimestamp(item, "effectiveTo", out var effectiveTo) ||
                effectiveTo is not null && effectiveFrom >= effectiveTo)
                return CatalogState.Invalid;
            parsed.Add(new(sourceSystem, sourceCode, sourceStatus, category, version, effectiveFrom, effectiveTo));
        }
        rows = parsed;
        return parsed.Count == 0 ? CatalogState.Missing : CatalogState.Valid;
    }

    private static CatalogState ReadRequirementCatalog(JsonElement snapshot, out IReadOnlyList<RequirementMapping> rows)
    {
        rows = Array.Empty<RequirementMapping>();
        if (snapshot.ValueKind != JsonValueKind.Object || !snapshot.TryGetProperty("requirementsDemo", out var raw))
            return CatalogState.Missing;
        if (raw.ValueKind != JsonValueKind.Array) return CatalogState.Invalid;
        var parsed = new List<RequirementMapping>();
        foreach (var item in raw.EnumerateArray())
        {
            if (!TryReadCode(item, "projectCode", out var projectCode) ||
                !TryReadCode(item, "positionCode", out var positionCode) ||
                !TryReadCode(item, "requirementCode", out var requirementCode) ||
                !TryReadCode(item, "category", out var category) || !RequirementCategories.Contains(category) ||
                !TryReadCode(item, "catalogVersion", out var version) ||
                !TryReadTimestamp(item, "effectiveFrom", out var effectiveFrom) ||
                !TryReadOptionalTimestamp(item, "effectiveTo", out var effectiveTo) ||
                effectiveTo is not null && effectiveFrom >= effectiveTo ||
                !TryReadBoolean(item, "informativeRemediable", out var informativeRemediable))
                return CatalogState.Invalid;
            parsed.Add(new(projectCode, positionCode, requirementCode, category, version,
                effectiveFrom, effectiveTo, informativeRemediable));
        }
        rows = parsed;
        return parsed.Count == 0 ? CatalogState.Missing : CatalogState.Valid;
    }

    private static bool HasOverlappingRequirements(IReadOnlyList<RequirementMapping> rows)
    {
        foreach (var group in rows.GroupBy(row => (row.ProjectCode, row.PositionCode, row.RequirementCode)))
        {
            var ordered = group.OrderBy(row => row.EffectiveFrom).ToArray();
            for (var index = 1; index < ordered.Length; index++)
                if (ordered[index - 1].EffectiveTo is null || ordered[index].EffectiveFrom < ordered[index - 1].EffectiveTo)
                    return true;
        }
        return false;
    }

    private static int R04Rank(NoveltyRequirementRuleDecision decision) => decision.Outcome switch
    {
        SchedulingRuleOutcome.BLOCKED => 5,
        SchedulingRuleOutcome.EXCEPTION_REQUIRED => 4,
        SchedulingRuleOutcome.WARNING => 3,
        SchedulingRuleOutcome.COMPLIANT => 2,
        _ => 1
    };

    private static bool Covers(DateTimeOffset from, DateTimeOffset? to, DateTimeOffset shiftStart, DateTimeOffset shiftEnd) =>
        from <= shiftStart && (to is null || to >= shiftEnd);

    private static bool TryReadCode(JsonElement source, string name, out string value)
    {
        value = string.Empty;
        if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty(name, out var property) ||
            property.ValueKind != JsonValueKind.String) return false;
        value = property.GetString() ?? string.Empty;
        return Code.IsMatch(value);
    }

    private static bool TryReadBoolean(JsonElement source, string name, out bool value)
    {
        value = default;
        if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty(name, out var property) ||
            property.ValueKind is not (JsonValueKind.True or JsonValueKind.False)) return false;
        value = property.GetBoolean();
        return true;
    }

    private static bool TryReadDate(JsonElement source, string name, out DateOnly value)
    {
        value = default;
        return source.ValueKind == JsonValueKind.Object && source.TryGetProperty(name, out var property) &&
               property.ValueKind == JsonValueKind.String &&
               DateOnly.TryParseExact(property.GetString(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out value);
    }

    private static bool TryReadOptionalTimestamp(JsonElement source, string name, out DateTimeOffset? value)
    {
        value = null;
        if (!source.TryGetProperty(name, out var property) || property.ValueKind == JsonValueKind.Null) return true;
        if (!TryParseTimestamp(property, out var parsed)) return false;
        value = parsed;
        return true;
    }

    private static bool TryReadTimestamp(JsonElement source, string name, out DateTimeOffset value)
    {
        value = default;
        return source.ValueKind == JsonValueKind.Object && source.TryGetProperty(name, out var property) &&
               TryParseTimestamp(property, out value);
    }

    private static bool TryParseTimestamp(JsonElement property, out DateTimeOffset value)
    {
        value = default;
        if (property.ValueKind != JsonValueKind.String) return false;
        var text = property.GetString() ?? string.Empty;
        return Regex.IsMatch(text, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d{1,7})?(?:Z|[+-]\\d{2}:\\d{2})$", RegexOptions.CultureInvariant) &&
               DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out value);
    }

    private static NoveltyRequirementRuleDecision R04Blocked(string suffix, string explanation) =>
        new(SchedulingRuleOutcome.BLOCKED, SchedulingRuleSeverity.BLOCKING, R04 + suffix, explanation, false);
    private static NoveltyRequirementRuleDecision R04Exception(string suffix, string explanation) =>
        new(SchedulingRuleOutcome.EXCEPTION_REQUIRED, SchedulingRuleSeverity.WARNING, R04 + suffix, explanation, true);
    private static NoveltyRequirementRuleDecision R04Warning(string suffix, string explanation) =>
        new(SchedulingRuleOutcome.WARNING, SchedulingRuleSeverity.WARNING, R04 + suffix, explanation, false);
    private static NoveltyRequirementRuleDecision R06Exception(string suffix, string explanation, bool allowed) =>
        new(SchedulingRuleOutcome.EXCEPTION_REQUIRED, SchedulingRuleSeverity.WARNING, R06 + suffix, explanation, allowed);
    private static NoveltyRequirementRuleDecision R06Warning(string suffix, string explanation) =>
        new(SchedulingRuleOutcome.WARNING, SchedulingRuleSeverity.WARNING, R06 + suffix, explanation, false);

    private sealed record NoveltyMapping(string SourceSystem, string SourceCode, string SourceStatus,
        string SemanticCategory, string MappingVersion, DateTimeOffset EffectiveFrom, DateTimeOffset? EffectiveTo);
    private sealed record RequirementMapping(string ProjectCode, string PositionCode, string RequirementCode,
        string Category, string CatalogVersion, DateTimeOffset EffectiveFrom, DateTimeOffset? EffectiveTo,
        bool InformativeRemediable);
    private enum CatalogState { Missing, Valid, Invalid }
}
