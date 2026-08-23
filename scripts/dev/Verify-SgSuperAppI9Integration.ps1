param(
    [string]$Database = "sg_superapp_dev",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$ApiBaseUrl = "http://localhost:5087/api"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$dotnet = "C:\tmp\dotnet6\dotnet.exe"
$schema = "sg_i9_close_{0}_{1}" -f $PID, (Get-Date -Format "yyyyMMddHHmmssfff")
$apiLog = Join-Path $root ".codex-tmp\i9-integration-api.log"
$apiErrorLog = Join-Path $root ".codex-tmp\i9-integration-api.err.log"
$exportDirectory = Join-Path $root ".codex-tmp\i9-integration-exports"
$apiProcess = $null
$previousPassword = $env:PGPASSWORD
$previousOptions = $env:PGOPTIONS
$apiUri = [Uri]$ApiBaseUrl
$listenUrl = "{0}://{1}:{2}" -f $apiUri.Scheme, $apiUri.Host, $apiUri.Port

if ($schema -notmatch '^sg_i9_close_[0-9]+_[0-9]{17}$') { throw "Unsafe integration schema." }
if (-not (Test-Path -LiteralPath $psql)) { throw "psql not found." }
if (-not (Test-Path -LiteralPath $dotnet)) { throw "dotnet runtime not found." }
if ($apiUri.Host -notin @("localhost", "127.0.0.1")) { throw "Integration API must use a local host." }

function Invoke-Psql([string]$sql) {
    $result = & $psql -X -q -t -A -h localhost -p 5432 -U $AppUser -d $Database -c $sql
    if ($LASTEXITCODE -ne 0) { throw "psql command failed." }
    return ($result -join "`n").Trim()
}

function Invoke-PsqlFile([string]$path) {
    & $psql -X -q -h localhost -p 5432 -U $AppUser -d $Database -f $path
    if ($LASTEXITCODE -ne 0) { throw "psql failed for $path." }
}

function Wait-ForApi {
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        if ($null -ne $script:apiProcess -and $script:apiProcess.HasExited) {
            throw "I9 integration API exited before becoming ready."
        }
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "$ApiBaseUrl/health" -TimeoutSec 1
            if ($response.StatusCode -eq 200) { return }
        } catch { Start-Sleep -Milliseconds 250 }
    }
    throw "I9 integration API did not become ready."
}

function Invoke-Verifier([string]$name, [string[]]$arguments) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $name) @arguments
    if ($LASTEXITCODE -ne 0) { throw "$name failed with exit code $LASTEXITCODE." }
}

try {
    New-Item -ItemType Directory -Force -Path (Split-Path $apiLog), $exportDirectory | Out-Null
    $env:PGPASSWORD = $AppPassword
    $env:PGOPTIONS = ""
    Invoke-Psql "CREATE SCHEMA $schema" | Out-Null
    $env:PGOPTIONS = "-c search_path=$schema,public"

    foreach ($migration in Get-ChildItem (Join-Path $root "db\migrations") -Filter "*.sql" | Sort-Object Name) {
        Invoke-PsqlFile $migration.FullName
    }
    foreach ($seedName in @("001_roles_and_permissions.sql", "004_i2_security_users_permissions.sql", "009_i9_scheduling_permissions.sql", "010_i9_shift_templates.sql")) {
        Invoke-PsqlFile (Join-Path $root "db\seeds\$seedName")
    }

    Invoke-Psql @"
INSERT INTO clients(code,name,status) VALUES ('I9-CLOSE','Cliente anonimizado de cierre','ACTIVO');
INSERT INTO service_projects(client_id,code,name,effective_from,status)
SELECT id,'I9-CLOSE','Proyecto anonimizado de cierre','2026-01-01','ACTIVO' FROM clients WHERE code='I9-CLOSE';
INSERT INTO service_positions(code,name,project_id,status)
SELECT 'I9-CLOSE-POS','Puesto anonimizado de cierre',id,'ACTIVO' FROM service_projects WHERE code='I9-CLOSE';
INSERT INTO employees(identification_type,identification_number,full_name,employment_status,job_title,hire_date,record_status,source)
VALUES ('CC','I9-CLOSE-EMP','Guarda anonimizado de cierre','ACTIVO','Vigilante','2026-01-01','ACTIVO','VERIFICACION_I9');
"@ | Out-Null
    $projectId = Invoke-Psql "SELECT id FROM service_projects WHERE code='I9-CLOSE'"

    $portProbe = New-Object System.Net.Sockets.TcpClient
    try {
        $portProbe.Connect($apiUri.Host, $apiUri.Port)
        throw "Integration API port $($apiUri.Port) is already in use."
    } catch [System.Net.Sockets.SocketException] {
        # Expected: the isolated API has not started yet.
    } finally {
        $portProbe.Dispose()
    }

    $env:PGOPTIONS = "-c search_path=$schema,public"
    $apiProcess = Start-Process -FilePath $dotnet -ArgumentList "run","--no-build","--urls",$listenUrl -WorkingDirectory (Join-Path $root "apps\sg-superapp-api") -WindowStyle Hidden -RedirectStandardOutput $apiLog -RedirectStandardError $apiErrorLog -PassThru
    Wait-ForApi

    Invoke-Verifier "Verify-SgSuperAppI9Configuration.ps1" @("-ApiBaseUrl",$ApiBaseUrl,"-Database",$Database,"-AppUser",$AppUser,"-AppPassword",$AppPassword)
    Invoke-Verifier "Verify-SgSuperAppI9Eligibility.ps1" @("-ApiBaseUrl",$ApiBaseUrl)
    Invoke-Verifier "Verify-SgSuperAppI9Recommendations.ps1" @("-ApiBaseUrl",$ApiBaseUrl)
    Invoke-Verifier "Verify-SgSuperAppI9ShiftCycles.ps1" @("-ApiBaseUrl",$ApiBaseUrl)
    Invoke-Verifier "Verify-SgSuperAppI9Workflow.ps1" @("-ApiBaseUrl",$ApiBaseUrl,"-ProjectId",$projectId)
    Invoke-Verifier "Verify-SgSuperAppI9Security.ps1" @("-ApiBaseUrl",$ApiBaseUrl,"-ProjectId",$projectId)

    $publishedVersionId = Invoke-Psql "SELECT sv.id FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id WHERE s.project_id=$projectId AND sv.status='PUBLICADA' ORDER BY sv.id DESC LIMIT 1"
    $positionId = Invoke-Psql "SELECT id FROM service_positions WHERE project_id=$projectId ORDER BY id LIMIT 1"
    if ([string]::IsNullOrWhiteSpace($publishedVersionId)) { throw "Workflow did not create a published version." }

    Invoke-Psql "WITH required AS (INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at) VALUES($publishedVersionId,$positionId,'2026-09-01','06:00','18:00') RETURNING id) INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,status,reasons) SELECT $publishedVersionId,id,'VACANTE','[]' FROM required" | Out-Null
    Invoke-Psql "INSERT INTO schedule_exceptions(schedule_version_id,exception_type,reason,responsible) VALUES($publishedVersionId,'SUBSANABLE','Proxima a vencer','operaciones.sg'); INSERT INTO schedule_versions(schedule_id,version_number,status,created_by) SELECT schedule_id,version_number+1,'PROPUESTA','operaciones.sg' FROM schedule_versions WHERE id=$publishedVersionId" | Out-Null
    Invoke-Verifier "Verify-SgSuperAppI9Replanning.ps1" @("-ApiBaseUrl",$ApiBaseUrl,"-VersionId",$publishedVersionId)
    $notificationState = Invoke-Psql "SELECT count(*) || '|' || count(DISTINCT deduplication_key) FROM notification_items WHERE source_module='SCHEDULING' AND deduplication_key LIKE 'SCHEDULING:%'"
    if ($notificationState -ne "4|4") { throw "Scheduling notifications are not complete and deduplicated: $notificationState" }
    Invoke-Verifier "Verify-SgSuperAppI9Exports.ps1" @("-ApiBaseUrl",$ApiBaseUrl,"-VersionId",$publishedVersionId,"-PositionId",$positionId,"-OutputDirectory",$exportDirectory)
    # The MVP rule engine stands up its own schema and its own API, so these run outside this one's
    # fixture rather than against it. Running them here keeps a rule-engine regression from passing
    # the closure suite unnoticed: Verify-SgSuperAppI9MvpRules.ps1 is the static and focused gate,
    # and Verify-SgSuperAppI9MvpIntegration.ps1 is the hermetic end-to-end one.
    Invoke-Verifier "Verify-SgSuperAppI9MvpIntegration.ps1" @()
    Invoke-Verifier "Verify-SgSuperAppI9MvpRules.ps1" @()
    $exportAuditCount = Invoke-Psql "SELECT count(*) FROM audit_log WHERE event_type='SCHEDULE_EXPORTED' AND entity_id='$publishedVersionId'"
    if ($exportAuditCount -ne "2") { throw "Expected two scheduling export audit events, found $exportAuditCount." }
    Write-Output "I9 INTEGRATION PASS"
}
finally {
    if ($null -ne $apiProcess -and -not $apiProcess.HasExited) { Stop-Process -Id $apiProcess.Id -Force }
    Start-Sleep -Milliseconds 250
    $env:PGOPTIONS = ""
    $env:PGPASSWORD = $AppPassword
    if ($schema -match '^sg_i9_close_[0-9]+_[0-9]{17}$') {
        & $psql -X -q -h localhost -p 5432 -U $AppUser -d $Database -c "DROP SCHEMA IF EXISTS $schema CASCADE" | Out-Null
    }
    foreach ($path in @($apiLog, $apiErrorLog, $exportDirectory)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $env:PGPASSWORD = $previousPassword
    $env:PGOPTIONS = $previousOptions
}
