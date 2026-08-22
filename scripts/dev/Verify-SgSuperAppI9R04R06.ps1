[CmdletBinding()]
param([string]$RepositoryRoot)

$ErrorActionPreference = 'Stop'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
} else { (Resolve-Path $RepositoryRoot).Path }
$relativeFiles = @(
    'apps/sg-superapp-api/Domain/SchedulingRuleModels.cs',
    'apps/sg-superapp-api/Services/SchedulingRuleProfileValidator.cs',
    'apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs',
    'apps/sg-superapp-api/Services/SchedulingOverlapTravelRules.cs',
    'apps/sg-superapp-api/Services/SchedulingNoveltyRequirementRules.cs',
    'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs',
    'apps/sg-superapp-api/Contracts/Portal/SchedulingContracts.cs',
    'apps/sg-superapp-api/Contracts/Portal/SchedulingRuleContracts.cs'
)
$files = @($relativeFiles | ForEach-Object { Join-Path $repoRoot $_ })
$authorizationService = Join-Path $repoRoot 'apps/sg-superapp-api/Services/PortalAuthorizationService.cs'
$authorizationBoundary = Join-Path $repoRoot 'apps/sg-superapp-api/Endpoints/PortalEndpoints.cs'
$ruleEndpoints = Join-Path $repoRoot 'apps/sg-superapp-api/Endpoints/SchedulingRuleEndpoints.cs'
$portalRepository = Join-Path $repoRoot 'apps/sg-superapp-api/Services/PostgresPortalRepository.cs'
$migration = Join-Path $repoRoot 'db/migrations/012_i9_mvp_rule_profiles.sql'
if (@(($files + $authorizationService + $authorizationBoundary + $ruleEndpoints + $portalRepository + $migration) | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }).Count) {
    Write-Output 'I9 R04 R06 FAIL: required source missing'
    exit 1
}

$rules = Get-Content -LiteralPath $files[4] -Raw
$evaluator = Get-Content -LiteralPath $files[5] -Raw
$validationBoundary = $evaluator + (Get-Content -LiteralPath $ruleEndpoints -Raw) + (Get-Content -LiteralPath $portalRepository -Raw) + (Get-Content -LiteralPath $migration -Raw)
foreach ($pattern in @(
    'EvaluateR04\s*\(', 'EvaluateR06\s*\(', 'mappingDemo', 'requirementsDemo',
    'INCAPACITY_ACTIVE', 'VACATION_APPROVED_ACTIVE', 'LEAVE_OR_CALAMITY_ACTIVE',
    'SUSPENSION_OR_TERMINATION_ACTIVE', 'ABSENCE_CONFIRMED', 'ABSENCE_PENDING_CONFIRMATION',
    'TRAINING_OR_INDUCTION_OVERLAP', 'ADDITIONAL_SHIFT', 'ADMINISTRATIVE_EVENT',
    'COURSE', 'ACCREDITATION', 'CERTIFICATION', 'LICENSE_OR_PERMIT', 'OTHER_REQUIREMENT',
    'validForEntireShift', 'informativeRequiresOwnerAndDueDate', 'HasOverlappingRequirements'
)) {
    if ($rules -notmatch $pattern) { Write-Output "I9 R04 R06 FAIL: missing contract $pattern"; exit 1 }
}
foreach ($pattern in @(
    'SchedulingNoveltyRequirementRules', 'noveltyEvaluations', 'requirementEvaluations',
    'evidenceId', 'evidenceSource', 'sourceRequirementCode',
    'remediationOwnerRole', 'remediationOwnerKey',
    'Canonicalize\(entry\.CatalogSnapshot\)'
)) {
    if ($evaluator -notmatch $pattern) { Write-Output "I9 R04 R06 FAIL: evaluator contract $pattern"; exit 1 }
}
foreach ($forbidden in @('fullName', 'documentNumber', 'email', 'phone', 'freeText', 'description')) {
    if ($evaluator -match ('"' + [regex]::Escape($forbidden) + '"')) {
        Write-Output "I9 R04 R06 FAIL: non-minimized fact field $forbidden"
        exit 1
    }
}
$allowedFactsContract = [regex]::Match($evaluator, '(?s)AllowedNestedFacts\s*=\s*Fields\(.*?\);').Value
if ($allowedFactsContract -match '"hrValidated"|"hrValidation"|"validationId"|"validatorRoleKey"|"validatedAt"') { Write-Output 'I9 R04 R06 FAIL: client-controlled TH validation fact'; exit 1 }
foreach ($pattern in @('scheduling_rule_hr_validations', 'VALIDATE_REQUIREMENT', 'ValidateRequirementEvidenceAsync', 'SCHEDULE_REQUIREMENT_VALIDATION_DENIED', 'TH validation history is immutable')) {
    if ($validationBoundary -notmatch $pattern) { Write-Output "I9 R04 R06 FAIL: persisted TH validation contract $pattern"; exit 1 }
}

function Remove-CSharpComments([string]$source) {
    $builder = [Text.StringBuilder]::new(); $state = 'Code'; $index = 0
    while ($index -lt $source.Length) {
        $current = $source[$index]; $next = if ($index + 1 -lt $source.Length) { $source[$index + 1] } else { [char]0 }
        switch ($state) {
            'Code' {
                if ($current -eq '/' -and $next -eq '/') { $state = 'LineComment'; $index += 2; continue }
                if ($current -eq '/' -and $next -eq '*') { $state = 'BlockComment'; $index += 2; continue }
                if ($current -eq '@' -and $next -eq '"') { [void]$builder.Append($current); [void]$builder.Append($next); $state = 'VerbatimString'; $index += 2; continue }
                [void]$builder.Append($current)
                if ($current -eq '"') { $state = 'String' } elseif ($current -eq "'") { $state = 'Character' }
                $index++; continue
            }
            'LineComment' { if ($current -eq "`n") { [void]$builder.Append($current); $state = 'Code' }; $index++; continue }
            'BlockComment' { if ($current -eq '*' -and $next -eq '/') { $state = 'Code'; $index += 2; continue }; if ($current -eq "`n") { [void]$builder.Append($current) }; $index++; continue }
            'String' { [void]$builder.Append($current); if ($current -eq '\' -and $index + 1 -lt $source.Length) { $index++; [void]$builder.Append($source[$index]) } elseif ($current -eq '"') { $state = 'Code' }; $index++; continue }
            'Character' { [void]$builder.Append($current); if ($current -eq '\' -and $index + 1 -lt $source.Length) { $index++; [void]$builder.Append($source[$index]) } elseif ($current -eq "'") { $state = 'Code' }; $index++; continue }
            'VerbatimString' { [void]$builder.Append($current); if ($current -eq '"' -and $next -eq '"') { [void]$builder.Append($next); $index += 2; continue }; if ($current -eq '"') { $state = 'Code' }; $index++; continue }
        }
    }
    return $builder.ToString()
}
function Test-ExceptionRouteContract([string]$section) {
    $normalized = (Remove-CSharpComments $section) -replace '\s', ''
    $authorization = 'authorization.RequireAsync("SCHEDULING","APPROVE_EXCEPTION",ct)'
    $deniedReturn = 'if(deniedisnotnull)returndenied;'
    $mutation = 'repository.CreateScheduleExceptionAsync('
    $authorizationIndex = $normalized.IndexOf($authorization, [StringComparison]::Ordinal)
    $deniedIndex = $normalized.IndexOf($deniedReturn, [StringComparison]::Ordinal)
    $mutationIndex = $normalized.IndexOf($mutation, [StringComparison]::Ordinal)
    return $authorizationIndex -ge 0 -and $deniedIndex -gt $authorizationIndex -and $mutationIndex -gt $deniedIndex
}
$portalSource = Get-Content -LiteralPath $authorizationBoundary -Raw
$routeStart = $portalSource.IndexOf('app.MapPost("/api/portal/scheduling/proposals/{versionId:long}/exceptions"', [StringComparison]::Ordinal)
$routeEnd = if ($routeStart -ge 0) { $portalSource.IndexOf('app.MapPost("/api/portal/scheduling/proposals/{versionId:long}/approve"', $routeStart, [StringComparison]::Ordinal) } else { -1 }
if ($routeStart -lt 0 -or $routeEnd -le $routeStart -or -not (Test-ExceptionRouteContract $portalSource.Substring($routeStart, $routeEnd - $routeStart))) {
    Write-Output 'I9 R04 R06 BLOCKED: exact exception authorization boundary unavailable'
    exit 2
}

Write-Output 'I9 R04 R06 STATIC PASS'
$dotnet = 'C:\tmp\dotnet6\dotnet.exe'
if (-not (Test-Path -LiteralPath $dotnet -PathType Leaf)) {
    Write-Output 'I9 R04 R06 BLOCKED: dotnet unavailable'
    exit 2
}
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('sg-i9-r0406-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $links = @($files | ForEach-Object { [Security.SecurityElement]::Escape($_) })
    $authorizationLink = [Security.SecurityElement]::Escape($authorizationService)
@"
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><LangVersion>latest</LangVersion><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable></PropertyGroup><ItemGroup><FrameworkReference Include="Microsoft.AspNetCore.App"/><PackageReference Include="Npgsql" Version="6.0.10"/><Using Include="Microsoft.Extensions.Configuration"/><Using Include="Microsoft.AspNetCore.Http"/><Compile Include="$($links[0])" Link="Models.cs"/><Compile Include="$($links[1])" Link="Validator.cs"/><Compile Include="$($links[2])" Link="WorkRest.cs"/><Compile Include="$($links[3])" Link="Overlap.cs"/><Compile Include="$($links[4])" Link="NoveltyRequirements.cs"/><Compile Include="$($links[5])" Link="Evaluator.cs"/><Compile Include="$($links[6])" Link="SchedulingContracts.cs"/><Compile Include="$($links[7])" Link="SchedulingRuleContracts.cs"/><Compile Include="$authorizationLink" Link="PortalAuthorizationService.cs"/></ItemGroup></Project>
"@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Harness.csproj') -Encoding utf8
@'
namespace Sg.SuperApp.Api.Services;
public sealed record HarnessUser(long Id);
public sealed class RequestUserContext { public HarnessUser? User { get; set; } }
public sealed class PostgresPortalRepository
{
    private readonly bool _allowed;
    public PostgresPortalRepository(bool allowed) { _allowed = allowed; }
    public int PermissionCalls { get; private set; }
    public string? LastModuleCode { get; private set; }
    public string? LastActionCode { get; private set; }
    public Task<bool> HasPermissionAsync(long userId, string moduleCode, string actionCode, CancellationToken cancellationToken = default)
    { PermissionCalls++; LastModuleCode = moduleCode; LastActionCode = actionCode; return Task.FromResult(_allowed); }
}
'@ | Set-Content -LiteralPath (Join-Path $tempRoot 'AuthStubs.cs') -Encoding utf8
@'
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Sg.SuperApp.Api.Domain;
using Sg.SuperApp.Api.Services;

static JsonElement J(string text) { using var document = JsonDocument.Parse(text); return document.RootElement.Clone(); }
const string R04 = "I9-R04", R06 = "I9-R06";
const string Start = "2026-08-21T08:00:00-05:00", End = "2026-08-21T20:00:00-05:00";
var evaluator = new SchedulingRuleEvaluator(); var passed = 0;
var p4 = J("{\"unknownOutcome\":\"UNVERIFIED\",\"unknownApprovalBlocked\":true}");
var p6 = J("{\"validForEntireShift\":true,\"unverifiedOutcome\":\"EXCEPTION_REQUIRED\",\"informativeRequiresOwnerAndDueDate\":true}");
var p1 = J("{\"ordinaryDailyHours\":8,\"ordinaryWeeklyHours\":42,\"approvalFromDailyHours\":10,\"absoluteDailyHours\":12,\"absoluteWeeklyHours\":60,\"writtenAgreementRequiredAboveOrdinary\":true}");
var p2 = J("{\"minimumRestHours\":12}");
var p3 = J("{\"intervalSemantics\":\"HALF_OPEN\",\"adjacentIntervalsOverlap\":false}");
var p5 = J("{\"missingRelationOutcome\":\"EXCEPTION_REQUIRED\",\"neverAssumeZero\":true,\"directional\":true}");

void Q<T>(T expected, T actual, string label) where T : notnull { if (!EqualityComparer<T>.Default.Equals(expected, actual)) throw new Exception($"{label}: expected {expected}, got {actual}"); }
RuleEvaluation R(SchedulingRuleEvaluationBatch batch, string code) => batch.Evaluations.Single(result => result.RuleCode == code);
void Rule(RuleEvaluation result, SchedulingRuleOutcome outcome, SchedulingRuleSeverity severity, string code, bool exceptionAllowed, string label)
{
    Q(outcome, result.Outcome, label + " outcome"); Q(severity, result.Severity, label + " severity");
    Q(code, result.MessageCode, label + " code"); Q(exceptionAllowed, result.ExceptionAllowed, label + " exceptionAllowed");
    Q(false, string.IsNullOrWhiteSpace(result.Explanation), label + " explanation");
    if (!Regex.IsMatch(result.ScopeHash, "^[a-f0-9]{64}$")) throw new Exception(label + " hash");
}
void Summary(SchedulingRuleEvaluationBatch batch, int total, int compliant, int blocked, int exceptionRequired, int warning, int notApplicable, bool canApprove, string label)
{
    Q(total, batch.Summary.Total, label + " total"); Q(compliant, batch.Summary.Compliant, label + " compliant");
    Q(blocked, batch.Summary.Blocked, label + " blocked"); Q(exceptionRequired, batch.Summary.ExceptionRequired, label + " exception");
    Q(warning, batch.Summary.Warning, label + " warning"); Q(notApplicable, batch.Summary.NotApplicable, label + " notApplicable");
    Q(canApprove, batch.Summary.CanApproveOrPublish, label + " canApprove");
}
void Same(SchedulingRuleEvaluationBatch left, SchedulingRuleEvaluationBatch right, string label)
{
    Q(left.Summary, right.Summary, label + " summary"); Q(left.Evaluations.Count, right.Evaluations.Count, label + " count");
    for (var index = 0; index < left.Evaluations.Count; index++) {
        var a = left.Evaluations[index]; var b = right.Evaluations[index];
        Q(a.RuleCode, b.RuleCode, label + " rule"); Q(a.Outcome, b.Outcome, label + " outcome"); Q(a.Severity, b.Severity, label + " severity");
        Q(a.MessageCode, b.MessageCode, label + " code"); Q(a.ScopeHash, b.ScopeHash, label + " hash");
        Q(a.ParametersSnapshot.GetRawText(), b.ParametersSnapshot.GetRawText(), label + " params"); Q(a.FactsSnapshot.GetRawText(), b.FactsSnapshot.GetRawText(), label + " facts");
    }
}
void Done(string id) { passed++; Console.WriteLine(id + " PASS"); }
void WorkflowPending(string id) { Console.WriteLine(id + " WORKFLOW PENDING"); }

string Map(string sourceCode, string sourceStatus, string category, string version = "MAP-1", string sourceSystem = "HR") =>
    $"{{\"sourceSystem\":\"{sourceSystem}\",\"sourceCode\":\"{sourceCode}\",\"sourceStatus\":\"{sourceStatus}\",\"semanticCategory\":\"{category}\",\"mappingVersion\":\"{version}\",\"effectiveFrom\":\"2026-01-01T00:00:00Z\",\"effectiveTo\":null,\"mappedBy\":\"TH-DEMO-ROLE\",\"approvedBy\":\"OPS-DEMO-ROLE\"}}";
string Cat4(params string[] extra) {
    var rows = new[] { Map("INC","ACTIVE","INCAPACITY_ACTIVE"), Map("V","APPROVED","VACATION_APPROVED_ACTIVE"), Map("A","CONFIRMED","ABSENCE_CONFIRMED"), Map("A","PENDING","ABSENCE_PENDING_CONFIRMATION"), Map("TA","ACTIVE","ADDITIONAL_SHIFT"), Map("D","ACTIVE","UNKNOWN"), Map("N","ACTIVE","UNKNOWN"), Map("X","ACTIVE","UNKNOWN"), Map("TRAIN","ACTIVE","TRAINING_OR_INDUCTION_OVERLAP"), Map("FREE","ACTIVE","AVAILABLE"), Map("ADM","INFO","ADMINISTRATIVE_EVENT"), Map("ADM","FORMAL","INCAPACITY_ACTIVE"), Map("OLD","CANCELLED","EXPIRED_OR_CANCELLED") }.Concat(extra);
    return "{\"mappingDemo\":[" + string.Join(",", rows) + "]}";
}
string N(string code, string status, string category, string version = "MAP-1", string from = Start, string to = End, string id = "NOV-1", string source = "HR") =>
    $"{{\"noveltyId\":\"{id}\",\"sourceSystem\":\"{source}\",\"sourceCode\":\"{code}\",\"sourceStatus\":\"{status}\",\"semanticCategory\":\"{category}\",\"mappingVersion\":\"{version}\",\"validFrom\":\"{from}\",\"validTo\":\"{to}\"}}";
string G4(string items, string shiftId = "SHIFT-1", string employee = "GUARD-1", string start = Start, string end = End, string assignment = "ASSIGN-1", string extra = "") =>
    $"{{\"assignmentId\":\"{assignment}\",\"scheduleVersionId\":\"SCHEDULE-1\",\"employeeId\":\"{employee}\",\"shiftId\":\"{shiftId}\",\"shiftStart\":\"{start}\",\"shiftEnd\":\"{end}\",\"noveltyEvaluations\":[{items}]{extra}}}";
SchedulingRuleProfile P4(string? catalog = null, bool enabled = true, int version = 1) => new(20, "MVP-R04", version, SchedulingRuleOrigin.SIMULATED, SchedulingEnvironmentScope.MVP_TEST, "PROJECT-A", new DateOnly(2026,1,1), null, SchedulingRuleProfileStatus.ACTIVE, new string((char)('a' + version),64), new[] { new SchedulingRuleProfileEntry(R04,p4,J(catalog ?? Cat4()),enabled) });
SchedulingRuleEvaluationBatch E4(string facts, string? catalog = null, IReadOnlySet<string>? approvals = null, bool enabled = true, int version = 1) => evaluator.Evaluate(P4(catalog, enabled, version), "PROJECT-A", new DateOnly(2026,8,21), J(facts), approvals);
void Basic4(string id, string facts, SchedulingRuleOutcome outcome, SchedulingRuleSeverity severity, string code, bool exceptionAllowed, int co, int bl, int ex, int wa, int na, bool approve, string? catalog = null)
{
    var first = E4(facts,catalog); Rule(R(first,R04),outcome,severity,code,exceptionAllowed,id); Summary(first,1,co,bl,ex,wa,na,approve,id); Same(first,E4(facts,catalog),id+" deterministic"); Done(id);
}

Basic4("R04-T01",G4(N("INC","ACTIVE","INCAPACITY_ACTIVE")),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_INCAPACITY_ACTIVE",false,0,1,0,0,0,false);
Basic4("R04-T02",G4(N("V","APPROVED","VACATION_APPROVED_ACTIVE",from:"2026-08-21T12:00:00-05:00")),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_VACATION_APPROVED_ACTIVE",false,0,1,0,0,0,false);
Basic4("R04-T03",G4(N("A","CONFIRMED","ABSENCE_CONFIRMED")),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_ABSENCE_CONFIRMED",false,0,1,0,0,0,false);
Basic4("R04-T04",G4(N("A","PENDING","ABSENCE_PENDING_CONFIRMATION")),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R04_ABSENCE_PENDING_CONFIRMATION",true,0,0,1,0,0,false);
var coexistProfile = new SchedulingRuleProfile(20,"MVP-R04",1,SchedulingRuleOrigin.SIMULATED,SchedulingEnvironmentScope.MVP_TEST,"PROJECT-A",new DateOnly(2026,1,1),null,SchedulingRuleProfileStatus.ACTIVE,new string('a',64),new[] { new SchedulingRuleProfileEntry("I9-R01",p1,J("{}"),true), new SchedulingRuleProfileEntry("I9-R02",p2,J("{}"),true), new SchedulingRuleProfileEntry(R04,p4,J(Cat4()),true) });
var coexistFacts = G4(N("TA","ACTIVE","ADDITIONAL_SHIFT"),extra:",\"dailyHours\":8,\"weeklyHours\":42,\"writtenAgreement\":false,\"previousShiftEnd\":\"2026-08-20T20:00:00-05:00\",\"proposedShiftStart\":\"2026-08-21T08:00:00-05:00\"");
var coexist = evaluator.Evaluate(coexistProfile,"PROJECT-A",new DateOnly(2026,8,21),J(coexistFacts)); Rule(R(coexist,R04),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R04_ADDITIONAL_SHIFT",true,"R04-T05"); Rule(R(coexist,"I9-R01"),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R01_COMPLIANT",false,"R04-T05 R01"); Rule(R(coexist,"I9-R02"),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R02_COMPLIANT",false,"R04-T05 R02"); Summary(coexist,3,2,0,1,0,0,false,"R04-T05"); Same(coexist,evaluator.Evaluate(coexistProfile,"PROJECT-A",new DateOnly(2026,8,21),J(coexistFacts)),"R04-T05 deterministic"); Done("R04-T05");
Basic4("R04-T06",G4(N("LIC","ACTIVE","UNKNOWN")),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R04_UNVERIFIED",false,0,0,0,1,0,false);
Basic4("R04-T07",G4(N("TRAIN","ACTIVE","TRAINING_OR_INDUCTION_OVERLAP")),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R04_TRAINING_OR_INDUCTION_OVERLAP",true,0,0,1,0,0,false);
Basic4("R04-T08",G4(N("FREE","ACTIVE","AVAILABLE")),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R04_AVAILABLE",false,1,0,0,0,0,true);
Basic4("R04-T09",G4(N("ADM","INFO","ADMINISTRATIVE_EVENT")),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R04_ADMINISTRATIVE_EVENT",false,1,0,0,0,0,true);
Basic4("R04-T10",G4(N("ADM","FORMAL","INCAPACITY_ACTIVE")),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_INCAPACITY_ACTIVE",false,0,1,0,0,0,false);
Basic4("R04-T11",G4(N("OLD","CANCELLED","EXPIRED_OR_CANCELLED",from:"2026-08-21T08:00:00-05:00",to:"2026-08-21T20:00:00-05:00")),SchedulingRuleOutcome.NOT_APPLICABLE,SchedulingRuleSeverity.INFO,"I9_R04_NO_CURRENT_EFFECT",false,0,0,0,0,1,true);
Basic4("R04-T12",G4(N("INC-LIKE","ACTIVE","INCAPACITY_ACTIVE")),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R04_UNVERIFIED",false,0,0,0,1,0,false);
foreach (var code in new[] { "D", "N", "X" }) { var rejected=E4(G4(N(code,"ACTIVE","AVAILABLE"))); Rule(R(rejected,R04),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R04_NON_NOVELTY_CODE",false,"R04-T13 "+code); Summary(rejected,1,0,0,0,1,0,false,"R04-T13 "+code); } Done("R04-T13");
var missingStart=N("INC","ACTIVE","INCAPACITY_ACTIVE").Replace($",\"validFrom\":\"{Start}\"",""); Basic4("R04-T14",G4(missingStart),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R04_UNVERIFIED",false,0,0,0,1,0,false);
var missingEnd=N("INC","ACTIVE","INCAPACITY_ACTIVE").Replace($",\"validTo\":\"{End}\"",""); Basic4("R04-T15",G4(missingEnd),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R04_UNVERIFIED",false,0,0,0,1,0,false);
Basic4("R04-T16",G4(N("OLD","CANCELLED","EXPIRED_OR_CANCELLED",from:"2026-08-20T08:00:00-05:00",to:"2026-08-21T07:00:00-05:00")),SchedulingRuleOutcome.NOT_APPLICABLE,SchedulingRuleSeverity.INFO,"I9_R04_NO_CURRENT_EFFECT",false,0,0,0,0,1,true);
Basic4("R04-T17",G4(string.Join(",",N("INC","ACTIVE","INCAPACITY_ACTIVE",id:"N1"),N("A","PENDING","ABSENCE_PENDING_CONFIRMATION",id:"N2"),N("ADM","INFO","ADMINISTRATIVE_EVENT",id:"N3"))),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_INCAPACITY_ACTIVE",false,0,1,0,0,0,false);
Basic4("R04-T18",G4(string.Join(",",N("A","PENDING","ABSENCE_PENDING_CONFIRMATION",id:"N1"),N("ADM","INFO","ADMINISTRATIVE_EVENT",id:"N2"))),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R04_ABSENCE_PENDING_CONFIRMATION",true,0,0,1,0,0,false);
async Task<int> HttpStatus(IResult result) { using var services=new ServiceCollection().AddLogging().BuildServiceProvider(); var context=new DefaultHttpContext{RequestServices=services}; await result.ExecuteAsync(context); return context.Response.StatusCode; }
var deniedRepo4=new PostgresPortalRepository(false); var auth4=new PortalAuthorizationService(new RequestUserContext{User=new HarnessUser(4)},deniedRepo4); var denied4=await auth4.RequireAsync("SCHEDULING","APPROVE_EXCEPTION",CancellationToken.None); Q(403,await HttpStatus(denied4!),"R04-T19 status"); Q(1,deniedRepo4.PermissionCalls,"R04-T19 calls"); Q("APPROVE_EXCEPTION",deniedRepo4.LastActionCode!,"R04-T19 action"); WorkflowPending("R04-T19");
var pending4=E4(G4(N("A","PENDING","ABSENCE_PENDING_CONFIRMATION"))); var wrong4=E4(G4(N("A","PENDING","ABSENCE_PENDING_CONFIRMATION")),approvals:new HashSet<string>{new string('f',64)}); Summary(wrong4,1,0,0,1,0,0,false,"R04-T20 wrong"); var approved4=E4(G4(N("A","PENDING","ABSENCE_PENDING_CONFIRMATION")),approvals:new HashSet<string>{R(pending4,R04).ScopeHash}); Summary(approved4,1,0,0,1,0,0,true,"R04-T20 exact"); WorkflowPending("R04-T20");
var h21=R(pending4,R04).ScopeHash; var otherShift4=E4(G4(N("A","PENDING","ABSENCE_PENDING_CONFIRMATION"),shiftId:"SHIFT-2"),approvals:new HashSet<string>{h21}); var otherNovelty4=E4(G4(N("A","PENDING","ABSENCE_PENDING_CONFIRMATION",id:"NOV-2")),approvals:new HashSet<string>{h21}); Q(false,h21==R(otherShift4,R04).ScopeHash,"R04-T21 shift hash"); Q(false,h21==R(otherNovelty4,R04).ScopeHash,"R04-T21 novelty hash"); Summary(otherShift4,1,0,0,1,0,0,false,"R04-T21 shift"); Summary(otherNovelty4,1,0,0,1,0,0,false,"R04-T21 novelty"); WorkflowPending("R04-T21");
var oldCat=Cat4(Map("LEGACY","ACTIVE","AVAILABLE","MAP-OLD")); var newCat=Cat4(Map("LEGACY","ACTIVE","INCAPACITY_ACTIVE","MAP-NEW")); var oldFacts=G4(N("LEGACY","ACTIVE","AVAILABLE","MAP-OLD")); var oldEval=E4(oldFacts,oldCat); Rule(R(oldEval,R04),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R04_AVAILABLE",false,"R04-T22 old"); Same(oldEval,E4(oldFacts,oldCat),"R04-T22 preserved"); var newEval=E4(G4(N("LEGACY","ACTIVE","INCAPACITY_ACTIVE","MAP-NEW")),newCat,version:2); Rule(R(newEval,R04),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_INCAPACITY_ACTIVE",false,"R04-T22 new"); Q(false,R(oldEval,R04).ScopeHash==R(newEval,R04).ScopeHash,"R04-T22 hash"); Done("R04-T22");
var duplicateCat=Cat4(Map("V","APPROVED","VACATION_APPROVED_ACTIVE","MAP-2")); var duplicateRejected=false; try { E4(G4(N("INC","ACTIVE","INCAPACITY_ACTIVE")),duplicateCat); } catch(SchedulingRuleContractException) { duplicateRejected=true; } Q(true,duplicateRejected,"R04-T23 unrelated duplicate rejected before decision"); Done("R04-T23");
var disabled4=E4(G4(N("FREE","ACTIVE","AVAILABLE")),enabled:false); Rule(R(disabled4,R04),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.ERROR,"I9_R04_DISABLED_UNVERIFIED",false,"R04-T24"); Summary(disabled4,1,0,0,0,1,0,false,"R04-T24"); Done("R04-T24");

string Req(string code,string category,string version="REQ-1",bool remedial=false,string from="2026-01-01T00:00:00Z",string to="null",string project="PROJECT-A",string position="POSITION-1",string source="I3-DEMO",string sourceCode="") => $"{{\"projectCode\":\"{project}\",\"positionCode\":\"{position}\",\"requirementCode\":\"{code}\",\"category\":\"{category}\",\"catalogVersion\":\"{version}\",\"sourceSystem\":\"{source}\",\"sourceRequirementCode\":\"{(sourceCode.Length==0?"SRC-"+code:sourceCode)}\",\"sourceStatus\":\"ACTIVE\",\"evidenceType\":\"DEMO_RECORD\",\"evidenceSource\":\"{source}\",\"effectiveFrom\":\"{from}\",\"effectiveTo\":{(to=="null"?"null":"\""+to+"\"")},\"informativeRemediable\":{remedial.ToString().ToLowerInvariant()}}}";
string Cat6(params string[] requirements) => "{\"requirementsDemo\":["+string.Join(",",requirements)+"]}";
string Ev(string code,string category,string state="VERIFIED",string version="REQ-1",string from=Start,string to=End,string extra="",string source="I3-DEMO",string sourceCode="",string evidenceId="") { var evidence=evidenceId.Length==0?"EVID-"+code:evidenceId; return $"{{\"evaluationId\":\"EVAL-{code}\",\"requirementCode\":\"{code}\",\"category\":\"{category}\",\"catalogVersion\":\"{version}\",\"sourceSystem\":\"{source}\",\"sourceRequirementCode\":\"{(sourceCode.Length==0?"SRC-"+code:sourceCode)}\",\"sourceStatus\":\"ACTIVE\",\"evidenceId\":\"{evidence}\",\"evidenceSource\":\"{source}\",\"evidenceType\":\"DEMO_RECORD\",\"evidenceState\":\"{state}\",\"validFrom\":\"{from}\",\"validTo\":\"{to}\"{extra}}}"; }
string G6(string items,string employee="GUARD-1",string position="POSITION-1",string shift="SHIFT-1",string start=Start,string end=End,string extra="") => $"{{\"assignmentId\":\"ASSIGN-1\",\"scheduleVersionId\":\"SCHEDULE-1\",\"employeeId\":\"{employee}\",\"positionCode\":\"{position}\",\"shiftId\":\"{shift}\",\"shiftStart\":\"{start}\",\"shiftEnd\":\"{end}\",\"requirementEvaluations\":[{items}]{extra}}}";
SchedulingRuleProfile P6(string catalog,bool enabled=true,int version=1) => new(21,"MVP-R06",version,SchedulingRuleOrigin.SIMULATED,SchedulingEnvironmentScope.MVP_TEST,"PROJECT-A",new DateOnly(2026,1,1),null,SchedulingRuleProfileStatus.ACTIVE,new string((char)('k'+version),64),new[]{new SchedulingRuleProfileEntry(R06,p6,J(catalog),enabled)});
SchedulingRuleEvaluationBatch E6(string facts,string catalog,IReadOnlySet<string>? approvals=null,bool enabled=true,int version=1) => evaluator.Evaluate(P6(catalog,enabled,version),"PROJECT-A",new DateOnly(2026,8,21),J(facts),approvals);
void Basic6(string id,string facts,string catalog,SchedulingRuleOutcome outcome,SchedulingRuleSeverity severity,string code,bool exceptionAllowed,int co,int ex,int wa,bool approve)
{ var first=E6(facts,catalog); Rule(R(first,R06),outcome,severity,code,exceptionAllowed,id); Summary(first,1,co,0,ex,wa,0,approve,id); Same(first,E6(facts,catalog),id+" deterministic"); Done(id); }
var allCatalog=Cat6(Req("COURSE-1","COURSE"),Req("ACC-1","ACCREDITATION"),Req("CERT-1","CERTIFICATION"),Req("LIC-1","LICENSE_OR_PERMIT"),Req("OTHER-1","OTHER_REQUIREMENT")); var allEvidence=string.Join(",",Ev("COURSE-1","COURSE"),Ev("ACC-1","ACCREDITATION"),Ev("CERT-1","CERTIFICATION"),Ev("LIC-1","LICENSE_OR_PERMIT"),Ev("OTHER-1","OTHER_REQUIREMENT"));
Basic6("R06-T01",G6(allEvidence),allCatalog,SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R06_COMPLIANT",false,1,0,0,true);
var courseCat=Cat6(Req("COURSE-1","COURSE")); Basic6("R06-T02",G6(""),courseCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_MISSING",false,0,1,0,false);
Basic6("R06-T03",G6(Ev("COURSE-1","COURSE",to:"2026-08-21T07:00:00-05:00")),courseCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_EXPIRED_OR_PARTIAL",false,0,1,0,false);
Basic6("R06-T04",G6(Ev("COURSE-1","COURSE",to:"2026-08-21T12:00:00-05:00")),courseCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_EXPIRED_OR_PARTIAL",false,0,1,0,false);
Basic6("R06-T05",G6(Ev("COURSE-1","COURSE",to:End)),courseCat,SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R06_COMPLIANT",false,1,0,0,true);
Basic6("R06-T06",G6(Ev("COURSE-1","COURSE",state:"UNVERIFIED")),courseCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_UNVERIFIED",false,0,1,0,false);
Basic6("R06-T07",G6(Ev("COURSE-1","COURSE",source:"UNKNOWN-SOURCE")),courseCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_UNVERIFIED",false,0,1,0,false);
var remedialCat=Cat6(Req("COURSE-1","COURSE",remedial:true)); var remedialExtra=",\"informativeRemediable\":true,\"remediationOwnerRole\":\"HR_REVIEWER\",\"remediationOwnerKey\":\"ROLE-7\",\"dueDate\":\"2026-08-22\""; Basic6("R06-T08",G6(Ev("COURSE-1","COURSE",state:"MISSING",extra:remedialExtra)),remedialCat,SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R06_INFORMATIVE_REMEDIABLE",false,0,0,1,false);
var noOwner=",\"informativeRemediable\":true,\"dueDate\":\"2026-08-22\""; Basic6("R06-T09",G6(Ev("COURSE-1","COURSE",state:"MISSING",extra:noOwner)),remedialCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_UNVERIFIED_REMEDIATION",false,0,1,0,false);
var noDue=",\"informativeRemediable\":true,\"remediationOwnerRole\":\"HR_REVIEWER\",\"remediationOwnerKey\":\"ROLE-7\""; Basic6("R06-T10",G6(Ev("COURSE-1","COURSE",state:"MISSING",extra:noDue)),remedialCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_UNVERIFIED_REMEDIATION",false,0,1,0,false);
Basic6("R06-T11",G6(Ev("COURSE-1","COURSE",state:"MISSING")),courseCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_MISSING",false,0,1,0,false);
var hrMissing=Ev("COURSE-1","COURSE",state:"MISSING"); var hrPending=E6(G6(hrMissing),courseCat); Rule(R(hrPending,R06),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_MISSING",false,"R06-T12"); Summary(hrPending,1,0,0,1,0,0,false,"R06-T12"); WorkflowPending("R06-T12");
var hrApproved=E6(G6(hrMissing),courseCat,new HashSet<string>{R(hrPending,R06).ScopeHash}); Summary(hrApproved,1,0,0,1,0,0,false,"R06-T13"); Q(R(hrPending,R06).ScopeHash,R(hrApproved,R06).ScopeHash,"R06-T13 exact hash"); WorkflowPending("R06-T13");
var noHrMissing=Ev("COURSE-1","COURSE",state:"MISSING"); var noHr=E6(G6(noHrMissing),courseCat); var noHrApproved=E6(G6(noHrMissing),courseCat,new HashSet<string>{R(noHr,R06).ScopeHash}); Rule(R(noHrApproved,R06),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_MISSING",false,"R06-T14"); Summary(noHrApproved,1,0,0,1,0,0,false,"R06-T14"); WorkflowPending("R06-T14");
var deniedRepo6=new PostgresPortalRepository(false); var auth6=new PortalAuthorizationService(new RequestUserContext{User=new HarnessUser(6)},deniedRepo6); var denied6=await auth6.RequireAsync("SCHEDULING","VALIDATE_REQUIREMENT",CancellationToken.None); Q(403,await HttpStatus(denied6!),"R06-T15 status"); Q("SCHEDULING",deniedRepo6.LastModuleCode!,"R06-T15 module"); Q("VALIDATE_REQUIREMENT",deniedRepo6.LastActionCode!,"R06-T15 action"); WorkflowPending("R06-T15");
var oldHash=R(hrPending,R06).ScopeHash; var otherTurn=E6(G6(hrMissing,shift:"SHIFT-2"),courseCat,new HashSet<string>{oldHash}); var otherRequirementCat=Cat6(Req("COURSE-2","COURSE")); var otherRequirementEvidence=Ev("COURSE-2","COURSE",state:"MISSING"); var otherRequirement=E6(G6(otherRequirementEvidence),otherRequirementCat,new HashSet<string>{oldHash}); Summary(otherTurn,1,0,0,1,0,0,false,"R06-T16 turn"); Summary(otherRequirement,1,0,0,1,0,0,false,"R06-T16 requirement"); Q(false,oldHash==R(otherTurn,R06).ScopeHash,"R06-T16 turn hash"); Q(false,oldHash==R(otherRequirement,R06).ScopeHash,"R06-T16 requirement hash"); WorkflowPending("R06-T16");
var baseHash=R(E6(G6(Ev("COURSE-1","COURSE")),courseCat),R06).ScopeHash; var guardHash=R(E6(G6(Ev("COURSE-1","COURSE"),employee:"GUARD-2"),courseCat),R06).ScopeHash; var positionCat=Cat6(Req("COURSE-1","COURSE",position:"POSITION-2")); var positionHash=R(E6(G6(Ev("COURSE-1","COURSE"),position:"POSITION-2"),positionCat),R06).ScopeHash; var turnHash=R(E6(G6(Ev("COURSE-1","COURSE"),shift:"SHIFT-2"),courseCat),R06).ScopeHash; var versionCat=Cat6(Req("COURSE-1","COURSE",version:"REQ-2")); var versionHash=R(E6(G6(Ev("COURSE-1","COURSE",version:"REQ-2")),versionCat,version:2),R06).ScopeHash; foreach(var hash in new[]{guardHash,positionHash,turnHash,versionHash})Q(false,baseHash==hash,"R06-T17 changed hash"); WorkflowPending("R06-T17");
var overlapping=Cat6(Req("COURSE-1","COURSE","REQ-1",from:"2026-01-01T00:00:00Z",to:"2026-12-31T00:00:00Z"),Req("COURSE-1","COURSE","REQ-2",from:"2026-06-01T00:00:00Z")); Basic6("R06-T18",G6(Ev("COURSE-1","COURSE")),overlapping,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_INVALID_CATALOG",false,0,1,0,false);
Basic6("R06-T19",G6(""),Cat6(),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R06_CATALOG_INCOMPLETE",false,0,0,1,false);
Basic6("R06-T20",G6(Ev("COURSE-1","COURSE",to:"2026-08-21T19:59:59.9999999-05:00")),courseCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_EXPIRED_OR_PARTIAL",false,0,1,0,false);
var blockingProfile=new SchedulingRuleProfile(22,"MVP-MIX",1,SchedulingRuleOrigin.SIMULATED,SchedulingEnvironmentScope.MVP_TEST,"PROJECT-A",new DateOnly(2026,1,1),null,SchedulingRuleProfileStatus.ACTIVE,new string('z',64),new[]{new SchedulingRuleProfileEntry("I9-R01",p1,J("{}"),true),new SchedulingRuleProfileEntry(R06,p6,J(courseCat),true)}); var blockingFacts=G6(hrMissing,extra:",\"dailyHours\":12.01,\"weeklyHours\":42,\"writtenAgreement\":true"); var initialBlock=evaluator.Evaluate(blockingProfile,"PROJECT-A",new DateOnly(2026,8,21),J(blockingFacts)); var afterR06=evaluator.Evaluate(blockingProfile,"PROJECT-A",new DateOnly(2026,8,21),J(blockingFacts),new HashSet<string>{R(initialBlock,R06).ScopeHash}); Rule(R(afterR06,"I9-R01"),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R01_ABSOLUTE_MAX_EXCEEDED",false,"R06-T21 R01"); Summary(afterR06,2,0,1,1,0,0,false,"R06-T21 R01");
var prohibitedMatrix=J("{\"matrixDemo\":[{\"from\":\"PROJECT-A/POSITION-1\",\"to\":\"PROJECT-C/POSITION-3\",\"minutes\":null,\"prohibited\":true}]}"); var overlapProfile=new SchedulingRuleProfile(23,"MVP-MIX-OVERLAP",1,SchedulingRuleOrigin.SIMULATED,SchedulingEnvironmentScope.MVP_TEST,"PROJECT-A",new DateOnly(2026,1,1),null,SchedulingRuleProfileStatus.ACTIVE,new string('y',64),new[]{new SchedulingRuleProfileEntry("I9-R03",p3,J("{}"),true),new SchedulingRuleProfileEntry("I9-R05",p5,prohibitedMatrix,true),new SchedulingRuleProfileEntry(R06,p6,J(courseCat),true)}); var overlapExtra=",\"proposedShiftStart\":\"2026-08-21T08:00:00-05:00\",\"proposedShiftEnd\":\"2026-08-21T20:00:00-05:00\",\"existingIntervals\":[{\"employeeId\":\"GUARD-1\",\"status\":\"APPROVED\",\"start\":\"2026-08-21T09:00:00-05:00\",\"end\":\"2026-08-21T10:00:00-05:00\"}],\"previousAssignmentId\":\"ASSIGN-0\",\"originPositionCode\":\"PROJECT-A/POSITION-1\",\"destinationPositionCode\":\"PROJECT-C/POSITION-3\",\"previousShiftStart\":\"2026-08-20T08:00:00-05:00\",\"previousShiftEnd\":\"2026-08-20T20:00:00-05:00\""; var overlapFacts=G6(hrMissing,extra:overlapExtra); var overlapInitial=evaluator.Evaluate(overlapProfile,"PROJECT-A",new DateOnly(2026,8,21),J(overlapFacts)); var overlapApproved=evaluator.Evaluate(overlapProfile,"PROJECT-A",new DateOnly(2026,8,21),J(overlapFacts),new HashSet<string>{R(overlapInitial,R06).ScopeHash}); Rule(R(overlapApproved,"I9-R03"),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R03_OVERLAP_APPROVED_BLOCKED",false,"R06-T21 R03"); Rule(R(overlapApproved,"I9-R05"),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R05_PROHIBITED",false,"R06-T21 R05"); Summary(overlapApproved,3,0,2,1,0,0,false,"R06-T21 R03/R05"); Done("R06-T21");
var oldReqCat=Cat6(Req("COURSE-1","COURSE","REQ-1")); var oldReqFacts=G6(Ev("COURSE-1","COURSE",version:"REQ-1")); var immutableOldProfile=P6(oldReqCat); var oldReq=evaluator.Evaluate(immutableOldProfile,"PROJECT-A",new DateOnly(2026,8,21),J(oldReqFacts)); var newReqCat=Cat6(Req("COURSE-1","COURSE","REQ-2")); var replacementProfile=P6(newReqCat,version:2); var newReq=evaluator.Evaluate(replacementProfile,"PROJECT-A",new DateOnly(2026,8,21),J(oldReqFacts)); Same(oldReq,evaluator.Evaluate(immutableOldProfile,"PROJECT-A",new DateOnly(2026,8,21),J(oldReqFacts)),"R06-T22 immutable snapshot preserved"); Rule(R(oldReq,R06),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R06_COMPLIANT",false,"R06-T22 old"); Rule(R(newReq,R06),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_UNVERIFIED",false,"R06-T22 new"); Q(false,R(oldReq,R06).ScopeHash==R(newReq,R06).ScopeHash,"R06-T22 hash"); Done("R06-T22");
var disabled6=E6(G6(allEvidence),allCatalog,enabled:false); Rule(R(disabled6,R06),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.ERROR,"I9_R06_DISABLED_UNVERIFIED",false,"R06-T23"); Summary(disabled6,1,0,0,0,1,0,false,"R06-T23"); Done("R06-T23");

var malformed4=SchedulingNoveltyRequirementRules.EvaluateR04(p4,J(Cat4()),J("{}")); Q(SchedulingRuleOutcome.WARNING,malformed4.Outcome,"malformed R04 outside count");
var malformed6=SchedulingNoveltyRequirementRules.EvaluateR06(p6,J(courseCat),J("{}"),"PROJECT-A"); Q(SchedulingRuleOutcome.EXCEPTION_REQUIRED,malformed6.Outcome,"malformed R06 outside count");
var incompleteMappingRejected=false; try { SchedulingNoveltyRequirementRules.EvaluateR04(p4,J("{\"mappingDemo\":[{\"sourceSystem\":\"HR\",\"sourceCode\":\"INC\",\"sourceStatus\":\"ACTIVE\",\"semanticCategory\":\"INCAPACITY_ACTIVE\",\"mappingVersion\":\"MAP-1\",\"effectiveFrom\":\"2026-01-01T00:00:00Z\",\"effectiveTo\":null}]}"),J(G4(N("INC","ACTIVE","INCAPACITY_ACTIVE")))); } catch(SchedulingRuleContractException) { incompleteMappingRejected=true; } Q(true,incompleteMappingRejected,"R04 mapping governance rejected outside count");
var piiRejected=false; try { E4(G4(N("FREE","ACTIVE","AVAILABLE"),employee:"Jane Doe")); } catch(ArgumentException) { piiRejected=true; } Q(true,piiRejected,"PII/free text rejected outside count");
var payloadRejected=false; try { E4(G4(N("FREE","ACTIVE","AVAILABLE"),employee:new string('A',81))); } catch(ArgumentException) { payloadRejected=true; } Q(true,payloadRejected,"payload rejected outside count");
Q(38,passed,"numbered rules scenario count"); Console.WriteLine($"I9 R04 R06 RULES PASS {passed}");
'@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Program.cs') -Encoding utf8
    & $dotnet run --project (Join-Path $tempRoot 'Harness.csproj') --configuration Release
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
    $settingsPath = Join-Path $repoRoot 'apps/sg-superapp-api/appsettings.json'
    if (-not (Test-Path -LiteralPath $psql -PathType Leaf) -or -not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
        Write-Output 'I9 R04 R06 BLOCKED: local PostgreSQL test prerequisites unavailable'; exit 2
    }
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    $parts = @{}
    foreach ($part in ([string]$settings.ConnectionStrings.Postgres -split ';')) {
        if ($part -match '^([^=]+)=(.*)$') { $parts[$matches[1].Trim()] = $matches[2] }
    }
    if (@('Host','Port','Database','Username','Password') | Where-Object { -not $parts[$_] }) {
        Write-Output 'I9 R04 R06 BLOCKED: local PostgreSQL configuration incomplete'; exit 2
    }
    $env:PGHOST=$parts.Host; $env:PGPORT=$parts.Port; $env:PGDATABASE=$parts.Database
    $env:PGUSER=$parts.Username; $env:PGPASSWORD=$parts.Password
    $schema = 'i9_r0406_' + [guid]::NewGuid().ToString('N').Substring(0,12)
    try {
        & $psql -X -w -v ON_ERROR_STOP=1 -c "CREATE SCHEMA $schema" | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Output 'I9 R04 R06 BLOCKED: cannot create temporal schema'; exit 2 }
        $env:PGOPTIONS = "--search_path=$schema,public"
        Get-ChildItem (Join-Path $repoRoot 'db/migrations') -Filter '*.sql' | Sort-Object Name | ForEach-Object {
            & $psql -X -w -v ON_ERROR_STOP=1 -f $_.FullName | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "migration failed: $($_.Name)" }
        }
        1..2 | ForEach-Object {
            & $psql -X -w -v ON_ERROR_STOP=1 -f (Join-Path $repoRoot 'db/seeds/011_i9_mvp_simulated_rule_profile.sql') | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'seed failed' }
            & $psql -X -w -v ON_ERROR_STOP=1 -f (Join-Path $repoRoot 'db/tests/008_i9_mvp_rule_profiles_contract.sql') | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'database contract failed' }
        }
        $apiAssembly = [Security.SecurityElement]::Escape((Join-Path $repoRoot 'apps/sg-superapp-api/bin/Release/net6.0/sg-superapp-api.dll'))
@"
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><LangVersion>preview</LangVersion><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup><FrameworkReference Include="Microsoft.AspNetCore.App"/><PackageReference Include="Npgsql" Version="6.0.10"/><Compile Include="WorkflowProgram.cs"/><Reference Include="sg-superapp-api"><HintPath>$apiAssembly</HintPath></Reference></ItemGroup></Project>
"@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Workflow.csproj') -Encoding utf8
        $env:I9_TEMP_CONNECTION = "Host=$($parts.Host);Port=$($parts.Port);Database=$($parts.Database);Username=$($parts.Username);Password=$($parts.Password);Search Path=$schema,public"
@'
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Npgsql;
using Sg.SuperApp.Api.Contracts.Portal;
using Sg.SuperApp.Api.Domain;
using Sg.SuperApp.Api.Services;

var connectionString=Environment.GetEnvironmentVariable("I9_TEMP_CONNECTION")??throw new Exception("missing connection");
var config=new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>{{"ConnectionStrings:Postgres",connectionString}}).Build();
var validator=new SchedulingRuleProfileValidator();var profileRepository=new SchedulingRuleProfileRepository(config,validator);var httpRepository=new SchedulingRuleHttpRepository(config);var portalRepository=new PostgresPortalRepository(config);var evaluator=new SchedulingRuleEvaluator();
static JsonElement J(string value){using var d=JsonDocument.Parse(value);return d.RootElement.Clone();}
static void Q(bool value,string label){if(!value)throw new Exception(label);Console.WriteLine(label+" PASS");}
static async Task<long> ValidationCount(string connectionString,long evaluationId){await using var c=new NpgsqlConnection(connectionString);await c.OpenAsync();await using var q=new NpgsqlCommand("select count(*) from scheduling_rule_hr_validations where evaluation_id=@id",c);q.Parameters.AddWithValue("id",evaluationId);return (long)(await q.ExecuteScalarAsync()??0L);}
static async Task<(int Version,string Outcome,string ScopeHash,string Parameters,string Facts,string Status)> PersistedSnapshot(string connectionString,long evaluationId){await using var c=new NpgsqlConnection(connectionString);await c.OpenAsync();await using var q=new NpgsqlCommand("select p.version,e.outcome,e.scope_hash,e.parameters_snapshot::text,e.facts_snapshot::text,e.exception_status from scheduling_rule_evaluations e join scheduling_rule_profiles p on p.id=e.rule_profile_id where e.id=@id",c);q.Parameters.AddWithValue("id",evaluationId);await using var r=await q.ExecuteReaderAsync();if(!await r.ReadAsync())throw new Exception("persisted snapshot");return(r.GetInt32(0),r.GetString(1),r.GetString(2),r.GetString(3),r.GetString(4),r.GetString(5));}
long actorId,versionId;
await using(var cn=new NpgsqlConnection(connectionString)){await cn.OpenAsync();
 await using var cmd=new NpgsqlCommand(@"insert into app_users(full_name,username,password_hash) values('I9 Demo Actor','i9.demo.actor','not-a-real-password') returning id;
insert into clients(code,name,status) values('I9-DEMO-CLIENT','I9 Demo Client','ACTIVO') returning id;",cn);await using var rd=await cmd.ExecuteReaderAsync();await rd.ReadAsync();actorId=rd.GetInt64(0);await rd.NextResultAsync();await rd.ReadAsync();var clientId=rd.GetInt64(0);await rd.CloseAsync();
 await using var fixture=new NpgsqlCommand(@"with p as (insert into service_projects(client_id,code,name,effective_from,status,created_at,updated_at) values(@client,'PROJECT-A','Project A',date '2026-01-01','ACTIVO',now(),now()) returning id),s as (insert into schedules(project_id,period_start,period_end,created_by) select id,date '2026-08-21',date '2026-08-21','i9.demo.actor' from p returning id) insert into schedule_versions(schedule_id,version_number,status,created_by) select id,1,'PROPUESTA','i9.demo.actor' from s returning id",cn);fixture.Parameters.AddWithValue("client",clientId);versionId=(long)(await fixture.ExecuteScalarAsync()??throw new Exception("fixture"));}
var profile=await profileRepository.LoadActiveAsync("PROJECT-A",new DateOnly(2026,8,21),SchedulingEnvironmentScope.MVP_TEST,CancellationToken.None);
var facts=J("""{"dailyHours":8,"weeklyHours":42,"writtenAgreement":false,"previousShiftEnd":"2026-08-20T20:00:00-05:00","proposedShiftStart":"2026-08-21T08:00:00-05:00","proposedShiftEnd":"2026-08-21T20:00:00-05:00","assignmentId":"ASSIGN-1","scheduleVersionId":"SCHEDULE-1","employeeId":"GUARD-1","positionCode":"POSITION-1","shiftId":"SHIFT-1","shiftStart":"2026-08-21T08:00:00-05:00","shiftEnd":"2026-08-21T20:00:00-05:00","noveltyEvaluations":[{"noveltyId":"NOV-1","sourceSystem":"HR-DEMO","sourceCode":"A","sourceStatus":"PENDING","semanticCategory":"ABSENCE_PENDING_CONFIRMATION","mappingVersion":"MAP-V2","validFrom":"2026-08-21T08:00:00-05:00","validTo":"2026-08-21T20:00:00-05:00"}],"requirementEvaluations":[{"evaluationId":"EVAL-COURSE","requirementCode":"COURSE-DEMO","category":"COURSE","catalogVersion":"REQ-V2","sourceSystem":"I3-DEMO","sourceRequirementCode":"SRC-COURSE-DEMO","sourceStatus":"ACTIVE","evidenceId":"EVID-COURSE","evidenceSource":"I3-DEMO","evidenceType":"DEMO_RECORD","evidenceState":"MISSING","validFrom":"2026-08-21T08:00:00-05:00","validTo":"2026-08-21T20:00:00-05:00","hrValidation":{"validationId":"TH-COURSE","validatorRoleKey":"TH-VALIDATOR","validatedAt":"2026-08-20T12:00:00-05:00","evidenceId":"EVID-COURSE"}},{"evaluationId":"EVAL-ACC","requirementCode":"ACCREDITATION-DEMO","category":"ACCREDITATION","catalogVersion":"REQ-V2","sourceSystem":"I3-DEMO","sourceRequirementCode":"SRC-ACCREDITATION-DEMO","sourceStatus":"ACTIVE","evidenceId":"EVID-ACC","evidenceSource":"I3-DEMO","evidenceType":"DEMO_RECORD","evidenceState":"MISSING","validFrom":"2026-08-21T08:00:00-05:00","validTo":"2026-08-21T20:00:00-05:00","hrValidation":{"validationId":"TH-ACC","validatorRoleKey":"TH-VALIDATOR","validatedAt":"2026-08-20T12:00:00-05:00","evidenceId":"EVID-ACC"}}]}""");
var clientHrRejected=false;try{evaluator.Evaluate(profile,"PROJECT-A",new DateOnly(2026,8,21),facts);}catch(ArgumentException){clientHrRejected=true;}Q(clientHrRejected,"client TH facts rejected");
var cleanFacts=J(facts.GetRawText().Replace(",\"hrValidation\":{\"validationId\":\"TH-COURSE\",\"validatorRoleKey\":\"TH-VALIDATOR\",\"validatedAt\":\"2026-08-20T12:00:00-05:00\",\"evidenceId\":\"EVID-COURSE\"}","").Replace(",\"hrValidation\":{\"validationId\":\"TH-ACC\",\"validatorRoleKey\":\"TH-VALIDATOR\",\"validatedAt\":\"2026-08-20T12:00:00-05:00\",\"evidenceId\":\"EVID-ACC\"}",""));
var batch=evaluator.Evaluate(profile,"PROJECT-A",new DateOnly(2026,8,21),cleanFacts);var saved=await httpRepository.PersistEvaluationsAsync(versionId,null,"PROJECT-A",batch,"i9.demo.actor",CancellationToken.None);
var r04=saved.Single(x=>x.Evaluation.RuleCode=="I9-R04");var r06=saved.Single(x=>x.Evaluation.RuleCode=="I9-R06");
Q(await portalRepository.AuditScheduleExceptionDenialAsync(versionId,actorId,"i9.demo.actor"),"R04-T19");
await portalRepository.CreateScheduleExceptionAsync(versionId,new(null,r04.Id,"I9-R04","HR_VALIDATED_DEMO","demo","OPS","2026-08-22",1),new DateOnly(2026,8,22),actorId,"i9.demo.actor");Q(true,"R04-T20");
try{await portalRepository.CreateScheduleExceptionAsync(versionId+999,new(null,r04.Id,"I9-R04","HR_VALIDATED_DEMO","demo","OPS","2026-08-22",1),new DateOnly(2026,8,22),actorId,"i9.demo.actor");throw new Exception("reuse accepted");}catch(KeyNotFoundException){}Q(true,"R04-T21");
Q(!r06.Evaluation.ExceptionAllowed,"R06-T12");await httpRepository.ValidateRequirementEvidenceAsync(r06.Id,"EVID-COURSE",actorId,"i9.demo.actor",CancellationToken.None);await httpRepository.ValidateRequirementEvidenceAsync(r06.Id,"EVID-ACC",actorId,"i9.demo.actor",CancellationToken.None);await portalRepository.CreateScheduleExceptionAsync(versionId,new(null,r06.Id,"I9-R06","HR_VALIDATED_DEMO","demo","TH","2026-08-22",1),new DateOnly(2026,8,22),actorId,"i9.demo.actor");Q(true,"R06-T13");
var noHrBatch=evaluator.Evaluate(profile,"PROJECT-A",new DateOnly(2026,8,21),cleanFacts);var noHrSaved=await httpRepository.PersistEvaluationsAsync(versionId,null,"PROJECT-A",noHrBatch,"i9.demo.actor",CancellationToken.None);var noHrR06=noHrSaved.Single(x=>x.Evaluation.RuleCode=="I9-R06");try{await portalRepository.CreateScheduleExceptionAsync(versionId,new(null,noHrR06.Id,"I9-R06","HR_VALIDATED_DEMO","demo","TH","2026-08-22",1),new DateOnly(2026,8,22),actorId,"i9.demo.actor");throw new Exception("no HR accepted");}catch(InvalidOperationException){}Q(true,"R06-T14");
var validationCountBefore=await ValidationCount(connectionString,noHrR06.Id);Q(await httpRepository.AuditRequirementValidationDenialAsync(noHrR06.Id,actorId,"i9.demo.actor",CancellationToken.None),"R06-T15 audit");Q(validationCountBefore==await ValidationCount(connectionString,noHrR06.Id),"R06-T15 no mutation");try{await portalRepository.CreateScheduleExceptionAsync(versionId+999,new(null,r06.Id,"I9-R06","HR_VALIDATED_DEMO","demo","TH","2026-08-22",1),new DateOnly(2026,8,22),actorId,"i9.demo.actor");throw new Exception("wrong version accepted");}catch(KeyNotFoundException){}Q(true,"R06-T16");
var changed=J(cleanFacts.GetRawText().Replace("SHIFT-1","SHIFT-2"));var changedBatch=evaluator.Evaluate(profile,"PROJECT-A",new DateOnly(2026,8,21),changed);var changedSaved=await httpRepository.PersistEvaluationsAsync(versionId,null,"PROJECT-A",changedBatch,"i9.demo.actor",CancellationToken.None);Q(changedSaved.Single(x=>x.Evaluation.RuleCode=="I9-R06").Evaluation.ScopeHash!=r06.Evaluation.ScopeHash,"R06-T17");
var oldStored=await PersistedSnapshot(connectionString,r06.Id);long replacementProfileId;
await using(var cn=new NpgsqlConnection(connectionString)){await cn.OpenAsync();await using(var retire=new NpgsqlCommand("update scheduling_rule_profiles set status='RETIRED',effective_to=date '2026-08-21' where id=@id",cn)){retire.Parameters.AddWithValue("id",profile.Id);await retire.ExecuteNonQueryAsync();}await using(var insert=new NpgsqlCommand(@"insert into scheduling_rule_profiles(profile_code,version,origin,environment_scope,scope_code,effective_from,status,checksum,created_by,approval_evidence) select profile_code,version+1,origin,environment_scope,scope_code,date '2026-08-22','DRAFT',repeat('3',64),'i9.traceability',jsonb_build_object('mode','SIMULATED','purpose','MVP_TEST','catalogVersion','REQ-V3') from scheduling_rule_profiles where id=@old returning id",cn)){insert.Parameters.AddWithValue("old",profile.Id);replacementProfileId=(long)(await insert.ExecuteScalarAsync()??throw new Exception("replacement profile"));}await using(var entries=new NpgsqlCommand(@"insert into scheduling_rule_profile_entries(rule_profile_id,rule_code,parameters,catalog_snapshot,enabled) select @new,rule_code,parameters,case when rule_code='I9-R06' then replace(catalog_snapshot::text,'REQ-V2','REQ-V3')::jsonb else catalog_snapshot end,enabled from scheduling_rule_profile_entries where rule_profile_id=@old",cn)){entries.Parameters.AddWithValue("new",replacementProfileId);entries.Parameters.AddWithValue("old",profile.Id);await entries.ExecuteNonQueryAsync();}await using(var activate=new NpgsqlCommand("update scheduling_rule_profiles set status='ACTIVE',activated_by='i9.traceability',activated_at=now() where id=@id",cn)){activate.Parameters.AddWithValue("id",replacementProfileId);await activate.ExecuteNonQueryAsync();}}
long replacementVersionId;await using(var cn=new NpgsqlConnection(connectionString)){await cn.OpenAsync();await using var replacementVersion=new NpgsqlCommand(@"with s as (insert into schedules(project_id,period_start,period_end,created_by) select s.project_id,date '2026-08-22',date '2026-08-22','i9.traceability' from schedule_versions sv join schedules s on s.id=sv.schedule_id where sv.id=@old returning id) insert into schedule_versions(schedule_id,version_number,status,created_by) select id,1,'PROPUESTA','i9.traceability' from s returning id",cn);replacementVersion.Parameters.AddWithValue("old",versionId);replacementVersionId=(long)(await replacementVersion.ExecuteScalarAsync()??throw new Exception("replacement schedule version"));}
var replacementEntries=profile.Entries.Select(x=>x.RuleCode=="I9-R06"?new SchedulingRuleProfileEntry(x.RuleCode,x.Parameters,J(x.CatalogSnapshot.GetRawText().Replace("REQ-V2","REQ-V3")),x.Enabled):x).ToArray();var replacementProfile=new SchedulingRuleProfile(replacementProfileId,profile.ProfileCode,profile.Version+1,profile.Origin,profile.EnvironmentScope,profile.ScopeCode,new DateOnly(2026,8,22),null,SchedulingRuleProfileStatus.ACTIVE,new string('3',64),replacementEntries);var replacementFacts=J(cleanFacts.GetRawText().Replace("REQ-V2","REQ-V3"));var replacementBatch=evaluator.Evaluate(replacementProfile,"PROJECT-A",new DateOnly(2026,8,22),replacementFacts);await httpRepository.PersistEvaluationsAsync(replacementVersionId,null,"PROJECT-A",replacementBatch,"i9.traceability",CancellationToken.None);var reloaded=await httpRepository.LoadEvaluationsAsync(replacementVersionId,CancellationToken.None);var oldReloaded=await PersistedSnapshot(connectionString,r06.Id);var newReloaded=reloaded.Single(x=>x.RuleCode=="I9-R06"&&x.ProfileVersion==profile.Version+1);Q(oldStored.ScopeHash==oldReloaded.ScopeHash&&oldStored.Parameters==oldReloaded.Parameters&&oldStored.Facts==oldReloaded.Facts&&oldStored.Outcome==oldReloaded.Outcome&&oldStored.Version==oldReloaded.Version&&oldStored.Status==oldReloaded.Status,"R06-T22 old persisted snapshot immutable");Q(newReloaded.ProfileVersion==profile.Version+1&&newReloaded.ScopeHash!=oldReloaded.ScopeHash,"R06-T22 replacement persisted");
Console.WriteLine("I9 R04 R06 PASS 47");
'@ | Set-Content -LiteralPath (Join-Path $tempRoot 'WorkflowProgram.cs') -Encoding utf8
        Move-Item -LiteralPath (Join-Path $tempRoot 'Program.cs') -Destination (Join-Path $tempRoot 'RulesProgram.cs')
        & $dotnet run --project (Join-Path $tempRoot 'Workflow.csproj') --configuration Release
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    catch { Write-Output "I9 R04 R06 FAIL: $($_.Exception.Message)"; exit 1 }
    finally {
        $env:I9_TEMP_CONNECTION=$null; $env:PGOPTIONS=$null
        & $psql -X -w -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS $schema CASCADE" | Out-Null
        $clean = & $psql -X -w -Atqc "select to_regnamespace('$schema') is null"
        if ($clean -ne 't') { Write-Output 'I9 R04 R06 FAIL: temporal schema cleanup'; exit 1 }
    }
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
