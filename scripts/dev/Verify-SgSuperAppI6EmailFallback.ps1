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
$dedupePrefix = "I6_TASK6_EMAIL"

function Invoke-Postgres {
    param([string]$Sql)
    $output = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -q -t -A -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
    return @($output | Where-Object { $_ -match '\S' })
}

function Get-SessionHeaders {
    param([string]$Username, [string]$Password)
    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($response.sessionToken)" }
}

function Invoke-JsonRequest {
    param([string]$Method, [string]$Uri, [hashtable]$Headers, [object]$Body = $null)
    try {
        $json = if ($null -eq $Body) { $null } else { $Body | ConvertTo-Json -Depth 8 }
        $response = Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers -ContentType "application/json" -Body $json -UseBasicParsing
        $parsed = if ([string]::IsNullOrWhiteSpace($response.Content)) { $null } else { $response.Content | ConvertFrom-Json }
        return @{ Status = [int]$response.StatusCode; Body = $parsed }
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

    $notificationId = [long](Invoke-Postgres "INSERT INTO notification_items (target_type, target_key, title, body, status, source_module, severity, source_type, source_id, action_url, dedupe_key) VALUES ('ROLE', 'TH', 'I6 Task6 Email Fallback', 'Resumen para intento de correo sin SMTP', 'UNREAD', 'TRAINING', 'WARNING', 'TRAINING_EXPIRY', 'TASK6-EMAIL', '/portal/courses', '$dedupePrefix-WARNING') RETURNING id;" | Select-Object -Last 1)

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $response = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/notifications-summary/email" -Headers $thHeaders -Body @{
        status = "UNREAD"
        severity = "WARNING"
        sourceModule = "TRAINING"
        recipient = "talento.humano@example.invalid"
    }
    Assert-Status -Response $response -ExpectedStatus 200 -Message "Email summary endpoint must respond with controlled fallback when SMTP is unavailable."
    Assert-Equals -Actual $response.Body.emailAttempted -Expected $true -Message "Email summary must report that an email attempt was registered."
    Assert-Equals -Actual $response.Body.smtpAvailable -Expected $false -Message "Default local environment must report SMTP unavailable."
    Assert-Equals -Actual $response.Body.fallbackAvailable -Expected $true -Message "Email summary must keep export fallback available."
    Assert-Equals -Actual $response.Body.matchedNotifications -Expected 1 -Message "Email summary must apply filters to visible notifications."

    $attemptedCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_events WHERE notification_id = $notificationId AND actor_username = 'th.sg' AND event_type = 'EMAIL_ATTEMPTED';" | Select-Object -Last 1)
    Assert-Equals -Actual $attemptedCount -Expected 1 -Message "Email summary must register EMAIL_ATTEMPTED event."

    $failedCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_events WHERE notification_id = $notificationId AND actor_username = 'th.sg' AND event_type = 'EMAIL_FAILED';" | Select-Object -Last 1)
    Assert-Equals -Actual $failedCount -Expected 1 -Message "Unavailable SMTP must register EMAIL_FAILED without blocking response."

    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $deniedResponse = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/notifications-summary/email" -Headers $gerenciaHeaders -Body @{
        status = "UNREAD"
        severity = "WARNING"
        sourceModule = "TRAINING"
        recipient = "gerencia@example.invalid"
    }
    Assert-Status -Response $deniedResponse -ExpectedStatus 403 -Message "Gerencia must not be allowed to configure or attempt notification email."

    Write-Host "I6 email fallback verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%'); DELETE FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
