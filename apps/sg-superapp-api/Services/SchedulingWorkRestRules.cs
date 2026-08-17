using System.Globalization;
using System.Text.Json;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed record WorkRestRuleDecision(
    SchedulingRuleOutcome Outcome,
    SchedulingRuleSeverity Severity,
    string MessageCode,
    string Explanation,
    bool ExceptionAllowed);

public static class SchedulingWorkRestRules
{
    public static WorkRestRuleDecision EvaluateR01(JsonElement parameters, JsonElement facts)
    {
        if (!TryReadDecimal(parameters, "ordinaryDailyHours", out var ordinaryDailyHours) ||
            !TryReadDecimal(parameters, "ordinaryWeeklyHours", out var ordinaryWeeklyHours) ||
            !TryReadDecimal(parameters, "approvalFromDailyHours", out var approvalFromDailyHours) ||
            !TryReadDecimal(parameters, "absoluteDailyHours", out var absoluteDailyHours) ||
            !TryReadDecimal(parameters, "absoluteWeeklyHours", out var absoluteWeeklyHours) ||
            !TryReadBoolean(parameters, "writtenAgreementRequiredAboveOrdinary", out var agreementRequired) ||
            !TryReadDecimal(facts, "dailyHours", out var dailyHours) ||
            !TryReadDecimal(facts, "weeklyHours", out var weeklyHours) ||
            dailyHours < 0 || weeklyHours < 0 || ordinaryDailyHours <= 0 || ordinaryWeeklyHours <= 0 ||
            approvalFromDailyHours < ordinaryDailyHours || absoluteDailyHours < approvalFromDailyHours ||
            absoluteWeeklyHours < ordinaryWeeklyHours)
            return Blocked("I9_R01_INVALID_INPUT", "La configuracion o los hechos de jornada no son validos.");

        if (dailyHours > absoluteDailyHours || weeklyHours > absoluteWeeklyHours)
            return Blocked("I9_R01_ABSOLUTE_MAX_EXCEEDED",
                "La jornada supera un maximo absoluto diario o semanal y no admite excepcion.");

        var aboveOrdinary = dailyHours > ordinaryDailyHours || weeklyHours > ordinaryWeeklyHours;
        var hasWrittenAgreement = TryReadBoolean(facts, "writtenAgreement", out var writtenAgreement) && writtenAgreement;
        if (aboveOrdinary && agreementRequired && !hasWrittenAgreement)
            return Blocked("I9_R01_WRITTEN_AGREEMENT_REQUIRED",
                "Superar la jornada ordinaria exige marca de acuerdo escrito.");

        if (dailyHours > approvalFromDailyHours)
            return ExceptionRequired("I9_R01_EXCEPTION_REQUIRED",
                "La jornada diaria supera el umbral aprobable y requiere excepcion ligada al alcance evaluado.");

        return Compliant("I9_R01_COMPLIANT", "La jornada cumple los limites configurados.");
    }

    public static WorkRestRuleDecision EvaluateR02(JsonElement parameters, JsonElement facts)
    {
        if (!TryReadDecimal(parameters, "minimumRestHours", out var minimumRestHours) || minimumRestHours <= 0 ||
            !TryReadTimestamp(facts, "previousShiftEnd", out var previousShiftEnd) ||
            !TryReadTimestamp(facts, "proposedShiftStart", out var proposedShiftStart))
            return Blocked("I9_R02_INVALID_INPUT", "La configuracion o los hechos de descanso no son validos.");

        var restTicks = (proposedShiftStart.ToUniversalTime() - previousShiftEnd.ToUniversalTime()).Ticks;
        var restHours = (decimal)restTicks / TimeSpan.TicksPerHour;
        if (restHours < minimumRestHours)
            return ExceptionRequired("I9_R02_EXCEPTION_REQUIRED",
                "El descanso es menor al minimo configurado; permite generar, pero exige excepcion antes de aprobar o publicar.");

        return Compliant("I9_R02_COMPLIANT", "El descanso cumple el minimo configurado.");
    }

    private static bool TryReadDecimal(JsonElement source, string name, out decimal value)
    {
        value = default;
        return source.ValueKind == JsonValueKind.Object && source.TryGetProperty(name, out var property) &&
               property.ValueKind == JsonValueKind.Number && property.TryGetDecimal(out value);
    }

    private static bool TryReadBoolean(JsonElement source, string name, out bool value)
    {
        value = default;
        if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty(name, out var property) ||
            property.ValueKind is not (JsonValueKind.True or JsonValueKind.False)) return false;
        value = property.GetBoolean();
        return true;
    }

    private static bool TryReadTimestamp(JsonElement source, string name, out DateTimeOffset value)
    {
        value = default;
        if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty(name, out var property) ||
            property.ValueKind != JsonValueKind.String) return false;
        var text = property.GetString() ?? string.Empty;
        var hasExplicitOffset = text.EndsWith("Z", StringComparison.OrdinalIgnoreCase) ||
                                text.Length >= 6 && text[^3] == ':' && (text[^6] is '+' or '-');
        return hasExplicitOffset && DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture,
            DateTimeStyles.RoundtripKind, out value);
    }

    private static WorkRestRuleDecision Compliant(string code, string explanation) =>
        new(SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO, code, explanation, false);

    private static WorkRestRuleDecision Blocked(string code, string explanation) =>
        new(SchedulingRuleOutcome.BLOCKED, SchedulingRuleSeverity.BLOCKING, code, explanation, false);

    private static WorkRestRuleDecision ExceptionRequired(string code, string explanation) =>
        new(SchedulingRuleOutcome.EXCEPTION_REQUIRED, SchedulingRuleSeverity.WARNING, code, explanation, true);
}
