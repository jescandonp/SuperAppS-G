param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$DatabaseName = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"
$fixturePath = Join-Path $PSScriptRoot "task7-cancel-fixture.csv"
$originalPassword = $env:PGPASSWORD
$env:PGPASSWORD = $AppPassword
$psqlExe = "C:\Program Files\PostgreSQL\18\bin\psql.exe"

function Invoke-PostgresScalar {
    param([string]$Sql)
    $result = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -t -A -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
    return ($result | Select-Object -First 1)
}

function Get-SessionHeaders {
    param([string]$Username, [string]$Password)
    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($login.sessionToken)" }
}

function Assert-HttpStatus {
    param([string]$Uri, [hashtable]$Headers, [int]$ExpectedStatus)
    try {
        Invoke-WebRequest -Uri $Uri -Method Post -Headers $Headers -UseBasicParsing | Out-Null
        $status = 200
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw }
        $status = [int]$_.Exception.Response.StatusCode
    }
    if ($status -ne $ExpectedStatus) {
        throw "Expected HTTP $ExpectedStatus for POST $Uri, received $status."
    }
}

try {
    @"
documento,nombre,estado,cargo,fecha_ingreso,salario
I2-CANCEL-VALID,Empleado Cancelacion,ACTIVO,Guarda,2026-01-01,1500000
"@ | Set-Content -LiteralPath $fixturePath -Encoding utf8

    $adminHeaders = Get-SessionHeaders "admin.sg" "Admin123"
    $thHeaders = Get-SessionHeaders "th.sg" "Th123456"
    $gerenciaHeaders = Get-SessionHeaders "gerencia.sg" "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders "operaciones.sg" "Operaciones123"
    $result = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $thHeaders -Form @{ file = Get-Item -LiteralPath $fixturePath }

    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/cancel" -Headers $adminHeaders -ExpectedStatus 403
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/cancel" -Headers $gerenciaHeaders -ExpectedStatus 403
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/cancel" -Headers $operacionesHeaders -ExpectedStatus 403
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/cancel" -Headers @{} -ExpectedStatus 401

    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/cancel" -Headers $thHeaders -ExpectedStatus 200
    $status = Invoke-PostgresScalar "select status from import_batches where id = $($result.batchId);"
    if ($status -ne "CANCELADA") { throw "Expected CANCELADA status, received '$status'." }

    $audit = Invoke-PostgresScalar "select actor_username || ':' || event_type || ':' || result from audit_log where entity_type = 'IMPORT_BATCH' and entity_id = '$($result.batchId)' order by id desc limit 1;"
    if ($audit -ne "th.sg:IMPORT_CANCELLED:SUCCESS") { throw "Unexpected cancellation audit '$audit'." }

    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/cancel" -Headers $thHeaders -ExpectedStatus 409
    Invoke-PostgresScalar "update import_batches set status = 'IMPORTADA' where id = $($result.batchId);"
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/cancel" -Headers $thHeaders -ExpectedStatus 409
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/999999999/cancel" -Headers $thHeaders -ExpectedStatus 404

    Write-Host "I2 import cancellation verification completed."
}
finally {
    Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
    $env:PGPASSWORD = $originalPassword
}
