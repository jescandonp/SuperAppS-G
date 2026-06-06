param(
    [string]$ApiBaseUrl = "http://localhost:5080/api"
)

$ErrorActionPreference = "Stop"
$fixturePath = Join-Path $PSScriptRoot "task7-rows-fixture.csv"

function Get-SessionHeaders {
    param([string]$Username, [string]$Password)
    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($login.sessionToken)" }
}

function Assert-HttpStatus {
    param([string]$Uri, [hashtable]$Headers, [int]$ExpectedStatus)
    try {
        Invoke-WebRequest -Uri $Uri -Headers $Headers -UseBasicParsing | Out-Null
        $status = 200
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw }
        $status = [int]$_.Exception.Response.StatusCode
    }
    if ($status -ne $ExpectedStatus) {
        throw "Expected HTTP $ExpectedStatus for $Uri, received $status."
    }
}

try {
    @"
documento,nombre,estado,cargo,fecha_ingreso,salario
I2-ROWS-VALID,Empleado Valido,ACTIVO,Guarda,2026-01-01,1500000
,Empleado Incompleto,ACTIVO,Guarda,2026-01-01,1500000
"@ | Set-Content -LiteralPath $fixturePath -Encoding utf8

    $adminHeaders = Get-SessionHeaders "admin.sg" "Admin123"
    $thHeaders = Get-SessionHeaders "th.sg" "Th123456"
    $gerenciaHeaders = Get-SessionHeaders "gerencia.sg" "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders "operaciones.sg" "Operaciones123"
    $result = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $thHeaders -Form @{ file = Get-Item -LiteralPath $fixturePath }

    $allRows = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/rows" -Headers $thHeaders
    if ($allRows.Count -ne 2 -or $allRows[0].normalizedPayload.identification_number -ne "I2-ROWS-VALID") {
        throw "TH must receive the staged rows with normalized payload."
    }

    $incompleteRows = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/rows?classification=INCOMPLETO" -Headers $adminHeaders
    if ($incompleteRows.Count -ne 1 -or $incompleteRows[0].classification -ne "INCOMPLETO") {
        throw "ADMIN classification filter did not return the expected staged row."
    }

    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/rows?classification=NO_EXISTE" -Headers $thHeaders -ExpectedStatus 400
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/rows" -Headers $gerenciaHeaders -ExpectedStatus 403
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/rows" -Headers $operacionesHeaders -ExpectedStatus 403
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/rows" -Headers @{} -ExpectedStatus 401

    Write-Host "I2 import rows verification completed."
}
finally {
    Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
}
