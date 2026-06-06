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
$activeIdentification = "I4-PREVIEW-ACTIVE"
$noSalaryIdentification = "I4-PREVIEW-NOSALARY"
$retiredIdentification = "I4-PREVIEW-RETIRED"
$signerName = "Firmante I4 Preview Activo"

function Invoke-Postgres {
    param([string]$Sql)
    & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -c $Sql | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
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
DELETE FROM labor_certificate_variables WHERE certificate_id IN (SELECT id FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$activeIdentification', '$noSalaryIdentification', '$retiredIdentification')));
DELETE FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$activeIdentification', '$noSalaryIdentification', '$retiredIdentification'));
DELETE FROM employee_salary_history WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$activeIdentification', '$noSalaryIdentification', '$retiredIdentification'));
DELETE FROM employees WHERE identification_number IN ('$activeIdentification', '$noSalaryIdentification', '$retiredIdentification');
DELETE FROM certificate_signers WHERE full_name = '$signerName';

INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, termination_date, termination_reason, contract_type, record_status, source)
VALUES
    ('CC', '$activeIdentification', 'Empleado Activo Preview I4', 'ACTIVO', 'Guarda', DATE '2025-01-01', NULL, NULL, 'Indefinido', 'ACTIVO', 'TEST'),
    ('CC', '$noSalaryIdentification', 'Empleado Sin Salario I4', 'ACTIVO', 'Guarda', DATE '2025-01-01', NULL, NULL, 'Indefinido', 'ACTIVO', 'TEST'),
    ('CC', '$retiredIdentification', 'Empleado Retirado Preview I4', 'RETIRADO', 'Guarda', DATE '2024-01-01', DATE '2025-01-01', 'Fin contrato', 'Fijo', 'ACTIVO', 'TEST');

INSERT INTO employee_salary_history (employee_id, base_salary_amount, effective_from, source)
SELECT id, 1800000, DATE '2025-01-01', 'TEST'
FROM employees
WHERE identification_number = '$activeIdentification';

INSERT INTO certificate_signers (full_name, job_title, valid_from, status)
VALUES ('$signerName', 'Directora TH', DATE '2026-01-01', 'ACTIVO');
"@

    $activeEmployeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$activeIdentification';")
    $noSalaryEmployeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$noSalaryIdentification';")
    $retiredEmployeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$retiredIdentification';")
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"

    $preview = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $thHeaders -Body @{
        employeeId = $activeEmployeeId
        purpose = "TRAMITE_GENERAL"
        issueDate = "2026-03-01"
        variables = @()
    }
    Assert-Status -Response $preview -ExpectedStatus 200 -Message "TH must preview active certificate."
    if ($preview.Body.certificateType -ne "ACTIVO" -or $preview.Body.baseSalary -ne 1800000 -or $preview.Body.variables.Count -ne 0) {
        throw "Active preview must return active snapshot without variables."
    }

    $noSalary = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $thHeaders -Body @{
        employeeId = $noSalaryEmployeeId
        purpose = "TRAMITE_GENERAL"
        issueDate = "2026-03-01"
        variables = @()
    }
    Assert-Status -Response $noSalary -ExpectedStatus 409 -Message "Active employee without salary must be rejected."

    $retired = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $thHeaders -Body @{
        employeeId = $retiredEmployeeId
        purpose = "TRAMITE_GENERAL"
        issueDate = "2026-03-01"
        variables = @()
    }
    Assert-Status -Response $retired -ExpectedStatus 200 -Message "Preview endpoint must route retired employee to retired certificate."
    if ($retired.Body.certificateType -ne "RETIRADO") {
        throw "Retired employee must return retired certificate type."
    }

    Invoke-Postgres "UPDATE certificate_signers SET status = 'INACTIVO' WHERE full_name = '$signerName';"
    $noSigner = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $thHeaders -Body @{
        employeeId = $activeEmployeeId
        purpose = "TRAMITE_GENERAL"
        issueDate = "2026-03-01"
        variables = @()
    }
    Assert-Status -Response $noSigner -ExpectedStatus 409 -Message "Preview without active signer must be rejected."

    $forbidden = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $gerenciaHeaders -Body @{
        employeeId = $activeEmployeeId
        purpose = "TRAMITE_GENERAL"
        issueDate = "2026-03-01"
        variables = @()
    }
    Assert-Status -Response $forbidden -ExpectedStatus 403 -Message "GERENCIA must not preview certificates."

    Write-Host "I4 active preview verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM labor_certificate_variables WHERE certificate_id IN (SELECT id FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$activeIdentification', '$noSalaryIdentification', '$retiredIdentification'))); DELETE FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$activeIdentification', '$noSalaryIdentification', '$retiredIdentification')); DELETE FROM employee_salary_history WHERE employee_id IN (SELECT id FROM employees WHERE identification_number IN ('$activeIdentification', '$noSalaryIdentification', '$retiredIdentification')); DELETE FROM employees WHERE identification_number IN ('$activeIdentification', '$noSalaryIdentification', '$retiredIdentification'); DELETE FROM certificate_signers WHERE full_name = '$signerName';"
    $env:PGPASSWORD = $originalPassword
}
