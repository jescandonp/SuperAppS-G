param([string]$ApiBaseUrl = "http://localhost:5080/api")

$ErrorActionPreference = "Stop"

function Get-Headers([string]$Username, [string]$Password) {
    $body = @{ username=$Username; password=$Password } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization="Bearer $($login.sessionToken)" }
}

function Invoke-Evaluation([hashtable]$Headers, [object]$Facts) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "$ApiBaseUrl/portal/scheduling/eligibility/evaluate" `
            -Method Post -Headers $Headers -ContentType "application/json" -Body ($Facts | ConvertTo-Json -Depth 6)
        return @{ Status=[int]$response.StatusCode; Json=$response.Content; Body=($response.Content | ConvertFrom-Json) }
    } catch {
        if ($null -eq $_.Exception.Response) { throw }
        return @{ Status=[int]$_.Exception.Response.StatusCode; Json=$null; Body=$null }
    }
}

$admin = Get-Headers "admin.sg" "Admin123"
$operations = Get-Headers "operaciones.sg" "Operaciones123"
$th = Get-Headers "th.sg" "Th123456"

# The versioned rule evaluation is the only source of truth. The isolated booleans this file
# used to post (hasOverlap, restRuleSatisfied and the rest) were a parallel truth that could
# contradict the rules, and no longer exist in the contract.
$scope = 'a' * 64
function New-Evaluation([string]$rule, [string]$outcome, [string]$severity, [string]$code) {
    @{ ruleCode=$rule; ruleProfileVersion=3; outcome=$outcome; severity=$severity; messageCode=$code
       explanation='Evaluacion simulada MVP_TEST.'; scopeHash=$scope; exceptionAllowed=($outcome -eq 'EXCEPTION_REQUIRED') }
}
function New-Facts([object[]]$evaluations, [object[]]$requirements = @(), [bool]$active = $true) {
    @{ active=$active; ruleProfileId=7; ruleProfileVersion=3; simulated=$true
       ruleEvaluations=$evaluations; requirementReasons=$requirements }
}
$compliant = @(New-Evaluation 'I9-R03' 'COMPLIANT' 'INFO' 'I9_R03_COMPLIANT')

$eligibleFacts = New-Facts $compliant
$eligible = Invoke-Evaluation $operations $eligibleFacts
if ($eligible.Status -eq 404) { throw "I9 eligibility endpoint is missing (HTTP 404)." }
if ($eligible.Status -ne 200 -or -not $eligible.Body.eligible -or $eligible.Body.requiresException -or @($eligible.Body.reasons).Count -ne 0) { throw "Active eligible guard was not accepted." }

$cases = @(
    @{ Name="inactive"; Facts=(New-Facts $compliant @() $false); Code="EMPLOYEE_INACTIVE" },
    @{ Name="incapacity"; Facts=(New-Facts @(New-Evaluation 'I9-R04' 'BLOCKED' 'BLOCKING' 'I9_R04_INCAPACITY_ACTIVE')); Code="I9_R04_INCAPACITY_ACTIVE" },
    @{ Name="overlap"; Facts=(New-Facts @(New-Evaluation 'I9-R03' 'BLOCKED' 'BLOCKING' 'I9_R03_OVERLAP_APPROVED_BLOCKED')); Code="I9_R03_OVERLAP_APPROVED_BLOCKED" },
    @{ Name="travel"; Facts=(New-Facts @(New-Evaluation 'I9-R05' 'BLOCKED' 'BLOCKING' 'I9_R05_PROHIBITED')); Code="I9_R05_PROHIBITED" },
    @{ Name="unverified"; Facts=(New-Facts @(New-Evaluation 'I9-R07' 'WARNING' 'ERROR' 'I9_R07_DISABLED_UNVERIFIED')); Code="I9_R07_DISABLED_UNVERIFIED" },
    @{ Name="missing evaluation"; Facts=(New-Facts @()); Code="RULE_EVALUATION_MISSING" },
    @{ Name="orphan profile"; Facts=@{ active=$true; ruleProfileId=0; ruleProfileVersion=0; simulated=$true; ruleEvaluations=$compliant; requirementReasons=@() }; Code="RULE_PROFILE_MISSING" },
    @{ Name="requirement"; Facts=(New-Facts $compliant @(@{ code="REQUIREMENT_EXPIRED"; severity="BLOQUEANTE"; message="Requisito bloqueante vencido." })); Code="REQUIREMENT_EXPIRED" }
)
foreach ($case in $cases) {
    $result = Invoke-Evaluation $admin $case.Facts
    if ($result.Status -ne 200 -or $result.Body.eligible -or $result.Body.requiresException) { throw "Blocking case $($case.Name) was not blocked." }
    if (@($result.Body.reasons | Where-Object code -eq $case.Code).Count -ne 1) { throw "Blocking case $($case.Name) missing stable code $($case.Code)." }
}

# An evaluation whose declared profile version does not match the decision is not trusted.
$mismatched = New-Facts @(@{ ruleCode='I9-R03'; ruleProfileVersion=99; outcome='COMPLIANT'; severity='INFO'
    messageCode='I9_R03_COMPLIANT'; explanation='Version ajena.'; scopeHash=$scope; exceptionAllowed=$false })
$mismatchedResult = Invoke-Evaluation $admin $mismatched
if ($mismatchedResult.Body.eligible -or @($mismatchedResult.Body.reasons | Where-Object code -eq 'RULE_EVALUATION_UNTRUSTED').Count -ne 1) {
    throw "An evaluation from another profile version must not be trusted."
}

$subsanableFacts = New-Facts $compliant @(@{ code="COURSE_RENEWAL_DUE"; severity="SUBSANABLE"; message="Curso subsanable." })
$subsanable = Invoke-Evaluation $operations $subsanableFacts
if (-not $subsanable.Body.eligible -or -not $subsanable.Body.requiresException) { throw "Subsanable requirement must remain eligible and require exception." }

# A rule that demands an exception keeps the candidate assignable but pending a decision.
$pendingFacts = New-Facts @(New-Evaluation 'I9-R02' 'EXCEPTION_REQUIRED' 'WARNING' 'I9_R02_MIN_REST')
$pending = Invoke-Evaluation $operations $pendingFacts
if (-not $pending.Body.eligible -or -not $pending.Body.requiresException) { throw "An exception-required rule must stay eligible and pending." }
if (@($pending.Body.reasons | Where-Object { $_.code -eq 'I9_R02_MIN_REST' -and $_.severity -eq 'SUBSANABLE' }).Count -ne 1) {
    throw "An exception-required rule must be reported as SUBSANABLE."
}

$informativeFacts = New-Facts $compliant @(@{ code="INFO_ONLY"; severity="INFORMATIVA"; message="Informacion." })
$informative = Invoke-Evaluation $admin $informativeFacts
if (-not $informative.Body.eligible -or $informative.Body.requiresException) { throw "Informative requirement must not block or require exception." }

$orderedFacts = New-Facts @(
    (New-Evaluation 'I9-R05' 'BLOCKED' 'BLOCKING' 'I9_R05_PROHIBITED'),
    (New-Evaluation 'I9-R02' 'BLOCKED' 'BLOCKING' 'I9_R02_MIN_REST_BLOCKED'),
    (New-Evaluation 'I9-R04' 'BLOCKED' 'BLOCKING' 'I9_R04_INCAPACITY_ACTIVE'),
    (New-Evaluation 'I9-R03' 'BLOCKED' 'BLOCKING' 'I9_R03_OVERLAP_APPROVED_BLOCKED')
) @(@{ code="REQ_SUBSANABLE"; severity="SUBSANABLE"; message="Subsanable." }) $false
$ordered = Invoke-Evaluation $admin $orderedFacts
$orderedCodes = @($ordered.Body.reasons | ForEach-Object code) -join ","
if ($orderedCodes -ne "EMPLOYEE_INACTIVE,I9_R02_MIN_REST_BLOCKED,I9_R03_OVERLAP_APPROVED_BLOCKED,I9_R04_INCAPACITY_ACTIVE,I9_R05_PROHIBITED,REQ_SUBSANABLE") {
    throw "Eligibility reasons are not returned in stable rule order: $orderedCodes"
}

$invalidSeverityFacts = New-Facts $compliant @(@{ code="BAD"; severity="OPCIONAL"; message="Invalida." })
$invalidSeverity = Invoke-Evaluation $admin $invalidSeverityFacts
if ($invalidSeverity.Status -ne 400) { throw "Unknown requirement severity must return HTTP 400." }

$first = Invoke-Evaluation $operations $subsanableFacts
$second = Invoke-Evaluation $operations $subsanableFacts
if ($first.Json -cne $second.Json) { throw "Identical eligibility facts must return deterministic JSON." }

$forbidden = Invoke-Evaluation $th $eligibleFacts
if ($forbidden.Status -ne 403) { throw "TH eligibility evaluation must return HTTP 403." }
$anonymous = Invoke-Evaluation @{} $eligibleFacts
if ($anonymous.Status -ne 401) { throw "Anonymous eligibility evaluation must return HTTP 401." }

Write-Host "I9 ELIGIBILITY PASS"
