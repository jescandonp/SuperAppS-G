[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$defaultRepositoryRoot = Join-Path $PSScriptRoot '..\..'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path -LiteralPath $defaultRepositoryRoot).Path
}
else {
    (Resolve-Path -LiteralPath $RepositoryRoot).Path
}

$failures = New-Object 'System.Collections.Generic.List[string]'

function Get-MissingPatternLabels {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][object[]]$Patterns
    )

    $missing = New-Object 'System.Collections.Generic.List[string]'
    foreach ($pattern in $Patterns) {
        if (-not [regex]::IsMatch($Content, $pattern.Regex)) {
            $missing.Add([string]$pattern.Label)
        }
    }
    return @($missing)
}

function Invoke-HelperSelfTest {
    $patterns = @(
        [pscustomobject]@{ Label = 'profile version'; Regex = '(?i)profileVersion' },
        [pscustomobject]@{ Label = 'scope hash'; Regex = '(?i)scopeHash' }
    )
    $positive = @(Get-MissingPatternLabels -Content 'profileVersion scopeHash' -Patterns $patterns)
    $negative = @(Get-MissingPatternLabels -Content 'profileVersion' -Patterns $patterns)

    if ($positive.Count -ne 0) {
        throw 'I9 MVP rules verifier helper positive self-test failed.'
    }
    if ($negative.Count -ne 1 -or $negative[0] -ne 'scope hash') {
        throw 'I9 MVP rules verifier helper negative self-test failed.'
    }
}

function Assert-FileContains {
    param(
        [Parameter(Mandatory = $true)][string]$Requirement,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][object[]]$Patterns
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("$Requirement`: missing file '$RelativePath'")
        return
    }

    $content = Get-Content -LiteralPath $path -Raw
    $missingLabels = @(Get-MissingPatternLabels -Content $content -Patterns $Patterns)
    foreach ($label in $missingLabels) {
        $failures.Add("$Requirement`: '$RelativePath' is missing $label")
    }
}

function Pattern {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Regex
    )

    return [pscustomobject]@{ Label = $Label; Regex = $Regex }
}

Invoke-HelperSelfTest

Assert-FileContains 'Versioned rule profile persistence' 'db/migrations/012_i9_mvp_rule_profiles.sql' @(
    (Pattern 'scheduling_rule_profiles' '(?i)\bscheduling_rule_profiles\b'),
    (Pattern 'scheduling_rule_profile_entries' '(?i)\bscheduling_rule_profile_entries\b'),
    (Pattern 'scheduling_rule_evaluations' '(?i)\bscheduling_rule_evaluations\b'),
    (Pattern 'profile version and checksum fields' '(?is)\bversion\b.*\bchecksum\b'),
    (Pattern 'rule-bound exception snapshot fields' '(?is)\brule_code\b.*\bevaluation_id\b.*\bscope_hash\b'),
    (Pattern 'schedule version profile and simulated markers' '(?is)\bschedule_versions\b.*\b(rule_profile|rule_profile_id|rule_profile_version)\b.*\bsimulated\b')
)

Assert-FileContains 'Simulated MVP profile seed' 'db/seeds/011_i9_mvp_simulated_rule_profile.sql' @(
    (Pattern 'SIMULATED origin' '(?i)\bSIMULATED\b'),
    (Pattern 'MVP_TEST environment' '(?i)\bMVP_TEST\b'),
    (Pattern 'all rule entries I9-R01 through I9-R07' '(?is)I9-R01.*I9-R02.*I9-R03.*I9-R04.*I9-R05.*I9-R06.*I9-R07')
)

Assert-FileContains 'Versioned profile database contract' 'db/tests/008_i9_mvp_rule_profiles_contract.sql' @(
    (Pattern 'active profile uniqueness' '(?is)\bACTIVE\b.*(unique|overlap|superpuest|vigencia)'),
    (Pattern 'active profile immutability' '(?is)(immutable|inmutab|reject|rechaz).*(active|activo)'),
    (Pattern 'evaluation history immutability' '(?is)(immutable|inmutab|reject|rechaz).*evaluat')
)

Assert-FileContains 'Typed versioned profile and common result contracts' 'apps/sg-superapp-api/Domain/SchedulingRuleModels.cs' @(
    (Pattern 'profile identity and version' '(?is)ProfileCode.*Version'),
    (Pattern 'origin and environment scope' '(?is)Origin.*EnvironmentScope'),
    (Pattern 'effective dates, status and checksum' '(?is)EffectiveFrom.*EffectiveTo.*Status.*Checksum'),
    (Pattern 'common rule evaluation result' '(?i)(record|class)\s+RuleEvaluation'),
    (Pattern 'all common outcomes' '(?is)COMPLIANT.*BLOCKED.*EXCEPTION_REQUIRED.*WARNING.*NOT_APPLICABLE'),
    (Pattern 'scopeHash' '(?i)ScopeHash')
)

Assert-FileContains 'Profile repository integration' 'apps/sg-superapp-api/Services/SchedulingRuleProfileRepository.cs' @(
    (Pattern 'exact active profile selection' '(?is)ACTIVE.*(project|proyecto).*(period|periodo).*(environment|ambiente)'),
    (Pattern 'versioned profile entries' '(?i)SchedulingRuleProfileEntr')
)

Assert-FileContains 'Fail-closed profile validation and environment gate' 'apps/sg-superapp-api/Services/SchedulingRuleProfileValidator.cs' @(
    (Pattern 'SIMULATED profile handling' '(?i)SIMULATED'),
    (Pattern 'MVP_TEST allowance' '(?i)MVP_TEST'),
    (Pattern 'PRODUCTION rejection' '(?i)PRODUCTION'),
    (Pattern 'profile completeness across R01-R07' '(?is)I9-R01.*I9-R02.*I9-R03.*I9-R04.*I9-R05.*I9-R06.*I9-R07'),
    (Pattern 'checksum validation' '(?i)checksum')
)

Assert-FileContains 'Common evaluator, precedence and deterministic snapshot' 'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs' @(
    (Pattern 'all rules R01-R07' '(?is)I9-R01.*I9-R02.*I9-R03.*I9-R04.*I9-R05.*I9-R06.*I9-R07'),
    (Pattern 'BLOCKED precedence' '(?i)BLOCKED'),
    (Pattern 'R03 precedence over R05' '(?is)I9-R03.*I9-R05'),
    (Pattern 'deterministic scopeHash' '(?i)scopeHash'),
    (Pattern 'parameter and fact snapshots' '(?is)(parameter|parametro).*(snapshot|facts|hechos)')
)

Assert-FileContains 'I9-R01 and I9-R02 rule implementation' 'apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs' @(
    (Pattern 'I9-R01' 'I9-R01'),
    (Pattern 'I9-R02' 'I9-R02'),
    (Pattern 'R01 daily boundaries 8, 10 and 12 hours' '(?s)\b8\b.*\b10\b.*\b12\b'),
    (Pattern 'R01 weekly boundaries 42 and 60 hours' '(?s)\b42\b.*\b60\b'),
    (Pattern 'R02 minimum rest' '(?i)(rest|descanso)')
)

Assert-FileContains 'I9-R03 and I9-R05 rule implementation' 'apps/sg-superapp-api/Services/SchedulingOverlapTravelRules.cs' @(
    (Pattern 'I9-R03' 'I9-R03'),
    (Pattern 'I9-R05' 'I9-R05'),
    (Pattern 'overlap evaluation' '(?i)(overlap|solap)'),
    (Pattern 'directional travel evaluation' '(?i)(direction|direcc|travel|traslado)'),
    (Pattern 'prohibited travel handling' '(?i)(prohibit|prohibid)')
)

Assert-FileContains 'I9-R04 and I9-R06 rule implementation' 'apps/sg-superapp-api/Services/SchedulingNoveltyRequirementRules.cs' @(
    (Pattern 'I9-R04' 'I9-R04'),
    (Pattern 'I9-R06' 'I9-R06'),
    (Pattern 'unknown or unverified novelty handling' '(?i)(UNKNOWN|UNVERIFIED)'),
    (Pattern 'employee and position requirement evaluation' '(?is)employeeId.*(position|puesto).*(requirement|requisito)'),
    (Pattern 'requirement evidence and validity' '(?is)(evidence|evidencia).*(valid|vigencia|expiry|expires)')
)

Assert-FileContains 'I9-R07 rule implementation' 'apps/sg-superapp-api/Services/SchedulingTemplateDeviationRule.cs' @(
    (Pattern 'I9-R07' 'I9-R07'),
    (Pattern 'template version and anchor comparison' '(?is)(template|plantilla).*(version).*(anchor|anclaje)'),
    (Pattern 'expected and proposed cell values' '(?is)(expected|esperado).*(proposed|propuesto).*(cell|celda)'),
    (Pattern 'scopeHash-bound deviation' '(?i)scopeHash')
)

Assert-FileContains 'Rule profile HTTP endpoints' 'apps/sg-superapp-api/Endpoints/SchedulingRuleEndpoints.cs' @(
    (Pattern 'GET /api/portal/scheduling/rule-profiles' '(?i)MapGet\s*\(\s*"/api/portal/scheduling/rule-profiles"'),
    (Pattern 'GET /api/portal/scheduling/rule-profiles/{id}' '(?i)MapGet\s*\(\s*"/api/portal/scheduling/rule-profiles/\{id(?::long)?\}"'),
    (Pattern 'POST /api/portal/scheduling/rule-profiles' '(?i)MapPost\s*\(\s*"/api/portal/scheduling/rule-profiles"'),
    (Pattern 'POST /api/portal/scheduling/rule-profiles/{id}/activate' '(?i)MapPost\s*\(\s*"/api/portal/scheduling/rule-profiles/\{id(?::long)?\}/activate"'),
    (Pattern 'POST /api/portal/scheduling/rule-profiles/{id}/retire' '(?i)MapPost\s*\(\s*"/api/portal/scheduling/rule-profiles/\{id(?::long)?\}/retire"'),
    (Pattern 'POST /api/portal/scheduling/rules/evaluate' '(?i)MapPost\s*\(\s*"/api/portal/scheduling/rules/evaluate"'),
    (Pattern 'VIEW, CONFIGURE and GENERATE authorization' '(?is)SCHEDULING/VIEW.*SCHEDULING/CONFIGURE.*SCHEDULING/GENERATE')
)

Assert-FileContains 'Rule HTTP response contracts' 'apps/sg-superapp-api/Contracts/Portal/SchedulingRuleContracts.cs' @(
    (Pattern 'rule profile response' '(?i)RuleProfile'),
    (Pattern 'rule evaluation summary' '(?i)(RuleEvaluation|RuleSummary)'),
    (Pattern 'scopeHash' '(?i)scopeHash'),
    (Pattern 'simulated marker' '(?i)simulated')
)

Assert-FileContains 'Backend endpoint registration' 'apps/sg-superapp-api/Program.cs' @(
    (Pattern 'scheduling rule endpoint mapping' '(?i)(MapSchedulingRule|SchedulingRuleEndpoints)')
)

Assert-FileContains 'Generation and manual-edit domain rule contracts' 'apps/sg-superapp-api/Domain/SchedulingModels.cs' @(
    (Pattern 'versioned rule profile reference' '(?i)RuleProfile(Id|Version|Reference)'),
    (Pattern 'common RuleEvaluation results in scheduling models' '(?i)RuleEvaluation'),
    (Pattern 'scopeHash-bound scheduling snapshot' '(?i)ScopeHash'),
    (Pattern 'simulated scheduling marker' '(?i)Simulated')
)

Assert-FileContains 'Generation, exception, approval and publication portal contracts' 'apps/sg-superapp-api/Contracts/Portal/SchedulingContracts.cs' @(
    (Pattern 'generation/edit/transition response rule profile' '(?is)Schedule(Proposal|Version|Workflow)Response.*RuleProfile'),
    (Pattern 'generation/edit/transition response rule result summary' '(?is)Schedule(Proposal|Version|Workflow)Response.*Rule(Evaluation|Summary|Result)'),
    (Pattern 'generation/edit/transition response simulated marker' '(?is)Schedule(Proposal|Version|Workflow)Response.*Simulated'),
    (Pattern 'manual-edit contract' '(?i)UpdateScheduleAssignmentRequest'),
    (Pattern 'exception ruleCode snapshot' '(?is)CreateScheduleExceptionRequest.*RuleCode'),
    (Pattern 'exception evaluationId snapshot' '(?is)CreateScheduleExceptionRequest.*EvaluationId'),
    (Pattern 'exception scopeHash snapshot' '(?is)CreateScheduleExceptionRequest.*ScopeHash'),
    (Pattern 'catalogued exception motive' '(?is)CreateScheduleExceptionRequest.*(MotiveCode|ReasonCode)'),
    (Pattern 'approval/publication transition contract' '(?i)ScheduleTransitionRequest')
)

Assert-FileContains 'Generation eligibility integration' 'apps/sg-superapp-api/Services/SchedulingEligibilityService.cs' @(
    (Pattern 'versioned rule evaluator integration' '(?i)SchedulingRuleEvaluator'),
    (Pattern 'BLOCKED candidate rejection' '(?i)BLOCKED')
)

Assert-FileContains 'Recommendation integration' 'apps/sg-superapp-api/Services/SchedulingRecommendationEngine.cs' @(
    (Pattern 'versioned rule evaluation result' '(?i)RuleEvaluation'),
    (Pattern 'exception-required scoring' '(?i)EXCEPTION_REQUIRED')
)

Assert-FileContains 'Workflow snapshot and stale-exception integration' 'apps/sg-superapp-api/Services/PostgresPortalRepository.cs' @(
    (Pattern 'rule profile snapshot persistence' '(?is)rule.*profile.*snapshot'),
    (Pattern 'scopeHash revalidation' '(?i)scopeHash'),
    (Pattern 'simulated marker persistence' '(?i)simulated'),
    (Pattern 'approval or publication rule revalidation' '(?is)(approv|aproba|publish|publica).*(RuleEvaluation|BLOCKED|EXCEPTION_REQUIRED)')
)

Assert-FileContains 'Exception, approval and publication endpoint rule enforcement' 'apps/sg-superapp-api/Endpoints/PortalEndpoints.cs' @(
    (Pattern 'exception endpoint rule snapshot handling' '(?is)/exceptions.*(RuleCode|EvaluationId).*ScopeHash'),
    (Pattern 'approval endpoint rule revalidation' '(?is)/approve.*(SchedulingRuleEvaluator|RuleEvaluation|BLOCKED|EXCEPTION_REQUIRED)'),
    (Pattern 'publication endpoint rule revalidation' '(?is)/publish.*(SchedulingRuleEvaluator|RuleEvaluation|BLOCKED|EXCEPTION_REQUIRED)'),
    (Pattern 'stale scopeHash conflict response' '(?is)ScopeHash.*(Conflict|Results\.Conflict|409|stale|obsolet|desactual)')
)

Assert-FileContains 'Frontend rule profile and result types' 'apps/sg-superapp-web/src/types/portal.ts' @(
    (Pattern 'rule profile type' '(?i)(interface|type)\s+.*RuleProfile'),
    (Pattern 'rule result or summary type' '(?i)(interface|type)\s+.*Rule(Evaluation|Summary|Result)'),
    (Pattern 'scopeHash' '(?i)scopeHash'),
    (Pattern 'simulated marker' '(?i)simulated')
)

Assert-FileContains 'Frontend rule profile API client' 'apps/sg-superapp-web/src/services/portalApi.ts' @(
    (Pattern 'rule-profiles endpoint' '(?i)rule-profiles'),
    (Pattern 'rules/evaluate endpoint' '(?i)rules/evaluate')
)

Assert-FileContains 'Frontend shell rule state integration' 'apps/sg-superapp-web/src/hooks/usePortalShell.ts' @(
    (Pattern 'rule profile state' '(?i)ruleProfile'),
    (Pattern 'rule evaluation or summary state' '(?i)rule(Evaluation|Summary|Results)'),
    (Pattern 'revalidation after changes' '(?i)(revalid|evaluateRules|ruleEvaluation)')
)

Assert-FileContains 'Frontend rule results panel' 'apps/sg-superapp-web/src/features/scheduling/RuleEvaluationPanel.tsx' @(
    (Pattern 'persistent simulated MVP label' '(?i)DATOS SIMULADOS\s*-\s*MVP'),
    (Pattern 'rule result summary' '(?i)(COMPLIANT|BLOCKED|EXCEPTION_REQUIRED|WARNING)'),
    (Pattern 'accessible status announcement' '(?i)(aria-live|role=.status)')
)

Assert-FileContains 'Scheduling page rule panel integration' 'apps/sg-superapp-web/src/features/scheduling/SchedulingPage.tsx' @(
    (Pattern 'RuleEvaluationPanel' '(?i)RuleEvaluationPanel'),
    (Pattern 'simulated marker' '(?i)simulated')
)

Assert-FileContains 'Exception panel scope snapshot integration' 'apps/sg-superapp-web/src/features/scheduling/ExceptionPanel.tsx' @(
    (Pattern 'rule code' '(?i)ruleCode'),
    (Pattern 'scopeHash' '(?i)scopeHash')
)

$ruleVerifierContracts = @(
    @{ Requirement = 'I9-R01/R02 focused verifier'; Path = 'scripts/dev/Verify-SgSuperAppI9R01R02.ps1'; Rules = '(?is)I9-R01.*I9-R02' },
    @{ Requirement = 'I9-R03/R05 focused verifier'; Path = 'scripts/dev/Verify-SgSuperAppI9R03R05.ps1'; Rules = '(?is)I9-R03.*I9-R05' },
    @{ Requirement = 'I9-R04/R06 focused verifier'; Path = 'scripts/dev/Verify-SgSuperAppI9R04R06.ps1'; Rules = '(?is)I9-R04.*I9-R06' },
    @{ Requirement = 'I9-R07 focused verifier'; Path = 'scripts/dev/Verify-SgSuperAppI9R07.ps1'; Rules = 'I9-R07' }
)
foreach ($verifier in $ruleVerifierContracts) {
    Assert-FileContains $verifier.Requirement $verifier.Path @(
        (Pattern 'the expected rule codes' $verifier.Rules),
        (Pattern 'an explicit PASS outcome' '(?i)\bPASS\b')
    )
}

Assert-FileContains 'MVP generation integration verifier' 'scripts/dev/Verify-SgSuperAppI9MvpGeneration.ps1' @(
    (Pattern 'blocked candidate rejection' '(?is)BLOCKED.*(candidate|candidato|assign|asign)'),
    (Pattern 'scopeHash invalidation after edit' '(?is)scopeHash.*(invalid|recalcul|change|cambi)')
)

Assert-FileContains 'MVP workflow integration verifier' 'scripts/dev/Verify-SgSuperAppI9MvpWorkflow.ps1' @(
    (Pattern 'stale scopeHash rejection' '(?is)scopeHash.*(stale|obsolet|desactual|invalid)'),
    (Pattern 'approval and publication blocking' '(?is)(approv|aproba).*(publish|publica).*(BLOCKED|EXCEPTION_REQUIRED)')
)

Assert-FileContains 'MVP frontend API verifier' 'scripts/dev/Verify-SgSuperAppI9MvpFrontendApi.ps1' @(
    (Pattern 'rule profile contract' '(?i)ruleProfile'),
    (Pattern 'simulated marker contract' '(?i)simulated')
)

Assert-FileContains 'MVP UI verifier' 'scripts/dev/Verify-SgSuperAppI9MvpUi.ps1' @(
    (Pattern 'simulated MVP label' '(?i)DATOS SIMULADOS\s*-\s*MVP'),
    (Pattern 'rule result states' '(?is)BLOCKED.*EXCEPTION_REQUIRED.*WARNING')
)

Assert-FileContains 'Existing I9 suite extended with MVP closure regression' 'scripts/dev/Verify-SgSuperAppI9Integration.ps1' @(
    (Pattern 'MVP rules closure verifier invocation' '(?i)Verify-SgSuperAppI9MvpRules\.ps1'),
    (Pattern 'MVP hermetic integration verifier invocation' '(?i)Verify-SgSuperAppI9MvpIntegration\.ps1'),
    (Pattern 'generation and workflow regression coverage' '(?is)Verify-SgSuperAppI9(Eligibility|Recommendations)\.ps1.*Verify-SgSuperAppI9Workflow\.ps1'),
    (Pattern 'security and export regression coverage' '(?is)Verify-SgSuperAppI9Security\.ps1.*Verify-SgSuperAppI9Exports\.ps1')
)

Assert-FileContains 'Hermetic MVP closure suite' 'scripts/dev/Verify-SgSuperAppI9MvpIntegration.ps1' @(
    (Pattern 'all rule verifiers or rules R01-R07' '(?is)I9-R01.*I9-R02.*I9-R03.*I9-R04.*I9-R05.*I9-R06.*I9-R07'),
    (Pattern 'MVP_TEST simulated profile' '(?is)MVP_TEST.*SIMULATED'),
    (Pattern 'PRODUCTION rejection' '(?is)PRODUCTION.*(reject|rechaz|fail|conflict)'),
    (Pattern 'deterministic double execution' '(?i)(double|doble|twice|segunda ejecucion)'),
    (Pattern 'explicit PASS outcome' '(?i)I9 MVP.*PASS')
)

if ($failures.Count -gt 0) {
    Write-Host 'I9 MVP RULES FAIL'
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host 'I9 MVP RULES PASS'
