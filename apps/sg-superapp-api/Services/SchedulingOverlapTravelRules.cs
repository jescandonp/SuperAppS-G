using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed record OverlapTravelRuleDecision(
    SchedulingRuleOutcome Outcome,
    SchedulingRuleSeverity Severity,
    string MessageCode,
    string Explanation,
    bool ExceptionAllowed);

public static class SchedulingOverlapTravelRules
{
    private const string I9R03 = "I9-R03";
    private const string I9R05 = "I9-R05";
    private static readonly Regex CompleteIsoTimestamp = new(
        "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d{1,7})?(?:Z|[+-]\\d{2}:\\d{2})$",
        RegexOptions.CultureInvariant);
    private static readonly string[] OffsetTimestampFormats =
    {
        "yyyy-MM-dd'T'HH:mm:sszzz", "yyyy-MM-dd'T'HH:mm:ss.FFFFFFFzzz"
    };
    private static readonly string[] UtcTimestampFormats =
    {
        "yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm:ss.FFFFFFF'Z'"
    };
    private static readonly Regex NonNegativeInteger = new("^(?:0|[1-9]\\d*)$", RegexOptions.CultureInvariant);

    public static OverlapTravelRuleDecision EvaluateR03(JsonElement parameters, JsonElement facts)
    {
        if (!HasR03Contract(parameters) || !TryReadCode(facts, "employeeId", out var employeeId) ||
            !TryReadTimestamp(facts, "proposedShiftStart", out var proposedStart) ||
            !TryReadTimestamp(facts, "proposedShiftEnd", out var proposedEnd) || proposedStart >= proposedEnd ||
            !TryReadExistingIntervals(facts, out var existingIntervals))
            return Blocked(R03Code("_INVALID_INPUT"), "La configuracion o los intervalos anonimos no son validos.");

        var approvedOverlap = false;
        var draftOverlap = false;
        foreach (var interval in existingIntervals)
        {
            if (!IsCurrent(interval.Status) || !string.Equals(employeeId, interval.EmployeeId, StringComparison.Ordinal))
                continue;
            // Half-open intervals: adjacency is compliant because end == start is not an overlap.
            if (proposedStart < interval.End && interval.Start < proposedEnd)
            {
                approvedOverlap |= interval.Status == "APPROVED";
                draftOverlap |= interval.Status == "DRAFT";
            }
        }
        if (approvedOverlap)
            return Blocked(R03Code("_OVERLAP_APPROVED_BLOCKED"),
                "El turno se solapa con un turno aprobado vigente del mismo guarda y no admite excepcion.");
        if (draftOverlap)
            return Blocked(R03Code("_OVERLAP_DRAFT_BLOCKED"),
                "El turno se solapa con un borrador vigente del mismo guarda y no admite excepcion.");
        return Compliant(R03Code("_COMPLIANT"), "No existe solapamiento vigente para el guarda anonimo evaluado.");
    }

    public static OverlapTravelRuleDecision EvaluateR05(JsonElement parameters, JsonElement catalogSnapshot, JsonElement facts)
    {
        if (!HasR05Contract(parameters) || !TryReadCode(facts, "employeeId", out _) ||
            !TryReadCode(facts, "assignmentId", out _) || !TryReadCode(facts, "previousAssignmentId", out _) ||
            !TryReadCode(facts, "originPositionCode", out var origin) ||
            !TryReadCode(facts, "destinationPositionCode", out var destination) ||
            !TryReadTimestamp(facts, "previousShiftStart", out var previousStart) ||
            !TryReadTimestamp(facts, "previousShiftEnd", out var previousEnd) ||
            !TryReadTimestamp(facts, "proposedShiftStart", out var proposedStart) ||
            !TryReadTimestamp(facts, "proposedShiftEnd", out var proposedEnd) || previousStart >= previousEnd ||
            proposedStart >= proposedEnd)
            return Blocked(R05Code("_INVALID_INPUT"), "La configuracion o los turnos anonimos no son validos.");

        var availableTicks = (proposedStart.ToUniversalTime() - previousEnd.ToUniversalTime()).Ticks;
        if (availableTicks < 0 || availableTicks % TimeSpan.TicksPerMinute != 0)
            return Blocked(R05Code("_INVALID_GAP"), "El intervalo exacto entre turnos no es un numero entero no negativo de minutos.");
        var availableMinutes = availableTicks / TimeSpan.TicksPerMinute;

        var matrixAvailability = ReadMatrix(catalogSnapshot, out var matrix);
        if (matrixAvailability == MatrixAvailability.Missing)
            return ExceptionRequired(R05Code("_MATRIX_UNAVAILABLE"),
                "No existe una matriz versionada aplicable; nunca se presume desplazamiento cero.");
        if (matrixAvailability == MatrixAvailability.Invalid)
            return Blocked(R05Code("_INVALID_MATRIX"), "La matriz de traslado versionada no es valida.");

        if (string.Equals(origin, destination, StringComparison.Ordinal))
            return Compliant(R05Code("_SAME_POSITION"), "El mismo puesto exacto no exige desplazamiento.");

        var relation = matrix.SingleOrDefault(row => string.Equals(row.From, origin, StringComparison.Ordinal) &&
                                                   string.Equals(row.To, destination, StringComparison.Ordinal));
        if (relation is null)
            return ExceptionRequired(R05Code("_RELATION_MISSING"),
                "No hay relacion direccional aplicable; nunca se presume desplazamiento cero.");
        if (relation.Prohibited)
            return Blocked(R05Code("_PROHIBITED"), "La matriz versionada prohibe este traslado y no admite excepcion.");
        if (availableMinutes < relation.Minutes!.Value)
            return ExceptionRequired(R05Code("_EXCEPTION_REQUIRED"),
                "El tiempo disponible es menor al traslado configurado y exige excepcion ligada al alcance evaluado.");
        return Compliant(R05Code("_COMPLIANT"), "El tiempo disponible cubre el traslado direccional configurado.");
    }

    private static bool HasR03Contract(JsonElement parameters) =>
        parameters.ValueKind == JsonValueKind.Object &&
        parameters.TryGetProperty("intervalSemantics", out var semantics) && semantics.ValueKind == JsonValueKind.String &&
        string.Equals(semantics.GetString(), "HALF_OPEN", StringComparison.Ordinal) &&
        parameters.TryGetProperty("adjacentIntervalsOverlap", out var adjacent) && adjacent.ValueKind == JsonValueKind.False;

    private static bool HasR05Contract(JsonElement parameters) =>
        parameters.ValueKind == JsonValueKind.Object &&
        parameters.TryGetProperty("missingRelationOutcome", out var missing) && missing.ValueKind == JsonValueKind.String &&
        string.Equals(missing.GetString(), "EXCEPTION_REQUIRED", StringComparison.Ordinal) &&
        parameters.TryGetProperty("neverAssumeZero", out var neverAssumeZero) && neverAssumeZero.ValueKind == JsonValueKind.True &&
        parameters.TryGetProperty("directional", out var directional) && directional.ValueKind == JsonValueKind.True;

    private static bool TryReadExistingIntervals(JsonElement facts, out IReadOnlyList<ExistingInterval> intervals)
    {
        intervals = Array.Empty<ExistingInterval>();
        if (facts.ValueKind != JsonValueKind.Object || !facts.TryGetProperty("existingIntervals", out var raw) ||
            raw.ValueKind != JsonValueKind.Array) return false;
        var parsed = new List<ExistingInterval>();
        foreach (var item in raw.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object || !TryReadCode(item, "employeeId", out var employeeId) ||
                !TryReadCode(item, "status", out var status) || !IsCurrent(status) || !TryReadTimestamp(item, "start", out var start) ||
                !TryReadTimestamp(item, "end", out var end) || start >= end) return false;
            parsed.Add(new ExistingInterval(employeeId, status, start, end));
        }
        intervals = parsed;
        return true;
    }

    private static MatrixAvailability ReadMatrix(JsonElement catalogSnapshot, out IReadOnlyList<MatrixRelation> matrix)
    {
        matrix = Array.Empty<MatrixRelation>();
        if (catalogSnapshot.ValueKind != JsonValueKind.Object || !catalogSnapshot.TryGetProperty("matrixDemo", out var raw))
            return MatrixAvailability.Missing;
        if (raw.ValueKind != JsonValueKind.Array) return MatrixAvailability.Invalid;
        var parsed = new List<MatrixRelation>();
        var keys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var item in raw.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object || !TryReadCode(item, "from", out var from) ||
                !TryReadCode(item, "to", out var to) || !TryReadBoolean(item, "prohibited", out var prohibited)) return MatrixAvailability.Invalid;
            long? minutes = null;
            if (prohibited)
            {
                if (!item.TryGetProperty("minutes", out var rawMinutes) || rawMinutes.ValueKind != JsonValueKind.Null) return MatrixAvailability.Invalid;
            }
            else if (!TryReadNonNegativeInteger(item, "minutes", out var value)) return MatrixAvailability.Invalid;
            else minutes = value;
            if (!keys.Add(from + "\u001f" + to)) return MatrixAvailability.Invalid;
            parsed.Add(new MatrixRelation(from, to, minutes, prohibited));
        }
        matrix = parsed;
        return MatrixAvailability.Valid;
    }

    private static bool IsCurrent(string status) => status is "APPROVED" or "DRAFT";

    private static string R03Code(string suffix) => I9R03.Replace("-", "_", StringComparison.Ordinal) + suffix;
    private static string R05Code(string suffix) => I9R05.Replace("-", "_", StringComparison.Ordinal) + suffix;

    private static bool TryReadCode(JsonElement source, string name, out string value)
    {
        value = string.Empty;
        if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty(name, out var property) ||
            property.ValueKind != JsonValueKind.String) return false;
        value = property.GetString() ?? string.Empty;
        return !string.IsNullOrWhiteSpace(value);
    }

    private static bool TryReadBoolean(JsonElement source, string name, out bool value)
    {
        value = default;
        if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty(name, out var property) ||
            property.ValueKind is not (JsonValueKind.True or JsonValueKind.False)) return false;
        value = property.GetBoolean();
        return true;
    }

    private static bool TryReadNonNegativeInteger(JsonElement source, string name, out long value)
    {
        value = default;
        return source.ValueKind == JsonValueKind.Object && source.TryGetProperty(name, out var property) &&
               property.ValueKind == JsonValueKind.Number && NonNegativeInteger.IsMatch(property.GetRawText()) &&
               long.TryParse(property.GetRawText(), NumberStyles.None, CultureInfo.InvariantCulture, out value);
    }

    private static bool TryReadTimestamp(JsonElement source, string name, out DateTimeOffset value)
    {
        value = default;
        if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty(name, out var property) ||
            property.ValueKind != JsonValueKind.String) return false;
        var text = property.GetString() ?? string.Empty;
        if (!CompleteIsoTimestamp.IsMatch(text)) return false;
        return text.EndsWith("Z", StringComparison.Ordinal)
            ? DateTimeOffset.TryParseExact(text, UtcTimestampFormats, CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out value)
            : DateTimeOffset.TryParseExact(text, OffsetTimestampFormats, CultureInfo.InvariantCulture,
                DateTimeStyles.None, out value);
    }

    private static OverlapTravelRuleDecision Compliant(string code, string explanation) =>
        new(SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO, code, explanation, false);

    private static OverlapTravelRuleDecision Blocked(string code, string explanation) =>
        new(SchedulingRuleOutcome.BLOCKED, SchedulingRuleSeverity.BLOCKING, code, explanation, false);

    private static OverlapTravelRuleDecision ExceptionRequired(string code, string explanation) =>
        new(SchedulingRuleOutcome.EXCEPTION_REQUIRED, SchedulingRuleSeverity.WARNING, code, explanation, true);

    private sealed record ExistingInterval(string EmployeeId, string Status, DateTimeOffset Start, DateTimeOffset End);
    private sealed record MatrixRelation(string From, string To, long? Minutes, bool Prohibited);
    private enum MatrixAvailability { Missing, Valid, Invalid }
}
