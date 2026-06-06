param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$DatabaseName = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"
$fixturePath = Join-Path $PSScriptRoot "task8-confirm-fixture.csv"
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
    Invoke-PostgresScalar "delete from employees where identification_number in ('I2-CONFIRM-VALID','I2-CONFIRM-INCOMPLETE');"
    @"
tipo_documento;documento;nombre;estado;cargo;fecha_ingreso;salario
CE;I2-CONFIRM-VALID;Empleado Importado;ACTIVO;Guarda;2026-01-15;`$ 1.500.000,50
CC;I2-CONFIRM-INCOMPLETE;;ACTIVO;Guarda;2026-01-15;1500000
"@ | Set-Content -LiteralPath $fixturePath -Encoding utf8

    $adminHeaders = Get-SessionHeaders "admin.sg" "Admin123"
    $thHeaders = Get-SessionHeaders "th.sg" "Th123456"
    $gerenciaHeaders = Get-SessionHeaders "gerencia.sg" "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders "operaciones.sg" "Operaciones123"
    $result = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $thHeaders -Form @{ file = Get-Item -LiteralPath $fixturePath }

    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/confirm" -Headers $adminHeaders -ExpectedStatus 403
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/confirm" -Headers $gerenciaHeaders -ExpectedStatus 403
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/confirm" -Headers $operacionesHeaders -ExpectedStatus 403
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/confirm" -Headers @{} -ExpectedStatus 401

    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/confirm" -Headers $thHeaders -ExpectedStatus 200
    $imported = Invoke-PostgresScalar "select count(*) from employees where identification_type = 'CE' and identification_number = 'I2-CONFIRM-VALID' and source = 'IMPORT';"
    $notImported = Invoke-PostgresScalar "select count(*) from employees where identification_number = 'I2-CONFIRM-INCOMPLETE';"
    if ([int]$imported -ne 1 -or [int]$notImported -ne 0) { throw "Confirmation must import only valid staged rows." }

    $salary = Invoke-PostgresScalar "select s.base_salary_amount || ':' || s.effective_from || ':' || coalesce(s.effective_to::text, 'OPEN') || ':' || s.source from employee_salary_history s join employees e on e.id = s.employee_id where e.identification_number = 'I2-CONFIRM-VALID';"
    if ($salary -ne "1500000.50:2026-01-15:OPEN:IMPORT") { throw "Unexpected imported salary '$salary'." }

    $batch = Invoke-PostgresScalar "select status || ':' || valid_records || ':' || (imported_at is not null)::text from import_batches where id = $($result.batchId);"
    if ($batch -ne "IMPORTADA:1:true") { throw "Unexpected imported batch state '$batch'." }

    $audit = Invoke-PostgresScalar "select actor_username || ':' || event_type || ':' || result || ':' || (detail->>'imported_records') from audit_log where entity_type = 'IMPORT_BATCH' and entity_id = '$($result.batchId)' order by id desc limit 1;"
    if ($audit -ne "th.sg:IMPORT_CONFIRMED:SUCCESS:1") { throw "Unexpected import audit '$audit'." }

    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/confirm" -Headers $thHeaders -ExpectedStatus 409
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/cancel" -Headers $thHeaders -ExpectedStatus 409
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/999999999/confirm" -Headers $thHeaders -ExpectedStatus 404

    Write-Host "I2 import confirmation verification completed."
}
finally {
    Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
    Invoke-PostgresScalar "delete from employees where identification_number in ('I2-CONFIRM-VALID','I2-CONFIRM-INCOMPLETE');"
    $env:PGPASSWORD = $originalPassword
}
