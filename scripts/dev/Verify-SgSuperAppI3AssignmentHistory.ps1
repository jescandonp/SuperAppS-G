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
$employeeIdentification = "I3-HISTORY-EMP"
$firstPositionCode = "I3-HISTORY-ONE"
$secondPositionCode = "I3-HISTORY-TWO"

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
   OR position_id IN (SELECT id FROM service_positions WHERE code IN ('$firstPositionCode', '$secondPositionCode'));
DELETE FROM employees WHERE identification_number = '$employeeIdentification';
DELETE FROM service_positions WHERE code IN ('$firstPositionCode', '$secondPositionCode');

INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, record_status, source)
VALUES ('CC', '$employeeIdentification', 'Empleado Historial I3', 'ACTIVO', 'Guarda', DATE '2026-01-01', 'ACTIVO', 'TEST');

INSERT INTO service_positions (code, name, client_text, location_text, status)
VALUES
    ('$firstPositionCode', 'Puesto Historial Uno', 'Cliente Historial', 'Bogota', 'ACTIVO'),
    ('$secondPositionCode', 'Puesto Historial Dos', 'Cliente Historial', 'Cali', 'ACTIVO');
"@

    $employeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$employeeIdentification';")
    $firstPositionId = [long](Get-Scalar "SELECT id FROM service_positions WHERE code = '$firstPositionCode';")
    $secondPositionId = [long](Get-Scalar "SELECT id FROM service_positions WHERE code = '$secondPositionCode';")

    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"

    $firstCreate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $thHeaders -Body @{
        positionId = $firstPositionId
        startDate = "2026-02-01"
        changeReason = "Asignacion inicial"
        notes = $null
    }
    Assert-Status -Response $firstCreate -ExpectedStatus 200 -Message "TH must create the first assignment."

    $firstAssignmentId = [long]$firstCreate.Body.id
    $finalize = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/position-assignments/$firstAssignmentId/finalize" -Headers $adminHeaders -Body @{
        endDate = "2026-02-10"
        changeReason = $null
        notes = $null
    }
    Assert-Status -Response $finalize -ExpectedStatus 200 -Message "ADMIN must finalize the first assignment without reason."

    $secondCreate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $thHeaders -Body @{
        positionId = $secondPositionId
        startDate = "2026-02-11"
        changeReason = "Nueva asignacion"
        notes = "Historial Task 8"
    }
    Assert-Status -Response $secondCreate -ExpectedStatus 200 -Message "TH must create a second active assignment."

    $history = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $gerenciaHeaders
    Assert-Status -Response $history -ExpectedStatus 200 -Message "GERENCIA must read assignment history."
    $items = @($history.Body)
    if ($items.Count -ne 2) {
        throw "Assignment history must return two assignments."
    }

    $current = $items | Where-Object { $_.status -eq "VIGENTE" } | Select-Object -First 1
    $closed = $items | Where-Object { $_.status -eq "FINALIZADA" } | Select-Object -First 1
    if ($null -eq $current -or $current.positionName -ne "Puesto Historial Dos") {
        throw "History must expose the second position as current."
    }

    if ($null -eq $closed -or $closed.positionName -ne "Puesto Historial Uno" -or $closed.endDate -ne "2026-02-10") {
        throw "History must keep the finalized first position with its end date."
    }

    $detail = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees/$employeeId" -Headers $gerenciaHeaders
    Assert-Status -Response $detail -ExpectedStatus 200 -Message "GERENCIA must read employee detail."
    if ($detail.Body.currentServicePositionName -ne "Puesto Historial Dos") {
        throw "Employee detail must expose the current normalized position."
    }

    Write-Host "I3 assignment history verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employee_position_assignments WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification') OR position_id IN (SELECT id FROM service_positions WHERE code IN ('$firstPositionCode', '$secondPositionCode')); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM service_positions WHERE code IN ('$firstPositionCode', '$secondPositionCode');"
    $env:PGPASSWORD = $originalPassword
}
