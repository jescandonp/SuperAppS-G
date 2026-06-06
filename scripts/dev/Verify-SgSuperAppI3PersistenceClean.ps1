param(
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$Database = "sg_superapp_dev",
    [string]$VerificationSchema = "i3_verify_clean"
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$psqlExe = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$scripts = @(
    (Join-Path $workspaceRoot "db\migrations\001_identity_and_access.sql"),
    (Join-Path $workspaceRoot "db\migrations\002_employee_master.sql"),
    (Join-Path $workspaceRoot "db\migrations\003_i2_persistence_completion.sql"),
    (Join-Path $workspaceRoot "db\migrations\005_i3_service_positions_assignments.sql"),
    (Join-Path $workspaceRoot "db\tests\003_i3_persistence_contract.sql")
)
$originalPassword = $env:PGPASSWORD
$originalOptions = $env:PGOPTIONS

try {
    $env:PGPASSWORD = $AppPassword
    & $psqlExe -U $AppUser -d $Database -c "DROP SCHEMA IF EXISTS $VerificationSchema CASCADE; CREATE SCHEMA $VerificationSchema AUTHORIZATION $AppUser;"
    $env:PGOPTIONS = "-c search_path=$VerificationSchema,public"

    foreach ($script in $scripts) {
        & $psqlExe -U $AppUser -d $Database -f $script
        if ($LASTEXITCODE -ne 0) {
            throw "Clean I3 persistence verification failed while executing $script."
        }
    }
}
finally {
    $env:PGOPTIONS = $originalOptions
    & $psqlExe -U $AppUser -d $Database -c "DROP SCHEMA IF EXISTS $VerificationSchema CASCADE;"
    $env:PGPASSWORD = $originalPassword
}
