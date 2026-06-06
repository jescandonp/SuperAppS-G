param([string]$ApiBaseUrl = "http://localhost:5080/api")

$ErrorActionPreference = "Stop"
$fixturePath = Join-Path $PSScriptRoot "task5-mapping-fixture.csv"

try {
    @"
documento,nombre,estado,cargo,fecha_ingreso,salario,columna_desconocida
I2-MAP-001,Empleado Mapeo,ACTIVO,Guarda,2026-01-01,1500000,ignorar
"@ | Set-Content -LiteralPath $fixturePath -Encoding utf8

    $loginBody = @{ username = "th.sg"; password = "Th123456" } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
    $headers = @{ Authorization = "Bearer $($login.sessionToken)" }
    $prevalidation = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $headers -Form @{ file = Get-Item -LiteralPath $fixturePath }
    $mappingResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/$($prevalidation.batchId)/mappings" -Headers $headers
    $mappings = @($mappingResponse | ForEach-Object { $_ })

    if ($mappings.Count -ne 7) {
        throw "Expected 7 persisted mappings, received $($mappings.Count)."
    }

    $documentMapping = @($mappings | Where-Object { $_.sourceHeader -eq "documento" })[0]
    if ($documentMapping.targetField -ne "identification_number" -or $documentMapping.mappingStatus -ne "MAPPED") {
        throw "Known header mapping was not persisted correctly."
    }

    $unknownMapping = @($mappings | Where-Object { $_.sourceHeader -eq "columna_desconocida" })[0]
    if ($null -ne $unknownMapping.targetField -or $unknownMapping.mappingStatus -ne "UNMAPPED") {
        throw "Unknown header must be persisted as UNMAPPED."
    }

    Write-Host "I2 import mapping verification completed."
}
finally {
    Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
}
