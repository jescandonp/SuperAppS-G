param(
    [string]$WebRoot = "apps/sg-superapp-web"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$pagePath = Join-Path $repoRoot "$WebRoot\src\features\alerts\AlertsPage.tsx"
$workspacePath = Join-Path $repoRoot "$WebRoot\src\features\shell\ModuleWorkspace.tsx"
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

Assert-FileExists -Path $pagePath -Message "AlertsPage must exist for I6 Task 9."
Assert-FileContains -Path $workspacePath -Pattern "AlertsPage" -Message "ModuleWorkspace must route alerts module to AlertsPage."
Assert-FileContains -Path $pagePath -Pattern "generateTrainingAlerts" -Message "AlertsPage must trigger I5 training alert generation."
Assert-FileContains -Path $pagePath -Pattern "generateImportAlerts" -Message "AlertsPage must trigger I2 import alert generation."
Assert-FileContains -Path $pagePath -Pattern "generateCertificateAlerts" -Message "AlertsPage must trigger I4 certificate alert generation."
Assert-FileContains -Path $pagePath -Pattern "exportNotificationSummary" -Message "AlertsPage must expose summary export fallback."
Assert-FileContains -Path $pagePath -Pattern "sendNotificationEmailSummary" -Message "AlertsPage must expose email fallback status."
Assert-FileContains -Path $pagePath -Pattern "canManageAlerts" -Message "AlertsPage must gate generation/configuration to ADMIN/TH."
Assert-FileContains -Path $pagePath -Pattern "GERENCIA/OPERACIONES" -Message "AlertsPage must show consulta-only state for Gerencia/Operaciones."
Assert-FileContains -Path $pagePath -Pattern "fallbackAvailable" -Message "AlertsPage must display fallback availability."
Assert-FileContains -Path $stylesPath -Pattern "\.alerts-workspace" -Message "Styles must include alerts workspace layout."
Assert-FileContains -Path $stylesPath -Pattern "\.alert-action-grid" -Message "Styles must include alert action grid."

Write-Host "I6 alerts fallback UI verification completed."
