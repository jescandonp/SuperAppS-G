param(
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$Database = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$psqlExe = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$verificationScript = Join-Path $workspaceRoot "db\tests\007_i9_scheduling_contract.sql"
$originalPassword = $env:PGPASSWORD

if (-not (Test-Path $psqlExe)) {
    throw "psql not found: $psqlExe"
}

try {
    $env:PGPASSWORD = $AppPassword
    & $psqlExe -U $AppUser -d $Database -f $verificationScript

    if ($LASTEXITCODE -ne 0) {
        throw "I9 persistence verification failed with exit code $LASTEXITCODE."
    }
}
finally {
    $env:PGPASSWORD = $originalPassword
}
