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
$requiredExpiredEmployee = "I5-ENABLEMENT-REQUIRED-EXPIRED"
$requiredValidEmployee = "I5-ENABLEMENT-REQUIRED-VALID"
$optionalExpiredEmployee = "I5-ENABLEMENT-OPTIONAL-EXPIRED"
$requiredTypeCode = "I5-ENABLEMENT-REQUIRED"
$optionalTypeCode = "I5-ENABLEMENT-OPTIONAL"

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

function Assert-Enablement {
    param([long]$EmployeeId, [hashtable]$Headers, [string]$ExpectedStatus, [int]$ExpectedBlockingCount, [string]$Message)
    $response = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees/$EmployeeId/training/enablement" -Headers $Headers
    Assert-Status -Response $response -ExpectedStatus 200 -Message $Message
    if ($response.Body.serviceEnablementStatus -ne $ExpectedStatus) {
        throw "$Message Expected serviceEnablementStatus $ExpectedStatus, received '$($response.Body.serviceEnablementStatus)'."
    }
    if ($response.Body.blockingExpiredRequirementsCount -ne $ExpectedBlockingCount) {
        throw "$Message Expected blocking count $ExpectedBlockingCount, received '$($response.Body.blockingExpiredRequirementsCount)'."
    }
}

try {
    Invoke-Postgres "DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$requiredExpiredEmployee', '$requiredValidEmployee', '$optionalExpiredEmployee')); DELETE FROM employees WHERE identification_number IN ('$requiredExpiredEmployee', '$requiredValidEmployee', '$optionalExpiredEmployee'); DELETE FROM training_requirement_types WHERE code IN ('$requiredTypeCode', '$optionalTypeCode');" | Out-Null

    $requiredTypeId = [long](Invoke-Postgres "INSERT INTO training_requirement_types (code, name, category, validity_days, is_service_required) VALUES ('$requiredTypeCode', 'Requisito obligatorio I5', 'CURSO', null, true) RETURNING id;")
    $optionalTypeId = [long](Invoke-Postgres "INSERT INTO training_requirement_types (code, name, category, validity_days, is_service_required) VALUES ('$optionalTypeCode', 'Requisito opcional I5', 'CURSO', null, false) RETURNING id;")
    $requiredExpiredEmployeeId = [long](Invoke-Postgres "INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) VALUES ('CC', '$requiredExpiredEmployee', 'Empleado I5 Obligatorio Vencido', 'ACTIVO', 'Guarda', CURRENT_DATE - 120) RETURNING id;")
    $requiredValidEmployeeId = [long](Invoke-Postgres "INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) VALUES ('CC', '$requiredValidEmployee', 'Empleado I5 Obligatorio Vigente', 'ACTIVO', 'Guarda', CURRENT_DATE - 120) RETURNING id;")
    $optionalExpiredEmployeeId = [long](Invoke-Postgres "INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) VALUES ('CC', '$optionalExpiredEmployee', 'Empleado I5 Opcional Vencido', 'ACTIVO', 'Guarda', CURRENT_DATE - 120) RETURNING id;")

    Invoke-Postgres "INSERT INTO employee_training_records (employee_id, requirement_type_id, completed_at, expires_at, created_by) VALUES ($requiredExpiredEmployeeId, $requiredTypeId, CURRENT_DATE - 30, CURRENT_DATE - 1, 'th.sg'), ($requiredValidEmployeeId, $requiredTypeId, CURRENT_DATE - 30, CURRENT_DATE + 30, 'th.sg'), ($optionalExpiredEmployeeId, $optionalTypeId, CURRENT_DATE - 30, CURRENT_DATE - 1, 'th.sg');" | Out-Null

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"

    Assert-Enablement -EmployeeId $requiredExpiredEmployeeId -Headers $thHeaders -ExpectedStatus "NO_HABILITADO" -ExpectedBlockingCount 1 -Message "Required expired renewal must block service."
    Assert-Enablement -EmployeeId $requiredValidEmployeeId -Headers $thHeaders -ExpectedStatus "HABILITADO" -ExpectedBlockingCount 0 -Message "Required valid renewal must keep service enabled."
    Assert-Enablement -EmployeeId $optionalExpiredEmployeeId -Headers $thHeaders -ExpectedStatus "HABILITADO" -ExpectedBlockingCount 0 -Message "Optional expired renewal must not block service."
    Assert-Enablement -EmployeeId $requiredExpiredEmployeeId -Headers $operacionesHeaders -ExpectedStatus "NO_HABILITADO" -ExpectedBlockingCount 1 -Message "OPERACIONES must read service enablement."
    Assert-Enablement -EmployeeId $requiredExpiredEmployeeId -Headers $gerenciaHeaders -ExpectedStatus "NO_HABILITADO" -ExpectedBlockingCount 1 -Message "GERENCIA must read service enablement."

    $forbidden = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$requiredExpiredEmployeeId/training" -Headers $operacionesHeaders -Body @{
        requirementTypeId = $requiredTypeId
        completedAt = (Get-Date).ToString("yyyy-MM-dd")
        expiresAt = (Get-Date).AddDays(365).ToString("yyyy-MM-dd")
        supportPath = $null
        notes = $null
    }
    Assert-Status -Response $forbidden -ExpectedStatus 403 -Message "OPERACIONES must not edit training records."

    Write-Host "I5 service enablement verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$requiredExpiredEmployee', '$requiredValidEmployee', '$optionalExpiredEmployee')); DELETE FROM employees WHERE identification_number IN ('$requiredExpiredEmployee', '$requiredValidEmployee', '$optionalExpiredEmployee'); DELETE FROM training_requirement_types WHERE code IN ('$requiredTypeCode', '$optionalTypeCode');" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
