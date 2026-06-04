param(
    [string]$ApiBaseUrl = "http://localhost:5080/api"
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$frontendPath = Join-Path $workspaceRoot "apps\sg-superapp-web"
$nodeExe = "C:\Program Files\nodejs\node.exe"
$npmCli = "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js"

if (-not (Test-Path $nodeExe)) {
    throw "Node executable not found: $nodeExe"
}

if (-not (Test-Path $npmCli)) {
    throw "npm cli not found: $npmCli"
}

Write-Host "== API health =="
Invoke-RestMethod -Uri "$ApiBaseUrl/health" | Format-List

Write-Host "== Current user =="
Invoke-RestMethod -Uri "$ApiBaseUrl/auth/me" | Format-List

Write-Host "== ADMIN modules =="
Invoke-RestMethod -Uri "$ApiBaseUrl/portal/modules/ADMIN" | Format-Table

Write-Host "== Notifications =="
Invoke-RestMethod -Uri "$ApiBaseUrl/portal/notifications/admin.sg" | Format-Table

Write-Host "== Login success =="
$okBody = @{ username = "admin.sg"; password = "Admin123" } | ConvertTo-Json
Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $okBody | Format-List

Write-Host "== Login failure =="
$badBody = @{ username = "admin.sg"; password = "badpass" } | ConvertTo-Json
try {
    Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $badBody | Out-Null
    throw "Expected login failure did not occur."
}
catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 400) {
        throw
    }
    Write-Host "Expected HTTP 400 confirmed."
}

Write-Host "== Frontend build =="
Push-Location $frontendPath
try {
    & $nodeExe $npmCli run build
}
finally {
    Pop-Location
}

Write-Host "Verification completed."

