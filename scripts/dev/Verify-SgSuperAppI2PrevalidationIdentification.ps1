param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$DatabaseName = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"
$fixturePath = Join-Path $PSScriptRoot "task6-identification-fixture.csv"
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
    Invoke-PostgresScalar "delete from employees where identification_number in ('I2-ID-SHARED','I2-ID-EXISTING');"
    Invoke-PostgresScalar "insert into employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) values ('CC','I2-ID-EXISTING','Empleado existente','ACTIVO','Guarda','2026-01-01');"

    @"
tipo_documento,documento,nombre,estado,cargo,fecha_ingreso,salario
CC,,Identificacion Vacia,ACTIVO,Guarda,2026-01-01,1500000
CC,#N/A,Identificacion NA,ACTIVO,Guarda,2026-01-01,1500000
CC,I2-ID-SHARED,CC Original,ACTIVO,Guarda,2026-01-01,1500000
CE,I2-ID-SHARED,CE Mismo Numero,ACTIVO,Guarda,2026-01-01,1500000
CC,I2-ID-SHARED,CC Duplicado,ACTIVO,Guarda,2026-01-01,1500000
CC,I2-ID-EXISTING,CC Existente,ACTIVO,Guarda,2026-01-01,1500000
CE,I2-ID-EXISTING,CE No Existente,ACTIVO,Guarda,2026-01-01,1500000
"@ | Set-Content -LiteralPath $fixturePath -Encoding utf8

    $loginBody = @{ username = "th.sg"; password = "Th123456" } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
    $headers = @{ Authorization = "Bearer $($login.sessionToken)" }
    $result = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $headers -Form @{ file = Get-Item -LiteralPath $fixturePath }

    $classifications = Invoke-PostgresScalar "select string_agg(classification, ',' order by row_number) from import_batch_rows where import_batch_id = $($result.batchId);"
    if ($classifications -ne "INCOMPLETO,INCOMPLETO,VALIDO,VALIDO,DUPLICADO,DUPLICADO,VALIDO") {
        throw "Unexpected functional-key classifications: '$classifications'."
    }

    $duplicateErrors = Invoke-PostgresScalar "select count(*) from import_batch_errors where import_batch_id = $($result.batchId) and error_type = 'DUPLICADO';"
    if ([int]$duplicateErrors -ne 2) {
        throw "Expected exactly two duplicate errors, received '$duplicateErrors'."
    }

    $incompleteErrors = Invoke-PostgresScalar "select count(*) from import_batch_errors where import_batch_id = $($result.batchId) and field_name = 'numero_identificacion' and error_type = 'INCOMPLETO';"
    if ([int]$incompleteErrors -ne 2) {
        throw "Expected empty and #N/A identification errors."
    }

    Write-Host "I2 prevalidation identification verification completed."
}
finally {
    Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
    Invoke-PostgresScalar "delete from employees where identification_type = 'CC' and identification_number = 'I2-ID-EXISTING';"
    $env:PGPASSWORD = $originalPassword
}
