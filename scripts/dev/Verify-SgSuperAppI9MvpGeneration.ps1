[CmdletBinding()]
param([string]$RepositoryRoot)
$ErrorActionPreference='Stop'
$repoRoot=if([string]::IsNullOrWhiteSpace($RepositoryRoot)){(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path}else{(Resolve-Path $RepositoryRoot).Path}
$files=@(
 'apps/sg-superapp-api/Domain/SchedulingRuleModels.cs',
 'apps/sg-superapp-api/Domain/SchedulingModels.cs',
 'apps/sg-superapp-api/Services/SchedulingRuleProfileValidator.cs',
 'apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs',
 'apps/sg-superapp-api/Services/SchedulingOverlapTravelRules.cs',
 'apps/sg-superapp-api/Services/SchedulingNoveltyRequirementRules.cs',
 'apps/sg-superapp-api/Services/SchedulingTemplateDeviationRule.cs',
 'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs',
 'apps/sg-superapp-api/Services/SchedulingEligibilityService.cs',
 'apps/sg-superapp-api/Services/SchedulingRecommendationEngine.cs'
)|%{Join-Path $repoRoot $_}
if(@($files|?{-not(Test-Path -LiteralPath $_ -PathType Leaf)}).Count){Write-Output 'I9 MVP GENERATION FAIL: required source missing';exit 1}

$models=Get-Content $files[1] -Raw
$eligibility=Get-Content $files[8] -Raw
$engine=Get-Content $files[9] -Raw

# The isolated booleans were a truth parallel to the versioned rules: a caller could claim
# hasOverlap=false while I9-R03 blocked. They must be gone, not merely ignored.
foreach($forbidden in @('HasOverlap','RestRuleSatisfied','HasBlockingAbsence','HasBlockingLocationMismatch')){
  if($models-match ('\b'+[regex]::Escape($forbidden)+'\b')){
    Write-Output "I9 MVP GENERATION FAIL: SchedulingModels still carries the isolated fact $forbidden";exit 1
  }
  if($eligibility-match ('\b'+[regex]::Escape($forbidden)+'\b')){
    Write-Output "I9 MVP GENERATION FAIL: eligibility still reads the isolated fact $forbidden";exit 1
  }
}
foreach($p in @('RuleEvaluationReference','ScopeHash','RuleProfileId','RuleProfileVersion','Simulated')){
  if($models-notmatch ('(?s)'+$p)){Write-Output "I9 MVP GENERATION FAIL: SchedulingModels missing $p";exit 1}
}
foreach($p in @('SchedulingRuleEvaluator','BLOCKED','EXCEPTION_REQUIRED','RULE_EVALUATION_MISSING')){
  if($eligibility-notmatch ('(?s)'+$p)){Write-Output "I9 MVP GENERATION FAIL: eligibility missing $p";exit 1}
}
foreach($p in @('RuleEvaluation','EXCEPTION_REQUIRED','ScopeHash')){
  if($engine-notmatch ('(?s)'+$p)){Write-Output "I9 MVP GENERATION FAIL: recommendation engine missing $p";exit 1}
}
Write-Output 'I9 MVP GENERATION STATIC PASS'

$dotnet='C:\tmp\dotnet6\dotnet.exe';if(-not(Test-Path $dotnet -PathType Leaf)){Write-Output 'I9 MVP GENERATION BLOCKED: dotnet unavailable';exit 2}
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('sg-gen-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory $tmp|Out-Null
try{
 $links=@($files|%{[Security.SecurityElement]::Escape($_)})
 $compile=($links|%{'<Compile Include="'+$_+'" Link="'+([IO.Path]::GetFileName($_))+'"/>'}) -join ''
@"
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><LangVersion>latest</LangVersion><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable></PropertyGroup><ItemGroup><FrameworkReference Include="Microsoft.AspNetCore.App"/><PackageReference Include="Npgsql" Version="6.0.10"/><Using Include="Microsoft.Extensions.Configuration"/><Using Include="Microsoft.AspNetCore.Http"/>$compile</ItemGroup></Project>
"@|Set-Content (Join-Path $tmp 'H.csproj') -Encoding utf8
@'
using System.Text.Json; using Sg.SuperApp.Api.Domain; using Sg.SuperApp.Api.Services;
static JsonElement J(string s){using var d=JsonDocument.Parse(s);return d.RootElement.Clone();}
void Q<T>(T x,T y,string n)where T:notnull{if(!EqualityComparer<T>.Default.Equals(x,y))throw new Exception($"{n}: {x}!={y}");}
var passed=0;void Done(string id){passed++;Console.WriteLine(id+" PASS");}

var evaluator=new SchedulingRuleEvaluator();
var eligibility=new SchedulingEligibilityService(evaluator);
var engine=new SchedulingRecommendationEngine();

// A real versioned evaluation, produced by the evaluator, is the only accepted input.
var p3=J("{\"intervalSemantics\":\"HALF_OPEN\",\"adjacentIntervalsOverlap\":false}");
var profile=new SchedulingRuleProfile(7,"MVP",3,SchedulingRuleOrigin.SIMULATED,SchedulingEnvironmentScope.MVP_TEST,"PROJECT-A",new DateOnly(2026,1,1),null,SchedulingRuleProfileStatus.ACTIVE,new string('a',64),new[]{new SchedulingRuleProfileEntry("I9-R03",p3,J("{}"),true)});
string Facts(string intervals)=>$"{{\"assignmentId\":\"assignment-a\",\"scheduleVersionId\":\"v-a\",\"employeeId\":\"guard-a\",\"proposedShiftStart\":\"2026-08-17T08:00:00-05:00\",\"proposedShiftEnd\":\"2026-08-17T16:00:00-05:00\",\"existingIntervals\":{intervals}}}";
const string Overlapping="[{\"employeeId\":\"guard-a\",\"start\":\"2026-08-17T10:00:00-05:00\",\"end\":\"2026-08-17T18:00:00-05:00\",\"status\":\"APPROVED\"}]";
RuleEvaluationReference[] Refs(string intervals){var batch=evaluator.Evaluate(profile,"PROJECT-A",new DateOnly(2026,8,17),J(Facts(intervals)));return batch.Evaluations.Select(x=>new RuleEvaluationReference(x.RuleCode,x.ProfileVersion,x.Outcome.ToString(),x.Severity.ToString(),x.MessageCode,x.Explanation,x.ScopeHash,x.ExceptionAllowed)).ToArray();}
GuardSchedulingFacts G(RuleEvaluationReference[]? refs,bool active=true,long profileId=7,int version=3)=>new(active,profileId,version,true,refs,Array.Empty<EligibilityReason>());

var compliant=Refs("[]");
var blocked=Refs(Overlapping);
Q("I9_R03_COMPLIANT",compliant[0].MessageCode,"fixture compliant");
Q("I9_R03_OVERLAP_APPROVED_BLOCKED",blocked[0].MessageCode,"fixture blocked");

// GEN-T01 a compliant versioned evaluation makes the guard eligible.
var okResult=eligibility.Evaluate(G(compliant));
Q(true,okResult.Eligible,"GEN-T01 eligible");Q(false,okResult.RequiresException,"GEN-T01 no exception");Q(0,okResult.Reasons.Count,"GEN-T01 reasons");
var direct=eligibility.EvaluateAgainstRules(profile,"PROJECT-A",new DateOnly(2026,8,17),J(Facts("[]")),true);
Q(okResult.Eligible,direct.Eligible,"GEN-T01 generation path agrees");Q(0,direct.Reasons.Count,"GEN-T01 generation path reasons");
var directBlocked=eligibility.EvaluateAgainstRules(profile,"PROJECT-A",new DateOnly(2026,8,17),J(Facts(Overlapping)),true);
Q(false,directBlocked.Eligible,"GEN-T01 generation path blocks");Done("GEN-T01");

// GEN-T02 a BLOCKED rule blocks the candidate and surfaces the rule message code.
var blockedResult=eligibility.Evaluate(G(blocked));
Q(false,blockedResult.Eligible,"GEN-T02 blocked");
Q(1,blockedResult.Reasons.Count(x=>x.Code=="I9_R03_OVERLAP_APPROVED_BLOCKED"&&x.Severity=="BLOCKING"),"GEN-T02 stable code");Done("GEN-T02");

// GEN-T03 absent versioned evaluation never presumes compliance.
foreach(var empty in new[]{(RuleEvaluationReference[]?)null,Array.Empty<RuleEvaluationReference>()}){
  var missing=eligibility.Evaluate(G(empty));
  Q(false,missing.Eligible,"GEN-T03 not eligible");
  Q(1,missing.Reasons.Count(x=>x.Code=="RULE_EVALUATION_MISSING"&&x.Severity=="BLOCKING"),"GEN-T03 stable code");
}
Done("GEN-T03");

// GEN-T04 an evaluation that does not declare its versioned profile is rejected.
foreach(var bad in new[]{G(compliant,profileId:0),G(compliant,version:0)}){
  var orphan=eligibility.Evaluate(bad);
  Q(false,orphan.Eligible,"GEN-T04 not eligible");
  Q(1,orphan.Reasons.Count(x=>x.Code=="RULE_PROFILE_MISSING"&&x.Severity=="BLOCKING"),"GEN-T04 stable code");
}
Done("GEN-T04");

// GEN-T05 an inactive guard is still blocked, independently of the rules.
var inactive=eligibility.Evaluate(G(compliant,active:false));
Q(false,inactive.Eligible,"GEN-T05 blocked");
Q(1,inactive.Reasons.Count(x=>x.Code=="EMPLOYEE_INACTIVE"),"GEN-T05 stable code");Done("GEN-T05");

// GEN-T06 an unverified rule never accredits compliance for an automatic assignment.
var unverified=new[]{new RuleEvaluationReference("I9-R07",3,"WARNING","ERROR","I9_R07_DISABLED_UNVERIFIED","sin verificar",new string('b',64),false)};
var unverifiedResult=eligibility.Evaluate(G(unverified));
Q(false,unverifiedResult.Eligible,"GEN-T06 not eligible");
Q(1,unverifiedResult.Reasons.Count(x=>x.Code=="I9_R07_DISABLED_UNVERIFIED"&&x.Severity=="BLOCKING"),"GEN-T06 stable code");Done("GEN-T06");

// GEN-T07 EXCEPTION_REQUIRED keeps the candidate assignable but marks it as needing a decision.
var pending=new[]{new RuleEvaluationReference("I9-R02",3,"EXCEPTION_REQUIRED","WARNING","I9_R02_MIN_REST","descanso","c".PadRight(64,'c'),true)};
var pendingResult=eligibility.Evaluate(G(pending));
Q(true,pendingResult.Eligible,"GEN-T07 eligible");Q(true,pendingResult.RequiresException,"GEN-T07 requires exception");
Q(1,pendingResult.Reasons.Count(x=>x.Code=="I9_R02_MIN_REST"&&x.Severity=="SUBSANABLE"),"GEN-T07 stable code");Done("GEN-T07");

// GEN-T08 a blocked candidate is never assigned; the shift stays vacant with the rule reason.
var weights=new SchedulingWeights(1m,1m,0.1m,0.1m,5m,0.1m);
EligibleCandidate Cand(long id,EligibilityResult result,RuleEvaluationReference[] refs)=>new(id,result,1m,1m,0m,0m,0m,refs);
var onlyBlocked=new ScheduleRecommendationRequest(null,"gen-t08",weights,new[]{new RequiredShiftRecommendationInput(1,10,"2026-08-17","08:00",new[]{Cand(100,blockedResult,blocked)})});
var t08=engine.Generate(onlyBlocked);
Q("VACANTE",t08.Assignments[0].Status,"GEN-T08 vacant");Q(true,t08.Assignments[0].EmployeeId is null,"GEN-T08 unassigned");
Q(true,t08.Assignments[0].RankingReasons.Any(x=>x.Contains("I9_R03_OVERLAP_APPROVED_BLOCKED",StringComparison.Ordinal)),"GEN-T08 reason visible");Done("GEN-T08");

// GEN-T09 the exception penalty makes a pending candidate lose to a clean one, and stays visible.
var clean=Cand(200,okResult,compliant);
var needsException=Cand(300,pendingResult,pending);
var mixed=new ScheduleRecommendationRequest(null,"gen-t09",weights,new[]{new RequiredShiftRecommendationInput(1,10,"2026-08-17","08:00",new[]{needsException,clean})});
var t09=engine.Generate(mixed);
Q(200L,t09.Assignments[0].EmployeeId ?? -1L,"GEN-T09 clean candidate wins");
var onlyPending=new ScheduleRecommendationRequest(null,"gen-t09b",weights,new[]{new RequiredShiftRecommendationInput(1,10,"2026-08-17","08:00",new[]{needsException})});
var t09b=engine.Generate(onlyPending);
Q(300L,t09b.Assignments[0].EmployeeId ?? -1L,"GEN-T09 pending candidate assignable");
Q(true,t09b.Assignments[0].RankingReasons.Any(x=>x.Contains("EXCEPTION_REQUIRED",StringComparison.Ordinal)&&x.Contains(pending[0].ScopeHash,StringComparison.Ordinal)),"GEN-T09 exception scope visible");Done("GEN-T09");

// GEN-T10 a manual edit changes the scope, so an earlier approval no longer applies.
Q(false,compliant[0].ScopeHash==blocked[0].ScopeHash,"GEN-T10 edit changes scopeHash");
var approvedBefore=new HashSet<string>{compliant[0].ScopeHash};
var afterEdit=evaluator.Evaluate(profile,"PROJECT-A",new DateOnly(2026,8,17),J(Facts(Overlapping)),approvedBefore);
Q(false,afterEdit.Summary.CanApproveOrPublish,"GEN-T10 stale approval does not survive the edit");
var recomputed=evaluator.Evaluate(profile,"PROJECT-A",new DateOnly(2026,8,17),J(Facts("[]")),approvedBefore);
Q(true,recomputed.Summary.CanApproveOrPublish,"GEN-T10 summary recomputed for the current scope");Done("GEN-T10");

// GEN-T15 a caller declaring itself eligible without any versioned evaluation is never assigned.
// The request body is the caller's word; ranking projects the verdicts instead of trusting it.
var noEvidence=new ScheduleRecommendationRequest(null,"gen-t15",weights,new[]{new RequiredShiftRecommendationInput(1,10,"2026-08-17","08:00",new[]{Cand(400,okResult,Array.Empty<RuleEvaluationReference>())})});
var t11=engine.Generate(noEvidence);
Q("VACANTE",t11.Assignments[0].Status,"GEN-T15 declared eligibility without evidence stays vacant");
Q(true,t11.Assignments[0].EmployeeId is null,"GEN-T15 unassigned");
Q(true,t11.Assignments[0].RankingReasons.Any(x=>x.Contains("RULE_EVALUATION_MISSING",StringComparison.Ordinal)),"GEN-T15 missing evaluation reason visible");Done("GEN-T15");

// GEN-T16 a caller declaring itself eligible while its own evidence blocks is never assigned.
// This is the contradiction the isolated booleans used to permit, now stated over the verdicts.
var contradiction=new ScheduleRecommendationRequest(null,"gen-t16",weights,new[]{new RequiredShiftRecommendationInput(1,10,"2026-08-17","08:00",new[]{Cand(500,okResult,blocked)})});
var t12=engine.Generate(contradiction);
Q("VACANTE",t12.Assignments[0].Status,"GEN-T16 declared eligibility cannot override a blocked rule");
Q(true,t12.Assignments[0].RankingReasons.Any(x=>x.Contains("I9_R03_OVERLAP_APPROVED_BLOCKED",StringComparison.Ordinal)),"GEN-T16 blocking rule still decides");Done("GEN-T16");

// GEN-T17 verdicts from two different profile versions accredit nothing: there is no single
// snapshot they all belong to, so none of them can be read as describing this decision.
var mixedVersions=new[]{compliant[0],new RuleEvaluationReference(compliant[0].RuleCode=="I9-R01"?"I9-R02":"I9-R01",compliant[0].RuleProfileVersion+1,"COMPLIANT","INFO","I9_MIXED","otra version",new string('d',64),false)};
var mixedRequest=new ScheduleRecommendationRequest(null,"gen-t17",weights,new[]{new RequiredShiftRecommendationInput(1,10,"2026-08-17","08:00",new[]{Cand(600,okResult,mixedVersions)})});
var t13=engine.Generate(mixedRequest);
Q("VACANTE",t13.Assignments[0].Status,"GEN-T17 verdicts from mixed profile versions stay vacant");
Q(true,t13.Assignments[0].RankingReasons.Any(x=>x.Contains("RULE_EVALUATION_UNTRUSTED",StringComparison.Ordinal)),"GEN-T17 untrusted reason visible");Done("GEN-T17");

Q(13,passed,"numbered generation scenario count");
Console.WriteLine($"I9 MVP GENERATION PASS {passed}");
Console.WriteLine("I9 MVP GENERATION PASS");
'@|Set-Content (Join-Path $tmp 'Program.cs') -Encoding utf8
 & $dotnet run --project (Join-Path $tmp 'H.csproj') --configuration Release;exit $LASTEXITCODE
}
finally{ if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Recurse -Force} }
