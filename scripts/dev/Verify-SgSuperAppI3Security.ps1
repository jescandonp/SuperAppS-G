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
$employeeIdentification = "I3-SEC-EMP"
$adminCode = "I3-SEC-ADMIN"
$thCode = "I3-SEC-TH"
$readonlyCode = "I3-SEC-RO"

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
        [hashtable]$Headers = @{},
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
        $parsedBody = if ([string]::IsNullOrWhiteSpace($response.Content)) { $null } else { $response.Content | ConvertFrom-Json }
        return @{ Status = [int]$response.StatusCode; Body = $parsedBody }
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
   OR position_id IN (SELECT id FROM service_positions WHERE code IN ('$adminCode', '$thCode', '$readonlyCode'));
DELETE FROM employees WHERE identification_number = '$employeeIdentification';
DELETE FROM service_positions WHERE code IN ('$adminCode', '$thCode', '$readonlyCode');

INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, record_status, source)
VALUES ('CC', '$employeeIdentification', 'Empleado Seguridad I3', 'ACTIVO', 'Guarda', DATE '2026-01-01', 'ACTIVO', 'TEST');

INSERT INTO service_positions (code, name, client_text, location_text, status)
VALUES ('I3-SEC-RO', 'Puesto Solo Lectura I3', 'Cliente Seguridad', 'Bogota', 'ACTIVO');
"@

    $employeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$employeeIdentification';")
    $readonlyPositionId = [long](Get-Scalar "SELECT id FROM service_positions WHERE code = '$readonlyCode';")

    $unauthorizedList = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/positions"
    Assert-Status -Response $unauthorizedList -ExpectedStatus 401 -Message "Anonymous users must not list positions."

    $unauthorizedAssignments = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments"
    Assert-Status -Response $unauthorizedAssignments -ExpectedStatus 401 -Message "Anonymous users must not read assignment history."

    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"

    foreach ($headers in @($adminHeaders, $thHeaders, $gerenciaHeaders, $operacionesHeaders)) {
        $list = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/positions?status=ACTIVO" -Headers $headers
        Assert-Status -Response $list -ExpectedStatus 200 -Message "All authenticated roles must list positions."
    }

    $adminCreate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions" -Headers $adminHeaders -Body @{
        code = $adminCode
        name = "Puesto Seguridad Admin I3"
        clientText = "Cliente Seguridad"
        locationText = "Bogota"
        notes = "Creado por ADMIN"
    }
    Assert-Status -Response $adminCreate -ExpectedStatus 200 -Message "ADMIN must create positions."
    $adminPositionId = [long]$adminCreate.Body.id

    $thCreate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions" -Headers $thHeaders -Body @{
        code = $thCode
        name = "Puesto Seguridad TH I3"
        clientText = "Cliente Seguridad"
        locationText = "Cali"
        notes = "Creado por TH"
    }
    Assert-Status -Response $thCreate -ExpectedStatus 200 -Message "TH must create positions."
    $thPositionId = [long]$thCreate.Body.id

    foreach ($headers in @($gerenciaHeaders, $operacionesHeaders)) {
        $createDenied = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions" -Headers $headers -Body @{
            code = "I3-SEC-DENY"
            name = "No autorizado"
            clientText = "Cliente"
            locationText = "Bogota"
            notes = $null
        }
        Assert-Status -Response $createDenied -ExpectedStatus 403 -Message "Read-only roles must not create positions."
    }

    $adminUpdate = Invoke-JsonRequest -Method "PUT" -Uri "$ApiBaseUrl/portal/positions/$adminPositionId" -Headers $adminHeaders -Body @{
        code = $adminCode
        name = "Puesto Seguridad Admin I3 Actualizado"
        clientText = "Cliente Seguridad"
        locationText = "Medellin"
        notes = "Actualizado por ADMIN"
    }
    Assert-Status -Response $adminUpdate -ExpectedStatus 200 -Message "ADMIN must update positions."

    $thInactivate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions/$thPositionId/inactivate" -Headers $thHeaders
    Assert-Status -Response $thInactivate -ExpectedStatus 200 -Message "TH must inactivate positions."

    foreach ($headers in @($gerenciaHeaders, $operacionesHeaders)) {
        $updateDenied = Invoke-JsonRequest -Method "PUT" -Uri "$ApiBaseUrl/portal/positions/$readonlyPositionId" -Headers $headers -Body @{
            code = $readonlyCode
            name = "Puesto Solo Lectura I3"
            clientText = "Cliente"
            locationText = "Bogota"
            notes = "No debe actualizar"
        }
        Assert-Status -Response $updateDenied -ExpectedStatus 403 -Message "Read-only roles must not update positions."

        $inactivateDenied = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions/$readonlyPositionId/inactivate" -Headers $headers
        Assert-Status -Response $inactivateDenied -ExpectedStatus 403 -Message "Read-only roles must not inactivate positions."
    }

    $assignmentCreate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $adminHeaders -Body @{
        positionId = $adminPositionId
        startDate = "2026-02-01"
        changeReason = "Asignacion seguridad"
        notes = "Creada por ADMIN"
    }
    Assert-Status -Response $assignmentCreate -ExpectedStatus 200 -Message "ADMIN must create assignments."
    $assignmentId = [long]$assignmentCreate.Body.id

    foreach ($headers in @($gerenciaHeaders, $operacionesHeaders)) {
        $history = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $headers
        Assert-Status -Response $history -ExpectedStatus 200 -Message "Read-only roles must read assignment history."
        if (@($history.Body).Count -ne 1) {
            throw "Assignment history must expose the active assignment to read-only roles."
        }

        $createAssignmentDenied = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $headers -Body @{
            positionId = $readonlyPositionId
            startDate = "2026-02-02"
            changeReason = "No autorizado"
            notes = $null
        }
        Assert-Status -Response $createAssignmentDenied -ExpectedStatus 403 -Message "Read-only roles must not create assignments."
    }

    foreach ($headers in @($adminHeaders, $thHeaders, $gerenciaHeaders, $operacionesHeaders)) {
        $positionAssignments = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/positions/$adminPositionId/assignments" -Headers $headers
        Assert-Status -Response $positionAssignments -ExpectedStatus 200 -Message "All roles must read assignments by position."
        if (@($positionAssignments.Body).Count -ne 1) {
            throw "Position detail must expose current assignment history to all roles."
        }
    }

    $finalize = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/position-assignments/$assignmentId/finalize" -Headers $thHeaders -Body @{
        endDate = "2026-02-10"
        changeReason = "Cierre de seguridad"
        notes = "Finalizada por TH"
    }
    Assert-Status -Response $finalize -ExpectedStatus 200 -Message "TH must finalize assignments."

    foreach ($headers in @($gerenciaHeaders, $operacionesHeaders)) {
        $finalizeDenied = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/position-assignments/$assignmentId/finalize" -Headers $headers -Body @{
            endDate = "2026-02-11"
            changeReason = "No autorizado"
            notes = $null
        }
        Assert-Status -Response $finalizeDenied -ExpectedStatus 403 -Message "Read-only roles must not finalize assignments."
    }

    Write-Host "I3 security verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employee_position_assignments WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification') OR position_id IN (SELECT id FROM service_positions WHERE code IN ('$adminCode', '$thCode', '$readonlyCode')); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM service_positions WHERE code IN ('$adminCode', '$thCode', '$readonlyCode');"
    $env:PGPASSWORD = $originalPassword
}
