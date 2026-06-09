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
$employeeIdentification = "I5-RENEWALS-EMPLOYEE"
$autoTypeCode = "I5-RENEWALS-AUTO"
$manualTypeCode = "I5-RENEWALS-MANUAL"
$inactiveTypeCode = "I5-RENEWALS-INACTIVE"

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
    Invoke-Postgres "DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM training_requirement_types WHERE code IN ('$autoTypeCode', '$manualTypeCode', '$inactiveTypeCode');" | Out-Null
    $employeeId = [long](Invoke-Postgres "INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) VALUES ('CC', '$employeeIdentification', 'Empleado I5 Renovaciones', 'ACTIVO', 'Guarda', CURRENT_DATE - 120) RETURNING id;")
    $autoTypeId = [long](Invoke-Postgres "INSERT INTO training_requirement_types (code, name, category, validity_days, is_service_required) VALUES ('$autoTypeCode', 'Curso automatico I5', 'CURSO', 365, true) RETURNING id;")
    $manualTypeId = [long](Invoke-Postgres "INSERT INTO training_requirement_types (code, name, category, validity_days, is_service_required) VALUES ('$manualTypeCode', 'Acreditacion manual I5', 'ACREDITACION', null, true) RETURNING id;")
    $inactiveTypeId = [long](Invoke-Postgres "INSERT INTO training_requirement_types (code, name, category, validity_days, is_service_required, status) VALUES ('$inactiveTypeCode', 'Tipo inactivo I5', 'CURSO', 365, true, 'INACTIVO') RETURNING id;")

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"

    $auto = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/training" -Headers $thHeaders -Body @{
        requirementTypeId = $autoTypeId
        completedAt = "2026-01-15"
        expiresAt = $null
        supportPath = "soportes/i5/curso.pdf"
        notes = "Calculado por vigencia"
    }
    Assert-Status -Response $auto -ExpectedStatus 200 -Message "TH must create renewal with automatic expiry."
    if ($auto.Body.expiresAt -ne "2027-01-15" -or $auto.Body.status -ne "ACTIVO" -or $auto.Body.requirementTypeId -ne $autoTypeId) {
        throw "Automatic renewal did not return expected calculated fields."
    }

    $missingManualExpiry = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/training" -Headers $thHeaders -Body @{
        requirementTypeId = $manualTypeId
        completedAt = "2026-02-01"
        expiresAt = $null
        supportPath = $null
        notes = $null
    }
    Assert-Status -Response $missingManualExpiry -ExpectedStatus 400 -Message "Manual expiry must be required when type has no validity."

    $manual = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/training" -Headers $thHeaders -Body @{
        requirementTypeId = $manualTypeId
        completedAt = "2026-02-01"
        expiresAt = "2026-08-01"
        supportPath = $null
        notes = "Vencimiento manual"
    }
    Assert-Status -Response $manual -ExpectedStatus 200 -Message "TH must create renewal with manual expiry."
    if ($manual.Body.expiresAt -ne "2026-08-01" -or $manual.Body.supportPath -ne $null) {
        throw "Manual renewal did not return expected fields."
    }

    $invalidRange = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/training" -Headers $thHeaders -Body @{
        requirementTypeId = $manualTypeId
        completedAt = "2026-08-01"
        expiresAt = "2026-02-01"
        supportPath = $null
        notes = $null
    }
    Assert-Status -Response $invalidRange -ExpectedStatus 400 -Message "Expiry before completion must be rejected."

    $inactive = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/training" -Headers $thHeaders -Body @{
        requirementTypeId = $inactiveTypeId
        completedAt = "2026-01-01"
        expiresAt = $null
        supportPath = $null
        notes = $null
    }
    Assert-Status -Response $inactive -ExpectedStatus 409 -Message "Inactive requirement type must be rejected."

    $missingEmployee = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/999999999/training" -Headers $thHeaders -Body @{
        requirementTypeId = $autoTypeId
        completedAt = "2026-01-01"
        expiresAt = $null
        supportPath = $null
        notes = $null
    }
    Assert-Status -Response $missingEmployee -ExpectedStatus 404 -Message "Missing employee must be rejected."

    $forbidden = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/training" -Headers $gerenciaHeaders -Body @{
        requirementTypeId = $autoTypeId
        completedAt = "2026-01-01"
        expiresAt = $null
        supportPath = $null
        notes = $null
    }
    Assert-Status -Response $forbidden -ExpectedStatus 403 -Message "GERENCIA must not create renewals."

    Write-Host "I5 renewals verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM training_requirement_types WHERE code IN ('$autoTypeCode', '$manualTypeCode', '$inactiveTypeCode');" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
