[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$rulesPath = Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs'
$evaluatorPath = Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs'
$modelsPath = Join-Path $repoRoot 'apps/sg-superapp-api/Domain/SchedulingRuleModels.cs'
$failures = [System.Collections.Generic.List[string]]::new()

foreach ($required in @($rulesPath, $evaluatorPath, $modelsPath)) {
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
        $evaluator -notmatch 'SchedulingWorkRestRules\.EvaluateR02') {
        $failures.Add('Common evaluator does not invoke both real R01/R02 evaluators')
    }
}

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if ($failures.Count -eq 0 -and $null -ne $dotnet) {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sg-i9-r01-r02-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    try {
        $escapedRules = [System.Security.SecurityElement]::Escape($rulesPath)
        $escapedModels = [System.Security.SecurityElement]::Escape($modelsPath)
        @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><LangVersion>latest</LangVersion><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable></PropertyGroup>
  <ItemGroup><Compile Include="$escapedRules" Link="SchedulingWorkRestRules.cs" /><Compile Include="$escapedModels" Link="SchedulingRuleModels.cs" /></ItemGroup>
</Project>
"@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Harness.csproj') -Encoding utf8
        @'
using System.Text.Json;
using Sg.SuperApp.Api.Domain;
using Sg.SuperApp.Api.Services;

static JsonElement J(string json) { using var d = JsonDocument.Parse(json); return d.RootElement.Clone(); }
static void Expect(string name, WorkRestRuleDecision actual, SchedulingRuleOutcome outcome, bool exceptionAllowed) {
    if (actual.Outcome != outcome || actual.ExceptionAllowed != exceptionAllowed)
        throw new Exception($"{name}: expected {outcome}/{exceptionAllowed}, got {actual.Outcome}/{actual.ExceptionAllowed}");
}
var r01p = J("{\"ordinaryDailyHours\":8,\"ordinaryWeeklyHours\":42,\"approvalFromDailyHours\":10,\"absoluteDailyHours\":12,\"absoluteWeeklyHours\":60,\"writtenAgreementRequiredAboveOrdinary\":true}");
var r02p = J("{\"minimumRestHours\":12}");
WorkRestRuleDecision R01(decimal daily, decimal weekly, bool agreement) => SchedulingWorkRestRules.EvaluateR01(r01p, J($"{{\"dailyHours\":{daily.ToString(System.Globalization.CultureInfo.InvariantCulture)},\"weeklyHours\":{weekly.ToString(System.Globalization.CultureInfo.InvariantCulture)},\"writtenAgreement\":{agreement.ToString().ToLowerInvariant()}}}"));
WorkRestRuleDecision R02(string previousEnd, string proposedStart) => SchedulingWorkRestRules.EvaluateR02(r02p, J($"{{\"previousShiftEnd\":\"{previousEnd}\",\"proposedShiftStart\":\"{proposedStart}\"}}"));

Expect("8h/42h", R01(8, 42, false), SchedulingRuleOutcome.COMPLIANT, false);
Expect("10h agreement", R01(10, 42, true), SchedulingRuleOutcome.COMPLIANT, false);
Expect("above ordinary no agreement", R01(8.01m, 42, false), SchedulingRuleOutcome.BLOCKED, false);
Expect("weekly above ordinary no agreement", R01(8, 42.01m, false), SchedulingRuleOutcome.BLOCKED, false);
Expect("above 10h", R01(10.01m, 42, true), SchedulingRuleOutcome.EXCEPTION_REQUIRED, true);
Expect("12h", R01(12, 60, true), SchedulingRuleOutcome.EXCEPTION_REQUIRED, true);
Expect("above 12h", R01(12.01m, 42, true), SchedulingRuleOutcome.BLOCKED, false);
Expect("60h", R01(8, 60, true), SchedulingRuleOutcome.COMPLIANT, false);
Expect("above 60h", R01(8, 60.01m, true), SchedulingRuleOutcome.BLOCKED, false);
Expect("R02 below 12", R02("2026-08-17T22:00:00-05:00", "2026-08-18T09:59:59-05:00"), SchedulingRuleOutcome.EXCEPTION_REQUIRED, true);
Expect("R02 exact 12", R02("2026-08-17T22:00:00-05:00", "2026-08-18T10:00:00-05:00"), SchedulingRuleOutcome.COMPLIANT, false);
var first = R01(10.01m, 42, true); var second = R01(10.01m, 42, true);
if (first != second) throw new Exception("R01 is not deterministic");
if (R01(12.01m, 42, true).Outcome != SchedulingRuleOutcome.BLOCKED || R02("2026-08-17T22:00:00Z", "2026-08-18T10:00:00Z").Outcome != SchedulingRuleOutcome.COMPLIANT)
    throw new Exception("R01 absolute BLOCKED did not retain precedence over an otherwise resolved R02");
Console.WriteLine("HARNESS PASS");
'@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Program.cs') -Encoding utf8
        $output = & $dotnet.Source run --project (Join-Path $tempRoot 'Harness.csproj') --nologo 2>&1
        if ($LASTEXITCODE -ne 0 -or ($output -join "`n") -notmatch 'HARNESS PASS') {
            $failures.Add("Executable R01/R02 harness failed: $($output -join ' ')")
        }
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
elseif ($failures.Count -eq 0) {
    Write-Output 'I9 R01 R02 SKIP: dotnet is unavailable; executable harness and API build require a .NET SDK'
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "I9 R01 R02 FAIL: $failure" }
    exit 1
}

Write-Output 'I9 R01 R02 PASS'
exit 0
