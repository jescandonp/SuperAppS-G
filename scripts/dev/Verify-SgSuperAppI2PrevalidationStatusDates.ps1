param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$DatabaseName = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"
$fixturePath = Join-Path $PSScriptRoot "task6-status-dates-fixture.csv"
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
documento,nombre,estado,cargo,fecha_ingreso,fecha_retiro,salario
I2-STATE-ACTIVE,Activo Inferido,,Guarda,2026-01-01,,1500000
I2-STATE-RETIRED,Retirado Inferido,,Guarda,2025-01-01,2026-01-01,1500000
I2-STATE-UNKNOWN,Estado Desconocido,SUSPENDIDO,Guarda,2026-01-01,,1500000
I2-STATE-BEFORE,Retiro Anterior,RETIRADO,Guarda,2026-02-01,2026-01-31,1500000
I2-STATE-EQUAL,Retiro Igual,RETIRADO,Guarda,2026-01-01,2026-01-01,1500000
"@ | Set-Content -LiteralPath $fixturePath -Encoding utf8

    $loginBody = @{ username = "th.sg"; password = "Th123456" } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
    $headers = @{ Authorization = "Bearer $($login.sessionToken)" }
    $result = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $headers -Form @{ file = Get-Item -LiteralPath $fixturePath }

    $rows = Invoke-PostgresScalar "select string_agg((normalized_payload->>'employment_status') || ':' || classification, ',' order by row_number) from import_batch_rows where import_batch_id = $($result.batchId);"
    if ($rows -ne "ACTIVO:VALIDO,RETIRADO:VALIDO,SUSPENDIDO:ERRONEO,RETIRADO:ERRONEO,RETIRADO:VALIDO") {
        throw "Unexpected status/date classifications: '$rows'."
    }

    $dateErrors = Invoke-PostgresScalar "select count(*) from import_batch_errors where import_batch_id = $($result.batchId) and field_name = 'fecha_retiro' and error_type = 'FECHA_INCONSISTENTE';"
    if ([int]$dateErrors -ne 1) {
        throw "Expected exactly one inconsistent retirement date error."
    }

    $unknownErrors = Invoke-PostgresScalar "select count(*) from import_batch_errors where import_batch_id = $($result.batchId) and field_name = 'estado_laboral' and error_type = 'VALOR_NO_RECONOCIDO';"
    if ([int]$unknownErrors -ne 1) {
        throw "Expected exactly one unknown employment status error."
    }

    Write-Host "I2 prevalidation status and dates verification completed."
}
finally {
    Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
    $env:PGPASSWORD = $originalPassword
}
