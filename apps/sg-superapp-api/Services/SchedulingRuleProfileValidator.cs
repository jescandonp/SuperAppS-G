using System.Security.Cryptography;
using System.Globalization;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using Sg.SuperApp.Api.Domain;

namespace Sg.SuperApp.Api.Services;

public sealed class SchedulingRuleProfileValidator
{
    private const int MaximumNumberDigits = 1000;
    private const int MaximumNumberScale = 1000;
    private static readonly string[] RequiredRules =
        { "I9-R01", "I9-R02", "I9-R03", "I9-R04", "I9-R05", "I9-R06", "I9-R07" };
    private static readonly JsonSerializerOptions JsonOptions = new()
        { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

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

        if (!string.Equals(profile.Checksum, ComputeChecksum(profile), StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("The scheduling rule profile checksum is invalid.");
    }

    public string ComputeChecksum(SchedulingRuleProfile profile)
    {
        var executableContent = string.Join("|", profile.Entries
            .OrderBy(entry => entry.RuleCode, StringComparer.Ordinal)
            .Select(entry => $"{entry.RuleCode}:{ToPostgresJsonbText(entry.Parameters)}:{ToPostgresJsonbText(entry.CatalogSnapshot)}"));
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(executableContent))).ToLowerInvariant();
    }

    private static bool RangesOverlap(DateOnly leftFrom, DateOnly? leftTo, DateOnly rightFrom, DateOnly? rightTo) =>
        leftFrom <= (rightTo ?? DateOnly.MaxValue) && rightFrom <= (leftTo ?? DateOnly.MaxValue);

    private static string ToPostgresJsonbText(JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                return "{" + string.Join(", ", element.EnumerateObject()
                    .OrderBy(property => property.Name, PostgresJsonbKeyComparer.Instance)
                    .Select(property => $"{JsonSerializer.Serialize(property.Name, JsonOptions)}: {ToPostgresJsonbText(property.Value)}")) + "}";
            case JsonValueKind.Array:
                return "[" + string.Join(", ", element.EnumerateArray().Select(ToPostgresJsonbText)) + "]";
            case JsonValueKind.String:
                return JsonSerializer.Serialize(element.GetString(), JsonOptions);
            case JsonValueKind.True: return "true";
            case JsonValueKind.False: return "false";
            case JsonValueKind.Null: return "null";
            case JsonValueKind.Number: return NormalizeJsonNumber(element.GetRawText());
            default: throw new InvalidOperationException("Unsupported JSON value in rule profile.");
        }
    }

    internal static string NormalizeJsonNumber(string rawNumber)
    {
        if (string.IsNullOrWhiteSpace(rawNumber) || rawNumber.Length > MaximumNumberDigits + 16)
            throw new InvalidOperationException("Rule profile number exceeds the supported canonical form.");

        var negative = rawNumber[0] == '-';
        var unsigned = negative ? rawNumber[1..] : rawNumber;
        var exponentIndex = unsigned.IndexOfAny(new[] { 'e', 'E' });
        var mantissa = exponentIndex < 0 ? unsigned : unsigned[..exponentIndex];
        var exponent = 0;
        if (exponentIndex >= 0 && !int.TryParse(unsigned[(exponentIndex + 1)..],
                NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out exponent))
            throw new InvalidOperationException("Rule profile number exponent is unsupported.");

        var decimalIndex = mantissa.IndexOf('.');
        var fractionalDigits = decimalIndex < 0 ? 0 : mantissa.Length - decimalIndex - 1;
        var digits = decimalIndex < 0 ? mantissa : mantissa.Remove(decimalIndex, 1);
        if (digits.Length == 0 || digits.Length > MaximumNumberDigits ||
            digits.Any(character => character is < '0' or > '9'))
            throw new InvalidOperationException("Rule profile number is unsupported.");

        digits = digits.TrimStart('0');
        if (digits.Length == 0) return "0";

        int scale;
        try { scale = checked(fractionalDigits - exponent); }
        catch (OverflowException) { throw new InvalidOperationException("Rule profile number scale is unsupported."); }
        while (digits.EndsWith("0", StringComparison.Ordinal))
        {
            digits = digits[..^1];
            scale--;
        }
        if (scale is < -MaximumNumberScale or > MaximumNumberScale)
            throw new InvalidOperationException("Rule profile number scale is unsupported.");

        string canonical;
        if (scale <= 0) canonical = digits + new string('0', -scale);
        else if (scale >= digits.Length) canonical = "0." + new string('0', scale - digits.Length) + digits;
        else canonical = digits.Insert(digits.Length - scale, ".");
        return negative ? "-" + canonical : canonical;
    }

    private sealed class PostgresJsonbKeyComparer : IComparer<string>
    {
        public static PostgresJsonbKeyComparer Instance { get; } = new();

        public int Compare(string? left, string? right)
        {
            var leftBytes = Encoding.UTF8.GetBytes(left ?? string.Empty);
            var rightBytes = Encoding.UTF8.GetBytes(right ?? string.Empty);
            var lengthComparison = leftBytes.Length.CompareTo(rightBytes.Length);
            if (lengthComparison != 0) return lengthComparison;
            for (var index = 0; index < leftBytes.Length; index++)
            {
                var byteComparison = leftBytes[index].CompareTo(rightBytes[index]);
                if (byteComparison != 0) return byteComparison;
            }
            return 0;
        }
    }
}
