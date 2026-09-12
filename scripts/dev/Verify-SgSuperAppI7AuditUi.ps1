param(
    [string]$WebRoot = "apps/sg-superapp-web"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$pagePath = Join-Path $repoRoot "$WebRoot\src\features\audit\AuditPage.tsx"
$workspacePath = Join-Path $repoRoot "$WebRoot\src\features\shell\ModuleWorkspace.tsx"
$mockPath = Join-Path $repoRoot "$WebRoot\src\mock\session.ts"
$stylesPath = Join-Path $repoRoot "$WebRoot\src\styles.css"

function Assert-FileExists {
    param([string]$Path, [string]$Message)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw $Message
    }
}

function Assert-FileContains {
    param([string]$Path, [string]$Pattern, [string]$Message)
    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch $Pattern) {
        throw $Message
    }
}

Assert-FileExists -Path $pagePath -Message "AuditPage must exist for I7 Task 6."
Assert-FileContains -Path $workspacePath -Pattern "AuditPage" -Message "ModuleWorkspace must route audit module to AuditPage."
Assert-FileContains -Path $mockPath -Pattern 'code: "audit"' -Message "Mock modules must expose audit navigation."
Assert-FileContains -Path $pagePath -Pattern "fetchAuditEvents" -Message "AuditPage must load events from I7 audit API."
Assert-FileContains -Path $pagePath -Pattern "audit-filters" -Message "AuditPage must render audit filters."
Assert-FileContains -Path $pagePath -Pattern "Modulo" -Message "AuditPage must expose module filter."
Assert-FileContains -Path $pagePath -Pattern "Actor" -Message "AuditPage must expose actor filter."
Assert-FileContains -Path $pagePath -Pattern "Desde" -Message "AuditPage must expose from-date filter."
Assert-FileContains -Path $pagePath -Pattern "Hasta" -Message "AuditPage must expose to-date filter."
Assert-FileContains -Path $pagePath -Pattern "audit-table" -Message "AuditPage must render compact audit table."
Assert-FileContains -Path $pagePath -Pattern "audit-detail-panel" -Message "AuditPage must render structured detail."
Assert-FileContains -Path $pagePath -Pattern "audit-loading" -Message "AuditPage must cover loading state."
Assert-FileContains -Path $pagePath -Pattern "audit-error" -Message "AuditPage must cover error state."
Assert-FileContains -Path $pagePath -Pattern "audit-empty" -Message "AuditPage must cover empty state."
Assert-FileContains -Path $pagePath -Pattern "Sin acciones de edicion" -Message "AuditPage must state audit is read-only."
Assert-FileContains -Path $stylesPath -Pattern "\.audit-workspace" -Message "Styles must include audit workspace layout."
Assert-FileContains -Path $stylesPath -Pattern "\.audit-filters" -Message "Styles must include audit filters."
Assert-FileContains -Path $stylesPath -Pattern "\.audit-table" -Message "Styles must include audit table."
Assert-FileContains -Path $stylesPath -Pattern "\.audit-detail-panel" -Message "Styles must include audit detail panel."

Write-Host "I7 audit UI verification completed."
