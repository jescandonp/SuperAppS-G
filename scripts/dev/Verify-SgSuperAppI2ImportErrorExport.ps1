param(
    [string]$ApiBaseUrl = "http://localhost:5080/api"
)

$ErrorActionPreference = "Stop"
$fixturePath = Join-Path $PSScriptRoot "task7-error-export-fixture.csv"
$exportPath = Join-Path $PSScriptRoot "task7-errors-export.csv"

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
,`"Empleado, incompleto`",ACTIVO,Guarda,fecha-invalida,abc
"@ | Set-Content -LiteralPath $fixturePath -Encoding utf8

    $adminHeaders = Get-SessionHeaders "admin.sg" "Admin123"
    $thHeaders = Get-SessionHeaders "th.sg" "Th123456"
    $gerenciaHeaders = Get-SessionHeaders "gerencia.sg" "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders "operaciones.sg" "Operaciones123"
    $result = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $thHeaders -Form @{ file = Get-Item -LiteralPath $fixturePath }
    $errors = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/errors" -Headers $thHeaders

    $response = Invoke-WebRequest -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/errors/export" -Headers $adminHeaders -OutFile $exportPath -PassThru
    if ($response.Headers.'Content-Type' -notlike 'text/csv*') {
        throw "Expected text/csv content type."
    }
    if ($response.Headers.'Content-Disposition' -notlike "*import-errors-$($result.batchId).csv*") {
        throw "Unexpected export filename."
    }

    $csvRows = Import-Csv -LiteralPath $exportPath
    if ($csvRows.Count -ne $errors.Count -or $csvRows[0].fila -ne "$($errors[0].rowNumber)") {
        throw "Exported CSV does not match persisted errors."
    }
    if (($csvRows | Where-Object { $_.tipo_error -eq 'FORMATO_INVALIDO' }).Count -lt 2) {
        throw "Expected formatted invalid errors in CSV."
    }

    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/errors/export" -Headers $gerenciaHeaders -ExpectedStatus 403
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/errors/export" -Headers $operacionesHeaders -ExpectedStatus 403
    Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/$($result.batchId)/errors/export" -Headers @{} -ExpectedStatus 401

    Write-Host "I2 import error export verification completed."
}
finally {
    Remove-Item -LiteralPath $fixturePath,$exportPath -Force -ErrorAction SilentlyContinue
}
