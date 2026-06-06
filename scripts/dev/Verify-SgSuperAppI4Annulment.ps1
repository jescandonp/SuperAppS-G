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
$identification = "I4-ANNUL-ACTIVE"
$signerName = "Firmante I4 Anulacion"

function Invoke-Postgres { param([string]$Sql) & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -c $Sql | Out-Null; if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." } }
function Get-Scalar { param([string]$Sql) $result = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -t -A -v ON_ERROR_STOP=1 -c $Sql; if ($LASTEXITCODE -ne 0) { throw "PostgreSQL scalar command failed." }; return $result.Trim() }
function Get-SessionHeaders { param([string]$Username, [string]$Password) $body = @{ username = $Username; password = $Password } | ConvertTo-Json; $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body; return @{ Authorization = "Bearer $($response.sessionToken)" } }
function Invoke-JsonRequest {
    param([string]$Method, [string]$Uri, [hashtable]$Headers, [object]$Body = $null)
    try {
        $parameters = @{ Uri = $Uri; Method = $Method; Headers = $Headers; UseBasicParsing = $true }
        if ($null -ne $Body) { $parameters.ContentType = "application/json"; $parameters.Body = ($Body | ConvertTo-Json -Depth 6) }
        $response = Invoke-WebRequest @parameters
        return @{ Status = [int]$response.StatusCode; Body = ($response.Content | ConvertFrom-Json) }
    } catch { if ($null -eq $_.Exception.Response) { throw }; return @{ Status = [int]$_.Exception.Response.StatusCode; Body = $null } }
}
function Assert-Status { param([hashtable]$Response, [int]$ExpectedStatus, [string]$Message) if ($Response.Status -ne $ExpectedStatus) { throw "$Message Expected HTTP $ExpectedStatus, received $($Response.Status)." } }

try {
    Invoke-Postgres @"
DELETE FROM labor_certificate_variables WHERE certificate_id IN (SELECT id FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification'));
DELETE FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification');
DELETE FROM employee_salary_history WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification');
DELETE FROM employees WHERE identification_number = '$identification';
DELETE FROM certificate_signers WHERE full_name = '$signerName';
INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, contract_type, record_status, source)
VALUES ('CC', '$identification', 'Empleado Anulacion I4', 'ACTIVO', 'Guarda', DATE '2025-01-01', 'Indefinido', 'ACTIVO', 'TEST');
INSERT INTO employee_salary_history (employee_id, base_salary_amount, effective_from, source)
SELECT id, 2200000, DATE '2025-01-01', 'TEST' FROM employees WHERE identification_number = '$identification';
INSERT INTO certificate_signers (full_name, job_title, valid_from, status)
VALUES ('$signerName', 'Directora TH', DATE '2026-01-01', 'ACTIVO');
"@
    $employeeId = [long](Get-Scalar "SELECT id FROM employees WHERE identification_number = '$identification';")
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $body = @{ employeeId = $employeeId; purpose = "TRAMITE_GENERAL"; issueDate = "2026-03-01"; variables = @() }
    $generated = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/approve-generate" -Headers $thHeaders -Body $body
    Assert-Status -Response $generated -ExpectedStatus 200 -Message "TH must generate certificate before annulment."
    $certificateId = [long]$generated.Body.id
    $pdfPath = Get-Scalar "SELECT pdf_path FROM labor_certificates WHERE id = $certificateId;"
    $snapshotBefore = Get-Scalar "SELECT snapshot_payload::text FROM labor_certificates WHERE id = $certificateId;"

    $blank = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/$certificateId/annul" -Headers $thHeaders -Body @{ reason = " " }
    Assert-Status -Response $blank -ExpectedStatus 400 -Message "Blank annulment reason must be rejected."

    $forbidden = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/$certificateId/annul" -Headers $gerenciaHeaders -Body @{ reason = "Solicitud invalida" }
    Assert-Status -Response $forbidden -ExpectedStatus 403 -Message "GERENCIA must not annul certificates."

    $annulled = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificates/$certificateId/annul" -Headers $thHeaders -Body @{ reason = "Solicitud del empleado" }
    Assert-Status -Response $annulled -ExpectedStatus 200 -Message "TH must annul generated certificate."
    if ($annulled.Body.status -ne "ANULADA") { throw "Annulled certificate must return ANULADA status." }
    if (-not (Test-Path -LiteralPath $pdfPath)) { throw "Annulment must not delete generated PDF." }
    $snapshotAfter = Get-Scalar "SELECT snapshot_payload::text FROM labor_certificates WHERE id = $certificateId;"
    if ($snapshotBefore -ne $snapshotAfter) { throw "Annulment must not mutate certificate snapshot." }
    $annulmentReason = Get-Scalar "SELECT annulment_reason FROM labor_certificates WHERE id = $certificateId;"
    if ($annulmentReason -ne "Solicitud del empleado") { throw "Annulment reason must be persisted." }

    $downloadPath = Join-Path $env:TEMP "sg-i4-annulled-download.pdf"
    Invoke-WebRequest -Uri "$ApiBaseUrl/portal/certificates/$certificateId/download" -Headers $thHeaders -OutFile $downloadPath -UseBasicParsing
    $header = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($downloadPath)[0..4])
    if ($header -ne "%PDF-") { throw "Annulled certificate PDF must remain downloadable." }

    Write-Host "I4 annulment verification completed."
}
finally {
    $paths = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -t -A -v ON_ERROR_STOP=1 -c "SELECT pdf_path FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification') AND pdf_path IS NOT NULL;"
    foreach ($path in $paths) { if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path.Trim())) { Remove-Item -LiteralPath $path.Trim() -Force } }
    Invoke-Postgres "DELETE FROM labor_certificate_variables WHERE certificate_id IN (SELECT id FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification')); DELETE FROM labor_certificates WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification'); DELETE FROM employee_salary_history WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$identification'); DELETE FROM employees WHERE identification_number = '$identification'; DELETE FROM certificate_signers WHERE full_name = '$signerName';"
    $env:PGPASSWORD = $originalPassword
}
