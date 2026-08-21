[CmdletBinding()]
param([string]$RepositoryRoot)

$ErrorActionPreference = 'Stop'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
} else { (Resolve-Path $RepositoryRoot).Path }
$rulesPath = Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs'
$evaluatorPath = Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs'
$validatorPath = Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingRuleProfileValidator.cs'
$modelsPath = Join-Path $repoRoot 'apps/sg-superapp-api/Domain/SchedulingRuleModels.cs'
$apiProjectPath = Join-Path $repoRoot 'apps/sg-superapp-api/sg-superapp-api.csproj'
$failures = [System.Collections.Generic.List[string]]::new()

foreach ($required in @($rulesPath, $evaluatorPath, $validatorPath, $modelsPath, $apiProjectPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        $failures.Add("Missing required file: $required")
    }
}

if ($failures.Count -eq 0) {
    $rules = Get-Content -LiteralPath $rulesPath -Raw
    $evaluator = Get-Content -LiteralPath $evaluatorPath -Raw
    foreach ($contract in @(
        @{ Name = 'R01 entry point'; Pattern = 'EvaluateR01\s*\(' },
        @{ Name = 'R02 entry point'; Pattern = 'EvaluateR02\s*\(' },
        @{ Name = 'absolute daily boundary'; Pattern = 'absoluteDailyHours' },
        @{ Name = 'absolute weekly boundary'; Pattern = 'absoluteWeeklyHours' },
        @{ Name = 'written agreement'; Pattern = 'writtenAgreement' },
        @{ Name = 'minimum rest'; Pattern = 'minimumRestHours' },
        @{ Name = 'absolute blocking'; Pattern = 'SchedulingRuleOutcome\.BLOCKED' },
        @{ Name = 'approvable exception'; Pattern = 'SchedulingRuleOutcome\.EXCEPTION_REQUIRED' }
    )) {
        if ($rules -notmatch $contract.Pattern) { $failures.Add("Rules missing $($contract.Name)") }
    }
    if ($evaluator -notmatch 'SchedulingWorkRestRules\.EvaluateR01' -or
        $evaluator -notmatch 'SchedulingWorkRestRules\.EvaluateR02' -or
        $evaluator -notmatch 'approvedExceptionScopeHashes\?\.Contains\s*\(\s*result\.ScopeHash\s*\)') {
        $failures.Add('Common evaluator does not invoke both real R01/R02 evaluators')
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "I9 R01 R02 FAIL: $failure" }
    exit 1
}
Write-Output 'I9 R01 R02 STATIC PASS'

$dotnetCandidates = [System.Collections.Generic.List[string]]::new()
$bundledDotnet = 'C:\tmp\dotnet6\dotnet.exe'
if (Test-Path -LiteralPath $bundledDotnet -PathType Leaf) {
    $dotnetCandidates.Add($bundledDotnet)
}
$dotnetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
if ($null -ne $dotnetCommand -and -not [string]::IsNullOrWhiteSpace($dotnetCommand.Source) -and
    (Test-Path -LiteralPath $dotnetCommand.Source -PathType Leaf)) {
    $dotnetCandidates.Add($dotnetCommand.Source)
}
$dotnetPath = $dotnetCandidates | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($dotnetPath)) {
    Write-Output 'I9 R01 R02 BLOCKED: dotnet unavailable'
    exit 2
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sg-i9-r01-r02-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    try {
        $escapedModels = [System.Security.SecurityElement]::Escape($modelsPath)
        $escapedValidator = [System.Security.SecurityElement]::Escape($validatorPath)
        $escapedRules = [System.Security.SecurityElement]::Escape($rulesPath)
        $escapedEvaluator = [System.Security.SecurityElement]::Escape($evaluatorPath)
@"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><LangVersion>latest</LangVersion><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable></PropertyGroup>
  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="Npgsql" Version="6.0.10" />
    <Using Include="Microsoft.Extensions.Configuration" />
    <Compile Include="$escapedModels" Link="SchedulingRuleModels.cs" />
    <Compile Include="$escapedValidator" Link="SchedulingRuleProfileValidator.cs" />
    <Compile Include="$escapedRules" Link="SchedulingWorkRestRules.cs" />
    <Compile Include="$escapedEvaluator" Link="SchedulingRuleEvaluator.cs" />
  </ItemGroup>
</Project>
"@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Harness.csproj') -Encoding utf8
@'
using System.Text.Json;
using Sg.SuperApp.Api.Domain;
using Sg.SuperApp.Api.Services;

static JsonElement J(string json) { using var d = JsonDocument.Parse(json); return d.RootElement.Clone(); }
var r01p = J("{\"ordinaryDailyHours\":8,\"ordinaryWeeklyHours\":42,\"approvalFromDailyHours\":10,\"absoluteDailyHours\":12,\"absoluteWeeklyHours\":60,\"writtenAgreementRequiredAboveOrdinary\":true}");
var r02p = J("{\"minimumRestHours\":12}");
var profile = new SchedulingRuleProfile(1, "MVP-RULES", 1, SchedulingRuleOrigin.SIMULATED,
    SchedulingEnvironmentScope.MVP_TEST, "PROJECT-A", new DateOnly(2026, 1, 1), null,
    SchedulingRuleProfileStatus.ACTIVE, new string('a', 64), new[] {
        new SchedulingRuleProfileEntry("I9-R01", r01p, J("{}"), true),
        new SchedulingRuleProfileEntry("I9-R02", r02p, J("{}"), true)
    });
var evaluator = new SchedulingRuleEvaluator();
SchedulingRuleEvaluationBatch Evaluate(decimal daily, decimal weekly, bool writtenAgreement, string start,
    IReadOnlySet<string>? approvals = null) =>
    evaluator.Evaluate(profile, "PROJECT-A", new DateOnly(2026, 8, 17),
        J($"{{\"dailyHours\":{daily.ToString(System.Globalization.CultureInfo.InvariantCulture)},\"weeklyHours\":{weekly.ToString(System.Globalization.CultureInfo.InvariantCulture)},\"writtenAgreement\":{writtenAgreement.ToString().ToLowerInvariant()},\"previousShiftEnd\":\"2026-08-17T22:00:00-05:00\",\"proposedShiftStart\":\"{start}\"}}"), approvals);
RuleEvaluation Rule(SchedulingRuleEvaluationBatch batch, string ruleCode) =>
    batch.Evaluations.Single(x => x.RuleCode == ruleCode);
void AssertEqual<T>(T expected, T actual, string label) where T : notnull {
    if (!EqualityComparer<T>.Default.Equals(expected, actual))
        throw new Exception($"{label}: expected '{expected}', got '{actual}'.");
}
void AssertRule(SchedulingRuleEvaluationBatch batch, string ruleCode, SchedulingRuleOutcome outcome,
    SchedulingRuleSeverity severity, bool exceptionAllowed, string label) {
    var result = Rule(batch, ruleCode);
    AssertEqual(outcome, result.Outcome, $"{label} outcome");
    AssertEqual(severity, result.Severity, $"{label} severity");
    AssertEqual(exceptionAllowed, result.ExceptionAllowed, $"{label} exceptionAllowed");
    if (!System.Text.RegularExpressions.Regex.IsMatch(result.ScopeHash, "^[a-f0-9]{64}$"))
        throw new Exception($"{label} scopeHash is not a lowercase SHA-256 hex value.");
}
void AssertSummary(SchedulingRuleEvaluationBatch batch, int compliant, int blocked, int exceptionRequired,
    bool canApproveOrPublish, string label, int warning = 0, int notApplicable = 0) {
    AssertEqual(2, batch.Summary.Total, $"{label} total");
    AssertEqual(compliant, batch.Summary.Compliant, $"{label} compliant");
    AssertEqual(blocked, batch.Summary.Blocked, $"{label} blocked");
    AssertEqual(exceptionRequired, batch.Summary.ExceptionRequired, $"{label} exceptionRequired");
    AssertEqual(warning, batch.Summary.Warning, $"{label} warning");
    AssertEqual(notApplicable, batch.Summary.NotApplicable, $"{label} notApplicable");
    AssertEqual(canApproveOrPublish, batch.Summary.CanApproveOrPublish, $"{label} canApproveOrPublish");
    foreach (var result in batch.Evaluations)
        if (!System.Text.RegularExpressions.Regex.IsMatch(result.ScopeHash, "^[a-f0-9]{64}$"))
            throw new Exception($"{label} {result.RuleCode} scopeHash is not a lowercase SHA-256 hex value.");
}

const string exactRest = "2026-08-18T10:00:00-05:00";
const string shortRest = "2026-08-18T09:59:59-05:00";

var ordinary = Evaluate(8m, 42m, false, exactRest);
AssertRule(ordinary, "I9-R01", SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO, false, "R01 8/42");
AssertRule(ordinary, "I9-R02", SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO, false, "R02 exact 12h");
AssertSummary(ordinary, 2, 0, 0, true, "R01 8/42");
var ordinaryRepeat = Evaluate(8m, 42m, false, exactRest);
AssertEqual(Rule(ordinary, "I9-R01").ScopeHash, Rule(ordinaryRepeat, "I9-R01").ScopeHash, "R01 identical scope stability");
AssertEqual(Rule(ordinary, "I9-R02").ScopeHash, Rule(ordinaryRepeat, "I9-R02").ScopeHash, "R02 identical scope stability");

var missingAgreement = Evaluate(8.01m, 42m, false, exactRest);
AssertRule(missingAgreement, "I9-R01", SchedulingRuleOutcome.BLOCKED, SchedulingRuleSeverity.BLOCKING, false,
    "R01 8.01 without agreement");
AssertSummary(missingAgreement, 1, 1, 0, false, "R01 8.01 without agreement");

var missingWeeklyAgreement = Evaluate(8m, 42.01m, false, exactRest);
AssertRule(missingWeeklyAgreement, "I9-R01", SchedulingRuleOutcome.BLOCKED, SchedulingRuleSeverity.BLOCKING, false,
    "R01 weekly 42.01 without agreement");
AssertRule(missingWeeklyAgreement, "I9-R02", SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO, false,
    "R02 alongside weekly 42.01 without agreement");
AssertSummary(missingWeeklyAgreement, 1, 1, 0, false, "R01 weekly 42.01 without agreement");

var tenHours = Evaluate(10m, 42m, true, exactRest);
AssertRule(tenHours, "I9-R01", SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO, false, "R01 10 with agreement");
AssertSummary(tenHours, 2, 0, 0, true, "R01 10 with agreement");

void VerifyR01ScopeBoundApproval(decimal dailyHours, string label) {
    var initial = Evaluate(dailyHours, 42m, true, exactRest);
    AssertRule(initial, "I9-R01", SchedulingRuleOutcome.EXCEPTION_REQUIRED, SchedulingRuleSeverity.WARNING, true, label);
    AssertSummary(initial, 1, 0, 1, false, label);
    var wrongScope = Evaluate(dailyHours, 42m, true, exactRest, new HashSet<string> { Rule(initial, "I9-R02").ScopeHash });
    AssertSummary(wrongScope, 1, 0, 1, false, $"{label} wrong scope");
    var approved = Evaluate(dailyHours, 42m, true, exactRest, new HashSet<string> { Rule(initial, "I9-R01").ScopeHash });
    AssertSummary(approved, 1, 0, 1, true, $"{label} approved scope");
}
VerifyR01ScopeBoundApproval(10.01m, "R01 10.01 with agreement");
VerifyR01ScopeBoundApproval(12m, "R01 12 with agreement");

var dailyAbsolute = Evaluate(12.01m, 42m, true, exactRest);
AssertRule(dailyAbsolute, "I9-R01", SchedulingRuleOutcome.BLOCKED, SchedulingRuleSeverity.BLOCKING, false, "R01 12.01");
AssertSummary(dailyAbsolute, 1, 1, 0, false, "R01 12.01");

var weeklyBoundary = Evaluate(8m, 60m, true, exactRest);
AssertRule(weeklyBoundary, "I9-R01", SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO, false, "R01 weekly 60");
AssertSummary(weeklyBoundary, 2, 0, 0, true, "R01 weekly 60");
if (Rule(ordinary, "I9-R01").ScopeHash == Rule(weeklyBoundary, "I9-R01").ScopeHash)
    throw new Exception("R01 weekly scopeHash did not change when weeklyHours changed.");

var weeklyAbsolute = Evaluate(8m, 60.01m, true, exactRest);
AssertRule(weeklyAbsolute, "I9-R01", SchedulingRuleOutcome.BLOCKED, SchedulingRuleSeverity.BLOCKING, false, "R01 weekly 60.01");
AssertSummary(weeklyAbsolute, 1, 1, 0, false, "R01 weekly 60.01");

var shortRestInitial = Evaluate(8m, 42m, false, shortRest);
AssertRule(shortRestInitial, "I9-R01", SchedulingRuleOutcome.COMPLIANT, SchedulingRuleSeverity.INFO, false, "R01 alongside R02 11:59:59");
AssertRule(shortRestInitial, "I9-R02", SchedulingRuleOutcome.EXCEPTION_REQUIRED, SchedulingRuleSeverity.WARNING, true, "R02 11:59:59");
AssertSummary(shortRestInitial, 1, 0, 1, false, "R02 11:59:59");
var r02WrongScope = Evaluate(8m, 42m, false, shortRest, new HashSet<string> { Rule(shortRestInitial, "I9-R01").ScopeHash });
AssertSummary(r02WrongScope, 1, 0, 1, false, "R02 11:59:59 wrong scope");
var r02Approved = Evaluate(8m, 42m, false, shortRest, new HashSet<string> { Rule(shortRestInitial, "I9-R02").ScopeHash });
AssertSummary(r02Approved, 1, 0, 1, true, "R02 11:59:59 approved scope");
if (Rule(ordinary, "I9-R02").ScopeHash == Rule(shortRestInitial, "I9-R02").ScopeHash)
    throw new Exception("R02 rest scopeHash did not change when the proposed start changed.");

void VerifyAbsolutePrecedence(decimal daily, decimal weekly, string label) {
    var initial = Evaluate(daily, weekly, true, shortRest);
    var r01 = initial.Evaluations.Single(x => x.RuleCode == "I9-R01");
    var r02 = initial.Evaluations.Single(x => x.RuleCode == "I9-R02");
    AssertRule(initial, "I9-R01", SchedulingRuleOutcome.BLOCKED, SchedulingRuleSeverity.BLOCKING, false, $"{label} R01");
    AssertRule(initial, "I9-R02", SchedulingRuleOutcome.EXCEPTION_REQUIRED, SchedulingRuleSeverity.WARNING, true, $"{label} R02");
    AssertSummary(initial, 0, 1, 1, false, label);
    var afterR02Approval = Evaluate(daily, weekly, true, shortRest, new HashSet<string> { r02.ScopeHash });
    AssertSummary(afterR02Approval, 0, 1, 1, false, $"{label} after R02 approval");
}
VerifyAbsolutePrecedence(12.01m, 42m, "R01 daily absolute plus R02 exception");
VerifyAbsolutePrecedence(8m, 60.01m, "R01 weekly absolute plus R02 exception");
Console.WriteLine("HARNESS PASS");
'@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Program.cs') -Encoding utf8
        $output = & $dotnetPath run --project (Join-Path $tempRoot 'Harness.csproj') --nologo 2>&1
        if ($LASTEXITCODE -ne 0 -or ($output -join "`n") -notmatch 'HARNESS PASS') {
            throw "Executable R01/R02 harness failed: $($output -join ' ')"
        }
    }
    catch {
        Write-Output "I9 R01 R02 FAIL: $($_.Exception.Message)"
        exit 1
    }
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'I9 R01 R02 PASS'
exit 0
