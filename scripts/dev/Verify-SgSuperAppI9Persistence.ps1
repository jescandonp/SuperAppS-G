param(
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$Database = "sg_superapp_dev",
    [string]$HostName = "localhost",
    [int]$Port = 5432
)

$ErrorActionPreference = "Stop"
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$psqlExe = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$schemaName = "sg_i9_verify_{0}_{1}" -f $PID, (Get-Date -Format "yyyyMMddHHmmssfff")
$partialSchemaName = "${schemaName}_partial"
$originalPassword = $env:PGPASSWORD
$originalPgOptions = $env:PGOPTIONS

if (-not (Test-Path $psqlExe)) { throw "psql not found: $psqlExe" }
if ($schemaName -notmatch '^sg_i9_verify_[0-9]+_[0-9]{17}$') { throw "Unsafe verification schema name." }
if ($partialSchemaName -notmatch '^sg_i9_verify_[0-9]+_[0-9]{17}_partial$') { throw "Unsafe partial verification schema name." }

function Invoke-PsqlFile([string]$Path) {
    & $psqlExe -X -q -h $HostName -p $Port -U $AppUser -d $Database -f $Path
    if ($LASTEXITCODE -ne 0) { throw "psql failed for $Path with exit code $LASTEXITCODE." }
}

function Invoke-PsqlScalar([string]$Sql) {
    $result = & $psqlExe -X -q -t -A -h $HostName -p $Port -U $AppUser -d $Database -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "psql query failed with exit code $LASTEXITCODE." }
    return ($result -join "`n").Trim()
}

try {
    $env:PGPASSWORD = $AppPassword
    $env:PGOPTIONS = ""

    Invoke-PsqlScalar "CREATE SCHEMA $partialSchemaName" | Out-Null
    $env:PGOPTIONS = "-c search_path=$partialSchemaName"
    Invoke-PsqlScalar "CREATE TABLE shift_templates (id BIGINT PRIMARY KEY)" | Out-Null
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $partialOutput = & $psqlExe -X -h $HostName -p $Port -U $AppUser -d $Database -f (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql") 2>&1
        $partialExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($partialExitCode -eq 0) { throw "Partial I9 fixture unexpectedly accepted an incomplete shift_templates table." }
    if (($partialOutput -join "`n") -notmatch 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: missing shift_templates\.code') {
        throw "Partial I9 fixture did not return the canonical actionable migration error."
    }
    $env:PGOPTIONS = ""
    Invoke-PsqlScalar "DROP SCHEMA $partialSchemaName CASCADE" | Out-Null

    Invoke-PsqlScalar "CREATE SCHEMA $schemaName" | Out-Null
    $env:PGOPTIONS = "-c search_path=$schemaName"

    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\001_identity_and_access.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\002_employee_master.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\005_i3_service_positions_assignments.sql")
    Invoke-PsqlScalar "INSERT INTO roles(code,name,description) VALUES ('ADMIN','Admin','I9'),('OPERACIONES','Operaciones','I9'),('TH','TH','I9'),('GERENCIA','Gerencia','I9')" | Out-Null
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql")

    Invoke-PsqlScalar "INSERT INTO scheduling_rules(source_level,scope_type,severity,effective_from,parameters) VALUES ('VERIFICACION','GLOBAL','INFORMATIVA',CURRENT_DATE,'{}')" | Out-Null
    $rulesBefore = Invoke-PsqlScalar "SELECT count(*) FROM scheduling_rules"
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\seeds\009_i9_scheduling_permissions.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\seeds\010_i9_shift_templates.sql")
    $stepIdsBefore = Invoke-PsqlScalar "SELECT string_agg(sts.id::text, ',' ORDER BY st.code, sts.step_order) FROM shift_template_steps sts JOIN shift_templates st ON st.id=sts.template_id WHERE st.code IN ('2X2','4X2','6X1')"

    Invoke-PsqlScalar "INSERT INTO shift_template_steps(template_id,step_order,shift_code) SELECT id,99,'X' FROM shift_templates WHERE code='2X2' AND version=1" | Out-Null
    Invoke-PsqlScalar "INSERT INTO role_permissions(role_id,module_code,action_code,allowed) SELECT id,'SCHEDULING','CONFIGURE',TRUE FROM roles WHERE code='TH'" | Out-Null
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\seeds\009_i9_scheduling_permissions.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\seeds\010_i9_shift_templates.sql")
    $stepIdsAfter = Invoke-PsqlScalar "SELECT string_agg(sts.id::text, ',' ORDER BY st.code, sts.step_order) FROM shift_template_steps sts JOIN shift_templates st ON st.id=sts.template_id WHERE st.code IN ('2X2','4X2','6X1')"
    $rulesAfter = Invoke-PsqlScalar "SELECT count(*) FROM scheduling_rules"

    if ($stepIdsBefore -ne $stepIdsAfter) { throw "I9 template step IDs changed after seed rerun." }
    if ($rulesBefore -ne $rulesAfter) { throw "I9 seeds inserted scheduling rules." }
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\tests\007_i9_scheduling_contract.sql")
}
finally {
    $env:PGOPTIONS = ""
    if ($env:PGPASSWORD) {
        & $psqlExe -X -q -h $HostName -p $Port -U $AppUser -d $Database -c "DROP SCHEMA IF EXISTS $schemaName CASCADE" | Out-Null
        & $psqlExe -X -q -h $HostName -p $Port -U $AppUser -d $Database -c "DROP SCHEMA IF EXISTS $partialSchemaName CASCADE" | Out-Null
    }
    $env:PGPASSWORD = $originalPassword
    $env:PGOPTIONS = $originalPgOptions
}
