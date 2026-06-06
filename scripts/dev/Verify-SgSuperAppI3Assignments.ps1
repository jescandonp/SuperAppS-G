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
$employeeIdentification = "I3-ASSIGN-EMP"
$activeCode = "I3-ASSIGN-ACTIVE"
$inactiveCode = "I3-ASSIGN-INACTIVE"
$importedPositionText = "Puesto importado I2 sin normalizar"

function Invoke-Postgres {
    param([string]$Sql)

    & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -c $Sql | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL command failed."
    }
}

function Get-Scalar {
    param([string]$Sql)

    $result = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -t -A -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL scalar command failed."
    }

    return $result.Trim()
}

function Get-SessionHeaders {
    param([string]$Username, [string]$Password)

    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($response.sessionToken)" }
}

function Invoke-JsonRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers,
        [object]$Body = $null
    )

    try {
        $parameters = @{
            Uri = $Uri
            Method = $Method
            Headers = $Headers
            UseBasicParsing = $true
        }

        if ($null -ne $Body) {
            $parameters.ContentType = "application/json"
            $parameters.Body = ($Body | ConvertTo-Json)
        }

        $response = Invoke-WebRequest @parameters
        return @{ Status = [int]$response.StatusCode; Body = ($response.Content | ConvertFrom-Json) }
    }
    catch {
        if ($null -eq $_.Exception.Response) {
            throw
        }

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
    Invoke-Postgres @"
DELETE FROM employee_position_assignments
WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification')
   OR position_id IN (SELECT id FROM service_positions WHERE code IN ('$activeCode', '$inactiveCode'));
DELETE FROM employees WHERE identification_number = '$employeeIdentification';
DELETE FROM service_positions WHERE code IN ('$activeCode', '$inactiveCode');

INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, current_service_position_text, record_status, source)
VALUES ('CC', '$employeeIdentification', 'Empleado Asignacion I3', 'ACTIVO', 'Guarda', DATE '2026-01-01', '$importedPositionText', 'ACTIVO', 'TEST');

INSERT INTO service_positions (code, name, client_text, location_text, status)
VALUES
    ('$activeCode', 'Puesto Activo I3', 'Cliente Asignacion', 'Bogota', 'ACTIVO'),
    ('$inactiveCode', 'Puesto Inactivo I3', 'Cliente Asignacion', 'Medellin', 'INACTIVO');
"@

    $employeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$employeeIdentification';")
    $activePositionId = [long](Get-Scalar "SELECT id FROM service_positions WHERE code = '$activeCode';")
    $inactivePositionId = [long](Get-Scalar "SELECT id FROM service_positions WHERE code = '$inactiveCode';")
    $initialPositionCount = [long](Get-Scalar "SELECT count(*) FROM service_positions;")

    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"

    $inactiveAttempt = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $thHeaders -Body @{
        positionId = $inactivePositionId
        startDate = "2026-02-01"
        changeReason = "No debe permitir inactivo"
        notes = $null
    }
    Assert-Status -Response $inactiveAttempt -ExpectedStatus 409 -Message "Inactive positions must be rejected."

    $create = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $thHeaders -Body @{
        positionId = $activePositionId
        startDate = "2026-02-01"
        changeReason = "Asignacion inicial"
        notes = "Task 3"
    }
    Assert-Status -Response $create -ExpectedStatus 200 -Message "TH must create assignment."
    $assignmentId = [long]$create.Body.id
    if ($create.Body.status -ne "VIGENTE" -or $create.Body.positionName -ne "Puesto Activo I3") {
        throw "Created assignment must return active position data."
    }

    $duplicate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $adminHeaders -Body @{
        positionId = $activePositionId
        startDate = "2026-02-02"
        changeReason = "Doble vigente"
        notes = $null
    }
    Assert-Status -Response $duplicate -ExpectedStatus 409 -Message "Second active assignment must be rejected."

    foreach ($headers in @($gerenciaHeaders, $operacionesHeaders)) {
        $forbidden = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $headers -Body @{
            positionId = $activePositionId
            startDate = "2026-03-01"
            changeReason = "No autorizado"
            notes = $null
        }
        Assert-Status -Response $forbidden -ExpectedStatus 403 -Message "Read-only roles must not create assignments."
    }

    $history = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $operacionesHeaders
    Assert-Status -Response $history -ExpectedStatus 200 -Message "OPERACIONES must read assignment history."
    if (@($history.Body).Count -ne 1 -or $history.Body[0].status -ne "VIGENTE") {
        throw "Assignment history must include current assignment."
    }

    $detail = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees/$employeeId" -Headers $gerenciaHeaders
    Assert-Status -Response $detail -ExpectedStatus 200 -Message "GERENCIA must read employee detail."
    if ($detail.Body.currentServicePositionName -ne "Puesto Activo I3") {
        throw "Employee detail must expose normalized current service position."
    }

    if ($detail.Body.currentServicePositionText -ne $importedPositionText) {
        throw "Employee detail must preserve imported I2 position text alongside normalized position."
    }

    $positionCountAfterAssignment = [long](Get-Scalar "SELECT count(*) FROM service_positions;")
    if ($positionCountAfterAssignment -ne $initialPositionCount) {
        throw "Assignments must not auto-create service positions from imported I2 text."
    }

    $badFinalize = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/position-assignments/$assignmentId/finalize" -Headers $thHeaders -Body @{
        endDate = "2026-01-31"
        changeReason = $null
        notes = $null
    }
    Assert-Status -Response $badFinalize -ExpectedStatus 400 -Message "End date before start date must be rejected."

    $finalize = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/position-assignments/$assignmentId/finalize" -Headers $adminHeaders -Body @{
        endDate = "2026-03-01"
        changeReason = $null
        notes = "Cierre sin motivo obligatorio"
    }
    Assert-Status -Response $finalize -ExpectedStatus 200 -Message "ADMIN must finalize assignments."
    if ($finalize.Body.status -ne "FINALIZADA" -or $null -eq $finalize.Body.endDate) {
        throw "Finalized assignment must return FINALIZADA and endDate."
    }

    Write-Host "I3 assignments verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employee_position_assignments WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification') OR position_id IN (SELECT id FROM service_positions WHERE code IN ('$activeCode', '$inactiveCode')); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM service_positions WHERE code IN ('$activeCode', '$inactiveCode');"
    $env:PGPASSWORD = $originalPassword
}
