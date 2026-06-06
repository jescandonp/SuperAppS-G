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
$employeeIdentification = "I4-VARIABLES-EMP"
$signerName = "Firmante I4 Variables"

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
DELETE FROM labor_certificate_variables WHERE certificate_id IN (SELECT id FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'));
DELETE FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification');
DELETE FROM employee_salary_history WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification');
DELETE FROM employees WHERE identification_number = '$employeeIdentification';
DELETE FROM certificate_signers WHERE full_name = '$signerName';

INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, contract_type, record_status, source)
VALUES ('CC', '$employeeIdentification', 'Empleado Variables I4', 'ACTIVO', 'Guarda', DATE '2025-01-01', 'Indefinido', 'ACTIVO', 'TEST');

INSERT INTO employee_salary_history (employee_id, base_salary_amount, effective_from, source)
SELECT id, 2000000, DATE '2025-01-01', 'TEST'
FROM employees
WHERE identification_number = '$employeeIdentification';

INSERT INTO certificate_signers (full_name, job_title, valid_from, status)
VALUES ('$signerName', 'Directora TH', DATE '2026-01-01', 'ACTIVO');
"@

    $employeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$employeeIdentification';")
    $salaryCountBefore = [long](Get-Scalar "SELECT count(*) FROM employee_salary_history WHERE employee_id = $employeeId;")
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"

    $preview = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $thHeaders -Body @{
        employeeId = $employeeId
        purpose = "ENTIDAD_FINANCIERA"
        issueDate = "2026-03-01"
        variables = @(
            @{ conceptCode = "aux_transporte"; conceptLabel = "Auxilio de transporte"; amount = 162000; notes = "Mes marzo" },
            @{ conceptCode = "extras"; conceptLabel = "Horas extras"; amount = 250000; notes = $null }
        )
    }
    Assert-Status -Response $preview -ExpectedStatus 200 -Message "TH must preview active certificate with variables."
    if (@($preview.Body.variables).Count -ne 2) {
        throw "Preview must return manual variables."
    }
    if ($preview.Body.previewContent -notlike "*Variables manuales*" -or $preview.Body.previewContent -notlike "*Auxilio de transporte*") {
        throw "Preview content must include manual variables when present."
    }

    $invalidVariable = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/preview" -Headers $thHeaders -Body @{
        employeeId = $employeeId
        purpose = "ENTIDAD_FINANCIERA"
        issueDate = "2026-03-01"
        variables = @(@{ conceptCode = "extras"; conceptLabel = "Horas extras"; amount = -1; notes = $null })
    }
    Assert-Status -Response $invalidVariable -ExpectedStatus 400 -Message "Negative variables must be rejected."

    $salaryCountAfter = [long](Get-Scalar "SELECT count(*) FROM employee_salary_history WHERE employee_id = $employeeId;")
    if ($salaryCountAfter -ne $salaryCountBefore) {
        throw "Manual variables must not modify employee salary history."
    }

    Write-Host "I4 salary variables verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM labor_certificate_variables WHERE certificate_id IN (SELECT id FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification')); DELETE FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'); DELETE FROM employee_salary_history WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM certificate_signers WHERE full_name = '$signerName';"
    $env:PGPASSWORD = $originalPassword
}
