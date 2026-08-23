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
$dedupePrefix = "I6_TASK6_EXPORT"

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

function Invoke-WebRequestSafe {
    param([string]$Method, [string]$Uri, [hashtable]$Headers)
    try {
        $response = Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers -UseBasicParsing
        return @{ Status = [int]$response.StatusCode; Content = $response.Content; Headers = $response.Headers }
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw }
        return @{ Status = [int]$_.Exception.Response.StatusCode; Content = $null; Headers = @{} }
    }
}

function Assert-Status {
    param([hashtable]$Response, [int]$ExpectedStatus, [string]$Message)
    if ($Response.Status -ne $ExpectedStatus) {
        throw "$Message Expected HTTP $ExpectedStatus, received $($Response.Status)."
    }
}

function Assert-Contains {
    param([string]$Text, [string]$Expected, [string]$Message)
    if ($Text -notlike "*$Expected*") {
        throw "$Message Expected content to contain '$Expected'."
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

    $criticalId = [long](Invoke-Postgres "INSERT INTO notification_items (target_type, target_key, title, body, status, source_module, severity, source_type, source_id, action_url, dedupe_key) VALUES ('ROLE', 'TH', 'I6 Task6 Export Critica', 'Debe salir en export CRITICAL TRAINING', 'UNREAD', 'TRAINING', 'CRITICAL', 'TRAINING_EXPIRY', 'TASK6-1', '/portal/courses', '$dedupePrefix-CRITICAL') RETURNING id;" | Select-Object -Last 1)
    Invoke-Postgres "INSERT INTO notification_items (target_type, target_key, title, body, status, source_module, severity, source_type, source_id, action_url, dedupe_key) VALUES ('ROLE', 'TH', 'I6 Task6 Export Info', 'No debe salir por filtro', 'UNREAD', 'CERTIFICATES', 'INFO', 'LABOR_CERTIFICATE', 'TASK6-2', '/portal/certificates', '$dedupePrefix-INFO');" | Out-Null

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $response = Invoke-WebRequestSafe -Method "GET" -Uri "$ApiBaseUrl/portal/notifications-summary/export?severity=CRITICAL&sourceModule=TRAINING&status=UNREAD" -Headers $thHeaders
    Assert-Status -Response $response -ExpectedStatus 200 -Message "Notification export endpoint must be available to TH."
    Assert-Contains -Text $response.Content -Expected "I6 Task6 Export Critica" -Message "Export must include matching notification title."
    Assert-Contains -Text $response.Content -Expected "CRITICAL" -Message "Export must include severity column/value."
    if ($response.Content -like "*I6 Task6 Export Info*") {
        throw "Export must honor severity and module filters."
    }

    $eventCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_events WHERE notification_id = $criticalId AND actor_username = 'th.sg' AND event_type = 'EXPORTED';" | Select-Object -Last 1)
    Assert-Equals -Actual $eventCount -Expected 1 -Message "Export must register EXPORTED event for exported notifications."

    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $gerenciaResponse = Invoke-WebRequestSafe -Method "GET" -Uri "$ApiBaseUrl/portal/notifications-summary/export?severity=CRITICAL&sourceModule=TRAINING&status=UNREAD" -Headers $gerenciaHeaders
    Assert-Status -Response $gerenciaResponse -ExpectedStatus 200 -Message "Gerencia must be allowed to export visible notification summaries."

    Write-Host "I6 notification export verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%'); DELETE FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
