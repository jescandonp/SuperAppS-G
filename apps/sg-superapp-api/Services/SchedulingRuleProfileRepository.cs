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
 (SELECT encode(public.digest(string_agg(x.rule_code || ':' || x.parameters::text || ':' ||
          x.catalog_snapshot::text, '|' ORDER BY x.rule_code), 'sha256'), 'hex')
    FROM scheduling_rule_profile_entries x WHERE x.rule_profile_id = p.id) AS executable_checksum,
 e.rule_code, e.parameters::text, e.catalog_snapshot::text, e.enabled
FROM scheduling_rule_profiles p
JOIN scheduling_rule_profile_entries e ON e.rule_profile_id = p.id
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

        var profiles = new Dictionary<long, ProfileBuilder>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var id = reader.GetInt64(0);
            if (!profiles.TryGetValue(id, out var profile))
            {
                if (!string.Equals(reader.GetString(9), reader.GetString(10), StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("The ACTIVE scheduling rule profile checksum is invalid.");
                profile = new ProfileBuilder(id, reader.GetString(1), reader.GetInt32(2),
                    Enum.Parse<SchedulingRuleOrigin>(reader.GetString(3), true),
                    Enum.Parse<SchedulingEnvironmentScope>(reader.GetString(4), true), reader.GetString(5),
                    DateOnly.FromDateTime(reader.GetDateTime(6)),
                    reader.IsDBNull(7) ? null : DateOnly.FromDateTime(reader.GetDateTime(7)),
                    Enum.Parse<SchedulingRuleProfileStatus>(reader.GetString(8), true), reader.GetString(9));
                profiles.Add(id, profile);
            }
            profile.Entries.Add(new SchedulingRuleProfileEntry(reader.GetString(11),
                ReadJson(reader.GetString(12)), ReadJson(reader.GetString(13)), reader.GetBoolean(14)));
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
