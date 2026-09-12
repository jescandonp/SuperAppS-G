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
$filePrefix = "i6-task5-import-alerts"

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

try {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE source_module = 'IMPORTS' AND source_type = 'IMPORT_BATCH' AND dedupe_key LIKE 'IMPORT_ALERT:%'); DELETE FROM notification_items WHERE source_module = 'IMPORTS' AND source_type = 'IMPORT_BATCH' AND dedupe_key LIKE 'IMPORT_ALERT:%'; DELETE FROM import_batches WHERE file_name LIKE '$filePrefix%';" | Out-Null

    $batchId = [long](Invoke-Postgres "INSERT INTO import_batches (load_type, file_name, uploaded_by, status, total_records, valid_records, incomplete_records, duplicate_records, invalid_records) VALUES ('EMPLOYEES', '$filePrefix.csv', 'th.sg', 'CON_ERRORES', 4, 1, 1, 1, 1) RETURNING id;" | Select-Object -Last 1)
    $incompleteRowId = [long](Invoke-Postgres "INSERT INTO import_batch_rows (import_batch_id, row_number, classification, identification_type, identification_number, normalized_payload, source_payload) VALUES ($batchId, 2, 'INCOMPLETO', 'CC', 'I6-TASK5-INC', '{}'::jsonb, '{}'::jsonb) RETURNING id;" | Select-Object -Last 1)
    $duplicateRowId = [long](Invoke-Postgres "INSERT INTO import_batch_rows (import_batch_id, row_number, classification, identification_type, identification_number, normalized_payload, source_payload) VALUES ($batchId, 3, 'DUPLICADO', 'CC', 'I6-TASK5-DUP', '{}'::jsonb, '{}'::jsonb) RETURNING id;" | Select-Object -Last 1)
    $errorRowId = [long](Invoke-Postgres "INSERT INTO import_batch_rows (import_batch_id, row_number, classification, identification_type, identification_number, normalized_payload, source_payload) VALUES ($batchId, 4, 'ERRONEO', 'CC', 'I6-TASK5-ERR', '{}'::jsonb, '{}'::jsonb) RETURNING id;" | Select-Object -Last 1)
    Invoke-Postgres "INSERT INTO import_batch_errors (import_batch_id, import_batch_row_id, row_number, field_name, error_type, message, original_value) VALUES ($batchId, $incompleteRowId, 2, 'full_name', 'INCOMPLETO', 'Nombre requerido', null), ($batchId, $duplicateRowId, 3, 'identification_number', 'DUPLICADO', 'Documento duplicado', 'I6-TASK5-DUP'), ($batchId, $errorRowId, 4, 'hire_date', 'FORMATO_INVALIDO', 'Fecha invalida', 'x');" | Out-Null

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $response = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/alerts/imports/generate" -Headers $thHeaders
    Assert-Status -Response $response -ExpectedStatus 200 -Message "Import alert generation endpoint must be available to TH."

    $alertCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_items WHERE source_module = 'IMPORTS' AND source_type = 'IMPORT_BATCH' AND source_id = '$batchId' AND target_type = 'ROLE' AND target_key = 'TH' AND severity = 'CRITICAL' AND status = 'UNREAD' AND body LIKE '%INCOMPLETO%' AND body LIKE '%DUPLICADO%' AND body LIKE '%ERRONEO%';" | Select-Object -Last 1)
    Assert-Equals -Actual $alertCount -Expected 1 -Message "CON_ERRORES import batch must create one CRITICAL TH alert summarizing error classifications."

    $eventCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_events ne JOIN notification_items ni ON ni.id = ne.notification_id WHERE ni.source_module = 'IMPORTS' AND ni.source_type = 'IMPORT_BATCH' AND ni.source_id = '$batchId' AND ne.event_type = 'CREATED' AND ne.actor_username = 'th.sg';" | Select-Object -Last 1)
    Assert-Equals -Actual $eventCount -Expected 1 -Message "Import alert must register one CREATED event."

    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $deniedResponse = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/alerts/imports/generate" -Headers $gerenciaHeaders
    Assert-Status -Response $deniedResponse -ExpectedStatus 403 -Message "Import alert generation must be restricted to alert operators."

    $secondResponse = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/alerts/imports/generate" -Headers $thHeaders
    Assert-Status -Response $secondResponse -ExpectedStatus 200 -Message "Import alert generation must be idempotent."

    $activeCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_items WHERE source_module = 'IMPORTS' AND source_type = 'IMPORT_BATCH' AND source_id = '$batchId' AND status IN ('UNREAD', 'READ');" | Select-Object -Last 1)
    Assert-Equals -Actual $activeCount -Expected 1 -Message "Import alert generator must not duplicate active alerts for the same batch."

    Write-Host "I6 import alert verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE source_module = 'IMPORTS' AND source_type = 'IMPORT_BATCH' AND dedupe_key LIKE 'IMPORT_ALERT:%'); DELETE FROM notification_items WHERE source_module = 'IMPORTS' AND source_type = 'IMPORT_BATCH' AND dedupe_key LIKE 'IMPORT_ALERT:%'; DELETE FROM import_batches WHERE file_name LIKE '$filePrefix%';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
