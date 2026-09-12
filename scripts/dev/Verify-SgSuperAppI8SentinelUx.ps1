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

function Assert-NotContains {
  param(
    [string] $Path,
    [string] $Pattern,
    [string] $Message
  )

  $content = Get-Content -Path $Path -Raw
  if ($content -match [regex]::Escape($Pattern)) {
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

# Task 3 - Programacion de turnos debe heredar superficie clara Sentinel Enterprise,
# no el degradado oscuro ni el texto casi blanco/dorado sobre fondo claro del tema previo a I8.
Assert-NotContains -Path $stylesPath -Pattern "linear-gradient(120deg, var(--sentinel-blue)" -Message "scheduling-hero todavia usa el degradado oscuro previo a I8."
Assert-Contains -Path $stylesPath -Pattern ".scheduling-control-bar label, .exception-form label { display: grid; gap: 0.35rem; color: var(--primary);" -Message "Etiquetas de programacion de turnos no usan var(--primary)."
Assert-Contains -Path $stylesPath -Pattern ".scheduling-table tbody th { background: #17283a; color: #ffffff; }" -Message "Encabezado de fila de la matriz no fuerza texto blanco sobre fondo oscuro."
Assert-Contains -Path $stylesPath -Pattern ".schedule-secondary, .summary-actions button, .scheduling-tabs button { background: transparent; color: var(--primary); }" -Message "Botones secundarios/pestanas de programacion de turnos conservan texto casi blanco."
Assert-Contains -Path $stylesPath -Pattern "background: var(--surface-alt);
  color: var(--text);
  font-weight: 700;
  padding: 0 0.85rem;
  cursor: pointer;" -Message "Boton de filtros de puestos conserva texto casi blanco sobre fondo claro."
Assert-Contains -Path $stylesPath -Pattern ".position-form-actions .secondary-action {
  border-color: var(--border);
  background: var(--surface-alt);
  color: var(--text);
}" -Message "Boton secundario del formulario de puestos conserva texto casi blanco sobre fondo claro."
Assert-Contains -Path $stylesPath -Pattern ".import-actions .secondary-action {
  border-color: var(--border);
  background: var(--surface-alt);
  color: var(--text);
}" -Message "Boton secundario de cargas de datos conserva texto casi blanco sobre fondo claro."

Write-Host "I8 Sentinel UX verification passed."
