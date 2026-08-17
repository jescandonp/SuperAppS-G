using System.Text.Json;
using Npgsql;
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
                    Enum.Parse<SchedulingRuleOrigin>(reader.GetString(3), true),
                    Enum.Parse<SchedulingEnvironmentScope>(reader.GetString(4), true), reader.GetString(5),
                    DateOnly.FromDateTime(reader.GetDateTime(6)),
                    reader.IsDBNull(7) ? null : DateOnly.FromDateTime(reader.GetDateTime(7)),
                    Enum.Parse<SchedulingRuleProfileStatus>(reader.GetString(8), true), reader.GetString(9));
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

    private static JsonElement ReadJson(string value)
    {
        using var document = JsonDocument.Parse(value);
        return document.RootElement.Clone();
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
