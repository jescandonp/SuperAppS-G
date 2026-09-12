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
$dedupePrefix = "I6-TASK3-ACTIONS"

function Invoke-Postgres {
    param([string]$Sql)
    $output = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -t -A -c $Sql
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
    param([string]$Method, [string]$Uri, [hashtable]$Headers)
    try {
        $response = Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers -UseBasicParsing
        $body = if ([string]::IsNullOrWhiteSpace($response.Content)) { $null } else { $response.Content | ConvertFrom-Json }
        return @{ Status = [int]$response.StatusCode; Body = $body }
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

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

try {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%'); DELETE FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%';" | Out-Null
    Invoke-Postgres "INSERT INTO notification_items (target_type, target_key, title, body, status, source_module, severity, source_type, source_id, dedupe_key, action_url, read_at, archived_at, managed_at, managed_by) VALUES ('USER', 'th.sg', 'I6 Task3 marcar leida', 'Accion personal TH', 'UNREAD', 'TRAINING', 'WARNING', 'TRAINING_EXPIRY', 'READ-1', '$dedupePrefix-READ', '/portal/cursos', null, null, null, null), ('ROLE', 'TH', 'I6 Task3 archivar rol', 'Accion rol TH', 'UNREAD', 'IMPORTS', 'CRITICAL', 'IMPORT_BATCH', 'ARCHIVE-1', '$dedupePrefix-ARCHIVE', '/portal/imports', null, null, null, null), ('USER', 'admin.sg', 'I6 Task3 fuera de alcance', 'No visible para TH', 'UNREAD', 'SYSTEM', 'INFO', 'SYSTEM_NOTICE', 'DENIED-1', '$dedupePrefix-DENIED', null, null, null, null, null);" | Out-Null

    $readId = [long](Invoke-Postgres "SELECT id FROM notification_items WHERE dedupe_key = '$dedupePrefix-READ';" | Select-Object -Last 1)
    $archiveId = [long](Invoke-Postgres "SELECT id FROM notification_items WHERE dedupe_key = '$dedupePrefix-ARCHIVE';" | Select-Object -Last 1)
    $deniedId = [long](Invoke-Postgres "SELECT id FROM notification_items WHERE dedupe_key = '$dedupePrefix-DENIED';" | Select-Object -Last 1)

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"

    $readResponse = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/notifications/$readId/read" -Headers $thHeaders
    Assert-Status -Response $readResponse -ExpectedStatus 200 -Message "Visible notification must be marked as read."
    Assert-Equals -Actual $readResponse.Body.status -Expected "READ" -Message "Read action response must return READ status."
    Assert-True -Condition ($null -ne $readResponse.Body.readAt) -Message "Read action response must include readAt."

    $readState = Invoke-Postgres "SELECT status || '|' || (read_at IS NOT NULL)::text || '|' || (managed_at IS NULL)::text || '|' || COALESCE(managed_by, '') FROM notification_items WHERE id = $readId;" | Select-Object -Last 1
    Assert-Equals -Actual $readState -Expected "READ|true|true|" -Message "Read action must update only status/read_at."

    $readEvents = [int](Invoke-Postgres "SELECT count(*) FROM notification_events WHERE notification_id = $readId AND actor_username = 'th.sg' AND event_type = 'READ';" | Select-Object -Last 1)
    Assert-Equals -Actual $readEvents -Expected 1 -Message "Read action must register one READ event."

    $archiveResponse = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/notifications/$archiveId/archive" -Headers $thHeaders
    Assert-Status -Response $archiveResponse -ExpectedStatus 200 -Message "Visible role notification must be archived."
    Assert-Equals -Actual $archiveResponse.Body.status -Expected "ARCHIVED" -Message "Archive action response must return ARCHIVED status."
    Assert-True -Condition ($null -ne $archiveResponse.Body.managedAt) -Message "Archive action response must include managedAt."
    Assert-Equals -Actual $archiveResponse.Body.managedBy -Expected "th.sg" -Message "Archive action response must include actor username."

    $archiveState = Invoke-Postgres "SELECT status || '|' || (managed_at IS NOT NULL)::text || '|' || COALESCE(managed_by, '') FROM notification_items WHERE id = $archiveId;" | Select-Object -Last 1
    Assert-Equals -Actual $archiveState -Expected "ARCHIVED|true|th.sg" -Message "Archive action must update status, managed_at and managed_by."

    $archiveEvents = [int](Invoke-Postgres "SELECT count(*) FROM notification_events WHERE notification_id = $archiveId AND actor_username = 'th.sg' AND event_type = 'ARCHIVED';" | Select-Object -Last 1)
    Assert-Equals -Actual $archiveEvents -Expected 1 -Message "Archive action must register one ARCHIVED event."

    $deniedRead = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/notifications/$deniedId/read" -Headers $thHeaders
    Assert-Status -Response $deniedRead -ExpectedStatus 404 -Message "User must not manage notifications outside own user/role scope."

    $deniedArchive = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/notifications/$deniedId/archive" -Headers $thHeaders
    Assert-Status -Response $deniedArchive -ExpectedStatus 404 -Message "User must not archive notifications outside own user/role scope."

    Write-Host "I6 notification action verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%'); DELETE FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
