using System.Security.Cryptography;
using System.Text.Json;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class SchedulingRuleProfileValidator
{
    private static readonly string[] RequiredRules =
        { "I9-R01", "I9-R02", "I9-R03", "I9-R04", "I9-R05", "I9-R06", "I9-R07" };

    public void Validate(SchedulingRuleProfile profile, SchedulingEnvironmentScope requestedEnvironment,
        IEnumerable<SchedulingRuleProfile>? otherProfiles = null)
    {
        if (string.IsNullOrWhiteSpace(profile.ProfileCode) || string.IsNullOrWhiteSpace(profile.ScopeCode) ||
            profile.Version <= 0 ||
            profile.EffectiveTo.HasValue && profile.EffectiveTo.Value < profile.EffectiveFrom)
            throw new InvalidOperationException("The scheduling rule profile is incomplete.");

        var enabledCodes = profile.Entries.Where(entry => entry.Enabled).Select(entry => entry.RuleCode).ToArray();
        if (enabledCodes.Length != RequiredRules.Length ||
            enabledCodes.Distinct(StringComparer.Ordinal).Count() != RequiredRules.Length ||
            RequiredRules.Except(enabledCodes, StringComparer.Ordinal).Any())
            throw new InvalidOperationException("The profile must contain one enabled entry for I9-R01 through I9-R07.");

        if (profile.Checksum.Length != 64 || profile.Checksum.Any(character => !Uri.IsHexDigit(character)) ||
            profile.Entries.Any(entry => entry.Parameters.ValueKind != JsonValueKind.Object ||
                                         entry.CatalogSnapshot.ValueKind != JsonValueKind.Object))
            throw new InvalidOperationException("The scheduling rule profile executable content is incomplete.");

        if (profile.EnvironmentScope != requestedEnvironment ||
            profile.Origin == SchedulingRuleOrigin.SIMULATED && requestedEnvironment == SchedulingEnvironmentScope.PRODUCTION)
            throw new InvalidOperationException("A SIMULATED profile cannot be used in PRODUCTION; use MVP_TEST.");

        if (otherProfiles?.Any(other => other.Id != profile.Id &&
                other.Status == SchedulingRuleProfileStatus.ACTIVE && profile.Status == SchedulingRuleProfileStatus.ACTIVE &&
                other.ProfileCode == profile.ProfileCode && other.ScopeCode == profile.ScopeCode &&
                other.EnvironmentScope == profile.EnvironmentScope &&
                RangesOverlap(profile.EffectiveFrom, profile.EffectiveTo, other.EffectiveFrom, other.EffectiveTo)) == true)
            throw new InvalidOperationException("Active scheduling rule profile versions overlap.");

    }

    public string ComputeChecksum(SchedulingRuleProfile profile)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream))
        {
            writer.WriteStartObject();
            writer.WriteString("profileCode", profile.ProfileCode);
            writer.WriteNumber("version", profile.Version);
            writer.WriteString("origin", profile.Origin.ToString());
            writer.WriteString("environmentScope", profile.EnvironmentScope.ToString());
            writer.WriteString("scopeCode", profile.ScopeCode);
            writer.WriteString("effectiveFrom", profile.EffectiveFrom.ToString("yyyy-MM-dd"));
            if (profile.EffectiveTo is { } effectiveTo) writer.WriteString("effectiveTo", effectiveTo.ToString("yyyy-MM-dd"));
            else writer.WriteNull("effectiveTo");
            writer.WritePropertyName("entries");
            writer.WriteStartArray();
            foreach (var entry in profile.Entries.OrderBy(item => item.RuleCode, StringComparer.Ordinal))
            {
                writer.WriteStartObject();
                writer.WriteString("ruleCode", entry.RuleCode);
                writer.WriteBoolean("enabled", entry.Enabled);
                writer.WritePropertyName("parameters");
                WriteCanonicalJson(writer, entry.Parameters);
                writer.WritePropertyName("catalogSnapshot");
                WriteCanonicalJson(writer, entry.CatalogSnapshot);
                writer.WriteEndObject();
            }
            writer.WriteEndArray();
            writer.WriteEndObject();
        }
        return Convert.ToHexString(SHA256.HashData(stream.ToArray())).ToLowerInvariant();
    }

    private static bool RangesOverlap(DateOnly leftFrom, DateOnly? leftTo, DateOnly rightFrom, DateOnly? rightTo) =>
        leftFrom <= (rightTo ?? DateOnly.MaxValue) && rightFrom <= (leftTo ?? DateOnly.MaxValue);

    private static void WriteCanonicalJson(Utf8JsonWriter writer, JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            writer.WriteStartObject();
            foreach (var property in element.EnumerateObject().OrderBy(item => item.Name, StringComparer.Ordinal))
            {
                writer.WritePropertyName(property.Name);
                WriteCanonicalJson(writer, property.Value);
            }
            writer.WriteEndObject();
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            writer.WriteStartArray();
            foreach (var item in element.EnumerateArray()) WriteCanonicalJson(writer, item);
            writer.WriteEndArray();
        }
        else element.WriteTo(writer);
    }
}
