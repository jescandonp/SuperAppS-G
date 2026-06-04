param(
    [string]$Urls = "http://localhost:5080"
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$apiProject = Join-Path $workspaceRoot "apps\sg-superapp-api\sg-superapp-api.csproj"
$dotnetExe = "C:\tmp\dotnet6\dotnet.exe"

if (-not (Test-Path $apiProject)) {
    throw "API project not found: $apiProject"
}

if (-not (Test-Path $dotnetExe)) {
    throw "dotnet executable not found: $dotnetExe"
}

$env:DOTNET_CLI_HOME = "C:\tmp\dotnet-home"
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
$env:DOTNET_NOLOGO = "1"

& $dotnetExe run --urls $Urls --project $apiProject

