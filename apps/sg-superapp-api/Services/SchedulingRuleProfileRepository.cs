using System.Text.Json;
using Npgsql;
using NpgsqlTypes;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class SchedulingRuleProfileRepository
{
    private readonly string _connectionString;
    private readonly SchedulingRuleProfileValidator _validator;

    public SchedulingRuleProfileRepository(IConfiguration configuration, SchedulingRuleProfileValidator validator)
    {
        _connectionString = configuration.GetConnectionString("Postgres")
            ?? throw new InvalidOperationException("Connection string 'Postgres' not configured.");
        _validator = validator;
    }

    public async Task<SchedulingRuleProfile> LoadActiveAsync(string projectCode, DateOnly period,
        SchedulingEnvironmentScope environment, CancellationToken cancellationToken = default)
    {
        const string sql = @"
SELECT p.id, p.profile_code, p.version, p.origin, p.environment_scope,
 p.scope_code, p.effective_from, p.effective_to, p.status, p.checksum,
 limits.entry_count, limits.payload_within_limits,
 e.rule_code, e.parameters::text, e.catalog_snapshot::text, e.enabled
FROM scheduling_rule_profiles p
CROSS JOIN LATERAL (
 SELECT count(*) AS entry_count,
        coalesce(bool_and(octet_length(convert_to(s.parameters::text,'UTF8')) <= @maximum_parameters_bytes
                     AND octet_length(convert_to(s.catalog_snapshot::text,'UTF8')) <= @maximum_catalog_bytes),TRUE)
          AS payload_within_limits
 FROM scheduling_rule_profile_entries s WHERE s.rule_profile_id=p.id
) limits
LEFT JOIN scheduling_rule_profile_entries e ON e.rule_profile_id = p.id
 AND limits.entry_count <= @maximum_entries AND limits.payload_within_limits
WHERE p.status = 'ACTIVE' AND p.scope_code = @project_code
 AND p.environment_scope = @environment_scope AND p.effective_from <= @period
 AND (p.effective_to IS NULL OR p.effective_to >= @period)
ORDER BY p.id, e.rule_code;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("project_code", projectCode);
        command.Parameters.AddWithValue("environment_scope", environment.ToString());
        command.Parameters.AddWithValue("period", period.ToDateTime(TimeOnly.MinValue));
        command.Parameters.AddWithValue("maximum_entries", SchedulingRuleProfileValidator.MaximumProfileEntries);
        command.Parameters.AddWithValue("maximum_parameters_bytes", SchedulingRuleProfileValidator.MaximumParametersUtf8Bytes);
        command.Parameters.AddWithValue("maximum_catalog_bytes", SchedulingRuleProfileValidator.MaximumCatalogSnapshotUtf8Bytes);

        var profiles = new Dictionary<long, ProfileBuilder>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            if (reader.GetInt64(10) > SchedulingRuleProfileValidator.MaximumProfileEntries || !reader.GetBoolean(11))
                throw new InvalidOperationException("The ACTIVE scheduling rule profile payload exceeds safe MVP limits.");
            var id = reader.GetInt64(0);
            if (!profiles.TryGetValue(id, out var profile))
            {
                profile = new ProfileBuilder(id, reader.GetString(1), reader.GetInt32(2),
                    ParseStoredEnum<SchedulingRuleOrigin>(reader.GetString(3)),
                    ParseStoredEnum<SchedulingEnvironmentScope>(reader.GetString(4)), reader.GetString(5),
                    DateOnly.FromDateTime(reader.GetDateTime(6)),
                    reader.IsDBNull(7) ? null : DateOnly.FromDateTime(reader.GetDateTime(7)),
                    ParseStoredEnum<SchedulingRuleProfileStatus>(reader.GetString(8)), reader.GetString(9));
                profiles.Add(id, profile);
            }
            if (!reader.IsDBNull(12))
                profile.Entries.Add(new SchedulingRuleProfileEntry(reader.GetString(12),
                    ReadJson(reader.GetString(13)), ReadJson(reader.GetString(14)), reader.GetBoolean(15)));
        }

        if (profiles.Count != 1)
            throw new InvalidOperationException($"Expected exactly one ACTIVE rule profile for project, period and environment; found {profiles.Count}.");
        var result = profiles.Values.Single().Build();
        _validator.Validate(result, environment);
        return result;
    }

    public async Task<SchedulingRuleProfile> CreateDraftAsync(SchedulingRuleProfile profile, string actor,
        CancellationToken cancellationToken = default)
    {
        if (profile.Status != SchedulingRuleProfileStatus.DRAFT || string.IsNullOrWhiteSpace(actor))
            throw new InvalidOperationException("Only attributed DRAFT profiles can be created.");
        _validator.Validate(profile, profile.EnvironmentScope);
        RejectPersonalData(profile);

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        try
        {
            const string profileSql = @"INSERT INTO scheduling_rule_profiles
(profile_code,version,origin,environment_scope,scope_code,effective_from,effective_to,status,checksum,created_by,created_at,approval_evidence)
VALUES(@code,@version,@origin,@environment,@scope,@from,@to,'DRAFT',@checksum,@actor,NOW(),'{}'::jsonb) RETURNING id";
            await using var profileCommand = new NpgsqlCommand(profileSql, connection, transaction);
            profileCommand.Parameters.AddWithValue("code", profile.ProfileCode);
            profileCommand.Parameters.AddWithValue("version", profile.Version);
            profileCommand.Parameters.AddWithValue("origin", profile.Origin.ToString());
            profileCommand.Parameters.AddWithValue("environment", profile.EnvironmentScope.ToString());
            profileCommand.Parameters.AddWithValue("scope", profile.ScopeCode);
            profileCommand.Parameters.Add("from", NpgsqlDbType.Date).Value = profile.EffectiveFrom.ToDateTime(TimeOnly.MinValue);
            profileCommand.Parameters.Add("to", NpgsqlDbType.Date).Value = profile.EffectiveTo is { } effectiveTo
                ? effectiveTo.ToDateTime(TimeOnly.MinValue) : DBNull.Value;
            profileCommand.Parameters.AddWithValue("checksum", profile.Checksum);
            profileCommand.Parameters.AddWithValue("actor", actor);
            var id = Convert.ToInt64(await profileCommand.ExecuteScalarAsync(cancellationToken));

            const string entrySql = @"INSERT INTO scheduling_rule_profile_entries
(rule_profile_id,rule_code,parameters,catalog_snapshot,enabled,created_at)
VALUES(@profile,@rule,@parameters,@catalog,@enabled,NOW())";
            foreach (var entry in profile.Entries.OrderBy(item => item.RuleCode, StringComparer.Ordinal))
            {
                await using var entryCommand = new NpgsqlCommand(entrySql, connection, transaction);
                entryCommand.Parameters.AddWithValue("profile", id);
                entryCommand.Parameters.AddWithValue("rule", entry.RuleCode);
                entryCommand.Parameters.Add("parameters", NpgsqlDbType.Jsonb).Value = entry.Parameters.GetRawText();
                entryCommand.Parameters.Add("catalog", NpgsqlDbType.Jsonb).Value = entry.CatalogSnapshot.GetRawText();
                entryCommand.Parameters.AddWithValue("enabled", entry.Enabled);
                await entryCommand.ExecuteNonQueryAsync(cancellationToken);
            }
            await transaction.CommitAsync(cancellationToken);
            return profile with { Id = id };
        }
        catch
        {
            try { await transaction.RollbackAsync(CancellationToken.None); } catch { }
            throw;
        }
    }

    private static JsonElement ReadJson(string value)
    {
        using var document = JsonDocument.Parse(value);
        return document.RootElement.Clone();
    }

    private static T ParseStoredEnum<T>(string value) where T : struct, Enum
    {
        if (!Enum.GetNames<T>().Contains(value, StringComparer.Ordinal) || !Enum.TryParse<T>(value, out var parsed))
            throw new SchedulingRuleContractException();
        return parsed;
    }

    private static void RejectPersonalData(SchedulingRuleProfile profile)
    {
        var forbiddenFragments = new[] { "name", "nombre", "email", "correo", "phone", "telefono", "address", "direccion", "document" };
        foreach (var root in profile.Entries.SelectMany(entry => new[] { entry.Parameters, entry.CatalogSnapshot }))
        {
            var pending = new Stack<JsonElement>();
            pending.Push(root);
            while (pending.Count > 0)
            {
                var current = pending.Pop();
                if (current.ValueKind == JsonValueKind.Object)
                    foreach (var property in current.EnumerateObject())
                    {
                        if (forbiddenFragments.Any(fragment => property.Name.Contains(fragment, StringComparison.OrdinalIgnoreCase)))
                            throw new InvalidOperationException("Rule profiles cannot contain personal data fields.");
                        if (property.Value.ValueKind == JsonValueKind.String && (property.Value.GetString() ?? string.Empty).Contains('@'))
                            throw new InvalidOperationException("Rule profiles cannot contain personal contact values.");
                        pending.Push(property.Value);
                    }
                else if (current.ValueKind == JsonValueKind.Array)
                    foreach (var item in current.EnumerateArray()) pending.Push(item);
            }
        }
    }

    private sealed record ProfileBuilder(long Id, string ProfileCode, int Version, SchedulingRuleOrigin Origin,
        SchedulingEnvironmentScope EnvironmentScope, string ScopeCode, DateOnly EffectiveFrom,
        DateOnly? EffectiveTo, SchedulingRuleProfileStatus Status, string Checksum)
    {
        public List<SchedulingRuleProfileEntry> Entries { get; } = new();
        public SchedulingRuleProfile Build() => new(Id, ProfileCode, Version, Origin, EnvironmentScope,
            ScopeCode, EffectiveFrom, EffectiveTo, Status, Checksum, Entries);
    }
}
