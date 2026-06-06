param([string]$ApiBaseUrl = "http://localhost:5080/api")

$ErrorActionPreference = "Stop"
$fixtureRoot = Join-Path $PSScriptRoot "task5-format-fixtures"

function Get-ThHeaders {
    $body = @{ username = "th.sg"; password = "Th123456" } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($login.sessionToken)" }
}

function Assert-UploadStatus {
    param([string]$Path, [hashtable]$Headers, [int]$ExpectedStatus)

    try {
        $response = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $Headers -Form @{ file = Get-Item -LiteralPath $Path }
        $actualStatus = 200
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw }
        $actualStatus = [int]$_.Exception.Response.StatusCode
        $response = $null
    }

    if ($actualStatus -ne $ExpectedStatus) {
        throw "Expected HTTP $ExpectedStatus for $(Split-Path -Leaf $Path), received $actualStatus."
    }

    return $response
}

function New-MinimalXlsx {
    param([string]$Path)

    $xlsxRoot = Join-Path $fixtureRoot "xlsx-root"
    New-Item -ItemType Directory -Path (Join-Path $xlsxRoot "_rels"),(Join-Path $xlsxRoot "xl\_rels"),(Join-Path $xlsxRoot "xl\worksheets") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $xlsxRoot "[Content_Types].xml") -Value '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>' -NoNewline
    Set-Content -LiteralPath (Join-Path $xlsxRoot "_rels\.rels") -Value '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>' -NoNewline
    Set-Content -LiteralPath (Join-Path $xlsxRoot "xl\workbook.xml") -Value '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Empleados" sheetId="1" r:id="rId1"/></sheets></workbook>' -NoNewline
    Set-Content -LiteralPath (Join-Path $xlsxRoot "xl\_rels\workbook.xml.rels") -Value '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>' -NoNewline
    Set-Content -LiteralPath (Join-Path $xlsxRoot "xl\worksheets\sheet1.xml") -Value '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>documento</t></is></c><c r="B1" t="inlineStr"><is><t>nombre</t></is></c><c r="C1" t="inlineStr"><is><t>estado</t></is></c><c r="D1" t="inlineStr"><is><t>cargo</t></is></c><c r="E1" t="inlineStr"><is><t>fecha_ingreso</t></is></c><c r="F1" t="inlineStr"><is><t>salario</t></is></c></row><row r="2"><c r="A2" t="inlineStr"><is><t>I2-XLSX-001</t></is></c><c r="B2" t="inlineStr"><is><t>Empleado XLSX</t></is></c><c r="C2" t="inlineStr"><is><t>ACTIVO</t></is></c><c r="D2" t="inlineStr"><is><t>Guarda</t></is></c><c r="E2" t="inlineStr"><is><t>2026-01-01</t></is></c><c r="F2"><v>1500000</v></c></row></sheetData></worksheet>' -NoNewline
    Compress-Archive -Path (Join-Path $xlsxRoot "*") -DestinationPath $Path -Force
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fixtureRoot "comma.csv") -Value "documento,nombre,estado,cargo,fecha_ingreso,salario`nI2-COMMA-001,Empleado Coma,ACTIVO,Guarda,2026-01-01,1500000"
    Set-Content -LiteralPath (Join-Path $fixtureRoot "semicolon.csv") -Value "documento;nombre;estado;cargo;fecha_ingreso;salario`nI2-SEMICOLON-001;Empleado Punto Coma;ACTIVO;Guarda;2026-01-01;1500000"
    Set-Content -LiteralPath (Join-Path $fixtureRoot "unknown.csv") -Value "foo,bar,baz`n1,2,3"
    Set-Content -LiteralPath (Join-Path $fixtureRoot "unsupported.txt") -Value "contenido"
    New-Item -ItemType File -Path (Join-Path $fixtureRoot "empty.csv") -Force | Out-Null
    $oversized = [System.IO.File]::Create((Join-Path $fixtureRoot "oversized.csv"))
    $oversized.SetLength(10MB + 1)
    $oversized.Dispose()
    New-MinimalXlsx -Path (Join-Path $fixtureRoot "valid.xlsx")

    $headers = Get-ThHeaders
    Assert-UploadStatus -Path (Join-Path $fixtureRoot "comma.csv") -Headers $headers -ExpectedStatus 200 | Out-Null
    Assert-UploadStatus -Path (Join-Path $fixtureRoot "semicolon.csv") -Headers $headers -ExpectedStatus 200 | Out-Null
    Assert-UploadStatus -Path (Join-Path $fixtureRoot "valid.xlsx") -Headers $headers -ExpectedStatus 200 | Out-Null
    Assert-UploadStatus -Path (Join-Path $fixtureRoot "empty.csv") -Headers $headers -ExpectedStatus 400 | Out-Null
    Assert-UploadStatus -Path (Join-Path $fixtureRoot "oversized.csv") -Headers $headers -ExpectedStatus 400 | Out-Null
    Assert-UploadStatus -Path (Join-Path $fixtureRoot "unknown.csv") -Headers $headers -ExpectedStatus 400 | Out-Null
    Assert-UploadStatus -Path (Join-Path $fixtureRoot "unsupported.txt") -Headers $headers -ExpectedStatus 400 | Out-Null

    Write-Host "I2 import format verification completed."
}
finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}
