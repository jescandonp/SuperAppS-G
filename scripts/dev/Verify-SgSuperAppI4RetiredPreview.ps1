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
$retiredIdentification = "I4-PREVIEW-RETIRED-OK"
$noReasonIdentification = "I4-PREVIEW-RETIRED-NOREASON"
$noDateIdentification = "I4-PREVIEW-RETIRED-NODATE"
$signerName = "Firmante I4 Preview Retirado"

function Invoke-Postgres {
    param([string]$Sql)
    & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -c $Sql | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
}

function Assert-PostgresFails {
    param([string]$Sql, [string]$Message)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -c $Sql > $null 2> $null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($exitCode -eq 0) { throw $Message }
}

function Get-Scalar {
    param([string]$Sql)
    $result = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -t -A -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL scalar command failed." }
    return $result.Trim()
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
            $parameters.Body = ($Body | ConvertTo-Json -Depth 5)
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
    Invoke-Postgres @"
DELETE FROM labor_certificate_variables WHERE certificate_id IN (SELECT id FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$retiredIdentification', '$noReasonIdentification', '$noDateIdentification')));
DELETE FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$retiredIdentification', '$noReasonIdentification', '$noDateIdentification'));
DELETE FROM employee_salary_history WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$retiredIdentification', '$noReasonIdentification', '$noDateIdentification'));
DELETE FROM employees WHERE identification_number IN ('$retiredIdentification', '$noReasonIdentification', '$noDateIdentification');
DELETE FROM certificate_signers WHERE full_name = '$signerName';

INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, termination_date, termination_reason, contract_type, record_status, source)
VALUES
    ('CC', '$retiredIdentification', 'Empleado Retirado Preview I4', 'RETIRADO', 'Supervisor', DATE '2022-01-10', DATE '2025-12-31', 'Terminacion de contrato', 'Fijo', 'ACTIVO', 'TEST'),
    ('CC', '$noReasonIdentification', 'Empleado Retirado Sin Motivo I4', 'RETIRADO', 'Guarda', DATE '2023-02-01', DATE '2025-11-30', NULL, 'Fijo', 'ACTIVO', 'TEST');

INSERT INTO certificate_signers (full_name, job_title, valid_from, status)
VALUES ('$signerName', 'Directora TH', DATE '2026-01-01', 'ACTIVO');
"@

    Assert-PostgresFails -Message "Retired employee without termination date must be rejected by persistence." -Sql @"
INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, termination_date, termination_reason, contract_type, record_status, source)
VALUES ('CC', '$noDateIdentification', 'Empleado Retirado Sin Fecha I4', 'RETIRADO', 'Guarda', DATE '2023-01-01', NULL, 'Terminacion de contrato', 'Fijo', 'ACTIVO', 'TEST');
"@

    $retiredEmployeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$retiredIdentification';")
    $noReasonEmployeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$noReasonIdentification';")
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"

    $cesantias = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $thHeaders -Body @{
        employeeId = $retiredEmployeeId
        purpose = "CESANTIAS"
        issueDate = "2026-03-01"
        variables = @()
    }
    Assert-Status -Response $cesantias -ExpectedStatus 200 -Message "TH must preview retired certificate for cesantias."
    if ($cesantias.Body.certificateType -ne "RETIRADO" -or $cesantias.Body.terminationDate -ne "2025-12-31" -or $null -ne $cesantias.Body.baseSalary) {
        throw "Retired preview must return retired snapshot with termination data and without active salary."
    }
    if ($cesantias.Body.previewContent -notmatch "cesantias") {
        throw "Retired cesantias preview must include contextual cesantias text."
    }

    $interesado = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $thHeaders -Body @{
        employeeId = $retiredEmployeeId
        purpose = "INTERESADO"
        issueDate = "2026-03-01"
        variables = @()
    }
    Assert-Status -Response $interesado -ExpectedStatus 200 -Message "TH must preview retired certificate for interesado."
    if ($interesado.Body.previewContent -notmatch "interesado") {
        throw "Retired interesado preview must include contextual interested-party text."
    }

    $noReason = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $thHeaders -Body @{
        employeeId = $noReasonEmployeeId
        purpose = "TRAMITE_GENERAL"
        issueDate = "2026-03-01"
        variables = @()
    }
    Assert-Status -Response $noReason -ExpectedStatus 409 -Message "Retired employee without termination reason must be rejected."

    $forbidden = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $gerenciaHeaders -Body @{
        employeeId = $retiredEmployeeId
        purpose = "CESANTIAS"
        issueDate = "2026-03-01"
        variables = @()
    }
    Assert-Status -Response $forbidden -ExpectedStatus 403 -Message "GERENCIA must not preview retired certificates."

    Write-Host "I4 retired preview verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM labor_certificate_variables WHERE certificate_id IN (SELECT id FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$retiredIdentification', '$noReasonIdentification', '$noDateIdentification'))); DELETE FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$retiredIdentification', '$noReasonIdentification', '$noDateIdentification')); DELETE FROM employee_salary_history WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$retiredIdentification', '$noReasonIdentification', '$noDateIdentification')); DELETE FROM employees WHERE identification_number IN ('$retiredIdentification', '$noReasonIdentification', '$noDateIdentification'); DELETE FROM certificate_signers WHERE full_name = '$signerName';"
    $env:PGPASSWORD = $originalPassword
}
