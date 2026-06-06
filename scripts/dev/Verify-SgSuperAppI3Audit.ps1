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
$employeeIdentification = "I3-AUDIT-EMP"
$positionCode = "I3-AUDIT-POS"

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

function Assert-Status {
    param([hashtable]$Response, [int]$ExpectedStatus, [string]$Message)

    if ($Response.Status -ne $ExpectedStatus) {
        throw "$Message Expected HTTP $ExpectedStatus, received $($Response.Status)."
    }
}

try {
    Invoke-Postgres @"
DELETE FROM audit_log
WHERE entity_type IN ('SERVICE_POSITION', 'POSITION_ASSIGNMENT')
  AND (entity_id IN (
        SELECT id::text FROM service_positions WHERE code = '$positionCode'
    ) OR entity_id IN (
        SELECT epa.id::text
        FROM employee_position_assignments epa
        JOIN employees e ON e.id = epa.employee_id
        WHERE e.identification_number = '$employeeIdentification'
    ));
DELETE FROM employee_position_assignments
WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification')
   OR position_id IN (SELECT id FROM service_positions WHERE code = '$positionCode');
DELETE FROM employees WHERE identification_number = '$employeeIdentification';
DELETE FROM service_positions WHERE code = '$positionCode';

INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, record_status, source)
VALUES ('CC', '$employeeIdentification', 'Empleado Auditoria I3', 'ACTIVO', 'Guarda', DATE '2026-01-01', 'ACTIVO', 'TEST');
"@

    $employeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$employeeIdentification';")
    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"

    $createPosition = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions" -Headers $adminHeaders -Body @{
        code = $positionCode
        name = "Puesto Auditoria I3"
        clientText = "Cliente Auditoria"
        locationText = "Bogota"
        notes = "Creado para auditoria"
    }
    Assert-Status -Response $createPosition -ExpectedStatus 200 -Message "Position creation must succeed."
    $positionId = [long]$createPosition.Body.id

    $updatePosition = Invoke-JsonRequest -Method "PUT" -Uri "$ApiBaseUrl/portal/positions/$positionId" -Headers $thHeaders -Body @{
        code = $positionCode
        name = "Puesto Auditoria I3 Actualizado"
        clientText = "Cliente Auditoria TH"
        locationText = "Medellin"
        notes = "Actualizado para auditoria"
    }
    Assert-Status -Response $updatePosition -ExpectedStatus 200 -Message "Position update must succeed."

    $createAssignment = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$employeeId/position-assignments" -Headers $adminHeaders -Body @{
        positionId = $positionId
        startDate = "2026-02-01"
        changeReason = "Alta inicial"
        notes = "Creada para auditoria"
    }
    Assert-Status -Response $createAssignment -ExpectedStatus 200 -Message "Assignment creation must succeed."
    $assignmentId = [long]$createAssignment.Body.id

    $finalizeAssignment = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/position-assignments/$assignmentId/finalize" -Headers $thHeaders -Body @{
        endDate = "2026-02-15"
        changeReason = "Rotacion"
        notes = "Finalizada para auditoria"
    }
    Assert-Status -Response $finalizeAssignment -ExpectedStatus 200 -Message "Assignment finalization must succeed."

    $inactivatePosition = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions/$positionId/inactivate" -Headers $adminHeaders
    Assert-Status -Response $inactivatePosition -ExpectedStatus 200 -Message "Position inactivation must succeed."

    $positionAudit = Get-Scalar @"
SELECT string_agg(actor_username || ':' || event_type || ':' || result, '|')
FROM (
    SELECT actor_username, event_type, result
    FROM audit_log
    WHERE entity_type = 'SERVICE_POSITION'
      AND entity_id = '$positionId'
    ORDER BY id
) events;
"@
    if ($positionAudit -ne "admin.sg:SERVICE_POSITION_CREATED:SUCCESS|th.sg:SERVICE_POSITION_UPDATED:SUCCESS|admin.sg:SERVICE_POSITION_INACTIVATED:SUCCESS") {
        throw "Unexpected service position audit trail '$positionAudit'."
    }

    $assignmentAudit = Get-Scalar @"
SELECT string_agg(actor_username || ':' || event_type || ':' || result, '|')
FROM (
    SELECT actor_username, event_type, result
    FROM audit_log
    WHERE entity_type = 'POSITION_ASSIGNMENT'
      AND entity_id = '$assignmentId'
    ORDER BY id
) events;
"@
    if ($assignmentAudit -ne "admin.sg:POSITION_ASSIGNMENT_CREATED:SUCCESS|th.sg:POSITION_ASSIGNMENT_FINALIZED:SUCCESS") {
        throw "Unexpected assignment audit trail '$assignmentAudit'."
    }

    $assignmentDetail = Get-Scalar "SELECT (detail->>'employee_id') || ':' || (detail->>'position_id') || ':' || (detail->>'status') FROM audit_log WHERE entity_type = 'POSITION_ASSIGNMENT' AND entity_id = '$assignmentId' AND event_type = 'POSITION_ASSIGNMENT_CREATED' ORDER BY id DESC LIMIT 1;"
    if ($assignmentDetail -ne "$employeeId`:$positionId`:VIGENTE") {
        throw "Unexpected assignment creation audit detail '$assignmentDetail'."
    }

    $finalizeDetail = Get-Scalar "SELECT (detail->>'end_date') || ':' || (detail->>'status') FROM audit_log WHERE entity_type = 'POSITION_ASSIGNMENT' AND entity_id = '$assignmentId' AND event_type = 'POSITION_ASSIGNMENT_FINALIZED' ORDER BY id DESC LIMIT 1;"
    if ($finalizeDetail -ne "2026-02-15:FINALIZADA") {
        throw "Unexpected assignment finalization audit detail '$finalizeDetail'."
    }

    Write-Host "I3 audit verification completed."
}
finally {
    Invoke-Postgres @"
DELETE FROM audit_log
WHERE entity_type IN ('SERVICE_POSITION', 'POSITION_ASSIGNMENT')
  AND (entity_id IN (
        SELECT id::text FROM service_positions WHERE code = '$positionCode'
    ) OR entity_id IN (
        SELECT epa.id::text
        FROM employee_position_assignments epa
        JOIN employees e ON e.id = epa.employee_id
        WHERE e.identification_number = '$employeeIdentification'
    ));
DELETE FROM employee_position_assignments
WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification')
   OR position_id IN (SELECT id FROM service_positions WHERE code = '$positionCode');
DELETE FROM employees WHERE identification_number = '$employeeIdentification';
DELETE FROM service_positions WHERE code = '$positionCode';
"@
    $env:PGPASSWORD = $originalPassword
}
