param(
    [switch]$BuildOnly
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$frontendPath = Join-Path $workspaceRoot "apps\sg-superapp-web"
$junctionRoot = "C:\tmp\sg-superapp-web-dev"
$nodeExe = "C:\Program Files\nodejs\node.exe"
$npmCli = "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js"

if (-not (Test-Path $frontendPath)) {
    throw "Frontend path not found: $frontendPath"
}

if (-not (Test-Path $nodeExe)) {
    throw "Node executable not found: $nodeExe"
}

if (-not (Test-Path $npmCli)) {
    throw "npm cli not found: $npmCli"
}

if (Test-Path $junctionRoot) {
    $item = Get-Item $junctionRoot -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Target path exists and is not a junction: $junctionRoot"
    }
    Remove-Item -LiteralPath $junctionRoot -Force
}

New-Item -ItemType Junction -Path $junctionRoot -Target $frontendPath | Out-Null

Push-Location $junctionRoot
try {
    if ($BuildOnly) {
        & $nodeExe $npmCli run build
    }
    else {
        & $nodeExe $npmCli run dev
    }
}
finally {
    Pop-Location
}

