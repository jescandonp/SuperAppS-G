param(
    [string]$PostgresUser = "postgres",
    [string]$PostgresPassword = "",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$Database = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$psqlExe = "C:\Program Files\PostgreSQL\18\bin\psql.exe"

if (-not (Test-Path $psqlExe)) {
    throw "psql not found: $psqlExe"
}

$bootstrapScript = Join-Path $workspaceRoot "db\bootstrap\001_create_sg_superapp_dev.sql"
$migrationScripts = @(
    (Join-Path $workspaceRoot "db\migrations\001_identity_and_access.sql"),
    (Join-Path $workspaceRoot "db\migrations\002_employee_master.sql"),
    (Join-Path $workspaceRoot "db\migrations\003_i2_persistence_completion.sql"),
    (Join-Path $workspaceRoot "db\migrations\004_i2_security_sessions.sql")
)
$seedScripts = @(
    (Join-Path $workspaceRoot "db\seeds\001_roles_and_permissions.sql"),
    (Join-Path $workspaceRoot "db\seeds\002_employee_master_seed.sql"),
    (Join-Path $workspaceRoot "db\seeds\003_import_batches_seed.sql"),
    (Join-Path $workspaceRoot "db\seeds\004_i2_security_users_permissions.sql")
)

$originalPassword = $env:PGPASSWORD

try {
    if ($PostgresPassword) {
        $env:PGPASSWORD = $PostgresPassword
    }

    & $psqlExe -U $PostgresUser -d postgres -f $bootstrapScript

    $env:PGPASSWORD = $AppPassword
    foreach ($migrationScript in $migrationScripts) {
        & $psqlExe -U $AppUser -d $Database -f $migrationScript
    }

    foreach ($seedScript in $seedScripts) {
        & $psqlExe -U $AppUser -d $Database -f $seedScript
    }
}
finally {
    $env:PGPASSWORD = $originalPassword
}
