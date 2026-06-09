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
$employeeIdentification = "I5-AUDIT-EMPLOYEE"
$typeCode = "I5-AUDIT-TYPE"

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
    param([string]$Method, [string]$Uri, [hashtable]$Headers, [object]$Body = $null)
    try {
        $parameters = @{ Uri = $Uri; Method = $Method; Headers = $Headers; UseBasicParsing = $true }
        if ($null -ne $Body) {
            $parameters.ContentType = "application/json"
            $parameters.Body = ($Body | ConvertTo-Json)
        }
        $response = Invoke-WebRequest @parameters
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

try {
    Invoke-Postgres "DELETE FROM audit_log WHERE entity_type = 'EMPLOYEE_TRAINING_RECORD' AND detail->>'verification' = 'I5-AUDIT'; DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM training_requirement_types WHERE code = '$typeCode';" | Out-Null
    $employeeId = [long](Invoke-Postgres "INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) VALUES ('CC', '$employeeIdentification', 'Empleado I5 Auditoria', 'ACTIVO', 'Guarda', CURRENT_DATE - 120) RETURNING id;")
    $typeId = [long](Invoke-Postgres "INSERT INTO training_requirement_types (code, name, category, validity_days, is_service_required) VALUES ('$typeCode', 'Curso auditoria I5', 'CURSO', 30, true) RETURNING id;")
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"

    $create = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/training" -Headers $thHeaders -Body @{
        requirementTypeId = $typeId
        completedAt = "2026-03-01"
        expiresAt = $null
        supportPath = $null
        notes = "verification=I5-AUDIT"
    }
    Assert-Status -Response $create -ExpectedStatus 200 -Message "TH must create renewal for audit."
    $recordId = [long]$create.Body.id

    $createdAudit = [int](Invoke-Postgres "SELECT count(*) FROM audit_log WHERE event_type = 'TRAINING_RECORD_CREATED' AND entity_type = 'EMPLOYEE_TRAINING_RECORD' AND entity_id = '$recordId';")
    if ($createdAudit -ne 1) {
        throw "Training record creation audit was not registered."
    }

    $inactivate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/training/$recordId/inactivate" -Headers $thHeaders
    Assert-Status -Response $inactivate -ExpectedStatus 200 -Message "TH must inactivate renewal."
    if ($inactivate.Body.status -ne "INACTIVO") {
        throw "Inactivated renewal must return INACTIVO status."
    }

    $inactiveAudit = [int](Invoke-Postgres "SELECT count(*) FROM audit_log WHERE event_type = 'TRAINING_RECORD_INACTIVATED' AND entity_type = 'EMPLOYEE_TRAINING_RECORD' AND entity_id = '$recordId';")
    if ($inactiveAudit -ne 1) {
        throw "Training record inactivation audit was not registered."
    }

    Write-Host "I5 audit verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM audit_log WHERE entity_type = 'EMPLOYEE_TRAINING_RECORD' AND detail->>'verification' = 'I5-AUDIT'; DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM training_requirement_types WHERE code = '$typeCode';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
