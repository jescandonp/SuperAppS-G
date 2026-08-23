param(
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$Database = "sg_superapp_dev",
    [string]$VerificationSchema = "i6_verify_clean"
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$psqlExe = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$scripts = @(
    (Join-Path $workspaceRoot "db\migrations\001_identity_and_access.sql"),
    (Join-Path $workspaceRoot "db\seeds\001_roles_and_permissions.sql"),
    (Join-Path $workspaceRoot "db\migrations\002_employee_master.sql"),
    (Join-Path $workspaceRoot "db\migrations\003_i2_persistence_completion.sql"),
    (Join-Path $workspaceRoot "db\migrations\005_i3_service_positions_assignments.sql"),
    (Join-Path $workspaceRoot "db\seeds\005_i3_positions_permissions.sql"),
    (Join-Path $workspaceRoot "db\migrations\006_i4_labor_certificates.sql"),
    (Join-Path $workspaceRoot "db\seeds\006_i4_certificates_permissions.sql"),
    (Join-Path $workspaceRoot "db\migrations\007_i5_training_accreditations.sql"),
    (Join-Path $workspaceRoot "db\seeds\007_i5_training_permissions.sql"),
    (Join-Path $workspaceRoot "db\migrations\008_i6_notifications.sql"),
    (Join-Path $workspaceRoot "db\seeds\008_i6_notification_permissions.sql"),
    (Join-Path $workspaceRoot "db\tests\006_i6_notifications_contract.sql")
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
            throw "Clean I6 persistence verification failed while executing $script."
        }
    }
}
finally {
    $env:PGOPTIONS = $originalOptions
    & $psqlExe -U $AppUser -d $Database -c "DROP SCHEMA IF EXISTS $VerificationSchema CASCADE;"
    $env:PGPASSWORD = $originalPassword
}
