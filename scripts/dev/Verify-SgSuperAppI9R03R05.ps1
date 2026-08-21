[CmdletBinding()]
param([string]$RepositoryRoot)

$ErrorActionPreference = 'Stop'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
} else { (Resolve-Path $RepositoryRoot).Path }
$required = @(
    'apps/sg-superapp-api/Domain/SchedulingRuleModels.cs',
    'apps/sg-superapp-api/Services/SchedulingRuleProfileValidator.cs',
    'apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs',
    'apps/sg-superapp-api/Services/SchedulingOverlapTravelRules.cs',
    'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs',
    'apps/sg-superapp-api/sg-superapp-api.csproj'
) | ForEach-Object { Join-Path $repoRoot $_ }
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($missing.Count -gt 0) {
    $missing | ForEach-Object { Write-Output "I9 R03 R05 FAIL: Missing required file: $_" }
    exit 1
}

$rules = Get-Content -LiteralPath (Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingOverlapTravelRules.cs') -Raw
$evaluator = Get-Content -LiteralPath (Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs') -Raw
foreach ($contract in @(
    @{ Name = 'R03 evaluator'; Pattern = 'EvaluateR03\s*\(' },
    @{ Name = 'R05 evaluator'; Pattern = 'EvaluateR05\s*\(' },
    @{ Name = 'half-open overlap'; Pattern = 'proposedStart\s*<\s*interval\.End\s*&&\s*interval\.Start\s*<\s*proposedEnd' },
    @{ Name = 'directional matrix'; Pattern = '(?s)row\.From.*row\.To' },
    @{ Name = 'never assume zero'; Pattern = 'RELATION_MISSING' },
    @{ Name = 'prohibited absolute block'; Pattern = 'PROHIBITED' }
)) {
    if ($rules -notmatch $contract.Pattern) { Write-Output "I9 R03 R05 FAIL: Rules missing $($contract.Name)"; exit 1 }
}
if ($evaluator -notmatch 'SchedulingOverlapTravelRules\.EvaluateR03' -or
    $evaluator -notmatch 'SchedulingOverlapTravelRules\.EvaluateR05') {
    Write-Output 'I9 R03 R05 FAIL: Common evaluator does not invoke both real R03/R05 evaluators'
    exit 1
}
Write-Output 'I9 R03 R05 STATIC PASS'

$dotnetPath = 'C:\tmp\dotnet6\dotnet.exe'
if (-not (Test-Path -LiteralPath $dotnetPath -PathType Leaf)) {
    Write-Output 'I9 R03 R05 BLOCKED: C:\tmp\dotnet6\dotnet.exe unavailable'
    exit 2
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sg-i9-r03-r05-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $models = [System.Security.SecurityElement]::Escape((Join-Path $repoRoot 'apps/sg-superapp-api/Domain/SchedulingRuleModels.cs'))
    $validator = [System.Security.SecurityElement]::Escape((Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingRuleProfileValidator.cs'))
    $workRest = [System.Security.SecurityElement]::Escape((Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs'))
    $overlap = [System.Security.SecurityElement]::Escape((Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingOverlapTravelRules.cs'))
    $evaluatorFile = [System.Security.SecurityElement]::Escape((Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs'))
@"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><LangVersion>latest</LangVersion><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable></PropertyGroup>
  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="Npgsql" Version="6.0.10" />
    <Using Include="Microsoft.Extensions.Configuration" />
    <Compile Include="$models" Link="SchedulingRuleModels.cs" />
    <Compile Include="$validator" Link="SchedulingRuleProfileValidator.cs" />
    <Compile Include="$workRest" Link="SchedulingWorkRestRules.cs" />
    <Compile Include="$overlap" Link="SchedulingOverlapTravelRules.cs" />
    <Compile Include="$evaluatorFile" Link="SchedulingRuleEvaluator.cs" />
  </ItemGroup>
</Project>
"@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Harness.csproj') -Encoding utf8
@'
using System.Text.Json;
using System.Text.RegularExpressions;
using Sg.SuperApp.Api.Domain;
using Sg.SuperApp.Api.Services;

static JsonElement J(string json) { using var document = JsonDocument.Parse(json); return document.RootElement.Clone(); }
const string R03 = "I9-R03";
const string R05 = "I9-R05";
var r03Parameters = J("{\"intervalSemantics\":\"HALF_OPEN\",\"adjacentIntervalsOverlap\":false,\"precedenceOver\":[\"I9-R05\"]}");
var r05Parameters = J("{\"missingRelationOutcome\":\"EXCEPTION_REQUIRED\",\"neverAssumeZero\":true,\"directional\":true}");
var matrix = J("{\"classification\":\"SIMULATED_DEMO_NOT_INSTITUTIONAL\",\"matrixDemo\":[{\"from\":\"PROJECT-A/POSITION-1\",\"to\":\"PROJECT-B/POSITION-2\",\"minutes\":45,\"prohibited\":false},{\"from\":\"PROJECT-B/POSITION-2\",\"to\":\"PROJECT-A/POSITION-1\",\"minutes\":60,\"prohibited\":false},{\"from\":\"PROJECT-A/POSITION-1\",\"to\":\"PROJECT-C/POSITION-3\",\"minutes\":null,\"prohibited\":true}]}");
var evaluator = new SchedulingRuleEvaluator();

SchedulingRuleProfile Profile(JsonElement? p03 = null, JsonElement? p05 = null, JsonElement? catalog = null) => new(
    19, "MVP-RULES", 1, SchedulingRuleOrigin.SIMULATED, SchedulingEnvironmentScope.MVP_TEST,
    "PROJECT-A", new DateOnly(2026, 1, 1), null, SchedulingRuleProfileStatus.ACTIVE, new string('b', 64), new[] {
        new SchedulingRuleProfileEntry(R03, p03 ?? r03Parameters, J("{}"), true),
        new SchedulingRuleProfileEntry(R05, p05 ?? r05Parameters, catalog ?? matrix, true)
    });
SchedulingRuleEvaluationBatch Evaluate(string facts, SchedulingRuleProfile? profile = null, IReadOnlySet<string>? approvals = null) =>
    evaluator.Evaluate(profile ?? Profile(), "PROJECT-A", new DateOnly(2026, 8, 17), J(facts), approvals);
RuleEvaluation Rule(SchedulingRuleEvaluationBatch batch, string rule) => batch.Evaluations.Single(value => value.RuleCode == rule);
void Equal<T>(T expected, T actual, string label) where T : notnull { if (!EqualityComparer<T>.Default.Equals(expected, actual)) throw new Exception($"{label}: expected {expected}, got {actual}"); }
SchedulingRuleSeverity Severity(SchedulingRuleOutcome outcome) => outcome switch { SchedulingRuleOutcome.COMPLIANT => SchedulingRuleSeverity.INFO, SchedulingRuleOutcome.EXCEPTION_REQUIRED => SchedulingRuleSeverity.WARNING, _ => SchedulingRuleSeverity.BLOCKING };
void CheckRule(RuleEvaluation result, SchedulingRuleOutcome expected, string label) {
    Equal(expected, result.Outcome, $"{label} outcome"); Equal(Severity(expected), result.Severity, $"{label} severity");
    Equal(expected == SchedulingRuleOutcome.EXCEPTION_REQUIRED, result.ExceptionAllowed, $"{label} exceptionAllowed");
    if (!Regex.IsMatch(result.ScopeHash, "^[a-f0-9]{64}$")) throw new Exception($"{label} scopeHash is not lowercase SHA-256");
}
void CheckSummary(SchedulingRuleEvaluationBatch batch, SchedulingRuleOutcome r03, SchedulingRuleOutcome r05, bool canApprove, string label) {
    Equal(2, batch.Summary.Total, $"{label} total");
    Equal(new[] { r03, r05 }.Count(value => value == SchedulingRuleOutcome.COMPLIANT), batch.Summary.Compliant, $"{label} compliant");
    Equal(new[] { r03, r05 }.Count(value => value == SchedulingRuleOutcome.BLOCKED), batch.Summary.Blocked, $"{label} blocked");
    Equal(new[] { r03, r05 }.Count(value => value == SchedulingRuleOutcome.EXCEPTION_REQUIRED), batch.Summary.ExceptionRequired, $"{label} exceptionRequired");
    Equal(0, batch.Summary.Warning, $"{label} warning"); Equal(0, batch.Summary.NotApplicable, $"{label} notApplicable");
    Equal(canApprove, batch.Summary.CanApproveOrPublish, $"{label} canApproveOrPublish");
}
void Case(string id, string facts, SchedulingRuleOutcome expected03, SchedulingRuleOutcome expected05, bool canApprove = false, SchedulingRuleProfile? profile = null, IReadOnlySet<string>? approvals = null) {
    var batch = Evaluate(facts, profile, approvals); CheckRule(Rule(batch, R03), expected03, id + " R03"); CheckRule(Rule(batch, R05), expected05, id + " R05"); CheckSummary(batch, expected03, expected05, canApprove, id); Console.WriteLine(id + " PASS");
}
string Facts(string employee, string proposedStart, string proposedEnd, string intervals, string origin = "PROJECT-A/POSITION-1", string destination = "PROJECT-A/POSITION-1", string available = "45") =>
    $"{{\"assignmentId\":\"assignment-a\",\"scheduleVersionId\":\"version-a\",\"employeeId\":\"{employee}\",\"proposedShiftStart\":\"{proposedStart}\",\"proposedShiftEnd\":\"{proposedEnd}\",\"existingIntervals\":{intervals},\"originPositionCode\":\"{origin}\",\"destinationPositionCode\":\"{destination}\",\"availableMinutes\":{available}}}";
string Interval(string employee, string start, string end, string status = "APPROVED") => $"[{{\"employeeId\":\"{employee}\",\"start\":\"{start}\",\"end\":\"{end}\",\"status\":\"{status}\"}}]";
const string Start = "2026-08-20T08:00:00-05:00";
const string End = "2026-08-20T16:00:00-05:00";

// R03-T01..T15: half-open boundaries, real overlap shapes, temporal edges, guards, fail-closed input, and precedence.
Case("R03-T01", Facts("guard-a", Start, End, "[]"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.COMPLIANT, true);
Case("R03-T02", Facts("guard-a", Start, End, Interval("guard-a", "2026-08-20T16:00:00-05:00", "2026-08-20T20:00:00-05:00")), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.COMPLIANT, true);
Case("R03-T03", Facts("guard-a", "2026-08-20T08:00:00-05:00", "2026-08-20T18:00:00-05:00", Interval("guard-a", "2026-08-20T10:00:00-05:00", "2026-08-20T12:00:00-05:00")), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT);
Case("R03-T04", Facts("guard-a", "2026-08-20T10:00:00-05:00", "2026-08-20T12:00:00-05:00", Interval("guard-a", Start, End)), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT);
Case("R03-T05", Facts("guard-a", Start, End, Interval("guard-a", Start, End)), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT);
Case("R03-T06", Facts("guard-a", "2026-08-20T06:00:00-05:00", "2026-08-20T10:00:00-05:00", Interval("guard-a", Start, End)), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT);
Case("R03-T07", Facts("guard-a", "2026-08-20T12:00:00-05:00", "2026-08-20T18:00:00-05:00", Interval("guard-a", Start, End)), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT);
Case("R03-T08", Facts("guard-a", "2026-08-20T23:30:00-05:00", "2026-08-21T01:00:00-05:00", Interval("guard-a", "2026-08-20T23:45:00-05:00", "2026-08-21T00:15:00-05:00")), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT);
Case("R03-T09", Facts("guard-a", "2026-08-31T23:30:00-05:00", "2026-09-01T01:00:00-05:00", Interval("guard-a", "2026-08-31T23:45:00-05:00", "2026-09-01T00:15:00-05:00")), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT);
Case("R03-T10", Facts("guard-a", "2026-12-31T23:30:00-05:00", "2027-01-01T01:00:00-05:00", Interval("guard-a", "2026-12-31T23:45:00-05:00", "2027-01-01T00:15:00-05:00")), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT);
Case("R03-T11", Facts("guard-a", Start, End, Interval("guard-b", Start, End)), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.COMPLIANT, true);
Case("R03-T12", Facts("guard-a", Start, End, Interval("guard-a", Start, End, "DRAFT")), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT);
Case("R03-T13", Facts("guard-a", End, Start, "[]"), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT);
Case("R03-T14", Facts("guard-a", Start, End, "[]"), SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.COMPLIANT, false, Profile(J("{}")));
var precedenceFacts = Facts("guard-a", Start, End, Interval("guard-a", Start, End), "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "44");
var precedence = Evaluate(precedenceFacts); var r05Approval = new HashSet<string> { Rule(precedence, R05).ScopeHash };
Case("R03-T15", precedenceFacts, SchedulingRuleOutcome.BLOCKED, SchedulingRuleOutcome.EXCEPTION_REQUIRED, false, null, r05Approval);

// R05-T01..T20: exact-position zero, directional matrix, exception and absolute outcomes, strict inputs, snapshots, and scope binding.
Case("R05-T01", Facts("guard-a", Start, End, "[]"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.COMPLIANT, true);
Case("R05-T02", Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "45"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.COMPLIANT, true);
Case("R05-T03", Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "44"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.EXCEPTION_REQUIRED);
Case("R05-T04", Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-Z/POSITION-9", "999"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.EXCEPTION_REQUIRED);
Case("R05-T05", Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-C/POSITION-3", "999"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.BLOCKED);
Case("R05-T06", Facts("guard-a", Start, End, "[]", "PROJECT-B/POSITION-2", "PROJECT-A/POSITION-1", "60"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.COMPLIANT, true);
Case("R05-T07", Facts("guard-a", Start, End, "[]", "PROJECT-B/POSITION-2", "PROJECT-A/POSITION-1", "59"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.EXCEPTION_REQUIRED);
Case("R05-T08", Facts("guard-a", "2026-08-31T23:59:00-05:00", "2026-09-01T00:01:00-05:00", "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "45"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.COMPLIANT, true);
Case("R05-T09", Facts("guard-a", "2026-12-31T23:59:00-05:00", "2027-01-01T00:01:00-05:00", "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "45"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.COMPLIANT, true);
Case("R05-T10", Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "44.5"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.BLOCKED);
Case("R05-T11", Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "-1"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.BLOCKED);
Case("R05-T12", Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "45"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.BLOCKED, false, Profile(null, J("{\"missingRelationOutcome\":\"COMPLIANT\",\"neverAssumeZero\":true,\"directional\":true}")));
Case("R05-T13", Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "45"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.BLOCKED, false, Profile(null, null, J("{\"matrixDemo\":[{\"from\":\"PROJECT-A/POSITION-1\",\"to\":\"PROJECT-B/POSITION-2\",\"minutes\":44.5,\"prohibited\":false}]}")));
Case("R05-T14", Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "45"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.BLOCKED, false, Profile(null, null, J("{\"matrixDemo\":[{\"from\":\"PROJECT-A/POSITION-1\",\"to\":\"PROJECT-B/POSITION-2\",\"minutes\":-1,\"prohibited\":false}]}")));
Case("R05-T15", Facts("guard-a", Start, End, "[]"), SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.BLOCKED, false, Profile(null, null, J("{}")));
var exceptionFacts = Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "44");
var exceptionBatch = Evaluate(exceptionFacts); var exactApproval = new HashSet<string> { Rule(exceptionBatch, R05).ScopeHash };
Case("R05-T16", exceptionFacts, SchedulingRuleOutcome.COMPLIANT, SchedulingRuleOutcome.EXCEPTION_REQUIRED, true, null, exactApproval);
var changedGuard = Evaluate(Facts("guard-b", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "44"));
Equal(false, Rule(exceptionBatch, R05).ScopeHash == Rule(changedGuard, R05).ScopeHash, "R05-T17 employee scope isolation"); Console.WriteLine("R05-T17 PASS");
var changedOrigin = Evaluate(Facts("guard-a", Start, End, "[]", "PROJECT-B/POSITION-2", "PROJECT-A/POSITION-1", "44"));
Equal(false, Rule(exceptionBatch, R05).ScopeHash == Rule(changedOrigin, R05).ScopeHash, "R05-T18 origin scope isolation"); Console.WriteLine("R05-T18 PASS");
var changedDestination = Evaluate(Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-C/POSITION-3", "44"));
Equal(false, Rule(exceptionBatch, R05).ScopeHash == Rule(changedDestination, R05).ScopeHash, "R05-T19 destination scope isolation"); Console.WriteLine("R05-T19 PASS");
var snapshotProfile = Profile(); var beforeSnapshot = snapshotProfile.Entries.Single(entry => entry.RuleCode == R05).CatalogSnapshot.GetRawText();
var snapshotBatch = Evaluate(Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "45"), snapshotProfile);
Equal(beforeSnapshot, snapshotProfile.Entries.Single(entry => entry.RuleCode == R05).CatalogSnapshot.GetRawText(), "R05-T20 profile matrix snapshot preserved");
Equal(Rule(snapshotBatch, R05).ScopeHash, Rule(Evaluate(Facts("guard-a", Start, End, "[]", "PROJECT-A/POSITION-1", "PROJECT-B/POSITION-2", "45"), snapshotProfile), R05).ScopeHash, "R05-T20 deterministic hash"); Console.WriteLine("R05-T20 PASS");
Console.WriteLine("I9 R03 R05 PASS");
'@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Program.cs') -Encoding utf8
    & $dotnetPath run --project (Join-Path $tempRoot 'Harness.csproj') --configuration Release
    exit $LASTEXITCODE
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
