param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$DatabaseName = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"
$fixturePath = Join-Path $PSScriptRoot "task6-salary-summary-fixture.csv"
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
documento;nombre;estado;cargo;fecha_ingreso;salario
I2-SALARY-FORMAT;Salario Formateado;ACTIVO;Guarda;2026-01-01;`$ 1.500.000,50
I2-SALARY-ZERO;Salario Cero;ACTIVO;Guarda;2026-01-01;0
I2-SALARY-EMPTY;Salario Vacio;ACTIVO;Guarda;2026-01-01;
I2-SALARY-NEGATIVE;Salario Negativo;ACTIVO;Guarda;2026-01-01;-1
I2-SALARY-TEXT;Salario Texto;ACTIVO;Guarda;2026-01-01;abc
"@ | Set-Content -LiteralPath $fixturePath -Encoding utf8

    $loginBody = @{ username = "th.sg"; password = "Th123456" } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
    $headers = @{ Authorization = "Bearer $($login.sessionToken)" }
    $result = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $headers -Form @{ file = Get-Item -LiteralPath $fixturePath }

    $rows = Invoke-PostgresScalar "select string_agg((normalized_payload->>'base_salary') || ':' || classification, ',' order by row_number) from import_batch_rows where import_batch_id = $($result.batchId);"
    if ($rows -ne "1500000.50:VALIDO,0.00:VALIDO,:INCOMPLETO,-1:ERRONEO,abc:ERRONEO") {
        throw "Unexpected salary normalization/classification: '$rows'."
    }

    $summary = Invoke-PostgresScalar "select total_records || ':' || valid_records || ':' || incomplete_records || ':' || duplicate_records || ':' || invalid_records from import_batches where id = $($result.batchId);"
    $staging = Invoke-PostgresScalar "select count(*) || ':' || count(*) filter (where classification = 'VALIDO') || ':' || count(*) filter (where classification = 'INCOMPLETO') || ':' || count(*) filter (where classification = 'DUPLICADO') || ':' || count(*) filter (where classification = 'ERRONEO') from import_batch_rows where import_batch_id = $($result.batchId);"
    if ($summary -ne $staging -or $summary -ne "5:2:1:0:2") {
        throw "Batch summary '$summary' does not match staging '$staging'."
    }

    Write-Host "I2 prevalidation salary and summary verification completed."
}
finally {
    Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
    $env:PGPASSWORD = $originalPassword
}
