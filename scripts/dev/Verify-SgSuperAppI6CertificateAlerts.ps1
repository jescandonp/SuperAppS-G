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
$employeeIdentification = "I6-TASK5-CERT-EMP"
$certificatePrefix = "I6-TASK5-CERT"

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
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE source_module = 'CERTIFICATES' AND source_type = 'LABOR_CERTIFICATE' AND dedupe_key LIKE 'CERTIFICATE_ALERT:%'); DELETE FROM notification_items WHERE source_module = 'CERTIFICATES' AND source_type = 'LABOR_CERTIFICATE' AND dedupe_key LIKE 'CERTIFICATE_ALERT:%'; DELETE FROM labor_certificates WHERE certificate_number LIKE '$certificatePrefix%'; DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM certificate_signers WHERE full_name = 'Firmante I6 Task5';" | Out-Null

    $employeeId = [long](Invoke-Postgres "INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) VALUES ('CC', '$employeeIdentification', 'Empleado Certificados I6 Task5', 'ACTIVO', 'Guarda', CURRENT_DATE - 180) RETURNING id;" | Select-Object -Last 1)
    $signerId = [long](Invoke-Postgres "INSERT INTO certificate_signers (full_name, job_title, valid_from, status) VALUES ('Firmante I6 Task5', 'Gerente TH', CURRENT_DATE - 30, 'ACTIVO') RETURNING id;" | Select-Object -Last 1)
    $approvedId = [long](Invoke-Postgres "INSERT INTO labor_certificates (certificate_number, employee_id, signer_id, certificate_type, purpose, status, snapshot_payload, preview_content, created_by, approved_by, approved_at) VALUES ('$certificatePrefix-APROBADA', $employeeId, $signerId, 'ACTIVO', 'TRAMITE_GENERAL', 'APROBADA', '{}'::jsonb, 'Vista aprobada', 'th.sg', 'th.sg', NOW()) RETURNING id;" | Select-Object -Last 1)
    $generatedId = [long](Invoke-Postgres "INSERT INTO labor_certificates (certificate_number, employee_id, signer_id, certificate_type, purpose, status, snapshot_payload, preview_content, pdf_path, created_by, approved_by, approved_at, generated_at) VALUES ('$certificatePrefix-GENERADA', $employeeId, $signerId, 'ACTIVO', 'CLIENTE', 'GENERADA', '{}'::jsonb, 'Vista generada', 'generated-certificates/task5.pdf', 'th.sg', 'th.sg', NOW(), NOW()) RETURNING id;" | Select-Object -Last 1)
    $annulledId = [long](Invoke-Postgres "INSERT INTO labor_certificates (certificate_number, employee_id, signer_id, certificate_type, purpose, status, snapshot_payload, preview_content, pdf_path, annulment_reason, created_by, approved_by, approved_at, generated_at, annulled_by, annulled_at) VALUES ('$certificatePrefix-ANULADA', $employeeId, $signerId, 'ACTIVO', 'INTERESADO', 'ANULADA', '{}'::jsonb, 'Vista anulada', 'generated-certificates/task5-annulled.pdf', 'Error de datos', 'th.sg', 'th.sg', NOW(), NOW(), 'th.sg', NOW()) RETURNING id;" | Select-Object -Last 1)

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $response = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/alerts/certificates/generate" -Headers $thHeaders
    Assert-Status -Response $response -ExpectedStatus 200 -Message "Certificate alert generation endpoint must be available to TH."

    foreach ($certificateId in @($approvedId, $generatedId, $annulledId)) {
        $alertCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_items WHERE source_module = 'CERTIFICATES' AND source_type = 'LABOR_CERTIFICATE' AND source_id = '$certificateId' AND target_type = 'ROLE' AND target_key = 'TH' AND severity = 'INFO' AND status = 'UNREAD';" | Select-Object -Last 1)
        Assert-Equals -Actual $alertCount -Expected 1 -Message "Certificate $certificateId must create one INFO TH notification."
    }

    $eventCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_events ne JOIN notification_items ni ON ni.id = ne.notification_id WHERE ni.source_module = 'CERTIFICATES' AND ni.source_type = 'LABOR_CERTIFICATE' AND ni.source_id IN ('$approvedId', '$generatedId', '$annulledId') AND ne.event_type = 'CREATED' AND ne.actor_username = 'th.sg';" | Select-Object -Last 1)
    Assert-Equals -Actual $eventCount -Expected 3 -Message "Certificate alerts must register one CREATED event per certificate."

    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $deniedResponse = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/alerts/certificates/generate" -Headers $gerenciaHeaders
    Assert-Status -Response $deniedResponse -ExpectedStatus 403 -Message "Certificate alert generation must be restricted to alert operators."

    $secondResponse = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/alerts/certificates/generate" -Headers $thHeaders
    Assert-Status -Response $secondResponse -ExpectedStatus 200 -Message "Certificate alert generation must be idempotent."

    $activeCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_items WHERE source_module = 'CERTIFICATES' AND source_type = 'LABOR_CERTIFICATE' AND source_id IN ('$approvedId', '$generatedId', '$annulledId') AND status IN ('UNREAD', 'READ');" | Select-Object -Last 1)
    Assert-Equals -Actual $activeCount -Expected 3 -Message "Certificate alert generator must not duplicate active alerts for the same certificate."

    Write-Host "I6 certificate alert verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE source_module = 'CERTIFICATES' AND source_type = 'LABOR_CERTIFICATE' AND dedupe_key LIKE 'CERTIFICATE_ALERT:%'); DELETE FROM notification_items WHERE source_module = 'CERTIFICATES' AND source_type = 'LABOR_CERTIFICATE' AND dedupe_key LIKE 'CERTIFICATE_ALERT:%'; DELETE FROM labor_certificates WHERE certificate_number LIKE '$certificatePrefix%'; DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM certificate_signers WHERE full_name = 'Firmante I6 Task5';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
