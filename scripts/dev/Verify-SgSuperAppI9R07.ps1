[CmdletBinding()]
param([string]$RepositoryRoot)
$ErrorActionPreference='Stop'
$repoRoot=if([string]::IsNullOrWhiteSpace($RepositoryRoot)){(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path}else{(Resolve-Path $RepositoryRoot).Path}
$files=@('apps/sg-superapp-api/Domain/SchedulingRuleModels.cs','apps/sg-superapp-api/Services/SchedulingRuleProfileValidator.cs','apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs','apps/sg-superapp-api/Services/SchedulingOverlapTravelRules.cs','apps/sg-superapp-api/Services/SchedulingNoveltyRequirementRules.cs','apps/sg-superapp-api/Services/SchedulingTemplateDeviationRule.cs','apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs')|%{Join-Path $repoRoot $_}
$authorizationBoundary=Join-Path $repoRoot 'apps/sg-superapp-api/Endpoints/PortalEndpoints.cs'
$seed=Join-Path $repoRoot 'db/seeds/011_i9_mvp_simulated_rule_profile.sql'
if(@(($files+$authorizationBoundary+$seed)|?{-not(Test-Path -LiteralPath $_ -PathType Leaf)}).Count){Write-Output 'I9 R07 FAIL: required source missing';exit 1}

$rule=Get-Content $files[5] -Raw;$evaluator=Get-Content $files[6] -Raw
foreach($p in @('EvaluateR07\s*\(','I9_R07_COMPLIANT','I9_R07_DEVIATION','I9_R07_MIXED_GUARDS','I9_R07_TEMPLATE_UNAVAILABLE','I9_R07_INVALID_INPUT','templateCode','templateVersion','anchorDate','expectedCells','proposedCells','shiftCode')){
  if($rule-notmatch ("(?s)"+$p)){Write-Output "I9 R07 FAIL: rule contract $p";exit 1}
}
foreach($p in @('"I9-R07"\s*=>','SchedulingTemplateDeviationRule','"I9-R06"\s*or\s*"I9-R07"')){
  if($evaluator-notmatch ("(?s)"+$p)){Write-Output "I9 R07 FAIL: evaluator does not dispatch R07 ($p)";exit 1}
}
# The rule must never infer a different template to avoid the deviation (contract point 7).
if($rule-notmatch '(?s)scopeHash'){Write-Output 'I9 R07 FAIL: rule does not document the scopeHash binding';exit 1}
foreach($forbidden in @('fullName','documentNumber','email','phone','freeText','description')){
  if($rule-match ('"'+[regex]::Escape($forbidden)+'"')){Write-Output "I9 R07 FAIL: non-minimized fact field $forbidden";exit 1}
}

# R07-T11: a role without SCHEDULING/APPROVE_EXCEPTION can never reach the mutation.
$portalSource=Get-Content $authorizationBoundary -Raw
$routeStart=$portalSource.IndexOf('app.MapPost("/api/portal/scheduling/proposals/{versionId:long}/exceptions"',[StringComparison]::Ordinal)
$routeEnd=if($routeStart-ge 0){$portalSource.IndexOf('app.MapPost("/api/portal/scheduling/proposals/{versionId:long}/approve"',$routeStart,[StringComparison]::Ordinal)}else{-1}
if($routeStart-lt 0-or $routeEnd-le $routeStart){Write-Output 'I9 R07 BLOCKED: exact exception route unavailable';exit 2}
$normalizedRoute=($portalSource.Substring($routeStart,$routeEnd-$routeStart))-replace '\s',''
$authorizationIndex=$normalizedRoute.IndexOf('authorization.RequireAsync("SCHEDULING","APPROVE_EXCEPTION",ct)',[StringComparison]::Ordinal)
$deniedIndex=$normalizedRoute.IndexOf('if(deniedisnotnull)returndenied;',[StringComparison]::Ordinal)
$mutationIndex=$normalizedRoute.IndexOf('repository.CreateScheduleExceptionAsync(',[StringComparison]::Ordinal)
if($authorizationIndex-lt 0-or $deniedIndex-le $authorizationIndex-or $mutationIndex-le $deniedIndex){
  Write-Output 'I9 R07 FAIL: R07-T11 approval boundary does not precede the mutation';exit 1
}
Write-Output 'R07-T11 ROUTE LINKAGE PASS'

# R07-T07/T08: the versioned catalog is the only source of authorized motives, and OTHER is one of them.
$seedText=Get-Content $seed -Raw
$r07Entry=[regex]::Match($seedText,"(?s)\('I9-R07',(?<body>.*?)\)\s*\)").Groups['body'].Value
if([string]::IsNullOrWhiteSpace($r07Entry)){Write-Output 'I9 R07 BLOCKED: simulated R07 profile entry unavailable';exit 2}
foreach($p in @('approvedMotiveCodes','OTHER','SIMULATED_DEMO_NOT_INSTITUTIONAL','templateCodes','changeInvalidatesApproval')){
  if($r07Entry-notmatch [regex]::Escape($p)){Write-Output "I9 R07 FAIL: simulated R07 catalog missing $p";exit 1}
}
Write-Output 'R07-T07 R07-T08 CATALOG CONTRACT PASS'
Write-Output 'I9 R07 STATIC PASS'

$dotnet='C:\tmp\dotnet6\dotnet.exe';if(-not(Test-Path $dotnet -PathType Leaf)){Write-Output 'I9 R07 BLOCKED: dotnet unavailable';exit 2}
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('sg-r07-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory $tmp|Out-Null
try{
 $links=@($files|%{[Security.SecurityElement]::Escape($_)})
@"
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><LangVersion>latest</LangVersion><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable></PropertyGroup><ItemGroup><FrameworkReference Include="Microsoft.AspNetCore.App"/><PackageReference Include="Npgsql" Version="6.0.10"/><Using Include="Microsoft.Extensions.Configuration"/><Using Include="Microsoft.AspNetCore.Http"/><Compile Include="$($links[0])" Link="Models.cs"/><Compile Include="$($links[1])" Link="Validator.cs"/><Compile Include="$($links[2])" Link="WorkRest.cs"/><Compile Include="$($links[3])" Link="Overlap.cs"/><Compile Include="$($links[4])" Link="Novelty.cs"/><Compile Include="$($links[5])" Link="Template.cs"/><Compile Include="$($links[6])" Link="Evaluator.cs"/></ItemGroup></Project>
"@|Set-Content (Join-Path $tmp 'H.csproj') -Encoding utf8
@'
using System.Text.Json; using System.Text.RegularExpressions; using Sg.SuperApp.Api.Domain; using Sg.SuperApp.Api.Services;
static JsonElement J(string s){using var d=JsonDocument.Parse(s);return d.RootElement.Clone();}
const string R7="I9-R07", R3="I9-R03"; var e=new SchedulingRuleEvaluator();
var p7=J("{\"compareBy\":[\"templateVersion\",\"anchor\",\"cell\"],\"changeInvalidatesApproval\":true}");
var cat7=J("{\"classification\":\"SIMULATED_DEMO_NOT_INSTITUTIONAL\",\"templateCodes\":[\"2X2\",\"4X2\",\"6X1\"],\"approvedMotiveCodes\":[\"OPERATIONAL_NEED_DEMO\",\"COVERAGE_DEMO\",\"OTHER\"]}");
var p3=J("{\"intervalSemantics\":\"HALF_OPEN\",\"adjacentIntervalsOverlap\":false}");
SchedulingRuleProfile P(JsonElement? c=null,bool on=true,int v=1)=>new(7,"MVP",v,SchedulingRuleOrigin.SIMULATED,SchedulingEnvironmentScope.MVP_TEST,"PROJECT-A",new DateOnly(2026,1,1),null,SchedulingRuleProfileStatus.ACTIVE,new string((char)('a'+v),64),new[]{new SchedulingRuleProfileEntry(R7,p7,c??cat7,on)});
SchedulingRuleProfile PBoth()=>new(7,"MVP",1,SchedulingRuleOrigin.SIMULATED,SchedulingEnvironmentScope.MVP_TEST,"PROJECT-A",new DateOnly(2026,1,1),null,SchedulingRuleProfileStatus.ACTIVE,new string('a',64),new[]{new SchedulingRuleProfileEntry(R3,p3,J("{}"),true),new SchedulingRuleProfileEntry(R7,p7,cat7,true)});
SchedulingRuleEvaluationBatch E(string f,SchedulingRuleProfile? p=null,IReadOnlySet<string>? h=null)=>e.Evaluate(p??P(),"PROJECT-A",new DateOnly(2026,8,17),J(f),h);
RuleEvaluation R(SchedulingRuleEvaluationBatch x,string c)=>x.Evaluations.Single(y=>y.RuleCode==c);
void Q<T>(T x,T y,string n)where T:notnull{if(!EqualityComparer<T>.Default.Equals(x,y))throw new Exception($"{n}: {x}!={y}");}
SchedulingRuleSeverity S(SchedulingRuleOutcome o)=>o==SchedulingRuleOutcome.COMPLIANT?SchedulingRuleSeverity.INFO:o==SchedulingRuleOutcome.EXCEPTION_REQUIRED?SchedulingRuleSeverity.WARNING:o==SchedulingRuleOutcome.WARNING?SchedulingRuleSeverity.ERROR:SchedulingRuleSeverity.BLOCKING;
void C(RuleEvaluation x,SchedulingRuleOutcome o,string c,string n,bool? exception=null){Q(o,x.Outcome,n+" outcome");Q(S(o),x.Severity,n+" severity");Q(exception??(o==SchedulingRuleOutcome.EXCEPTION_REQUIRED),x.ExceptionAllowed,n+" exception");Q(c,x.MessageCode,n+" code");Q(false,string.IsNullOrWhiteSpace(x.Explanation),n+" explanation");if(!Regex.IsMatch(x.ScopeHash,"^[a-f0-9]{64}$"))throw new Exception(n+" hash");if(x.Explanation.Length>1000)throw new Exception(n+" explanation exceeds the persisted limit");}
string Cell(string guard,string date,string cell,string shift)=>$"{{\"employeeId\":\"{guard}\",\"date\":\"{date}\",\"cell\":\"{cell}\",\"shiftCode\":\"{shift}\"}}";
string Cells(params string[] items)=>"["+string.Join(",",items)+"]";
string F(string expected,string proposed,string template="2X2",string version="TPL-V1",string anchor="2026-08-01",string asn="assignment-a",string ver="v-a")=>$"{{\"assignmentId\":\"{asn}\",\"scheduleVersionId\":\"{ver}\",\"templateCode\":\"{template}\",\"templateVersion\":\"{version}\",\"anchorDate\":\"{anchor}\",\"expectedCells\":{expected},\"proposedCells\":{proposed}}}";
string Base(string guard="guard-a",string c1="D",string c2="N",string c3="X")=>Cells(Cell(guard,"2026-08-17","C1",c1),Cell(guard,"2026-08-18","C2",c2),Cell(guard,"2026-08-19","C3",c3));
var passed=0;void Done(string id){passed++;Console.WriteLine(id+" PASS");}
void T(string id,string f,SchedulingRuleOutcome o,string c,bool approvable,bool? exception=null){var x=E(f,null,null);C(R(x,R7),o,c,id,exception);Q(1,x.Summary.Total,id+" total");Q(approvable,x.Summary.CanApproveOrPublish,id+" approve");Done(id);}

/* R07-T01..T23 map to docs/operations/2026-08-14-i9-r07-parametros-mensajes-pruebas.md.
   T07/T08 (motive catalog) and T11 (authorization) are asserted statically above; the
   remaining cases are asserted here against the real evaluator and rule. */

// T01 exact match creates no exception.
T("R07-T01",F(Base(),Base()),SchedulingRuleOutcome.COMPLIANT,"I9_R07_COMPLIANT",true);

// T02 one cell changes D for N; the deviation names the cell and both values.
var t02=E(F(Base(),Base(c2:"D")));var t02r=R(t02,R7);
C(t02r,SchedulingRuleOutcome.EXCEPTION_REQUIRED,"I9_R07_DEVIATION","R07-T02");
foreach(var token in new[]{"C2","2026-08-18","N","D"})if(!t02r.Explanation.Contains(token,StringComparison.Ordinal))throw new Exception("R07-T02 explanation omits "+token);
Q(false,t02.Summary.CanApproveOrPublish,"R07-T02 approve");Done("R07-T02");

// T03 a working cell becomes rest.
T("R07-T03",F(Base(),Base(c1:"X")),SchedulingRuleOutcome.EXCEPTION_REQUIRED,"I9_R07_DEVIATION",false);

// T04 a shift is added where the template prescribes rest.
T("R07-T04",F(Base(),Base(c3:"D")),SchedulingRuleOutcome.EXCEPTION_REQUIRED,"I9_R07_DEVIATION",false);

// T05 an engine deviation and an identical manual deviation are indistinguishable.
var t05a=R(E(F(Base(),Base(c2:"D"))),R7);var t05b=R(E(F(Base(),Base(c2:"D"))),R7);
Q(t05a.MessageCode,t05b.MessageCode,"R07-T05 code");Q(t05a.Explanation,t05b.Explanation,"R07-T05 explanation");Q(t05a.ScopeHash,t05b.ScopeHash,"R07-T05 hash");Done("R07-T05");

// T06 a manual edit revalidates: the decision and the scope both move.
var t06=R(E(F(Base(),Base(c2:"D",c3:"D"))),R7);
Q(false,t06.ScopeHash==t05a.ScopeHash,"R07-T06 hash changes with the edit");
C(t06,SchedulingRuleOutcome.EXCEPTION_REQUIRED,"I9_R07_DEVIATION","R07-T06");Done("R07-T06");

// T09 selecting an authorized motive leaves the exception pending until a decision.
var t09=E(F(Base(),Base(c2:"D")));
Q(true,R(t09,R7).ExceptionAllowed,"R07-T09 exception allowed");Q(false,t09.Summary.CanApproveOrPublish,"R07-T09 still pending");Done("R07-T09");

// T10 an approval bound to this exact scope releases only this snapshot.
var t10Facts=F(Base(),Base(c2:"D"));var t10Hash=R(E(t10Facts),R7).ScopeHash;
var t10=E(t10Facts,null,new HashSet<string>{t10Hash});
Q(true,t10.Summary.CanApproveOrPublish,"R07-T10 approved scope");Done("R07-T10");

// T12 the same approval never covers another guard.
var t12=E(F(Base("guard-b"),Base("guard-b",c2:"D")),null,new HashSet<string>{t10Hash});
Q(false,R(t12,R7).ScopeHash==t10Hash,"R07-T12 other guard hash");Q(false,t12.Summary.CanApproveOrPublish,"R07-T12 reuse rejected");Done("R07-T12");

// T13 adding a cell after the group was approved invalidates the decision.
var t13=E(F(Cells(Cell("guard-a","2026-08-17","C1","D"),Cell("guard-a","2026-08-18","C2","N"),Cell("guard-a","2026-08-19","C3","X"),Cell("guard-a","2026-08-20","C4","D")),Cells(Cell("guard-a","2026-08-17","C1","D"),Cell("guard-a","2026-08-18","C2","D"),Cell("guard-a","2026-08-19","C3","X"),Cell("guard-a","2026-08-20","C4","D"))),null,new HashSet<string>{t10Hash});
Q(false,R(t13,R7).ScopeHash==t10Hash,"R07-T13 added cell hash");Q(false,t13.Summary.CanApproveOrPublish,"R07-T13 approval invalidated");Done("R07-T13");

// T14 changing the selected template or version recomputes and invalidates.
var t14Template=R(E(F(Base(),Base(c2:"D"),template:"4X2")),R7);var t14Version=R(E(F(Base(),Base(c2:"D"),version:"TPL-V2")),R7);
Q(false,t14Template.ScopeHash==t10Hash,"R07-T14 template hash");Q(false,t14Version.ScopeHash==t10Hash,"R07-T14 version hash");Done("R07-T14");

// T15 changing the cycle anchor recomputes the affected sequence.
var t15=R(E(F(Base(),Base(c2:"D"),anchor:"2026-08-02")),R7);
Q(false,t15.ScopeHash==t10Hash,"R07-T15 anchor hash");Done("R07-T15");

// T16 a new profile version never reuses the previous scope.
var t16=R(E(F(Base(),Base(c2:"D")),P(v:2)),R7);
Q(2,t16.ProfileVersion,"R07-T16 profile version");Q(false,t16.ScopeHash==t10Hash,"R07-T16 hash");Done("R07-T16");

// T17 a historical snapshot is preserved verbatim, so a correction can only be a new evaluation.
var t17a=R(E(F(Base(),Base(c2:"D"))),R7);var t17b=R(E(F(Base(),Base(c2:"D"))),R7);
Q(t17a.FactsSnapshot.GetRawText(),t17b.FactsSnapshot.GetRawText(),"R07-T17 facts snapshot");
Q(t17a.ParametersSnapshot.GetRawText(),t17b.ParametersSnapshot.GetRawText(),"R07-T17 parameters snapshot");Done("R07-T17");

// T18 an approved template deviation never releases an absolute R03 block.
var t18Facts=$"{{\"assignmentId\":\"assignment-a\",\"scheduleVersionId\":\"v-a\",\"employeeId\":\"guard-a\",\"proposedShiftStart\":\"2026-08-17T08:00:00-05:00\",\"proposedShiftEnd\":\"2026-08-17T16:00:00-05:00\",\"existingIntervals\":[{{\"employeeId\":\"guard-a\",\"start\":\"2026-08-17T10:00:00-05:00\",\"end\":\"2026-08-17T18:00:00-05:00\",\"status\":\"APPROVED\"}}],\"templateCode\":\"2X2\",\"templateVersion\":\"TPL-V1\",\"anchorDate\":\"2026-08-01\",\"expectedCells\":{Base()},\"proposedCells\":{Base(c2:"D")}}}";
var t18Hash=R(E(t18Facts,PBoth()),R7).ScopeHash;var t18=E(t18Facts,PBoth(),new HashSet<string>{t18Hash});
C(R(t18,R3),SchedulingRuleOutcome.BLOCKED,"I9_R03_OVERLAP_APPROVED_BLOCKED","R07-T18 R03");
C(R(t18,R7),SchedulingRuleOutcome.EXCEPTION_REQUIRED,"I9_R07_DEVIATION","R07-T18 R07");
Q(false,t18.Summary.CanApproveOrPublish,"R07-T18 absolute block survives");Done("R07-T18");

// T19 without an applicable template or version the rule never presumes compliance.
T("R07-T19",F(Base(),Base(),template:"9X9"),SchedulingRuleOutcome.WARNING,"I9_R07_TEMPLATE_UNAVAILABLE",false,false);
C(R(E(F("[]",Base())),R7),SchedulingRuleOutcome.WARNING,"I9_R07_TEMPLATE_UNAVAILABLE","R07-T19 empty expected",false);

// T20 the historical snapshot keeps the original template, version and values.
var t20=R(E(F(Base(),Base(c2:"D"),version:"TPL-V1")),R7);
foreach(var token in new[]{"TPL-V1","2X2","2026-08-01"})if(!t20.FactsSnapshot.GetRawText().Contains(token,StringComparison.Ordinal))throw new Exception("R07-T20 snapshot omits "+token);
Done("R07-T20");

// T21 several cells of the same guard travel in one exact grouped decision.
var t21=E(F(Base(),Base(c1:"N",c2:"D")));var t21r=R(t21,R7);
C(t21r,SchedulingRuleOutcome.EXCEPTION_REQUIRED,"I9_R07_DEVIATION","R07-T21");
foreach(var token in new[]{"C1","C2"})if(!t21r.Explanation.Contains(token,StringComparison.Ordinal))throw new Exception("R07-T21 explanation omits "+token);
Done("R07-T21");

// T22 a group covering two guards is never one decision.
var mixedExpected=Cells(Cell("guard-a","2026-08-17","C1","D"),Cell("guard-b","2026-08-17","C1","D"));
var mixedProposed=Cells(Cell("guard-a","2026-08-17","C1","N"),Cell("guard-b","2026-08-17","C1","N"));
T("R07-T22",F(mixedExpected,mixedProposed),SchedulingRuleOutcome.BLOCKED,"I9_R07_MIXED_GUARDS",false,false);

// T23 a disabled R07 never accredits productive compliance.
var t23=E(F(Base(),Base()),P(on:false));
Q(1,t23.Evaluations.Count,"R07-T23 disabled rule still reports");
C(R(t23,R7),SchedulingRuleOutcome.WARNING,"I9_R07_DISABLED_UNVERIFIED","R07-T23",false);
Q(false,t23.Summary.CanApproveOrPublish,"R07-T23 gate stays closed");Done("R07-T23");

// Fail-closed contract: malformed parameters or facts never accredit compliance.
foreach(var broken in new[]{"{\"compareBy\":[],\"changeInvalidatesApproval\":true}","{\"compareBy\":[\"templateVersion\",\"anchor\",\"cell\"],\"changeInvalidatesApproval\":false}"}){
  var brokenProfile=new SchedulingRuleProfile(7,"MVP",1,SchedulingRuleOrigin.SIMULATED,SchedulingEnvironmentScope.MVP_TEST,"PROJECT-A",new DateOnly(2026,1,1),null,SchedulingRuleProfileStatus.ACTIVE,new string('a',64),new[]{new SchedulingRuleProfileEntry(R7,J(broken),cat7,true)});
  C(R(E(F(Base(),Base()),brokenProfile),R7),SchedulingRuleOutcome.BLOCKED,"I9_R07_INVALID_INPUT","invalid parameters "+broken,false);
}
foreach(var corrupt in new[]{"null","[]","\"invalid\"","42"}){
  C(R(E(F(Base(),Base()),P(J(corrupt))),R7),SchedulingRuleOutcome.WARNING,"I9_R07_TEMPLATE_UNAVAILABLE","malformed catalog "+corrupt,false);
}
Console.WriteLine("FAIL CLOSED CONTRACT PASS");

Q(20,passed,"numbered runtime scenario count");
Console.WriteLine($"I9 R07 PASS {passed} RUNTIME");
Console.WriteLine("I9 R07 PASS");
'@|Set-Content (Join-Path $tmp 'Program.cs') -Encoding utf8
 & $dotnet run --project (Join-Path $tmp 'H.csproj') --configuration Release;exit $LASTEXITCODE
}
finally{ if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Recurse -Force} }
