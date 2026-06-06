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
$testIdentification = "I2-FILTER-TEST"

function Get-SessionToken {
    $body = @{ username = "th.sg"; password = "Th123456" } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return $response.sessionToken
}

function Invoke-Postgres {
    param([string]$Sql)

    & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -c $Sql | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL command failed."
    }
}

if (-not (Test-Path -LiteralPath $psqlExe)) {
    throw "psql executable not found: $psqlExe"
}

try {
    Invoke-Postgres @"
INSERT INTO employees (
    identification_type,
    identification_number,
    full_name,
    employment_status,
    job_title,
    hire_date,
    record_status,
    source
)
VALUES ('CC', '$testIdentification', 'Empleado Incompleto Filtro I2', 'ACTIVO', 'Guarda de Seguridad', DATE '2026-01-01', 'INCOMPLETO', 'TEST')
ON CONFLICT (identification_type, identification_number) DO UPDATE
SET record_status = 'INCOMPLETO';
"@

    $headers = @{ Authorization = "Bearer $(Get-SessionToken)" }
    $incompleteEmployees = @(Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees?completeness=INCOMPLETO" -Headers $headers)
    $completeEmployees = @(Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees?completeness=COMPLETO" -Headers $headers)

    if ($incompleteEmployees.Count -eq 0 -or @($incompleteEmployees | Where-Object { $_.recordStatus -ne "INCOMPLETO" }).Count -gt 0) {
        throw "The INCOMPLETO filter must return only incomplete employees."
    }

    if (@($completeEmployees | Where-Object { $_.recordStatus -eq "INCOMPLETO" }).Count -gt 0) {
        throw "The COMPLETO filter must exclude incomplete employees."
    }

    Write-Host "I2 employee filter verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employees WHERE identification_type = 'CC' AND identification_number = '$testIdentification';"
    $env:PGPASSWORD = $originalPassword
}
