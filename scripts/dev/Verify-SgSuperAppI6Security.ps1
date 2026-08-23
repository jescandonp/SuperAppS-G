param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$DatabaseName = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"

$psqlExe = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$originalPassword = $env:PGPASSWORD
$env:PGPASSWORD = $AppPassword
$dedupePrefix = "I6-TASK3-SECURITY"

function Invoke-Postgres {
    param([string]$Sql)
    $output = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -t -A -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
    $lines = @($output | Where-Object { $_ -match '\S' })
    $scalar = @($lines | Where-Object { $_ -match '^\d+$' } | Select-Object -Last 1)
    if ($scalar.Count -gt 0) { return $scalar[0] }
    return @($lines | Select-Object -Last 1)
}

function Get-SessionHeaders {
    param([string]$Username, [string]$Password)
    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($response.sessionToken)" }
}

function Invoke-JsonRequest {
    param([string]$Method, [string]$Uri, [hashtable]$Headers)
    try {
        $response = Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers -UseBasicParsing
        return @{ Status = [int]$response.StatusCode; Body = ($response.Content | ConvertFrom-Json) }
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw }
        return @{ Status = [int]$_.Exception.Response.StatusCode; Body = $null }
    }
}

function Assert-Status {
    param([hashtable]$Response, [int]$ExpectedStatus, [string]$Message)
    if ($Response.Status -ne $ExpectedStatus) {
        throw "$Message Expected HTTP $ExpectedStatus, received $($Response.Status)."
    }
}

function Assert-Equals {
    param([object]$Actual, [object]$Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', received '$Actual'."
    }
}

try {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%'); DELETE FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%';" | Out-Null
    Invoke-Postgres "INSERT INTO notification_items (target_type, target_key, title, body, status, source_module, severity, source_type, source_id, dedupe_key, action_url, read_at, archived_at, managed_at, managed_by) VALUES ('USER', 'admin.sg', 'I6 seguridad fuera usuario', 'No gestionable por TH', 'UNREAD', 'SYSTEM', 'INFO', 'SYSTEM_NOTICE', 'SEC-USER', '$dedupePrefix-USER', null, null, null, null, null), ('ROLE', 'ADMIN', 'I6 seguridad fuera rol', 'No gestionable por TH', 'UNREAD', 'SYSTEM', 'INFO', 'SYSTEM_NOTICE', 'SEC-ROLE', '$dedupePrefix-ROLE', null, null, null, null, null);" | Out-Null

    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"

    foreach ($headers in @($adminHeaders, $thHeaders, $gerenciaHeaders, $operacionesHeaders)) {
        $inbox = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/notifications" -Headers $headers
        Assert-Status -Response $inbox -ExpectedStatus 200 -Message "All I6 operational roles with NOTIFICATIONS/VIEW must read inbox."

        $count = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/notifications/unread-count" -Headers $headers
        Assert-Status -Response $count -ExpectedStatus 200 -Message "All I6 operational roles with NOTIFICATIONS/VIEW must read unread count."
    }

    $restrictedPermissions = Invoke-Postgres "SELECT count(*) FROM roles r JOIN role_permissions rp ON rp.role_id = r.id WHERE r.code IN ('GERENCIA', 'OPERACIONES') AND rp.module_code = 'NOTIFICATIONS' AND rp.action_code IN ('GENERATE_ALERTS', 'CONFIGURE_EMAIL') AND rp.allowed = TRUE;"
    Assert-Equals -Actual ([int]$restrictedPermissions) -Expected 0 -Message "GERENCIA and OPERACIONES must not receive alert-generation or email-configuration permissions."

    $managementPermissions = Invoke-Postgres "SELECT count(*) FROM roles r JOIN role_permissions rp ON rp.role_id = r.id WHERE r.code IN ('ADMIN', 'TH') AND rp.module_code = 'NOTIFICATIONS' AND rp.action_code IN ('GENERATE_ALERTS', 'CONFIGURE_EMAIL') AND rp.allowed = TRUE;"
    Assert-Equals -Actual ([int]$managementPermissions) -Expected 4 -Message "ADMIN and TH must keep alert-generation and email-configuration permissions."

    $outsideUserId = [long](Invoke-Postgres "SELECT id FROM notification_items WHERE dedupe_key = '$dedupePrefix-USER';")
    $outsideRoleId = [long](Invoke-Postgres "SELECT id FROM notification_items WHERE dedupe_key = '$dedupePrefix-ROLE';")

    $outsideUserRead = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/notifications/$outsideUserId/read" -Headers $thHeaders
    Assert-Status -Response $outsideUserRead -ExpectedStatus 404 -Message "TH must not mark another user's notification as read."

    $outsideRoleArchive = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/notifications/$outsideRoleId/archive" -Headers $thHeaders
    Assert-Status -Response $outsideRoleArchive -ExpectedStatus 404 -Message "TH must not archive another role's notification."

    Write-Host "I6 security verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%'); DELETE FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
