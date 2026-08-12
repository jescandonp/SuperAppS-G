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
$constraintSchemaName = "${schemaName}_constraint"
$incompatibleSchemaName = "${schemaName}_incompatible"
$sequenceSchemaName = "${schemaName}_sequence"
$typeErrorSchemaName = "${schemaName}_type_error"
$originalPassword = $env:PGPASSWORD
$originalPgOptions = $env:PGOPTIONS

if (-not (Test-Path $psqlExe)) { throw "psql not found: $psqlExe" }
if ($schemaName -notmatch '^sg_i9_verify_[0-9]+_[0-9]{17}$') { throw "Unsafe verification schema name." }
if ($partialSchemaName -notmatch '^sg_i9_verify_[0-9]+_[0-9]{17}_partial$') { throw "Unsafe partial verification schema name." }
if ($constraintSchemaName -notmatch '^sg_i9_verify_[0-9]+_[0-9]{17}_constraint$') { throw "Unsafe constraint verification schema name." }
if ($incompatibleSchemaName -notmatch '^sg_i9_verify_[0-9]+_[0-9]{17}_incompatible$') { throw "Unsafe incompatible verification schema name." }
if ($sequenceSchemaName -notmatch '^sg_i9_verify_[0-9]+_[0-9]{17}_sequence$') { throw "Unsafe sequence verification schema name." }
if ($typeErrorSchemaName -notmatch '^sg_i9_verify_[0-9]+_[0-9]{17}_type_error$') { throw "Unsafe type-error verification schema name." }

function Invoke-PsqlFile([string]$Path) {
    & $psqlExe -X -q -h $HostName -p $Port -U $AppUser -d $Database -f $Path
    if ($LASTEXITCODE -ne 0) { throw "psql failed for $Path with exit code $LASTEXITCODE." }
}

function Invoke-PsqlScalar([string]$Sql) {
    $result = & $psqlExe -X -q -t -A -h $HostName -p $Port -U $AppUser -d $Database -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "psql query failed with exit code $LASTEXITCODE." }
    return ($result -join "`n").Trim()
}

function Initialize-I9Base([string]$Schema) {
    Invoke-PsqlScalar "CREATE SCHEMA $Schema" | Out-Null
    $env:PGOPTIONS = "-c search_path=$Schema"
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\001_identity_and_access.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\002_employee_master.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\005_i3_service_positions_assignments.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\007_i5_training_accreditations.sql")
}

try {
    $env:PGPASSWORD = $AppPassword
    $env:PGOPTIONS = ""

    Initialize-I9Base $partialSchemaName
    Invoke-PsqlScalar "CREATE TABLE shift_templates (id BIGSERIAL PRIMARY KEY); CREATE TABLE i9_constraint_decoy (x integer CONSTRAINT shift_templates_version_check CHECK (x < 0))" | Out-Null
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\010_i9_schedule_versions.sql")
    Invoke-PsqlScalar "INSERT INTO roles(code,name,description) VALUES ('ADMIN','Admin','I9'),('OPERACIONES','Operaciones','I9'),('TH','TH','I9'),('GERENCIA','Gerencia','I9')" | Out-Null
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\seeds\009_i9_scheduling_permissions.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\seeds\010_i9_shift_templates.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\tests\007_i9_scheduling_contract.sql")

    Initialize-I9Base $constraintSchemaName
    Invoke-PsqlScalar "CREATE TABLE shift_templates (id BIGSERIAL PRIMARY KEY, CONSTRAINT shift_templates_version_check CHECK (id > 0))" | Out-Null
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\010_i9_schedule_versions.sql")
    $repairedConstraint = Invoke-PsqlScalar "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='shift_templates'::regclass AND conname='shift_templates_version_check'"
    if ($repairedConstraint -notmatch 'version > 0') { throw "Incorrect same-table constraint was not repaired." }

    Initialize-I9Base $sequenceSchemaName
    Invoke-PsqlScalar "CREATE TABLE shift_templates (id INTEGER PRIMARY KEY, code TEXT, name varchar(180), version integer, effective_from date, effective_to date, mandatory_by_default boolean, status varchar(20)); INSERT INTO shift_templates(id,code,name,version,effective_from,mandatory_by_default,status) VALUES (9000,'EXISTING','Existing row',1,CURRENT_DATE,true,'ACTIVO')" | Out-Null
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\010_i9_schedule_versions.sql")
    $convergedTypes = Invoke-PsqlScalar "SELECT format_type(a.atttypid,a.atttypmod) FROM pg_attribute a WHERE a.attrelid='shift_templates'::regclass AND a.attname IN ('id','code') ORDER BY a.attname"
    if ($convergedTypes -ne "character varying(30)`nbigint") { throw "Compatible INTEGER/TEXT columns did not converge to BIGINT/VARCHAR(30)." }
    $generatedId = Invoke-PsqlScalar "INSERT INTO shift_templates(code,name,version,effective_from) VALUES ('GENERATED','Generated row',1,CURRENT_DATE) RETURNING id"
    if ([long]$generatedId -le 9000) { throw "Converged shift_templates sequence did not advance beyond the existing ID." }
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql")
    $rerunId = Invoke-PsqlScalar "INSERT INTO shift_templates(code,name,version,effective_from) VALUES ('RERUN','Rerun row',1,CURRENT_DATE) RETURNING id"
    if ([long]$rerunId -le [long]$generatedId) { throw "Converged shift_templates sequence was not stable across rerun." }

    Initialize-I9Base $typeErrorSchemaName
    Invoke-PsqlScalar "CREATE TABLE shift_templates (id INTEGER PRIMARY KEY, code TEXT, name varchar(180), version integer, effective_from date, effective_to date, mandatory_by_default boolean, status varchar(20)); INSERT INTO shift_templates(id,code,name,version,effective_from,mandatory_by_default,status) VALUES (1,repeat('X',31),'Too long',1,CURRENT_DATE,true,'ACTIVO')" | Out-Null
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $typeErrorOutput = & $psqlExe -X -h $HostName -p $Port -U $AppUser -d $Database -f (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql") 2>&1
        $typeErrorExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($typeErrorExitCode -eq 0) { throw "Oversized TEXT fixture unexpectedly converged to VARCHAR(30)." }
    if (($typeErrorOutput -join "`n") -notmatch 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: shift_templates\.code has type text, expected character varying\(30\)') {
        throw "Oversized TEXT fixture did not return the canonical type error."
    }

    Initialize-I9Base $incompatibleSchemaName
    Invoke-PsqlScalar "CREATE TABLE shift_templates (id BIGSERIAL PRIMARY KEY, code varchar(50)); INSERT INTO shift_templates(code) VALUES ('PARTIAL')" | Out-Null
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $partialOutput = & $psqlExe -X -h $HostName -p $Port -U $AppUser -d $Database -f (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql") 2>&1
        $partialExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($partialExitCode -eq 0) { throw "Partial I9 fixture unexpectedly accepted data without a safe backfill." }
    if (($partialOutput -join "`n") -notmatch 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: shift_templates\.name contains NULL values') {
        throw "Partial I9 fixture did not return the canonical actionable migration error."
    }
    $env:PGOPTIONS = ""

    Initialize-I9Base $schemaName
    Invoke-PsqlScalar "INSERT INTO roles(code,name,description) VALUES ('ADMIN','Admin','I9'),('OPERACIONES','Operaciones','I9'),('TH','TH','I9'),('GERENCIA','Gerencia','I9')" | Out-Null
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\010_i9_schedule_versions.sql")

    Invoke-PsqlScalar "INSERT INTO scheduling_rules(source_level,scope_type,severity,effective_from,parameters) VALUES ('VERIFICACION','GLOBAL','INFORMATIVA',CURRENT_DATE,'{}')" | Out-Null
    $rulesBefore = Invoke-PsqlScalar "SELECT count(*) FROM scheduling_rules"
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\seeds\009_i9_scheduling_permissions.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\seeds\010_i9_shift_templates.sql")
    $stepIdsBefore = Invoke-PsqlScalar "SELECT string_agg(sts.id::text, ',' ORDER BY st.code, sts.step_order) FROM shift_template_steps sts JOIN shift_templates st ON st.id=sts.template_id WHERE st.code IN ('2X2','4X2','6X1')"

    Invoke-PsqlScalar "INSERT INTO shift_template_steps(template_id,step_order,shift_code) SELECT id,99,'X' FROM shift_templates WHERE code='2X2' AND version=1" | Out-Null
    Invoke-PsqlScalar "INSERT INTO role_permissions(role_id,module_code,action_code,allowed) SELECT id,'SCHEDULING','CONFIGURE',TRUE FROM roles WHERE code='TH'" | Out-Null
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\009_i9_scheduling.sql")
    Invoke-PsqlFile (Join-Path $workspaceRoot "db\migrations\010_i9_schedule_versions.sql")
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
        & $psqlExe -X -q -h $HostName -p $Port -U $AppUser -d $Database -c "DROP SCHEMA IF EXISTS $constraintSchemaName CASCADE" | Out-Null
        & $psqlExe -X -q -h $HostName -p $Port -U $AppUser -d $Database -c "DROP SCHEMA IF EXISTS $incompatibleSchemaName CASCADE" | Out-Null
        & $psqlExe -X -q -h $HostName -p $Port -U $AppUser -d $Database -c "DROP SCHEMA IF EXISTS $sequenceSchemaName CASCADE" | Out-Null
        & $psqlExe -X -q -h $HostName -p $Port -U $AppUser -d $Database -c "DROP SCHEMA IF EXISTS $typeErrorSchemaName CASCADE" | Out-Null
    }
    $env:PGPASSWORD = $originalPassword
    $env:PGOPTIONS = $originalPgOptions
}

Write-Host "I9 PERSISTENCE PASS"
