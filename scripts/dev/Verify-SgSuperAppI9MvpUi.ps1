[CmdletBinding()]
param([string]$RepositoryRoot)

# Checks the rule panel against the rule the user set for this interface: it suggests, it does not
# decide. The assertions that matter are structural - that the simulated badge is not conditional,
# that every outcome carries words and a remedy rather than a colour, and that no button is
# switched off by a client-side guess about whether the server would allow the transition.

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

$panel = Text 'apps/sg-superapp-web/src/features/scheduling/RuleEvaluationPanel.tsx'
$page = Text 'apps/sg-superapp-web/src/features/scheduling/SchedulingPage.tsx'
$exceptions = Text 'apps/sg-superapp-web/src/features/scheduling/ExceptionPanel.tsx'
$styles = Text 'apps/sg-superapp-web/src/styles.css'

Q ($panel.Length -gt 0 -and $page.Length -gt 0) 'UI-T01 the rule panel and the scheduling page exist'

# --- the simulated mark survives every state ----------------------------------------------------
# Not a conditional: a reader must never be looking at this screen without knowing the data behind
# it is a simulated MVP scenario, least of all while it is loading or after it failed.
Q ($panel -match 'DATOS SIMULADOS - MVP') 'UI-T02 the panel carries the simulated label'
$badgeLine = ([regex]::Match($panel, '(?m)^.*DATOS SIMULADOS - MVP.*$')).Value
Q ($badgeLine -notmatch '\?' -and $badgeLine -notmatch '&&') 'UI-T02 the simulated label is not rendered conditionally'
Q ($panel -match 'const simulatedBadge') 'UI-T02 the label is defined once and reused across states'
Q ($styles -match '\.schedule-badge\.is-simulated') 'UI-T02 the simulated badge is styled distinctly'

# The marker is on the page itself, not only inside the panel: a reader on the Matriz tab is looking
# at the same simulated data. It states what is known rather than assuming - the origin is called
# simulated only once a profile has said so.
Q ($page -match 'DATOS SIMULADOS - MVP') 'UI-T02 the page states the simulated origin outside the panel'
Q ($page -match 'ORIGEN DE REGLAS SIN CONFIRMAR') 'UI-T02 an unconfirmed origin is not presented as simulated'
Q ($page -match 'const simulatedOrigin = demoMode \|\| \(ruleProfile\.status === "READY" && ruleProfile\.profile\.simulated\)') 'UI-T02 the origin comes from the profile the server returned'

# --- each outcome says what it is and what to do about it ---------------------------------------
foreach ($outcome in @('BLOCKED', 'EXCEPTION_REQUIRED', 'WARNING', 'COMPLIANT', 'NOT_APPLICABLE')) {
    Q ($panel -match "$outcome`:\s*\{") "UI-T03 the panel handles the $outcome outcome"
}
# The body only: the Record<...> type annotation declares label/tone/action too, and counting
# those would report one entry more than the table actually has.
$copyBlock = ([regex]::Match($panel, '(?s)const OUTCOME_COPY[^=]*= \{(.*?)\n\};')).Groups[1].Value
Q (([regex]::Matches($copyBlock, 'action:')).Count -eq 5) 'UI-T03 every outcome states a remedy, not only a colour'
Q (([regex]::Matches($copyBlock, 'label:')).Count -eq 5) 'UI-T03 every outcome is named in words'
Q ($panel -match 'Corrija la programación y vuelva a evaluar') 'UI-T03 a blocked rule tells the operator the schedule must change'
Q ($panel -match 'no acredita cumplimiento') 'UI-T03 an unverified rule is not presented as compliance'
Q ($panel -match 'Ir a excepciones') 'UI-T03 a pending decision offers the action that resolves it'

# --- an unconfigured scope is not a clean schedule -----------------------------------------------
Q ($panel -match 'UNCONFIGURED') 'UI-T04 the panel distinguishes an unconfigured scope'
Q ($panel -match 'No hay reglas que respalden una decisión') 'UI-T04 an unconfigured scope says nothing backs a decision'
Q ($panel -match 'Sin evaluación no se presume cumplimiento') 'UI-T04 an empty evaluation list is not read as compliance'

# --- nothing on this screen decides whether the transition may proceed ---------------------------
# The interface suggests. It may render what the server already decided; it must never compute the
# decision, nor switch a button off because it believes the server would refuse.
Q ($page -notmatch 'canApproveOrPublish') 'UI-T05 the page never reads or recomputes the approval decision'
Q ($panel -notmatch 'canApproveOrPublish\s*(=|\?)') 'UI-T05 the panel never assigns its own approval decision'
Q ($page -match 'function actionState') 'UI-T05 the disabled state is derived from permission, version state and work in flight'
$actionBlock = ([regex]::Match($page, '(?s)function actionState.*?\n\}')).Value
Q ($actionBlock -notmatch 'BLOCKED|EXCEPTION_REQUIRED|WARNING|evaluations') 'UI-T05 no rule outcome takes part in disabling a button'
Q ($page -match 'setGateProblem\(toProblem\(caught\)\)') 'UI-T05 a refusal is taken from the server, not predicted'
Q (([regex]::Matches($page, 'setGateProblem\(toProblem\(caught\)\)')).Count -eq 2) 'UI-T05 both approve and publish surrender the decision to the server'

# --- a disabled button always explains itself ---------------------------------------------------
Q ($page -match 'aria-describedby="approve-reason"') 'UI-T06 the approve button is described by its reason'
Q ($page -match 'aria-describedby="publish-reason"') 'UI-T06 the publish button is described by its reason'
Q ($page -match 'id="approve-reason"' -and $page -match 'id="publish-reason"') 'UI-T06 both reasons are rendered'
Q ($page -match 'No tiene permiso para esta acción') 'UI-T06 a missing permission is stated'
Q ($page -match 'Solo una versión en estado') 'UI-T06 a wrong version state is stated'
Q ($page -match 'Hay una operación en curso') 'UI-T06 work in flight is stated'

# --- the refusal the server gave is what the screen shows ---------------------------------------
Q ($panel -match 'gateProblem') 'UI-T07 the panel renders the refusal the server returned'
Q ($panel -match 'gateProblem\.code') 'UI-T07 the machine-readable state is shown alongside the message'
Q ($page -match 'setTab\("Reglas"\)') 'UI-T07 a refusal takes the reader to the rules'

# --- the decision on screen names the rule and the snapshot it binds to --------------------------
Q ($exceptions -match 'item\.ruleCode') 'UI-T08 a decision shows the rule it binds to'
Q ($exceptions -match 'item\.scopeHash') 'UI-T08 a decision shows the snapshot it binds to'
Q ($exceptions -match 'no ampara ninguna evaluación') 'UI-T08 a decision with no rule or scope is shown as covering nothing'

# --- the panel is announced to assistive technology ----------------------------------------------
Q (([regex]::Matches($panel, 'aria-live=|role="status"')).Count -ge 3) 'UI-T09 the panel announces its state changes'
Q ($panel -match 'role="alert"') 'UI-T09 failures are announced as alerts'
Q ($styles -match '\.rule-link:focus-visible') 'UI-T09 the panel action is reachable and visible by keyboard'

# --- the page compiles ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $node -PathType Leaf) -or -not (Test-Path -LiteralPath $tsc -PathType Leaf)) {
    $failures.Add('UI-T10 BLOCKED: the web toolchain is not installed; run npm install in apps/sg-superapp-web')
} else {
    Push-Location $web
    $build = & $node $tsc -p tsconfig.app.json --noEmit 2>&1
    $buildExit = $LASTEXITCODE
    Pop-Location
    Q ($buildExit -eq 0) "UI-T10 the scheduling UI type-checks ($($build -join ' '))"
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output "I9 MVP UI FAIL: $_" }
    exit 1
}

if ($passed -ne 43) {
    Write-Output "I9 MVP UI FAIL: expected 43 assertions, ran $passed"
    exit 1
}

Write-Output "I9 MVP UI PASS $passed"
exit 0
