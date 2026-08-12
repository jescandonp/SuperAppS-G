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

$eligibleFacts = @{ active=$true; hasBlockingAbsence=$false; hasOverlap=$false; restRuleSatisfied=$true; hasBlockingLocationMismatch=$false; requirementReasons=@() }
$eligible = Invoke-Evaluation $operations $eligibleFacts
if ($eligible.Status -eq 404) { throw "I9 eligibility endpoint is missing (HTTP 404)." }
if ($eligible.Status -ne 200 -or -not $eligible.Body.eligible -or $eligible.Body.requiresException -or @($eligible.Body.reasons).Count -ne 0) { throw "Active eligible guard was not accepted." }

$cases = @(
    @{ Name="inactive"; Facts=@{ active=$false; hasBlockingAbsence=$false; hasOverlap=$false; restRuleSatisfied=$true; hasBlockingLocationMismatch=$false; requirementReasons=@() }; Code="EMPLOYEE_INACTIVE" },
    @{ Name="incapacity"; Facts=@{ active=$true; hasBlockingAbsence=$true; hasOverlap=$false; restRuleSatisfied=$true; hasBlockingLocationMismatch=$false; requirementReasons=@() }; Code="BLOCKING_ABSENCE" },
    @{ Name="overlap"; Facts=@{ active=$true; hasBlockingAbsence=$false; hasOverlap=$true; restRuleSatisfied=$true; hasBlockingLocationMismatch=$false; requirementReasons=@() }; Code="SHIFT_OVERLAP" },
    @{ Name="rest"; Facts=@{ active=$true; hasBlockingAbsence=$false; hasOverlap=$false; restRuleSatisfied=$false; hasBlockingLocationMismatch=$false; requirementReasons=@() }; Code="MINIMUM_REST" },
    @{ Name="location"; Facts=@{ active=$true; hasBlockingAbsence=$false; hasOverlap=$false; restRuleSatisfied=$true; hasBlockingLocationMismatch=$true; requirementReasons=@() }; Code="LOCATION_RULE" },
    @{ Name="requirement"; Facts=@{ active=$true; hasBlockingAbsence=$false; hasOverlap=$false; restRuleSatisfied=$true; hasBlockingLocationMismatch=$false; requirementReasons=@(@{ code="REQUIREMENT_EXPIRED"; severity="BLOQUEANTE"; message="Requisito bloqueante vencido." }) }; Code="REQUIREMENT_EXPIRED" }
)
foreach ($case in $cases) {
    $result = Invoke-Evaluation $admin $case.Facts
    if ($result.Status -ne 200 -or $result.Body.eligible -or $result.Body.requiresException) { throw "Blocking case $($case.Name) was not blocked." }
    if (@($result.Body.reasons | Where-Object code -eq $case.Code).Count -ne 1) { throw "Blocking case $($case.Name) missing stable code $($case.Code)." }
}

$subsanableFacts = @{ active=$true; hasBlockingAbsence=$false; hasOverlap=$false; restRuleSatisfied=$true; hasBlockingLocationMismatch=$false; requirementReasons=@(@{ code="COURSE_RENEWAL_DUE"; severity="SUBSANABLE"; message="Curso subsanable." }) }
$subsanable = Invoke-Evaluation $operations $subsanableFacts
if (-not $subsanable.Body.eligible -or -not $subsanable.Body.requiresException) { throw "Subsanable requirement must remain eligible and require exception." }

$informativeFacts = @{ active=$true; hasBlockingAbsence=$false; hasOverlap=$false; restRuleSatisfied=$true; hasBlockingLocationMismatch=$false; requirementReasons=@(@{ code="INFO_ONLY"; severity="INFORMATIVA"; message="Informacion." }) }
$informative = Invoke-Evaluation $admin $informativeFacts
if (-not $informative.Body.eligible -or $informative.Body.requiresException) { throw "Informative requirement must not block or require exception." }

$orderedFacts = @{
    active=$false; hasBlockingAbsence=$true; hasOverlap=$true; restRuleSatisfied=$false; hasBlockingLocationMismatch=$true
    requirementReasons=@(@{ code="REQ_SUBSANABLE"; severity="SUBSANABLE"; message="Subsanable." })
}
$ordered = Invoke-Evaluation $admin $orderedFacts
$orderedCodes = @($ordered.Body.reasons | ForEach-Object code) -join ","
if ($orderedCodes -ne "EMPLOYEE_INACTIVE,BLOCKING_ABSENCE,SHIFT_OVERLAP,MINIMUM_REST,LOCATION_RULE,REQ_SUBSANABLE") {
    throw "Eligibility reasons are not returned in stable order: $orderedCodes"
}

$invalidSeverityFacts = @{ active=$true; hasBlockingAbsence=$false; hasOverlap=$false; restRuleSatisfied=$true; hasBlockingLocationMismatch=$false; requirementReasons=@(@{ code="BAD"; severity="OPCIONAL"; message="Invalida." }) }
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
