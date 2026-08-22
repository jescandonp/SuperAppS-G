using System.Text.Json;

namespace Sg.SuperApp.Api.Domain;

public enum SchedulingRuleOrigin { SIMULATED, INSTITUTIONAL }
public enum SchedulingEnvironmentScope { MVP_TEST, PRODUCTION }
public enum SchedulingRuleProfileStatus { DRAFT, ACTIVE, RETIRED }
public enum SchedulingRuleOutcome { COMPLIANT, BLOCKED, EXCEPTION_REQUIRED, WARNING, NOT_APPLICABLE }
public enum SchedulingRuleSeverity { INFO, WARNING, ERROR, BLOCKING }

public sealed class SchedulingRuleContractException : Exception
{
    public SchedulingRuleContractException() : base("Stored scheduling rule data violates its contract.") { }
}

public sealed class SchedulingScopeHashMismatchException : InvalidOperationException
{
    public SchedulingScopeHashMismatchException() : base("El scopeHash declarado no corresponde al snapshot evaluado vigente.") { }
}

public sealed record SchedulingRuleProfileEntry(
    string RuleCode,
    JsonElement Parameters,
    JsonElement CatalogSnapshot,
    bool Enabled);

public sealed record SchedulingRuleProfile(
    long Id,
    string ProfileCode,
    int Version,
    SchedulingRuleOrigin Origin,
    SchedulingEnvironmentScope EnvironmentScope,
    string ScopeCode,
    DateOnly EffectiveFrom,
    DateOnly? EffectiveTo,
    SchedulingRuleProfileStatus Status,
    string Checksum,
    IReadOnlyList<SchedulingRuleProfileEntry> Entries);

public sealed record RuleEvaluation(
    string RuleCode,
    int ProfileVersion,
    SchedulingRuleOutcome Outcome,
    SchedulingRuleSeverity Severity,
    string MessageCode,
    string Explanation,
    string ScopeHash,
    JsonElement ParametersSnapshot,
    JsonElement FactsSnapshot,
    bool ExceptionAllowed);
