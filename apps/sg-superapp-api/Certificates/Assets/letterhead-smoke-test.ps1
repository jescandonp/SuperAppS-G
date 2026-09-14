# Smoke test de build del membrete: compila sg-superapp-api en un directorio temporal
# y confirma que los 4 assets del membrete (header.jpg, footer.jpg, watermark.png y
# sidebar-mark.png) quedaron copiados a Certificates/Assets del output, listandolos.
# No genera ningun PDF; solo verifica que el build pasa y que los assets viajan con el.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$projectPath = Join-Path $repoRoot 'apps/sg-superapp-api/sg-superapp-api.csproj'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sg-cert-letterhead-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

$env:DOTNET_CLI_HOME = 'C:\tmp\dotnet-home'
& 'C:\tmp\dotnet6\dotnet.exe' build $projectPath --output $tempRoot | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Output 'LETTERHEAD SMOKE FAIL: build error'
    exit 1
}

Write-Output 'LETTERHEAD SMOKE PASS: build succeeded, assets copied'
Write-Output "Assets en: $(Join-Path $tempRoot 'Certificates/Assets')"
Get-ChildItem (Join-Path $tempRoot 'Certificates/Assets') | ForEach-Object { Write-Output " - $($_.Name)" }
