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
    'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs'
)
$files = @($relativeFiles | ForEach-Object { Join-Path $repoRoot $_ })
$authorizationService = Join-Path $repoRoot 'apps/sg-superapp-api/Services/PortalAuthorizationService.cs'
$authorizationBoundary = Join-Path $repoRoot 'apps/sg-superapp-api/Endpoints/PortalEndpoints.cs'
if (@(($files + $authorizationService + $authorizationBoundary) | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }).Count) {
    Write-Output 'I9 R04 R06 FAIL: required source missing'
    exit 1
}

$rules = Get-Content -LiteralPath $files[4] -Raw
$evaluator = Get-Content -LiteralPath $files[5] -Raw
foreach ($pattern in @(
    'EvaluateR04\s*\(', 'EvaluateR06\s*\(', 'mappingDemo', 'requirementsDemo',
    'INCAPACITY_ACTIVE', 'VACATION_ACTIVE', 'ABSENCE_CONFIRMED', 'TEMPORARY_ASSIGNMENT',
    'COURSE', 'ACCREDITATION', 'CERTIFICATION', 'LICENSE_OR_PERMIT', 'OTHER_REQUIREMENT',
    'validForEntireShift', 'informativeRequiresOwnerAndDueDate', 'HasOverlappingRequirements'
)) {
    if ($rules -notmatch $pattern) { Write-Output "I9 R04 R06 FAIL: missing contract $pattern"; exit 1 }
}
foreach ($pattern in @(
    'SchedulingNoveltyRequirementRules', 'noveltyEvaluations', 'requirementEvaluations',
    'remediationOwnerRole', 'remediationOwnerKey', 'Canonicalize\(entry\.CatalogSnapshot\)'
)) {
    if ($evaluator -notmatch $pattern) { Write-Output "I9 R04 R06 FAIL: evaluator contract $pattern"; exit 1 }
}
foreach ($forbidden in @('fullName', 'documentNumber', 'email', 'phone', 'freeText', 'description')) {
    if ($evaluator -match ('"' + [regex]::Escape($forbidden) + '"')) {
        Write-Output "I9 R04 R06 FAIL: non-minimized fact field $forbidden"
        exit 1
    }
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
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><LangVersion>latest</LangVersion><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable></PropertyGroup><ItemGroup><FrameworkReference Include="Microsoft.AspNetCore.App"/><PackageReference Include="Npgsql" Version="6.0.10"/><Using Include="Microsoft.Extensions.Configuration"/><Using Include="Microsoft.AspNetCore.Http"/><Compile Include="$($links[0])" Link="Models.cs"/><Compile Include="$($links[1])" Link="Validator.cs"/><Compile Include="$($links[2])" Link="WorkRest.cs"/><Compile Include="$($links[3])" Link="Overlap.cs"/><Compile Include="$($links[4])" Link="NoveltyRequirements.cs"/><Compile Include="$($links[5])" Link="Evaluator.cs"/><Compile Include="$authorizationLink" Link="PortalAuthorizationService.cs"/></ItemGroup></Project>
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

string Map(string sourceCode, string sourceStatus, string category, string version = "MAP-1", string sourceSystem = "HR") =>
    $"{{\"sourceSystem\":\"{sourceSystem}\",\"sourceCode\":\"{sourceCode}\",\"sourceStatus\":\"{sourceStatus}\",\"semanticCategory\":\"{category}\",\"mappingVersion\":\"{version}\",\"effectiveFrom\":\"2026-01-01T00:00:00Z\",\"effectiveTo\":null}}";
string Cat4(params string[] extra) {
    var rows = new[] { Map("INC","ACTIVE","INCAPACITY_ACTIVE"), Map("V","APPROVED","VACATION_ACTIVE"), Map("A","CONFIRMED","ABSENCE_CONFIRMED"), Map("A","PENDING","ABSENCE_PENDING"), Map("TA","ACTIVE","TEMPORARY_ASSIGNMENT"), Map("D","ACTIVE","UNKNOWN"), Map("N","ACTIVE","UNKNOWN"), Map("X","ACTIVE","UNKNOWN"), Map("TRAIN","ACTIVE","TEMPORARY_ASSIGNMENT"), Map("FREE","ACTIVE","AVAILABLE"), Map("ADM","INFO","ADMINISTRATIVE_EVENT"), Map("ADM","FORMAL","INCAPACITY_ACTIVE"), Map("OLD","CANCELLED","EXPIRED_OR_CANCELLED") }.Concat(extra);
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
Basic4("R04-T02",G4(N("V","APPROVED","VACATION_ACTIVE",from:"2026-08-21T12:00:00-05:00")),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_VACATION_ACTIVE",false,0,1,0,0,0,false);
Basic4("R04-T03",G4(N("A","CONFIRMED","ABSENCE_CONFIRMED")),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_ABSENCE_CONFIRMED",false,0,1,0,0,0,false);
Basic4("R04-T04",G4(N("A","PENDING","ABSENCE_PENDING")),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R04_ABSENCE_PENDING",true,0,0,1,0,0,false);
var coexistProfile = new SchedulingRuleProfile(20,"MVP-R04",1,SchedulingRuleOrigin.SIMULATED,SchedulingEnvironmentScope.MVP_TEST,"PROJECT-A",new DateOnly(2026,1,1),null,SchedulingRuleProfileStatus.ACTIVE,new string('a',64),new[] { new SchedulingRuleProfileEntry("I9-R01",p1,J("{}"),true), new SchedulingRuleProfileEntry("I9-R02",p2,J("{}"),true), new SchedulingRuleProfileEntry(R04,p4,J(Cat4()),true) });
var coexistFacts = G4(N("TA","ACTIVE","TEMPORARY_ASSIGNMENT"),extra:",\"dailyHours\":8,\"weeklyHours\":42,\"writtenAgreement\":false,\"previousShiftEnd\":\"2026-08-20T20:00:00-05:00\",\"proposedShiftStart\":\"2026-08-21T08:00:00-05:00\"");
var coexist = evaluator.Evaluate(coexistProfile,"PROJECT-A",new DateOnly(2026,8,21),J(coexistFacts)); Rule(R(coexist,R04),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R04_TEMPORARY_ASSIGNMENT",true,"R04-T05"); Rule(R(coexist,"I9-R01"),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R01_COMPLIANT",false,"R04-T05 R01"); Rule(R(coexist,"I9-R02"),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R02_COMPLIANT",false,"R04-T05 R02"); Summary(coexist,3,2,0,1,0,0,false,"R04-T05"); Same(coexist,evaluator.Evaluate(coexistProfile,"PROJECT-A",new DateOnly(2026,8,21),J(coexistFacts)),"R04-T05 deterministic"); Done("R04-T05");
Basic4("R04-T06",G4(N("LIC","ACTIVE","UNKNOWN")),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R04_UNVERIFIED",false,0,0,0,1,0,false);
Basic4("R04-T07",G4(N("TRAIN","ACTIVE","TEMPORARY_ASSIGNMENT")),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R04_TEMPORARY_ASSIGNMENT",true,0,0,1,0,0,false);
Basic4("R04-T08",G4(N("FREE","ACTIVE","AVAILABLE")),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R04_AVAILABLE",false,1,0,0,0,0,true);
Basic4("R04-T09",G4(N("ADM","INFO","ADMINISTRATIVE_EVENT")),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R04_ADMINISTRATIVE_EVENT",false,1,0,0,0,0,true);
Basic4("R04-T10",G4(N("ADM","FORMAL","INCAPACITY_ACTIVE")),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_INCAPACITY_ACTIVE",false,0,1,0,0,0,false);
Basic4("R04-T11",G4(N("INC","ACTIVE","INCAPACITY_ACTIVE",from:"2026-08-20T08:00:00-05:00",to:"2026-08-21T07:59:59-05:00")),SchedulingRuleOutcome.NOT_APPLICABLE,SchedulingRuleSeverity.INFO,"I9_R04_NO_CURRENT_EFFECT",false,0,0,0,0,1,true);
Basic4("R04-T12",G4(N("INC-LIKE","ACTIVE","INCAPACITY_ACTIVE")),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R04_UNVERIFIED",false,0,0,0,1,0,false);
foreach (var code in new[] { "D", "N", "X" }) { var rejected=E4(G4(N(code,"ACTIVE","AVAILABLE"))); Rule(R(rejected,R04),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R04_NON_NOVELTY_CODE",false,"R04-T13 "+code); Summary(rejected,1,0,0,0,1,0,false,"R04-T13 "+code); } Done("R04-T13");
var missingStart=N("INC","ACTIVE","INCAPACITY_ACTIVE").Replace($",\"validFrom\":\"{Start}\"",""); Basic4("R04-T14",G4(missingStart),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R04_UNVERIFIED",false,0,0,0,1,0,false);
var missingEnd=N("INC","ACTIVE","INCAPACITY_ACTIVE").Replace($",\"validTo\":\"{End}\"",""); Basic4("R04-T15",G4(missingEnd),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R04_UNVERIFIED",false,0,0,0,1,0,false);
Basic4("R04-T16",G4(N("OLD","CANCELLED","EXPIRED_OR_CANCELLED",from:"2026-08-20T08:00:00-05:00",to:"2026-08-21T07:00:00-05:00")),SchedulingRuleOutcome.NOT_APPLICABLE,SchedulingRuleSeverity.INFO,"I9_R04_NO_CURRENT_EFFECT",false,0,0,0,0,1,true);
Basic4("R04-T17",G4(string.Join(",",N("INC","ACTIVE","INCAPACITY_ACTIVE",id:"N1"),N("A","PENDING","ABSENCE_PENDING",id:"N2"),N("ADM","INFO","ADMINISTRATIVE_EVENT",id:"N3"))),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_INCAPACITY_ACTIVE",false,0,1,0,0,0,false);
Basic4("R04-T18",G4(string.Join(",",N("A","PENDING","ABSENCE_PENDING",id:"N1"),N("ADM","INFO","ADMINISTRATIVE_EVENT",id:"N2"))),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R04_ABSENCE_PENDING",true,0,0,1,0,0,false);
async Task<int> HttpStatus(IResult result) { using var services=new ServiceCollection().AddLogging().BuildServiceProvider(); var context=new DefaultHttpContext{RequestServices=services}; await result.ExecuteAsync(context); return context.Response.StatusCode; }
var deniedRepo4=new PostgresPortalRepository(false); var auth4=new PortalAuthorizationService(new RequestUserContext{User=new HarnessUser(4)},deniedRepo4); var denied4=await auth4.RequireAsync("SCHEDULING","APPROVE_EXCEPTION",CancellationToken.None); Q(403,await HttpStatus(denied4!),"R04-T19 status"); Q(1,deniedRepo4.PermissionCalls,"R04-T19 calls"); Q("APPROVE_EXCEPTION",deniedRepo4.LastActionCode!,"R04-T19 action"); Done("R04-T19");
var pending4=E4(G4(N("A","PENDING","ABSENCE_PENDING"))); var wrong4=E4(G4(N("A","PENDING","ABSENCE_PENDING")),approvals:new HashSet<string>{new string('f',64)}); Summary(wrong4,1,0,0,1,0,0,false,"R04-T20 wrong"); var approved4=E4(G4(N("A","PENDING","ABSENCE_PENDING")),approvals:new HashSet<string>{R(pending4,R04).ScopeHash}); Summary(approved4,1,0,0,1,0,0,true,"R04-T20 exact"); Done("R04-T20");
var h21=R(pending4,R04).ScopeHash; var otherShift4=E4(G4(N("A","PENDING","ABSENCE_PENDING"),shiftId:"SHIFT-2"),approvals:new HashSet<string>{h21}); var otherNovelty4=E4(G4(N("A","PENDING","ABSENCE_PENDING",id:"NOV-2")),approvals:new HashSet<string>{h21}); Q(false,h21==R(otherShift4,R04).ScopeHash,"R04-T21 shift hash"); Q(false,h21==R(otherNovelty4,R04).ScopeHash,"R04-T21 novelty hash"); Summary(otherShift4,1,0,0,1,0,0,false,"R04-T21 shift"); Summary(otherNovelty4,1,0,0,1,0,0,false,"R04-T21 novelty"); Done("R04-T21");
var oldCat=Cat4(Map("LEGACY","ACTIVE","AVAILABLE","MAP-OLD")); var newCat=Cat4(Map("LEGACY","ACTIVE","INCAPACITY_ACTIVE","MAP-NEW")); var oldFacts=G4(N("LEGACY","ACTIVE","AVAILABLE","MAP-OLD")); var oldEval=E4(oldFacts,oldCat); Rule(R(oldEval,R04),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R04_AVAILABLE",false,"R04-T22 old"); Same(oldEval,E4(oldFacts,oldCat),"R04-T22 preserved"); var newEval=E4(G4(N("LEGACY","ACTIVE","INCAPACITY_ACTIVE","MAP-NEW")),newCat,version:2); Rule(R(newEval,R04),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_INCAPACITY_ACTIVE",false,"R04-T22 new"); Q(false,R(oldEval,R04).ScopeHash==R(newEval,R04).ScopeHash,"R04-T22 hash"); Done("R04-T22");
var duplicateCat=Cat4(Map("INC","ACTIVE","INCAPACITY_ACTIVE","MAP-2")); Basic4("R04-T23",G4(N("INC","ACTIVE","INCAPACITY_ACTIVE")),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R04_AMBIGUOUS_MAPPING",false,0,1,0,0,0,false,duplicateCat);
var disabled4=E4(G4(N("FREE","ACTIVE","AVAILABLE")),enabled:false); Summary(disabled4,0,0,0,0,0,0,false,"R04-T24"); Q(false,disabled4.Evaluations.Any(),"R04-T24 no decision"); Done("R04-T24");

string Req(string code,string category,string version="REQ-1",bool remedial=false,string from="2026-01-01T00:00:00Z",string to="null",string project="PROJECT-A",string position="POSITION-1") => $"{{\"projectCode\":\"{project}\",\"positionCode\":\"{position}\",\"requirementCode\":\"{code}\",\"category\":\"{category}\",\"catalogVersion\":\"{version}\",\"effectiveFrom\":\"{from}\",\"effectiveTo\":{(to=="null"?"null":"\""+to+"\"")},\"informativeRemediable\":{remedial.ToString().ToLowerInvariant()}}}";
string Cat6(params string[] requirements) => "{\"requirementsDemo\":["+string.Join(",",requirements)+"]}";
string Ev(string code,string category,string state="VERIFIED",string version="REQ-1",string from=Start,string to=End,string extra="") => $"{{\"requirementCode\":\"{code}\",\"category\":\"{category}\",\"catalogVersion\":\"{version}\",\"evidenceState\":\"{state}\",\"validFrom\":\"{from}\",\"validTo\":\"{to}\"{extra}}}";
string G6(string items,string employee="GUARD-1",string position="POSITION-1",string shift="SHIFT-1",string start=Start,string end=End,bool hr=false) => $"{{\"assignmentId\":\"ASSIGN-1\",\"scheduleVersionId\":\"SCHEDULE-1\",\"employeeId\":\"{employee}\",\"positionCode\":\"{position}\",\"shiftId\":\"{shift}\",\"shiftStart\":\"{start}\",\"shiftEnd\":\"{end}\",\"hrValidated\":{hr.ToString().ToLowerInvariant()},\"requirementEvaluations\":[{items}]}}";
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
Basic6("R06-T07",G6(Ev("COURSE-1","COURSE",state:"UNKNOWN")),courseCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_UNVERIFIED",false,0,1,0,false);
var remedialCat=Cat6(Req("COURSE-1","COURSE",remedial:true)); var remedialExtra=",\"informativeRemediable\":true,\"remediationOwnerRole\":\"HR_REVIEWER\",\"remediationOwnerKey\":\"ROLE-7\",\"dueDate\":\"2026-08-22\""; Basic6("R06-T08",G6(Ev("COURSE-1","COURSE",state:"MISSING",extra:remedialExtra)),remedialCat,SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R06_INFORMATIVE_REMEDIABLE",false,0,0,1,false);
var noOwner=",\"informativeRemediable\":true,\"dueDate\":\"2026-08-22\""; Basic6("R06-T09",G6(Ev("COURSE-1","COURSE",state:"MISSING",extra:noOwner)),remedialCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_UNVERIFIED_REMEDIATION",false,0,1,0,false);
var noDue=",\"informativeRemediable\":true,\"remediationOwnerRole\":\"HR_REVIEWER\",\"remediationOwnerKey\":\"ROLE-7\""; Basic6("R06-T10",G6(Ev("COURSE-1","COURSE",state:"MISSING",extra:noDue)),remedialCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_UNVERIFIED_REMEDIATION",false,0,1,0,false);
Basic6("R06-T11",G6(Ev("COURSE-1","COURSE",state:"MISSING")),courseCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_MISSING",false,0,1,0,false);
var hrPending=E6(G6("",hr:true),courseCat); Rule(R(hrPending,R06),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_MISSING",true,"R06-T12"); Summary(hrPending,1,0,0,1,0,0,false,"R06-T12"); Done("R06-T12");
var hrApproved=E6(G6("",hr:true),courseCat,new HashSet<string>{R(hrPending,R06).ScopeHash}); Summary(hrApproved,1,0,0,1,0,0,true,"R06-T13"); Q(R(hrPending,R06).ScopeHash,R(hrApproved,R06).ScopeHash,"R06-T13 exact hash"); Done("R06-T13");
var noHr=E6(G6(""),courseCat); var noHrApproved=E6(G6(""),courseCat,new HashSet<string>{R(noHr,R06).ScopeHash}); Rule(R(noHrApproved,R06),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_MISSING",false,"R06-T14"); Summary(noHrApproved,1,0,0,1,0,0,false,"R06-T14"); Done("R06-T14");
var deniedRepo6=new PostgresPortalRepository(false); var auth6=new PortalAuthorizationService(new RequestUserContext{User=new HarnessUser(6)},deniedRepo6); var denied6=await auth6.RequireAsync("SCHEDULING","APPROVE_EXCEPTION",CancellationToken.None); Q(403,await HttpStatus(denied6!),"R06-T15 status"); Q("SCHEDULING",deniedRepo6.LastModuleCode!,"R06-T15 module"); Q("APPROVE_EXCEPTION",deniedRepo6.LastActionCode!,"R06-T15 action"); Done("R06-T15");
var oldHash=R(hrPending,R06).ScopeHash; var otherTurn=E6(G6("",shift:"SHIFT-2",hr:true),courseCat,new HashSet<string>{oldHash}); var otherRequirementCat=Cat6(Req("COURSE-2","COURSE")); var otherRequirement=E6(G6("",hr:true),otherRequirementCat,new HashSet<string>{oldHash}); Summary(otherTurn,1,0,0,1,0,0,false,"R06-T16 turn"); Summary(otherRequirement,1,0,0,1,0,0,false,"R06-T16 requirement"); Q(false,oldHash==R(otherTurn,R06).ScopeHash,"R06-T16 turn hash"); Q(false,oldHash==R(otherRequirement,R06).ScopeHash,"R06-T16 requirement hash"); Done("R06-T16");
var baseHash=R(E6(G6(Ev("COURSE-1","COURSE")),courseCat),R06).ScopeHash; var guardHash=R(E6(G6(Ev("COURSE-1","COURSE"),employee:"GUARD-2"),courseCat),R06).ScopeHash; var positionCat=Cat6(Req("COURSE-1","COURSE",position:"POSITION-2")); var positionHash=R(E6(G6(Ev("COURSE-1","COURSE"),position:"POSITION-2"),positionCat),R06).ScopeHash; var turnHash=R(E6(G6(Ev("COURSE-1","COURSE"),shift:"SHIFT-2"),courseCat),R06).ScopeHash; var versionCat=Cat6(Req("COURSE-1","COURSE",version:"REQ-2")); var versionHash=R(E6(G6(Ev("COURSE-1","COURSE",version:"REQ-2")),versionCat,version:2),R06).ScopeHash; foreach(var hash in new[]{guardHash,positionHash,turnHash,versionHash})Q(false,baseHash==hash,"R06-T17 changed hash"); Done("R06-T17");
var overlapping=Cat6(Req("COURSE-1","COURSE","REQ-1",from:"2026-01-01T00:00:00Z",to:"2026-12-31T00:00:00Z"),Req("COURSE-1","COURSE","REQ-2",from:"2026-06-01T00:00:00Z")); Basic6("R06-T18",G6(Ev("COURSE-1","COURSE")),overlapping,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_INVALID_CATALOG",false,0,1,0,false);
Basic6("R06-T19",G6(""),Cat6(),SchedulingRuleOutcome.WARNING,SchedulingRuleSeverity.WARNING,"I9_R06_CATALOG_INCOMPLETE",false,0,0,1,false);
Basic6("R06-T20",G6(Ev("COURSE-1","COURSE",to:"2026-08-21T19:59:59.9999999-05:00")),courseCat,SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_EXPIRED_OR_PARTIAL",false,0,1,0,false);
var blockingProfile=new SchedulingRuleProfile(22,"MVP-MIX",1,SchedulingRuleOrigin.SIMULATED,SchedulingEnvironmentScope.MVP_TEST,"PROJECT-A",new DateOnly(2026,1,1),null,SchedulingRuleProfileStatus.ACTIVE,new string('z',64),new[]{new SchedulingRuleProfileEntry("I9-R01",p1,J("{}"),true),new SchedulingRuleProfileEntry(R06,p6,J(courseCat),true)}); var blockingFacts=G6("",hr:true).Replace("{","{\"dailyHours\":12.01,\"weeklyHours\":42,\"writtenAgreement\":true,",StringComparison.Ordinal); var initialBlock=evaluator.Evaluate(blockingProfile,"PROJECT-A",new DateOnly(2026,8,21),J(blockingFacts)); var afterR06=evaluator.Evaluate(blockingProfile,"PROJECT-A",new DateOnly(2026,8,21),J(blockingFacts),new HashSet<string>{R(initialBlock,R06).ScopeHash}); Rule(R(afterR06,"I9-R01"),SchedulingRuleOutcome.BLOCKED,SchedulingRuleSeverity.BLOCKING,"I9_R01_ABSOLUTE_MAX_EXCEEDED",false,"R06-T21 R01"); Summary(afterR06,2,0,1,1,0,0,false,"R06-T21"); Done("R06-T21");
var oldReqCat=Cat6(Req("COURSE-1","COURSE","REQ-1")); var oldReqFacts=G6(Ev("COURSE-1","COURSE",version:"REQ-1")); var oldReq=E6(oldReqFacts,oldReqCat); Same(oldReq,E6(oldReqFacts,oldReqCat),"R06-T22 preserved"); var newReqCat=Cat6(Req("COURSE-1","COURSE","REQ-2")); var newReq=E6(oldReqFacts,newReqCat,version:2); Rule(R(oldReq,R06),SchedulingRuleOutcome.COMPLIANT,SchedulingRuleSeverity.INFO,"I9_R06_COMPLIANT",false,"R06-T22 old"); Rule(R(newReq,R06),SchedulingRuleOutcome.EXCEPTION_REQUIRED,SchedulingRuleSeverity.WARNING,"I9_R06_UNVERIFIED",false,"R06-T22 new"); Q(false,R(oldReq,R06).ScopeHash==R(newReq,R06).ScopeHash,"R06-T22 hash"); Done("R06-T22");
var disabled6=E6(G6(allEvidence),allCatalog,enabled:false); Summary(disabled6,0,0,0,0,0,0,false,"R06-T23"); Q(false,disabled6.Evaluations.Any(),"R06-T23 no decision"); Done("R06-T23");

var malformed4=SchedulingNoveltyRequirementRules.EvaluateR04(p4,J(Cat4()),J("{}")); Q(SchedulingRuleOutcome.WARNING,malformed4.Outcome,"malformed R04 outside count");
var malformed6=SchedulingNoveltyRequirementRules.EvaluateR06(p6,J(courseCat),J("{}"),"PROJECT-A"); Q(SchedulingRuleOutcome.EXCEPTION_REQUIRED,malformed6.Outcome,"malformed R06 outside count");
var piiRejected=false; try { E4(G4(N("FREE","ACTIVE","AVAILABLE"),employee:"Jane Doe")); } catch(ArgumentException) { piiRejected=true; } Q(true,piiRejected,"PII/free text rejected outside count");
var payloadRejected=false; try { E4(G4(N("FREE","ACTIVE","AVAILABLE"),employee:new string('A',81))); } catch(ArgumentException) { payloadRejected=true; } Q(true,payloadRejected,"payload rejected outside count");
Q(47,passed,"numbered scenario count"); Console.WriteLine($"I9 R04 R06 PASS {passed}"); Console.WriteLine("I9 R04 R06 PASS");
'@ | Set-Content -LiteralPath (Join-Path $tempRoot 'Program.cs') -Encoding utf8
    & $dotnet run --project (Join-Path $tempRoot 'Harness.csproj') --configuration Release
    exit $LASTEXITCODE
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
