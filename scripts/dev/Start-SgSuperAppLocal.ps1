param(
    [string]$ApiUrl = "http://localhost:5080",
    [string]$FrontendUrl = "http://localhost:3000"
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$apiScript = Join-Path $PSScriptRoot "Start-SgSuperAppApi.ps1"
$frontendSource = Join-Path $workspaceRoot "apps\sg-superapp-web"
$runStamp = Get-Date -Format "yyyyMMdd-HHmmss"
$frontendRun = "C:\tmp\sg-superapp-web-run-$runStamp"
$nodeExe = "C:\Program Files\nodejs\node.exe"
$npmCli = "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js"

if (-not (Test-Path $apiScript)) {
    throw "API start script not found: $apiScript"
}

if (-not (Test-Path $frontendSource)) {
    throw "Frontend source path not found: $frontendSource"
}

if (-not (Test-Path $nodeExe)) {
    throw "Node executable not found: $nodeExe"
}

if (-not (Test-Path $npmCli)) {
    throw "npm cli not found: $npmCli"
}

New-Item -ItemType Directory -Path $frontendRun | Out-Null
Copy-Item -Path (Join-Path $frontendSource "*") -Destination $frontendRun -Recurse -Force

$frontendEnv = Join-Path $frontendRun ".env.local"
Set-Content -Path $frontendEnv -Value "VITE_API_BASE_URL=$ApiUrl/api"

$apiOut = Join-Path $workspaceRoot "apps\sg-superapp-api\.api.out.log"
$apiErr = Join-Path $workspaceRoot "apps\sg-superapp-api\.api.err.log"
$webOut = Join-Path $frontendRun ".live.out.log"
$webErr = Join-Path $frontendRun ".live.err.log"

Get-Process sg-superapp-api -ErrorAction SilentlyContinue | Stop-Process -Force

Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy","Bypass","-File",$apiScript,"-Urls",$ApiUrl -WindowStyle Hidden -RedirectStandardOutput $apiOut -RedirectStandardError $apiErr
Start-Sleep -Seconds 4

Start-Process -FilePath $nodeExe -ArgumentList "`"$npmCli`"","run","dev" -WorkingDirectory $frontendRun -WindowStyle Hidden -RedirectStandardOutput $webOut -RedirectStandardError $webErr
Start-Sleep -Seconds 6

Write-Host "Frontend: $FrontendUrl"
Write-Host "Backend:  $ApiUrl"
Write-Host "Frontend logs: $webOut"
Write-Host "Backend logs:  $apiOut"
