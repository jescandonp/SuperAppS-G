$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$failures = New-Object System.Collections.Generic.List[string]

function Require-File([string]$relativePath) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("Missing file: $relativePath")
        return ""
    }
    return Get-Content -LiteralPath $path -Raw
}

function Require-Pattern([string]$text, [string]$pattern, [string]$label) {
    if ($text -notmatch $pattern) {
        $failures.Add("Missing contract: $label")
    }
}

$page = Require-File "apps/sg-superapp-web/src/features/scheduling/SchedulingPage.tsx"
$templates = Require-File "apps/sg-superapp-web/src/features/scheduling/ShiftTemplatesPanel.tsx"
$matrix = Require-File "apps/sg-superapp-web/src/features/scheduling/ScheduleMatrix.tsx"
$comparison = Require-File "apps/sg-superapp-web/src/features/scheduling/ProposalComparison.tsx"
$exceptions = Require-File "apps/sg-superapp-web/src/features/scheduling/ExceptionPanel.tsx"
$workspace = Require-File "apps/sg-superapp-web/src/features/shell/ModuleWorkspace.tsx"
$styles = Require-File "apps/sg-superapp-web/src/styles.css"

Require-Pattern $workspace 'moduleCode\s*===\s*"scheduling"' "scheduling route"
Require-Pattern $page 'Cargando programaci' "loading state"
Require-Pattern $page 'No fue posible|error' "error state"
Require-Pattern $page 'Seleccione un proyecto' "empty state"
foreach ($tab in @("Plantillas", "Matriz", "Comparar", "Excepciones")) {
    Require-Pattern $page $tab "tab $tab"
}
Require-Pattern $page 'aria-live' "live status region"
Require-Pattern $page 'capabilities\.generate' "generate capability"
Require-Pattern $page 'capabilities\.approve' "approve capability"
Require-Pattern $page 'capabilities\.publish' "publish capability"
Require-Pattern $page 'capabilities\.export' "export capability"
Require-Pattern $page 'PUBLICADA' "published read-only state"
Require-Pattern ($templates + $page) '2x2' "2x2 template"
Require-Pattern ($templates + $page) '4x2' "4x2 template"
Require-Pattern ($templates + $page) '6x1' "6x1 template"
Require-Pattern $templates 'Obligatoria por defecto' "mandatory template label"
Require-Pattern $matrix '<table' "semantic schedule table"
Require-Pattern $matrix '<caption' "schedule table caption"
Require-Pattern $matrix 'aria-label' "accessible schedule cells"
foreach ($code in @('D', 'N', 'X', 'VACANTE')) {
    Require-Pattern $matrix ('[">]' + $code + '[<"]') "matrix code $code"
}
Require-Pattern $comparison 'MINIMUM_IMPACT' "minimum-impact comparison"
Require-Pattern $comparison 'GLOBAL' "global comparison"
Require-Pattern $exceptions 'reason\.trim\(\)' "required deviation reason"
Require-Pattern $exceptions 'capabilities\.approveException|canApproveException' "exception capability"
Require-Pattern $styles '#003366' "Sentinel blue token"
Require-Pattern $styles '#FFC700' "Sentinel yellow token"
Require-Pattern $styles '@media\s*\(max-width:\s*899px\)' "mobile breakpoint"
Require-Pattern $styles 'position:\s*sticky' "sticky matrix header"
Require-Pattern $styles '\.scheduling-mobile-list' "mobile daily list"

if ($failures.Count -gt 0) {
    Write-Output "I9 UI FAIL"
    $failures | ForEach-Object { Write-Output " - $_" }
    exit 1
}

Write-Output "I9 UI PASS"
exit 0
