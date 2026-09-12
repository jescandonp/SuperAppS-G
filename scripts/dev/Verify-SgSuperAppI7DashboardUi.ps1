param(
    [string]$WebRoot = "apps/sg-superapp-web"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$pagePath = Join-Path $repoRoot "$WebRoot\src\features\dashboard\DashboardPage.tsx"
$appPath = Join-Path $repoRoot "$WebRoot\src\App.tsx"
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

Assert-FileExists -Path $pagePath -Message "DashboardPage must exist for I7 Task 5."
Assert-FileContains -Path $appPath -Pattern "DashboardPage" -Message "App route must render DashboardPage at /dashboard."
Assert-FileContains -Path $pagePath -Pattern "fetchDashboard" -Message "DashboardPage must load widgets from the I7 dashboard API."
Assert-FileContains -Path $pagePath -Pattern "currentUser" -Message "DashboardPage must render the current role/user context."
Assert-FileContains -Path $pagePath -Pattern "dashboard-loading" -Message "DashboardPage must cover loading state."
Assert-FileContains -Path $pagePath -Pattern "dashboard-error" -Message "DashboardPage must cover error state."
Assert-FileContains -Path $pagePath -Pattern "dashboard-empty" -Message "DashboardPage must cover empty widget state."
Assert-FileContains -Path $pagePath -Pattern "dashboard-widget-grid" -Message "DashboardPage must render dashboard widgets."
Assert-FileContains -Path $pagePath -Pattern "scope EXECUTIVE" -Message "DashboardPage must classify executive widgets."
Assert-FileContains -Path $pagePath -Pattern "scope TH" -Message "DashboardPage must classify TH widgets."
Assert-FileContains -Path $pagePath -Pattern "scope OPERATIONS" -Message "DashboardPage must classify operations widgets."
Assert-FileContains -Path $pagePath -Pattern "scope ADMIN" -Message "DashboardPage must classify admin widgets."
Assert-FileContains -Path $stylesPath -Pattern "\.dashboard-workspace" -Message "Styles must include dashboard workspace layout."
Assert-FileContains -Path $stylesPath -Pattern "\.dashboard-widget-grid" -Message "Styles must include dashboard widget grid."
Assert-FileContains -Path $stylesPath -Pattern "\.dashboard-widget" -Message "Styles must include stable dashboard widgets."

Write-Host "I7 dashboard UI verification completed."
