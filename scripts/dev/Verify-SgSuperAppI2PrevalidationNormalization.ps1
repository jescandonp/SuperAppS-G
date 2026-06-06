param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$DatabaseName = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"
$fixturePath = Join-Path $PSScriptRoot "task6-normalization-fixture.csv"
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
tipo_documento,documento,nombre,estado,cargo,fecha_ingreso,salario
,  I2-NORM-CC  ,  Empleado CC  , activo ,  Guarda  ,2026-01-01,1500000
 ce ,  I2-NORM-CE  ,  Empleado CE  , activo ,  Supervisor  ,2025-01-01,1500000
PASAPORTE,I2-NORM-BAD,Empleado Invalido,ACTIVO,Guarda,2026-01-01,1500000
"@ | Set-Content -LiteralPath $fixturePath -Encoding utf8

    $loginBody = @{ username = "th.sg"; password = "Th123456" } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
    $headers = @{ Authorization = "Bearer $($login.sessionToken)" }
    $result = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $headers -Form @{ file = Get-Item -LiteralPath $fixturePath }

    $rows = Invoke-PostgresScalar "select string_agg(identification_type || ':' || coalesce(identification_number, '') || ':' || classification, ',' order by row_number) from import_batch_rows where import_batch_id = $($result.batchId);"
    if ($rows -ne "CC:I2-NORM-CC:VALIDO,CE:I2-NORM-CE:VALIDO,PASAPORTE:I2-NORM-BAD:ERRONEO") {
        throw "Unexpected normalized identification rows: '$rows'."
    }

    $normalized = Invoke-PostgresScalar "select (normalized_payload->>'employment_status') || ':' || (normalized_payload->>'full_name') from import_batch_rows where import_batch_id = $($result.batchId) and identification_number = 'I2-NORM-CC';"
    if ($normalized -ne "ACTIVO:Empleado CC") {
        throw "Expected normalized status and name, received '$normalized'."
    }

    $sourceName = Invoke-PostgresScalar "select source_payload->>'nombre' from import_batch_rows where import_batch_id = $($result.batchId) and identification_number = 'I2-NORM-CC';"
    if ($sourceName -ne "  Empleado CC  ") {
        throw "Source payload must preserve the original value, received '$sourceName'."
    }

    $invalidTypeErrors = Invoke-PostgresScalar "select count(*) from import_batch_errors where import_batch_id = $($result.batchId) and field_name = 'tipo_identificacion' and error_type = 'VALOR_NO_RECONOCIDO';"
    if ([int]$invalidTypeErrors -ne 1) {
        throw "Expected one unsupported identification type error."
    }

    Write-Host "I2 prevalidation normalization verification completed."
}
finally {
    Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
    $env:PGPASSWORD = $originalPassword
}
