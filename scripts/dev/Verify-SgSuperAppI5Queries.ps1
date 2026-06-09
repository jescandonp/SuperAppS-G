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
$employeeNumber = "I5-QUERIES-EMPLOYEE"
$otherEmployeeNumber = "I5-QUERIES-OTHER"
$requiredTypeCode = "I5-QUERIES-REQUIRED"
$optionalTypeCode = "I5-QUERIES-OPTIONAL"
$positionCode = "I5-QUERIES-POS"

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
    Invoke-Postgres "DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$employeeNumber', '$otherEmployeeNumber')); DELETE FROM employee_position_assignments WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$employeeNumber', '$otherEmployeeNumber')); DELETE FROM employees WHERE identification_number IN ('$employeeNumber', '$otherEmployeeNumber'); DELETE FROM training_requirement_types WHERE code IN ('$requiredTypeCode', '$optionalTypeCode'); DELETE FROM service_positions WHERE code = '$positionCode';" | Out-Null

    $requiredTypeId = [long](Invoke-Postgres "INSERT INTO training_requirement_types (code, name, category, validity_days, is_service_required) VALUES ('$requiredTypeCode', 'Requisito consulta I5', 'CURSO', null, true) RETURNING id;")
    $optionalTypeId = [long](Invoke-Postgres "INSERT INTO training_requirement_types (code, name, category, validity_days, is_service_required) VALUES ('$optionalTypeCode', 'Opcional consulta I5', 'ACREDITACION', null, false) RETURNING id;")
    $employeeId = [long](Invoke-Postgres "INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) VALUES ('CC', '$employeeNumber', 'Empleado I5 Consultas', 'ACTIVO', 'Guarda', CURRENT_DATE - 120) RETURNING id;")
    $otherEmployeeId = [long](Invoke-Postgres "INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) VALUES ('CC', '$otherEmployeeNumber', 'Empleado I5 Vigente', 'ACTIVO', 'Guarda', CURRENT_DATE - 120) RETURNING id;")
    $positionId = [long](Invoke-Postgres "INSERT INTO service_positions (code, name, client_text, location_text) VALUES ('$positionCode', 'Puesto consulta I5', 'Cliente I5', 'Bogota') RETURNING id;")
    Invoke-Postgres "INSERT INTO employee_position_assignments (employee_id, position_id, start_date, status, created_by) VALUES ($employeeId, $positionId, CURRENT_DATE - 10, 'VIGENTE', 'th.sg');" | Out-Null
    Invoke-Postgres "INSERT INTO employee_training_records (employee_id, requirement_type_id, completed_at, expires_at, support_path, notes, status, created_by) VALUES ($employeeId, $requiredTypeId, CURRENT_DATE - 60, CURRENT_DATE - 1, '/evidencias/vencido.pdf', 'Registro vencido', 'ACTIVO', 'th.sg'), ($employeeId, $requiredTypeId, CURRENT_DATE - 420, CURRENT_DATE - 365, null, 'Historico finalizado', 'INACTIVO', 'th.sg'), ($employeeId, $optionalTypeId, CURRENT_DATE - 30, CURRENT_DATE + 45, null, 'Opcional vigente', 'ACTIVO', 'th.sg'), ($otherEmployeeId, $requiredTypeId, CURRENT_DATE - 20, CURRENT_DATE + 90, null, 'Vigente', 'ACTIVO', 'th.sg');" | Out-Null

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"

    $listBySearch = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/training-compliance?search=I5-QUERIES-EMPLOYEE" -Headers $thHeaders
    Assert-Status -Response $listBySearch -ExpectedStatus 200 -Message "Training compliance list by employee must be available."
    Assert-Equals -Actual @($listBySearch.Body).Count -Expected 1 -Message "Search filter must return one employee."
    Assert-Equals -Actual $listBySearch.Body[0].employeeId -Expected $employeeId -Message "Search result must match seeded employee."
    Assert-Equals -Actual $listBySearch.Body[0].serviceEnablementStatus -Expected "NO_HABILITADO" -Message "List must include service enablement."
    Assert-Equals -Actual $listBySearch.Body[0].currentPositionName -Expected "Puesto consulta I5" -Message "List must include current position."

    $listByType = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/training-compliance?typeId=$requiredTypeId" -Headers $thHeaders
    Assert-Status -Response $listByType -ExpectedStatus 200 -Message "Training compliance list by type must be available."
    if (-not (@($listByType.Body) | Where-Object { $_.employeeId -eq $employeeId })) { throw "Type filter must include employee with required type." }

    $listByStatus = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/training-compliance?complianceStatus=VENCIDO" -Headers $operacionesHeaders
    Assert-Status -Response $listByStatus -ExpectedStatus 200 -Message "OPERACIONES must read list by compliance status."
    if (-not (@($listByStatus.Body) | Where-Object { $_.employeeId -eq $employeeId -and $_.worstComplianceStatus -eq "VENCIDO" })) { throw "Compliance status filter must include expired employee." }

    $listByEnablement = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/training-compliance?enablementStatus=HABILITADO" -Headers $gerenciaHeaders
    Assert-Status -Response $listByEnablement -ExpectedStatus 200 -Message "GERENCIA must read list by enablement."
    if (-not (@($listByEnablement.Body) | Where-Object { $_.employeeId -eq $otherEmployeeId -and $_.serviceEnablementStatus -eq "HABILITADO" })) { throw "Enablement filter must include enabled employee." }

    $detail = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees/$employeeId/training-compliance" -Headers $gerenciaHeaders
    Assert-Status -Response $detail -ExpectedStatus 200 -Message "Training compliance detail must be available."
    Assert-Equals -Actual $detail.Body.employee.employeeId -Expected $employeeId -Message "Detail must include employee."
    Assert-Equals -Actual $detail.Body.currentPosition.name -Expected "Puesto consulta I5" -Message "Detail must include current position."
    Assert-Equals -Actual $detail.Body.serviceEnablement.serviceEnablementStatus -Expected "NO_HABILITADO" -Message "Detail must include service enablement."
    if (@($detail.Body.currentRequirements).Count -lt 2) { throw "Detail must include active/current requirements." }
    if (@($detail.Body.trainingHistory).Count -lt 3) { throw "Detail must include training history." }

    Write-Host "I5 queries verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$employeeNumber', '$otherEmployeeNumber')); DELETE FROM employee_position_assignments WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$employeeNumber', '$otherEmployeeNumber')); DELETE FROM employees WHERE identification_number IN ('$employeeNumber', '$otherEmployeeNumber'); DELETE FROM training_requirement_types WHERE code IN ('$requiredTypeCode', '$optionalTypeCode'); DELETE FROM service_positions WHERE code = '$positionCode';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
