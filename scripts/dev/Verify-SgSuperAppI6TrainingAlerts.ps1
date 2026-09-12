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
$typePrefix = "I6-TASK4-TRAINING"
$employeeIdentification = "I6-TASK4-EMPLOYEE"
$today = [DateTime]::Today

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

function Assert-Alert {
    param([string]$State, [long]$RecordId, [string]$Severity)
    $count = [int](Invoke-Postgres "SELECT count(*) FROM notification_items WHERE source_id = '$RecordId' AND target_type = 'ROLE' AND target_key = 'TH' AND source_module = 'TRAINING' AND source_type = 'TRAINING_EXPIRY' AND severity = '$Severity' AND status = 'UNREAD';" | Select-Object -Last 1)
    Assert-Equals -Actual $count -Expected 1 -Message "$State must generate exactly one active $Severity alert for TH."

    $events = [int](Invoke-Postgres "SELECT count(*) FROM notification_events ne JOIN notification_items ni ON ni.id = ne.notification_id WHERE ni.source_id = '$RecordId' AND ne.event_type = 'CREATED' AND ne.actor_username = 'th.sg';" | Select-Object -Last 1)
    Assert-Equals -Actual $events -Expected 1 -Message "$State alert must register one CREATED event."
}

try {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT ni.id FROM notification_items ni JOIN employee_training_records etr ON ni.source_id = etr.id::text JOIN employees e ON e.id = etr.employee_id WHERE e.identification_number = '$employeeIdentification' AND ni.source_module = 'TRAINING' AND ni.source_type = 'TRAINING_EXPIRY'); DELETE FROM notification_items ni USING employee_training_records etr, employees e WHERE ni.source_id = etr.id::text AND e.id = etr.employee_id AND e.identification_number = '$employeeIdentification' AND ni.source_module = 'TRAINING' AND ni.source_type = 'TRAINING_EXPIRY'; DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM training_requirement_types WHERE code LIKE '$typePrefix%';" | Out-Null

    $employeeId = [long](Invoke-Postgres "INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) VALUES ('CC', '$employeeIdentification', 'Empleado I6 Alertas Training', 'ACTIVO', 'Guarda', CURRENT_DATE - 120) RETURNING id;" | Select-Object -Last 1)
    $recordIds = @{}

    $states = @(
        @{ State = "VENCIDO"; Days = -1; Category = "CURSO"; Required = "true" },
        @{ State = "CRITICO"; Days = 15; Category = "ACREDITACION"; Required = "true" },
        @{ State = "PREVENTIVO"; Days = 30; Category = "CURSO"; Required = "true" },
        @{ State = "INFORMATIVO"; Days = 60; Category = "ACREDITACION"; Required = "false" },
        @{ State = "AL_DIA"; Days = 61; Category = "CURSO"; Required = "true" }
    )

    foreach ($item in $states) {
        $typeCode = "$typePrefix-$($item.State)"
        $typeId = [long](Invoke-Postgres "INSERT INTO training_requirement_types (code, name, category, validity_days, is_service_required) VALUES ('$typeCode', 'Tipo $($item.State) I6', '$($item.Category)', null, $($item.Required)) RETURNING id;" | Select-Object -Last 1)
        $completedAt = $today.AddDays(-10).ToString("yyyy-MM-dd")
        $expiresAt = $today.AddDays([int]$item.Days).ToString("yyyy-MM-dd")
        $recordIds[$item.State] = [long](Invoke-Postgres "INSERT INTO employee_training_records (employee_id, requirement_type_id, completed_at, expires_at, notes, status, created_by) VALUES ($employeeId, $typeId, DATE '$completedAt', DATE '$expiresAt', 'Task4 $($item.State)', 'ACTIVO', 'th.sg') RETURNING id;" | Select-Object -Last 1)
    }

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $response = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/alerts/training/generate" -Headers $thHeaders
    Assert-Status -Response $response -ExpectedStatus 200 -Message "Training alert generation endpoint must be available to TH."

    Assert-Alert -State "VENCIDO" -RecordId $recordIds["VENCIDO"] -Severity "CRITICAL"
    Assert-Alert -State "CRITICO" -RecordId $recordIds["CRITICO"] -Severity "CRITICAL"
    Assert-Alert -State "PREVENTIVO" -RecordId $recordIds["PREVENTIVO"] -Severity "WARNING"
    Assert-Alert -State "INFORMATIVO" -RecordId $recordIds["INFORMATIVO"] -Severity "INFO"

    $alDiaCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_items WHERE source_id = '$($recordIds["AL_DIA"])' AND source_module = 'TRAINING' AND source_type = 'TRAINING_EXPIRY';" | Select-Object -Last 1)
    Assert-Equals -Actual $alDiaCount -Expected 0 -Message "AL_DIA must not generate an alert."

    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $deniedResponse = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/alerts/training/generate" -Headers $gerenciaHeaders
    Assert-Status -Response $deniedResponse -ExpectedStatus 403 -Message "Training alert generation must be restricted to alert operators."

    $secondResponse = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/alerts/training/generate" -Headers $thHeaders
    Assert-Status -Response $secondResponse -ExpectedStatus 200 -Message "Training alert generation must be idempotent."

    $activeCount = [int](Invoke-Postgres "SELECT count(*) FROM notification_items ni JOIN employee_training_records etr ON ni.source_id = etr.id::text WHERE etr.employee_id = $employeeId AND ni.source_module = 'TRAINING' AND ni.source_type = 'TRAINING_EXPIRY' AND ni.status IN ('UNREAD', 'READ');" | Select-Object -Last 1)
    Assert-Equals -Actual $activeCount -Expected 4 -Message "Generator must not duplicate active alerts for the same employee/type/state."

    Write-Host "I6 training alert verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT ni.id FROM notification_items ni JOIN employee_training_records etr ON ni.source_id = etr.id::text JOIN employees e ON e.id = etr.employee_id WHERE e.identification_number = '$employeeIdentification' AND ni.source_module = 'TRAINING' AND ni.source_type = 'TRAINING_EXPIRY'); DELETE FROM notification_items ni USING employee_training_records etr, employees e WHERE ni.source_id = etr.id::text AND e.id = etr.employee_id AND e.identification_number = '$employeeIdentification' AND ni.source_module = 'TRAINING' AND ni.source_type = 'TRAINING_EXPIRY'; DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM training_requirement_types WHERE code LIKE '$typePrefix%';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
