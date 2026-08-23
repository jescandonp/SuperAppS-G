using System.Text.Json;

namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record CreateSchedulingRuleProfileRequest(
    string ProfileCode,
    int Version,
    string Origin,
    string EnvironmentScope,
    string ScopeCode,
    string EffectiveFrom,
    string? EffectiveTo,
    IReadOnlyList<CreateSchedulingRuleProfileEntryRequest?> Entries);

public sealed record CreateSchedulingRuleProfileEntryRequest(
    string RuleCode,
    JsonElement Parameters,
    JsonElement CatalogSnapshot,
    bool Enabled);

public sealed record ActivateSchedulingRuleProfileRequest(
    string ProjectCode,
    string Period,
    string EnvironmentScope);

public sealed record PreEvaluateSchedulingRulesRequest(
    long RuleProfileId,
    string ProjectCode,
    string Period,
    string EnvironmentScope,
    JsonElement Facts);

public sealed record SchedulingRuleProfileResponse(
    long Id,
    string ProfileCode,
    int Version,
    string Origin,
    string EnvironmentScope,
    string ScopeCode,
    string EffectiveFrom,
    string? EffectiveTo,
    string Status,
    string Checksum,
    bool Simulated,
    IReadOnlyList<SchedulingRuleProfileEntryResponse> Entries);

public sealed record SchedulingRuleProfileEntryResponse(
    string RuleCode,
    JsonElement Parameters,
    JsonElement CatalogSnapshot,
    bool Enabled);

public sealed record SchedulingRuleEvaluationResponse(
    string RuleCode,
    int ProfileVersion,
    string Outcome,
    string Severity,
    string MessageCode,
    string Explanation,
    string ScopeHash,
    JsonElement ParametersSnapshot,
    JsonElement FactsSnapshot,
    bool ExceptionAllowed);

public sealed record SchedulingRuleSummaryResponse(
    int Total,
    int Compliant,
    int Blocked,
    int ExceptionRequired,
    int Warning,
    int NotApplicable,
    bool CanApproveOrPublish);

public sealed record SchedulingRuleEvaluationBatchResponse(
    long RuleProfileId,
    string ProfileCode,
    int ProfileVersion,
    bool Simulated,
    IReadOnlyList<SchedulingRuleEvaluationResponse> Evaluations,
    SchedulingRuleSummaryResponse Summary);
