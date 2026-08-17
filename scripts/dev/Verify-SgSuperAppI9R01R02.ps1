[CmdletBinding()]
param([string]$RepositoryRoot)

$ErrorActionPreference = 'Stop'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
} else { (Resolve-Path $RepositoryRoot).Path }
$rulesPath = Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs'
$evaluatorPath = Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs'
$modelsPath = Join-Path $repoRoot 'apps/sg-superapp-api/Domain/SchedulingRuleModels.cs'
$apiProjectPath = Join-Path $repoRoot 'apps/sg-superapp-api/sg-superapp-api.csproj'
$failures = [System.Collections.Generic.List[string]]::new()

foreach ($required in @($rulesPath, $evaluatorPath, $modelsPath, $apiProjectPath)) {
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

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if ($null -eq $dotnet) {
    Write-Output 'I9 R01 R02 BLOCKED: dotnet unavailable'
    exit 2
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sg-i9-r01-r02-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    try {
        $escapedProject = [System.Security.SecurityElement]::Escape($apiProjectPath)
        @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><LangVersion>latest</LangVersion><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable></PropertyGroup>
  <ItemGroup><ProjectReference Include="$escapedProject" /></ItemGroup>
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
SchedulingRuleEvaluationBatch Evaluate(decimal daily, decimal weekly, string start, IReadOnlySet<string>? approvals = null) =>
    evaluator.Evaluate(profile, "PROJECT-A", new DateOnly(2026, 8, 17),
        J($"{{\"dailyHours\":{daily.ToString(System.Globalization.CultureInfo.InvariantCulture)},\"weeklyHours\":{weekly.ToString(System.Globalization.CultureInfo.InvariantCulture)},\"writtenAgreement\":true,\"previousShiftEnd\":\"2026-08-17T22:00:00-05:00\",\"proposedShiftStart\":\"{start}\"}}"), approvals);
void VerifyAbsolutePrecedence(decimal daily, decimal weekly) {
    var initial = Evaluate(daily, weekly, "2026-08-18T09:00:00-05:00");
    var r01 = initial.Evaluations.Single(x => x.RuleCode == "I9-R01");
    var r02 = initial.Evaluations.Single(x => x.RuleCode == "I9-R02");
    if (r01.Outcome != SchedulingRuleOutcome.BLOCKED || r01.ExceptionAllowed ||
        r02.Outcome != SchedulingRuleOutcome.EXCEPTION_REQUIRED || !r02.ExceptionAllowed)
        throw new Exception("Common evaluator did not produce BLOCKED R01 plus approvable R02");
    var afterR02Approval = Evaluate(daily, weekly, "2026-08-18T09:00:00-05:00", new HashSet<string> { r02.ScopeHash });
    if (afterR02Approval.Summary.Blocked != 1 || afterR02Approval.Summary.ExceptionRequired != 1 ||
        afterR02Approval.Summary.CanApproveOrPublish)
        throw new Exception("Approved R02 scope bypassed the absolute R01 block");
}
VerifyAbsolutePrecedence(12.01m, 42m);
VerifyAbsolutePrecedence(8m, 60.01m);
var exactRest = Evaluate(8m, 42m, "2026-08-18T10:00:00-05:00");
if (exactRest.Evaluations.Single(x => x.RuleCode == "I9-R02").Outcome != SchedulingRuleOutcome.COMPLIANT)
    throw new Exception("Exact 12-hour rest boundary is not COMPLIANT");
Console.WriteLine("HARNESS PASS");
'@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Program.cs') -Encoding utf8
        $output = & $dotnet.Source run --project (Join-Path $tempRoot 'Harness.csproj') --nologo 2>&1
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
