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
$identification = "I4-IMMUTABLE-ACTIVE"
$signerName = "Firmante I4 Inmutable"

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

try {
    Invoke-Postgres @"
DELETE FROM labor_certificate_variables WHERE certificate_id IN (SELECT id FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification'));
DELETE FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification');
DELETE FROM employee_salary_history WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification');
DELETE FROM employees WHERE identification_number = '$identification';
DELETE FROM certificate_signers WHERE full_name IN ('$signerName', '$signerName Cambiado');

INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, termination_date, termination_reason, contract_type, record_status, source)
VALUES ('CC', '$identification', 'Empleado Snapshot Original I4', 'ACTIVO', 'Guarda', DATE '2025-01-01', NULL, NULL, 'Indefinido', 'ACTIVO', 'TEST');

INSERT INTO employee_salary_history (employee_id, base_salary_amount, effective_from, source)
SELECT id, 1950000, DATE '2025-01-01', 'TEST'
FROM employees
WHERE identification_number = '$identification';

INSERT INTO certificate_signers (full_name, job_title, valid_from, status)
VALUES ('$signerName', 'Directora TH', DATE '2026-01-01', 'ACTIVO');
"@

    $employeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$identification';")
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $body = @{
        employeeId = $employeeId
        purpose = "TRAMITE_GENERAL"
        issueDate = "2026-03-01"
        variables = @()
    } | ConvertTo-Json -Depth 6

    $generated = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/certificates/approve-generate" -Method Post -Headers $thHeaders -ContentType "application/json" -Body $body
    $certificateId = [long]$generated.id
    $pdfPath = Get-Scalar "SELECT pdf_path FROM labor_certificates WHERE id = $certificateId;"
    $initialHash = (Get-FileHash -LiteralPath $pdfPath -Algorithm SHA256).Hash

    Invoke-Postgres @"
UPDATE employees
SET full_name = 'Empleado Snapshot Cambiado I4',
    job_title = 'Cargo Cambiado'
WHERE id = $employeeId;

UPDATE certificate_signers
SET full_name = '$signerName Cambiado',
    job_title = 'Cargo Firmante Cambiado'
WHERE full_name = '$signerName';
"@

    $snapshotEmployee = Get-Scalar "SELECT snapshot_payload->>'employeeFullName' FROM labor_certificates WHERE id = $certificateId;"
    $snapshotSigner = Get-Scalar "SELECT snapshot_payload->>'signerFullName' FROM labor_certificates WHERE id = $certificateId;"
    $snapshotSalary = Get-Scalar "SELECT snapshot_payload->>'baseSalary' FROM labor_certificates WHERE id = $certificateId;"
    $finalHash = (Get-FileHash -LiteralPath $pdfPath -Algorithm SHA256).Hash

    if ($snapshotEmployee -ne "Empleado Snapshot Original I4") {
        throw "Snapshot must keep original employee name after employee changes."
    }
    if ($snapshotSigner -ne $signerName) {
        throw "Snapshot must keep original signer name after signer changes."
    }
    if ([decimal]$snapshotSalary -ne 1950000) {
        throw "Snapshot must keep original salary."
    }
    if ($initialHash -ne $finalHash) {
        throw "Generated PDF must not change after master data changes."
    }

    Write-Host "I4 snapshot immutability verification completed."
}
finally {
    $paths = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -t -A -v ON_ERROR_STOP=1 -c "SELECT pdf_path FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification') AND pdf_path IS NOT NULL;"
    foreach ($path in $paths) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path.Trim())) {
            Remove-Item -LiteralPath $path.Trim() -Force
        }
    }
    Invoke-Postgres "DELETE FROM labor_certificate_variables WHERE certificate_id IN (SELECT id FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification')); DELETE FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification'); DELETE FROM employee_salary_history WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification'); DELETE FROM employees WHERE identification_number = '$identification'; DELETE FROM certificate_signers WHERE full_name IN ('$signerName', '$signerName Cambiado');"
    $env:PGPASSWORD = $originalPassword
}
