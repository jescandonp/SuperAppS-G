[CmdletBinding()]
param([string]$RepositoryRoot)

# Checks the typed frontier between the API and the web client. Two things are asserted that a
# pattern match cannot: that the rule-gate vocabulary the client declares is exactly the one the API
# emits, and that the unions are narrow enough to reject a state that does not exist - proved by
# compiling a probe that must fail. A type gate nothing can fail is not a gate.

$ErrorActionPreference = 'Stop'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
} else { (Resolve-Path $RepositoryRoot).Path }

$web = Join-Path $repoRoot 'apps/sg-superapp-web'
$node = 'C:\Program Files\nodejs\node.exe'
$tsc = Join-Path $web 'node_modules/typescript/bin/tsc'
$passed = 0
$failures = New-Object System.Collections.Generic.List[string]

function Q([bool]$value, [string]$label) {
    if ($value) { $script:passed++; Write-Output ($label + ' PASS') } else { $script:failures.Add($label) }
}

function Text([string]$relativePath) {
    $path = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    return Get-Content -LiteralPath $path -Raw
}

$types = Text 'apps/sg-superapp-web/src/types/portal.ts'
$api = Text 'apps/sg-superapp-web/src/services/portalApi.ts'
$hook = Text 'apps/sg-superapp-web/src/hooks/usePortalShell.ts'
# The scheduling page holds the live rule state. The shell used to carry a copy that nothing
# consumed, and three assertions below were aimed at it - satisfied by code that never ran
# while the path that does run went unchecked.
$page = Text 'apps/sg-superapp-web/src/features/scheduling/SchedulingPage.tsx'
$endpoints = Text 'apps/sg-superapp-api/Endpoints/PortalEndpoints.cs'
$endpointsRules = Text 'apps/sg-superapp-api/Endpoints/SchedulingRuleEndpoints.cs'

Q ($types.Length -gt 0 -and $api.Length -gt 0 -and $hook.Length -gt 0) 'FE-T01 the three client files exist'

# --- the vocabulary must not drift from the API -------------------------------------------------
# The API declares the codes it can emit in RuleGateCodes; the client declares the ones it can
# render. A code on one side only is a state the UI will meet and not understand, or a state it
# claims to handle that never arrives.
$apiCodes = [regex]::Matches($endpoints, 'RULE_[A-Z_]+') | ForEach-Object { $_.Value } | Sort-Object -Unique
$clientCodes = [regex]::Matches($types, '"(RULE_[A-Z_]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
Q ($apiCodes.Count -ge 6) 'FE-T02 the API declares its rule gate vocabulary'
Q (($apiCodes -join ',') -eq ($clientCodes -join ',')) "FE-T02 the client vocabulary matches the API exactly (api=$($apiCodes -join '|') client=$($clientCodes -join '|'))"
# The type union is erased at runtime. What decides whether a code survives readProblem is the
# RULE_GATE_CODES array, and emptying that array kept this verifier green while every gate refusal
# silently normalised to code: null - the exact discard Task 24 existed to stop.
$runtimeCodes = ''
$runtimeMatch = [regex]::Match($api, '(?s)RULE_GATE_CODES: readonly SchedulingRuleGateCode\[\] = \[(.*?)\];')
if ($runtimeMatch.Success) {
    # Line comments are stripped first: a commented-out entry is still text, and matching it would
    # let someone disable a code while this assertion kept reporting the full vocabulary.
    $liveArray = ($runtimeMatch.Groups[1].Value -split "`n" |
        Where-Object { $_.Trim() -notmatch '^//' }) -join "`n"
    $runtimeCodes = ([regex]::Matches($liveArray, '"(RULE_[A-Z_]+)"') |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ','
}
Q ($runtimeMatch.Success -and $runtimeCodes -eq ($apiCodes -join ',')) "FE-T02 the runtime allowlist matches the API exactly (runtime=$runtimeCodes)"

# --- the outcomes the evaluator can produce -----------------------------------------------------
foreach ($outcome in @('COMPLIANT', 'BLOCKED', 'EXCEPTION_REQUIRED', 'WARNING', 'NOT_APPLICABLE')) {
    Q ($types -match "`"$outcome`"") "FE-T03 the client declares the $outcome outcome"
}

# --- nothing is inferred on the client ----------------------------------------------------------
# canApproveOrPublish is the server's decision. The client may read it; it must never compute it.
Q ($types -match '(?m)canApproveOrPublish:\s*boolean;') 'FE-T04 the summary carries the server decision'
Q ($api -notmatch 'canApproveOrPublish\s*=' -and $hook -notmatch 'canApproveOrPublish\s*=' -and $page -notmatch 'canApproveOrPublish') 'FE-T04 the client never assigns or reads its own approval decision'
Q ($hook -notmatch 'role\s*===\s*"(ADMIN|OPERACIONES|TH)"') 'FE-T04 the shell never infers a permission from a role'

# --- errors, loading and incomplete configuration are typed -------------------------------------
Q ($api -match 'export class PortalApiError extends Error') 'FE-T05 the client raises a typed API error'
Q ($api -match '(?s)class PortalApiError.*?readonly code: SchedulingRuleGateCode \| null;') 'FE-T05 the typed error carries the rule gate code'
Q ($api -match 'isRuleGateCode\(data\.code\)') 'FE-T05 an unknown code is not passed through as understood'
# Declaring the class is not the same as raising it: a mutation that reverted the throw sites while
# leaving the declaration in place passed an earlier version of this check. Both request helpers
# must actually raise it, and neither may fall back to an untyped error.
$typedThrows = ([regex]::Matches($api, 'throw new PortalApiError\(await readProblem\(response\)\);')).Count
Q ($typedThrows -eq 2) "FE-T05 both request helpers raise the typed error (found $typedThrows)"
# Scoped to the two JSON request helpers. Login, the import actions and the file downloads have
# their own error paths and their own verifiers; rewriting them is not this task's business.
$helpers = ''
$helperMatch = [regex]::Match($api, '(?s)async function getJson<T>.*?async function downloadSchedulingExport')
if ($helperMatch.Success) { $helpers = $helperMatch.Value }
Q ($helperMatch.Success -and $helpers -notmatch 'throw new Error\(') 'FE-T05 neither JSON request helper falls back to an untyped error'
foreach ($state in @('LOADING', 'READY', 'UNCONFIGURED', 'FAILED')) {
    Q ($types -match "status: `"$state`"") "FE-T06 $state is a declared state, not an absent value"
}
Q ($page -match 'status: "UNCONFIGURED"') 'FE-T06 the page distinguishes an unconfigured scope from a clean one'
Q ($page -match 'filter\(\(item\) => item\.status === "ACTIVE"\)') 'FE-T06 only an ACTIVE profile is read as governing'
Q ($page -match 'active\.length === 1') 'FE-T06 exactly one active profile is required before one is used'

# --- the simulated mark travels with the data it qualifies ---------------------------------------
# It is what separates an MVP_TEST scenario from a real one. If the client drops it, the UI cannot
# label the screen and a simulated schedule becomes indistinguishable from an institutional one.
Q ($types -match '(?s)interface SchedulingRuleProfile \{.*?simulated: boolean;.*?\}') 'FE-T12 the rule profile carries the simulated mark'
Q ($types -match '(?s)interface PersistedSchedulingRuleBatch \{.*?simulated: boolean;.*?\}') 'FE-T12 the re-evaluation batch carries the simulated mark'
Q ($page -match 'ruleProfile') 'FE-T12 the page holds the rule profile it loaded'

# --- each route is modelled with the shape it really returns -------------------------------------
# Typing a list route as a single object is how UNCONFIGURED became unreachable, and typing a bare
# verdict list as a batch is how reading a summary threw. getJson casts blindly, so tsc cannot see
# either mistake; these assertions are the only thing that can.
Q ($endpointsRules -match '(?s)MapGet\("/api/portal/scheduling/rule-profiles",.*?Results\.Ok\(profiles\.Select') 'FE-T13 the profiles route returns a list'
Q ($api -match 'fetchSchedulingRuleProfiles[\s\S]{0,400}?Promise<SchedulingRuleProfile\[\]>') 'FE-T13 the client models the profiles route as a list'
Q ($api -notmatch 'error\.status === 404') 'FE-T13 the client does not treat a missing profile as a 404 the route never sends'
Q ($endpointsRules -match '(?s)MapGet\("/api/portal/scheduling/rules/evaluations",.*?Results\.Ok\(\(await httpRepository\.LoadEvaluationsAsync') 'FE-T13 the evaluations route returns a list'
Q ($api -match 'fetchSchedulingRuleEvaluations[\s\S]{0,400}?Promise<SchedulingRuleEvaluation\[\]>') 'FE-T13 the client models the evaluations route as a list with no summary'
Q ($api -match 'evaluateSchedulingRules[\s\S]{0,600}?Promise<PersistedSchedulingRuleBatch>') 'FE-T13 only the re-evaluation is modelled as a batch'
Q ($types -match '(?s)interface PersistedSchedulingRuleBatch \{.*?summary: SchedulingRuleSummary;.*?\}') 'FE-T13 the summary lives only on the re-evaluation batch'
Q ($types -notmatch 'READY"; batch: SchedulingRuleEvaluationBatch') 'FE-T13 the persisted verdicts are not presented as a batch'

# --- the client reaches the versioned rule endpoints --------------------------------------------
Q ($api -match 'rule-profiles') 'FE-T07 the client reads rule-profiles'
Q ($api -match 'rules/evaluate') 'FE-T07 the client can request a re-evaluation'
Q ($api -match 'rules/evaluations') 'FE-T07 the client reads persisted evaluations'
Q ($page -match 'reloadProfileFor') 'FE-T07 the page reloads the profile when the scope changes'

# --- existing I9 routes still compile against the same client -----------------------------------
foreach ($name in @('fetchSchedulingCapabilities', 'generateScheduleProposal', 'updateScheduleAssignment',
                    'approveScheduleException', 'approveSchedule', 'publishSchedule')) {
    Q ($api -match "(?m)^export async function $name\b") "FE-T08 the existing route $name is preserved"
}

# --- the types must actually reject a state that does not exist ---------------------------------
if (-not (Test-Path -LiteralPath $node -PathType Leaf) -or -not (Test-Path -LiteralPath $tsc -PathType Leaf)) {
    $failures.Add('FE-T09 BLOCKED: the web toolchain is not installed; run npm install in apps/sg-superapp-web')
} else {
    $probeDir = Join-Path $web 'src/__i9probe__'
    try {
        New-Item -ItemType Directory -Path $probeDir -Force | Out-Null

        # Compiles: the contracts used as intended, including an exhaustive switch that returns
        # never for an unhandled code.
        @'
import type { SchedulingRuleGateCode, PersistedSchedulingRuleBatch, SchedulingRuleProfileState } from "../types/portal";

export function describe(code: SchedulingRuleGateCode): string {
  switch (code) {
    case "RULE_BLOCKED": return "bloqueada";
    case "RULE_UNVERIFIED": return "sin verificar";
    case "RULE_EXCEPTION_REQUIRED": return "excepcion pendiente";
    case "RULE_EVALUATION_MISSING": return "sin evaluar";
    case "RULE_EVALUATION_SUPERSEDED": return "obsoleta";
    case "RULE_ASSIGNMENT_UNEVALUATED": return "asignacion sin evaluar";
    default: {
      const unhandled: never = code;
      return unhandled;
    }
  }
}

export function canApprove(batch: PersistedSchedulingRuleBatch): boolean {
  return batch.summary.canApproveOrPublish;
}

export function label(state: SchedulingRuleProfileState): string {
  return state.status === "READY" ? state.profile.profileCode : state.status;
}
'@ | Set-Content -LiteralPath (Join-Path $probeDir 'positive.ts') -Encoding UTF8

        Push-Location $web
        $positive = & $node $tsc -p tsconfig.app.json --noEmit 2>&1
        $positiveExit = $LASTEXITCODE
        Pop-Location
        Q ($positiveExit -eq 0) "FE-T09 the contracts compile as intended ($($positive -join ' '))"

        # Must NOT compile. One file per case, because tsc reports the widened type for several of
        # these and a message-text assertion could not tell them apart - an earlier version matched
        # any line naming the probe file and passed while the approval decision accepted a string.
        # A filename is unambiguous: each of the three must appear in the errors on its own.
        @'
import type { SchedulingRuleGateCode } from "../types/portal";
export const invented: SchedulingRuleGateCode = "RULE_DEFINITELY_NOT_A_STATE";
'@ | Set-Content -LiteralPath (Join-Path $probeDir 'reject-gate-code.ts') -Encoding UTF8
        @'
import type { SchedulingRuleOutcome } from "../types/portal";
export const bogus: SchedulingRuleOutcome = "PROBABLY_FINE";
'@ | Set-Content -LiteralPath (Join-Path $probeDir 'reject-outcome.ts') -Encoding UTF8
        @'
import type { SchedulingRuleSummary } from "../types/portal";
export const wrong: SchedulingRuleSummary["canApproveOrPublish"] = "quizas";
'@ | Set-Content -LiteralPath (Join-Path $probeDir 'reject-approval-as-text.ts') -Encoding UTF8

        Push-Location $web
        $negative = & $node $tsc -p tsconfig.app.json --noEmit 2>&1
        $negativeExit = $LASTEXITCODE
        Pop-Location
        $negativeText = $negative -join "`n"
        Q ($negativeExit -ne 0) 'FE-T10 the types reject a state that does not exist'
        Q ($negativeText -match 'reject-gate-code\.ts') 'FE-T10 an invented gate code is rejected'
        Q ($negativeText -match 'reject-outcome\.ts') 'FE-T10 an invented outcome is rejected'
        Q ($negativeText -match 'reject-approval-as-text\.ts') 'FE-T10 the approval decision cannot be restated as a string'
    }
    finally {
        if (Test-Path -LiteralPath $probeDir) { Remove-Item -LiteralPath $probeDir -Recurse -Force }
        # tsc in build mode would rewrite the tracked tsconfig.app.tsbuildinfo; -p with --noEmit does
        # not, but the guard stays so a future change cannot dirty the working tree unnoticed.
        Push-Location $repoRoot
        $dirty = & git status --porcelain -- 'apps/sg-superapp-web/tsconfig.app.tsbuildinfo' 2>&1; $gitExit = $LASTEXITCODE
        Pop-Location
        if ($gitExit -ne 0 -or -not [string]::IsNullOrWhiteSpace(($dirty -join ''))) {
            $failures.Add('FE-T11 the type check modified a tracked build artifact')
        } else {
            $passed++
            Write-Output 'FE-T11 the type check leaves the working tree clean PASS'
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output "I9 MVP FRONTEND API FAIL: $_" }
    exit 1
}

if ($passed -ne 51) {
    Write-Output "I9 MVP FRONTEND API FAIL: expected 51 assertions, ran $passed"
    exit 1
}

Write-Output "I9 MVP FRONTEND API PASS $passed"
exit 0
