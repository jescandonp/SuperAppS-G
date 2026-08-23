$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$stylesPath = Join-Path $root "apps/sg-superapp-web/src/styles.css"
$shellPath = Join-Path $root "apps/sg-superapp-web/src/features/shell/ShellLayout.tsx"
$designPath = Join-Path $root "docs/DESIGN.md"
$specPath = Join-Path $root "docs/specs/2026-06-16-sg-superapp-spec-i8-uxui-sentinel-enterprise.md"
$planPath = Join-Path $root "docs/plans/2026-06-16-sg-superapp-i8-uxui-sentinel-enterprise-plan.md"

function Assert-Contains {
  param(
    [string] $Path,
    [string] $Pattern,
    [string] $Message
  )

  $content = Get-Content -Path $Path -Raw
  if ($content -notmatch [regex]::Escape($Pattern)) {
    throw $Message
  }
}

Assert-Contains -Path $designPath -Pattern "Variante Enterprise Sentinel" -Message "docs/DESIGN.md no registra la variante Sentinel."
Assert-Contains -Path $specPath -Pattern "SPEC I8 - UX/UI Sentinel Enterprise" -Message "SPEC I8 no existe o no tiene titulo esperado."
Assert-Contains -Path $planPath -Pattern "Task 1 - Base visual Sentinel" -Message "Plan I8 no registra Task 1."
Assert-Contains -Path $stylesPath -Pattern "--primary: #003366;" -Message "styles.css no expone token primary Sentinel."
Assert-Contains -Path $stylesPath -Pattern "--accent: #ffc700;" -Message "styles.css no expone token accent Sentinel."
Assert-Contains -Path $stylesPath -Pattern "color-scheme: light;" -Message "styles.css no activa color-scheme light."
Assert-Contains -Path $stylesPath -Pattern ".sentinel-console" -Message "styles.css no define sentinel-console."
Assert-Contains -Path $stylesPath -Pattern ".shell-body" -Message "styles.css no define el grid central shell-body."
Assert-Contains -Path $stylesPath -Pattern "grid-template-columns: minmax(0, 1fr) 340px;" -Message "styles.css no define panel lateral de notificaciones."
Assert-Contains -Path $stylesPath -Pattern ".topbar-search" -Message "styles.css no define busqueda de topbar."
Assert-Contains -Path $stylesPath -Pattern ".dashboard-widget" -Message "styles.css no conserva dashboard-widget."
Assert-Contains -Path $stylesPath -Pattern ".audit-table-header" -Message "styles.css no conserva audit-table-header."
Assert-Contains -Path $shellPath -Pattern 'className="shell sentinel-console"' -Message "ShellLayout no adopta clase sentinel-console."
Assert-Contains -Path $shellPath -Pattern 'className="shell-body"' -Message "ShellLayout no separa contenido y notificaciones en shell-body."
Assert-Contains -Path $shellPath -Pattern 'className="topbar-search"' -Message "ShellLayout no incluye busqueda compacta en topbar."
Assert-Contains -Path $shellPath -Pattern "Consola enterprise" -Message "ShellLayout no actualiza copy de consola enterprise."

Write-Host "I8 Sentinel UX verification passed."
