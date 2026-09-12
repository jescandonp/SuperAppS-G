param(
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$Database = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$psqlExe = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$verificationScript = Join-Path $workspaceRoot "db\tests\006_i6_notifications_contract.sql"
$originalPassword = $env:PGPASSWORD

try {
    $env:PGPASSWORD = $AppPassword
    & $psqlExe -U $AppUser -d $Database -f $verificationScript

    if ($LASTEXITCODE -ne 0) {
        throw "I6 persistence verification failed with exit code $LASTEXITCODE."
    }
}
finally {
    $env:PGPASSWORD = $originalPassword
}
