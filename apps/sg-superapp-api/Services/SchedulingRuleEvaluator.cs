using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Npgsql;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed record SchedulingRuleEvaluationBatch(
    long RuleProfileId,
    string ProfileCode,
    int ProfileVersion,
    bool Simulated,
    IReadOnlyList<RuleEvaluation> Evaluations,
    SchedulingRuleEvaluationSummary Summary);

public sealed record SchedulingRuleEvaluationSummary(
    int Total,
    int Compliant,
    int Blocked,
    int ExceptionRequired,
    int Warning,
    int NotApplicable,
    bool CanApproveOrPublish);

public sealed class SchedulingRuleEvaluator
{
    private const int MaximumFactsUtf8Bytes = 256 * 1024;
    private const int MaximumFactsDepth = 32;
    private const int MaximumFactsNodes = 4096;
    private static readonly IReadOnlyDictionary<string, HashSet<string>> RootFactsByRule =
        new Dictionary<string, HashSet<string>>(StringComparer.Ordinal)
    {
        ["I9-R01"] = Fields("assignmentId", "scheduleVersionId", "dailyHours", "weeklyHours", "writtenAgreement"),
        ["I9-R02"] = Fields("assignmentId", "scheduleVersionId", "previousShiftEnd", "proposedShiftStart"),
        ["I9-R03"] = Fields("assignmentId", "scheduleVersionId", "proposedShiftStart", "proposedShiftEnd", "existingIntervals"),
        ["I9-R04"] = Fields("assignmentId", "scheduleVersionId", "noveltyCodes"),
        ["I9-R05"] = Fields("assignmentId", "scheduleVersionId", "originPositionCode", "destinationPositionCode", "availableMinutes"),
        ["I9-R06"] = Fields("assignmentId", "scheduleVersionId", "employeeId", "positionCode", "shiftStart", "shiftEnd", "requirementEvaluations"),
        ["I9-R07"] = Fields("assignmentId", "scheduleVersionId", "templateCode", "templateVersion", "anchorDate", "expectedCells", "proposedCells")
    };
    private static readonly HashSet<string> AllowedRootFacts = RootFactsByRule.Values
        .SelectMany(fields => fields).ToHashSet(StringComparer.Ordinal);
    private static readonly HashSet<string> AllowedNestedFacts = Fields(
        "start", "end", "positionCode", "shiftId", "code", "status", "validFrom", "validTo", "required",
        "evidenceCode", "minutes", "prohibited", "cell", "expected", "proposed", "date", "shiftCode", "employeeId");
    private static readonly Regex AnonymousCode = new("^[A-Za-z0-9._:-]{1,80}$", RegexOptions.CultureInvariant);

    public SchedulingRuleEvaluationBatch Evaluate(
        SchedulingRuleProfile profile,
        string projectCode,
        DateOnly period,
        JsonElement facts)
    {
        if (string.IsNullOrWhiteSpace(projectCode) || facts.ValueKind != JsonValueKind.Object)
            throw new ArgumentException("Project and object-shaped facts are required for rule evaluation.");
        ValidateFacts(facts);

        var results = profile.Entries
            .Where(entry => entry.Enabled)
            .OrderBy(entry => entry.RuleCode, StringComparer.Ordinal)
            .Select(entry => CreateEvaluation(profile, entry, projectCode, period, facts))
            .ToArray();

        var summary = new SchedulingRuleEvaluationSummary(
            results.Length,
            results.Count(result => result.Outcome == SchedulingRuleOutcome.COMPLIANT),
            results.Count(result => result.Outcome == SchedulingRuleOutcome.BLOCKED),
            results.Count(result => result.Outcome == SchedulingRuleOutcome.EXCEPTION_REQUIRED),
            results.Count(result => result.Outcome == SchedulingRuleOutcome.WARNING),
            results.Count(result => result.Outcome == SchedulingRuleOutcome.NOT_APPLICABLE),
            CanApproveOrPublish: results.Length > 0 && results.All(result =>
                result.Outcome is SchedulingRuleOutcome.COMPLIANT or SchedulingRuleOutcome.NOT_APPLICABLE));

        return new SchedulingRuleEvaluationBatch(
            profile.Id,
            profile.ProfileCode,
            profile.Version,
            profile.Origin == SchedulingRuleOrigin.SIMULATED,
            results,
            summary);
    }

    private static void ValidateFacts(JsonElement facts)
    {
        if (Encoding.UTF8.GetByteCount(facts.GetRawText()) > MaximumFactsUtf8Bytes)
            throw new ArgumentException("Facts exceed the safe MVP size limit.");
        var pending = new Stack<(JsonElement Element, int Depth)>();
        pending.Push((facts, 1));
        var nodes = 0;
        while (pending.Count > 0)
        {
            var current = pending.Pop();
            if (++nodes > MaximumFactsNodes || current.Depth > MaximumFactsDepth)
                throw new ArgumentException("Facts exceed safe MVP structural limits.");
            if (current.Element.ValueKind == JsonValueKind.Object)
            {
                foreach (var property in current.Element.EnumerateObject())
                {
                    var allowed = current.Depth == 1 ? AllowedRootFacts : AllowedNestedFacts;
                    if (!allowed.Contains(property.Name))
                        throw new ArgumentException("Facts contain a field outside the anonymous rule schema.");
                    if (property.Value.ValueKind == JsonValueKind.Array)
                        foreach (var item in property.Value.EnumerateArray())
                        {
                            if (item.ValueKind == JsonValueKind.Array)
                                throw new ArgumentException("Facts cannot contain nested arrays.");
                            ValidateScalar(property.Name, item);
                        }
                    else ValidateScalar(property.Name, property.Value);
                    pending.Push((property.Value, current.Depth + 1));
                }
            }
            else if (current.Element.ValueKind == JsonValueKind.Array)
                foreach (var item in current.Element.EnumerateArray()) pending.Push((item, current.Depth + 1));
        }
    }

    private static void ValidateScalar(string propertyName, JsonElement value)
    {
        if (value.ValueKind != JsonValueKind.String) return;
        var text = value.GetString() ?? string.Empty;
        if (propertyName.EndsWith("Start", StringComparison.Ordinal) || propertyName.EndsWith("End", StringComparison.Ordinal) ||
            propertyName is "start" or "end" or "validFrom" or "validTo" or "date" or "anchorDate")
        {
            if (!DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out _) &&
                !DateOnly.TryParseExact(text, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out _))
                throw new ArgumentException("Facts contain an invalid temporal value.");
            return;
        }
        if (!AnonymousCode.IsMatch(text))
            throw new ArgumentException("Facts contain a non-anonymous free-text value.");
    }

    private static JsonElement SanitizeFacts(string ruleCode, JsonElement facts)
    {
        if (!RootFactsByRule.TryGetValue(ruleCode, out var allowed)) throw new SchedulingRuleContractException();
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream))
        {
            writer.WriteStartObject();
            foreach (var property in facts.EnumerateObject().Where(property => allowed.Contains(property.Name))
                         .OrderBy(property => property.Name, StringComparer.Ordinal))
            {
                writer.WritePropertyName(property.Name);
                property.Value.WriteTo(writer);
            }
            writer.WriteEndObject();
        }
        using var document = JsonDocument.Parse(stream.ToArray());
        return document.RootElement.Clone();
    }

    private static HashSet<string> Fields(params string[] names) => new(names, StringComparer.Ordinal);

    private static RuleEvaluation CreateEvaluation(
        SchedulingRuleProfile profile,
        SchedulingRuleProfileEntry entry,
        string projectCode,
        DateOnly period,
        JsonElement facts)
    {
        var sanitizedFacts = SanitizeFacts(entry.RuleCode, facts);
        var scopeHash = ComputeScopeHash(profile, entry, projectCode, period, sanitizedFacts);
        var decision = entry.RuleCode switch
        {
            "I9-R01" => SchedulingWorkRestRules.EvaluateR01(entry.Parameters, sanitizedFacts),
            "I9-R02" => SchedulingWorkRestRules.EvaluateR02(entry.Parameters, sanitizedFacts),
            _ => null
        };
        if (decision is not null)
            return new RuleEvaluation(
                entry.RuleCode,
                profile.Version,
                decision.Outcome,
                decision.Severity,
                decision.MessageCode,
                decision.Explanation,
                scopeHash,
                entry.Parameters.Clone(),
                sanitizedFacts,
                decision.ExceptionAllowed);

        return new RuleEvaluation(
            entry.RuleCode,
            profile.Version,
            SchedulingRuleOutcome.WARNING,
            SchedulingRuleSeverity.ERROR,
            "I9_RULE_NOT_IMPLEMENTED",
            "La regla aun no tiene evaluador funcional; no se acredita cumplimiento.",
            scopeHash,
            entry.Parameters.Clone(),
            sanitizedFacts,
            ExceptionAllowed: false);
    }

    private static string ComputeScopeHash(
        SchedulingRuleProfile profile,
        SchedulingRuleProfileEntry entry,
        string projectCode,
        DateOnly period,
        JsonElement facts)
    {
        var scope = string.Join("|", new[]
        {
            profile.Id.ToString(CultureInfo.InvariantCulture),
            profile.ProfileCode,
            profile.Version.ToString(CultureInfo.InvariantCulture),
            profile.Checksum.ToLowerInvariant(),
            profile.EnvironmentScope.ToString(),
            projectCode.Trim(),
            period.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
            entry.RuleCode,
            Canonicalize(entry.Parameters),
            Canonicalize(facts)
        });
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(scope))).ToLowerInvariant();
    }

    private static string Canonicalize(JsonElement element) => element.ValueKind switch
    {
        JsonValueKind.Object => "{" + string.Join(",", element.EnumerateObject()
            .GroupBy(property => property.Name, StringComparer.Ordinal)
            .Select(group => group.Last())
            .OrderBy(property => property.Name, StringComparer.Ordinal)
            .Select(property => JsonSerializer.Serialize(property.Name) + ":" + Canonicalize(property.Value))) + "}",
        JsonValueKind.Array => "[" + string.Join(",", element.EnumerateArray().Select(Canonicalize)) + "]",
        JsonValueKind.String => JsonSerializer.Serialize(element.GetString()),
        JsonValueKind.Number => SchedulingRuleProfileValidator.NormalizeJsonNumber(element.GetRawText()),
        JsonValueKind.True => "true",
        JsonValueKind.False => "false",
        JsonValueKind.Null => "null",
        _ => throw new ArgumentException("Facts contain an unsupported JSON value.")
    };
}

public sealed class SchedulingRuleHttpRepository
{
    private readonly string _connectionString;

    public SchedulingRuleHttpRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("Postgres")
            ?? throw new InvalidOperationException("Postgres is not configured.");
    }

    public async Task<IReadOnlyList<SchedulingRuleProfile>> LoadProfilesAsync(string projectCode, DateOnly period,
        SchedulingEnvironmentScope environment, CancellationToken cancellationToken)
    {
        const string sql = @"SELECT p.id,p.profile_code,p.version,p.origin,p.environment_scope,p.scope_code,p.effective_from,p.effective_to,p.status,p.checksum,
limits.entry_count,limits.payload_within_limits,e.rule_code,e.parameters::text,e.catalog_snapshot::text,e.enabled FROM scheduling_rule_profiles p
CROSS JOIN LATERAL (SELECT count(*) entry_count,coalesce(bool_and(
octet_length(convert_to(s.parameters::text,'UTF8'))<=@parameters_bytes AND
octet_length(convert_to(s.catalog_snapshot::text,'UTF8'))<=@catalog_bytes),TRUE) payload_within_limits
FROM scheduling_rule_profile_entries s WHERE s.rule_profile_id=p.id) limits
LEFT JOIN scheduling_rule_profile_entries e ON e.rule_profile_id=p.id AND limits.entry_count<=@maximum_entries AND limits.payload_within_limits
WHERE p.scope_code=@scope AND p.environment_scope=@environment AND p.effective_from<=@period
AND (p.effective_to IS NULL OR p.effective_to>=@period) ORDER BY p.id,e.rule_code";
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("scope", projectCode.Trim());
        command.Parameters.AddWithValue("environment", environment.ToString());
        command.Parameters.AddWithValue("period", period.ToDateTime(TimeOnly.MinValue));
        AddPayloadLimitParameters(command);
        return await ReadProfilesAsync(command, cancellationToken);
    }

    public async Task<SchedulingRuleProfile?> LoadProfileByIdAsync(long id, CancellationToken cancellationToken)
    {
        const string sql = @"SELECT p.id,p.profile_code,p.version,p.origin,p.environment_scope,p.scope_code,p.effective_from,p.effective_to,p.status,p.checksum,
limits.entry_count,limits.payload_within_limits,e.rule_code,e.parameters::text,e.catalog_snapshot::text,e.enabled FROM scheduling_rule_profiles p
CROSS JOIN LATERAL (SELECT count(*) entry_count,coalesce(bool_and(
octet_length(convert_to(s.parameters::text,'UTF8'))<=@parameters_bytes AND
octet_length(convert_to(s.catalog_snapshot::text,'UTF8'))<=@catalog_bytes),TRUE) payload_within_limits
FROM scheduling_rule_profile_entries s WHERE s.rule_profile_id=p.id) limits
LEFT JOIN scheduling_rule_profile_entries e ON e.rule_profile_id=p.id AND limits.entry_count<=@maximum_entries AND limits.payload_within_limits
WHERE p.id=@id ORDER BY e.rule_code";
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("id", id);
        AddPayloadLimitParameters(command);
        return (await ReadProfilesAsync(command, cancellationToken)).SingleOrDefault();
    }

    public async Task<bool> ActivateProfileAsync(long id, string expectedChecksum, string actor,
        CancellationToken cancellationToken)
    {
        const string sql = @"UPDATE scheduling_rule_profiles p SET status='ACTIVE',activated_by=@actor,activated_at=NOW()
WHERE p.id=@id AND p.status='DRAFT' AND p.checksum=@checksum
AND p.checksum=(SELECT encode(public.digest(convert_to(string_agg(e.rule_code||':'||i9_mvp_canonical_jsonb(e.parameters)||':'||i9_mvp_canonical_jsonb(e.catalog_snapshot),'|' ORDER BY e.rule_code),'UTF8'),'sha256'),'hex')
FROM scheduling_rule_profile_entries e WHERE e.rule_profile_id=p.id)
AND (SELECT count(*) FROM scheduling_rule_profile_entries e WHERE e.rule_profile_id=p.id)=7 RETURNING p.id";
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("id", id);
        command.Parameters.AddWithValue("checksum", expectedChecksum);
        command.Parameters.AddWithValue("actor", actor);
        return await command.ExecuteScalarAsync(cancellationToken) is not null;
    }

    public async Task<bool> RetireProfileAsync(long id, CancellationToken cancellationToken)
    {
        const string sql = "UPDATE scheduling_rule_profiles SET status='RETIRED',effective_to=CURRENT_DATE WHERE id=@id AND status='ACTIVE' AND effective_from<=CURRENT_DATE RETURNING id";
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("id", id);
        return await command.ExecuteScalarAsync(cancellationToken) is not null;
    }

    public async Task<IReadOnlyList<RuleEvaluation>> LoadEvaluationsAsync(long scheduleVersionId,
        CancellationToken cancellationToken)
    {
        const string sql = @"SELECT rule_code,p.version,outcome,severity,message_code,explanation,scope_hash,
parameters_snapshot::text,facts_snapshot::text,exception_allowed FROM scheduling_rule_evaluations e
JOIN scheduling_rule_profiles p ON p.id=e.rule_profile_id WHERE schedule_version_id=@version ORDER BY rule_code,scope_hash";
        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("version", scheduleVersionId);
        var results = new List<RuleEvaluation>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
            results.Add(new RuleEvaluation(reader.GetString(0), reader.GetInt32(1),
                ParseStoredEnum<SchedulingRuleOutcome>(reader.GetString(2)),
                ParseStoredEnum<SchedulingRuleSeverity>(reader.GetString(3)), reader.GetString(4), reader.GetString(5),
                reader.GetString(6), ReadJson(reader.GetString(7)), ReadJson(reader.GetString(8)), reader.GetBoolean(9)));
        return results;
    }

    public async Task<IReadOnlyList<SchedulingRuleProfile>> LoadProfilesForEvaluationsAsync(long scheduleVersionId,
        CancellationToken cancellationToken)
    {
        const string sql = "SELECT DISTINCT rule_profile_id FROM scheduling_rule_evaluations WHERE schedule_version_id=@version ORDER BY rule_profile_id";
        var profileIds = new List<long>();
        await using (var connection = new NpgsqlConnection(_connectionString))
        {
            await connection.OpenAsync(cancellationToken);
            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("version", scheduleVersionId);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken)) profileIds.Add(reader.GetInt64(0));
        }
        var profiles = new List<SchedulingRuleProfile>(profileIds.Count);
        foreach (var profileId in profileIds)
        {
            var profile = await LoadProfileByIdAsync(profileId, cancellationToken);
            if (profile is null) throw new SchedulingRuleContractException();
            profiles.Add(profile);
        }
        return profiles;
    }

    private static async Task<IReadOnlyList<SchedulingRuleProfile>> ReadProfilesAsync(NpgsqlCommand command,
        CancellationToken cancellationToken)
    {
        var builders = new Dictionary<long, ProfileBuilder>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            if (reader.GetInt64(10) > SchedulingRuleProfileValidator.MaximumProfileEntries || !reader.GetBoolean(11))
                throw new InvalidOperationException("The rule profile payload exceeds safe MVP limits.");
            var id = reader.GetInt64(0);
            if (!builders.TryGetValue(id, out var builder))
            {
                builder = new ProfileBuilder(id, reader.GetString(1), reader.GetInt32(2),
                    ParseStoredEnum<SchedulingRuleOrigin>(reader.GetString(3)),
                    ParseStoredEnum<SchedulingEnvironmentScope>(reader.GetString(4)), reader.GetString(5),
                    DateOnly.FromDateTime(reader.GetDateTime(6)), reader.IsDBNull(7) ? null : DateOnly.FromDateTime(reader.GetDateTime(7)),
                    ParseStoredEnum<SchedulingRuleProfileStatus>(reader.GetString(8)), reader.GetString(9));
                builders.Add(id, builder);
            }
            if (!reader.IsDBNull(12))
                builder.Entries.Add(new SchedulingRuleProfileEntry(reader.GetString(12), ReadJson(reader.GetString(13)),
                    ReadJson(reader.GetString(14)), reader.GetBoolean(15)));
        }
        return builders.Values.Select(builder => builder.Build()).ToArray();
    }

    private static void AddPayloadLimitParameters(NpgsqlCommand command)
    {
        command.Parameters.AddWithValue("maximum_entries", SchedulingRuleProfileValidator.MaximumProfileEntries);
        command.Parameters.AddWithValue("parameters_bytes", SchedulingRuleProfileValidator.MaximumParametersUtf8Bytes);
        command.Parameters.AddWithValue("catalog_bytes", SchedulingRuleProfileValidator.MaximumCatalogSnapshotUtf8Bytes);
    }

    private static JsonElement ReadJson(string json)
    {
        using var document = JsonDocument.Parse(json);
        return document.RootElement.Clone();
    }

    private static T ParseStoredEnum<T>(string value) where T : struct, Enum
    {
        if (!Enum.GetNames<T>().Contains(value, StringComparer.Ordinal) || !Enum.TryParse<T>(value, out var parsed))
            throw new SchedulingRuleContractException();
        return parsed;
    }

    private sealed record ProfileBuilder(long Id, string ProfileCode, int Version, SchedulingRuleOrigin Origin,
        SchedulingEnvironmentScope EnvironmentScope, string ScopeCode, DateOnly EffectiveFrom, DateOnly? EffectiveTo,
        SchedulingRuleProfileStatus Status, string Checksum)
    {
        public List<SchedulingRuleProfileEntry> Entries { get; } = new();
        public SchedulingRuleProfile Build() => new(Id, ProfileCode, Version, Origin, EnvironmentScope, ScopeCode,
            EffectiveFrom, EffectiveTo, Status, Checksum, Entries);
    }
}
