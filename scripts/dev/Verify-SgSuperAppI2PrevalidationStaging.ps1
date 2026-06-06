param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$DatabaseName = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"
$fixturePath = Join-Path $PSScriptRoot "task6-staging-fixture.csv"
$originalPassword = $env:PGPASSWORD
$env:PGPASSWORD = $AppPassword
$psqlExe = "C:\Program Files\PostgreSQL\18\bin\psql.exe"

function Invoke-PostgresScalar {
    param([string]$Sql)
    $result = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -t -A -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
    return ($result | Select-Object -First 1)
}

try {
    @"
documento,nombre,estado,cargo,fecha_ingreso,salario
I2-STAGE-VALID,Empleado Valido,ACTIVO,Guarda,2026-01-01,1500000
,Empleado Incompleto,ACTIVO,Guarda,2026-01-01,1500000
I2-STAGE-VALID,Empleado Duplicado,ACTIVO,Guarda,2026-01-01,1500000
I2-STAGE-INVALID,Empleado Erroneo,ACTIVO,Guarda,fecha-invalida,abc
"@ | Set-Content -LiteralPath $fixturePath -Encoding utf8

    $beforeEmployees = Invoke-PostgresScalar "select count(*) from employees where identification_number in ('I2-STAGE-VALID','I2-STAGE-INVALID');"
    $loginBody = @{ username = "th.sg"; password = "Th123456" } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
    $headers = @{ Authorization = "Bearer $($login.sessionToken)" }
    $result = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $headers -Form @{ file = Get-Item -LiteralPath $fixturePath }

    $classifications = Invoke-PostgresScalar "select string_agg(classification, ',' order by row_number) from import_batch_rows where import_batch_id = $($result.batchId);"
    if ($classifications -ne "VALIDO,INCOMPLETO,DUPLICADO,ERRONEO") {
        throw "Expected staged classifications VALIDO,INCOMPLETO,DUPLICADO,ERRONEO, received '$classifications'."
    }

    $linkedErrors = Invoke-PostgresScalar "select count(*) from import_batch_errors where import_batch_id = $($result.batchId) and import_batch_row_id is not null;"
    $totalErrors = Invoke-PostgresScalar "select count(*) from import_batch_errors where import_batch_id = $($result.batchId);"
    if ($linkedErrors -ne $totalErrors -or [int]$totalErrors -eq 0) {
        throw "Every prevalidation error must be linked to its staged row."
    }

    $validPayload = Invoke-PostgresScalar "select normalized_payload->>'full_name' from import_batch_rows where import_batch_id = $($result.batchId) and classification = 'VALIDO';"
    if ($validPayload -ne "Empleado Valido") {
        throw "Normalized payload was not persisted."
    }

    $afterEmployees = Invoke-PostgresScalar "select count(*) from employees where identification_number in ('I2-STAGE-VALID','I2-STAGE-INVALID');"
    if ($beforeEmployees -ne $afterEmployees) {
        throw "Prevalidation must not create employees."
    }

    Write-Host "I2 prevalidation staging verification completed."
}
finally {
    Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
    $env:PGPASSWORD = $originalPassword
}
