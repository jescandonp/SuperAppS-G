param(
    [string]$WebRoot = "apps/sg-superapp-web"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$shellPath = Join-Path $repoRoot "$WebRoot\src\features\shell\ShellLayout.tsx"
$hookPath = Join-Path $repoRoot "$WebRoot\src\hooks\usePortalShell.ts"
$stylesPath = Join-Path $repoRoot "$WebRoot\src\styles.css"

function Assert-FileContains {
    param([string]$Path, [string]$Pattern, [string]$Message)
    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -notmatch $Pattern) {
        throw $Message
    }
}

Assert-FileContains -Path $hookPath -Pattern "fetchNotificationsInbox" -Message "Shell hook must load authenticated notification inbox."
Assert-FileContains -Path $hookPath -Pattern "fetchNotificationUnreadCount" -Message "Shell hook must load unread notification count."
Assert-FileContains -Path $hookPath -Pattern "markNotificationAsRead" -Message "Shell hook must expose read action."
Assert-FileContains -Path $hookPath -Pattern "archiveNotification" -Message "Shell hook must expose archive action."

Assert-FileContains -Path $shellPath -Pattern "notification-tray" -Message "Shell UI must render notification tray."
Assert-FileContains -Path $shellPath -Pattern "notification-filters" -Message "Shell UI must render notification filters."
Assert-FileContains -Path $shellPath -Pattern "Marcar leida" -Message "Shell UI must expose mark-as-read action."
Assert-FileContains -Path $shellPath -Pattern "Archivar" -Message "Shell UI must expose archive action."
Assert-FileContains -Path $shellPath -Pattern "Personales y rol" -Message "Shell UI must describe personal and role notifications."
Assert-FileContains -Path $shellPath -Pattern "aria-label=""Notificaciones no leidas""" -Message "Unread count must be accessible next to profile."

Assert-FileContains -Path $stylesPath -Pattern "\.notification-tray" -Message "Styles must include notification tray layout."
Assert-FileContains -Path $stylesPath -Pattern "\.notification-filters" -Message "Styles must include notification filters layout."
Assert-FileContains -Path $stylesPath -Pattern "\.notification-row" -Message "Styles must include stable notification rows."

Write-Host "I6 notification UI verification completed."
