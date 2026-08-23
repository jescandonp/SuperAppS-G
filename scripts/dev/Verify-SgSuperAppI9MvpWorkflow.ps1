[CmdletBinding()]
param([string]$RepositoryRoot,[int]$Port = 5399)

# Stands the real API up against a temporary schema and drives the exception, approval and
# publication frontier over HTTP. Everything asserted here is a real round trip: the status code,
# the media type and the absence of any row or audit event a refused call must not leave behind.
# The schema is always dropped, and the API process is always stopped.

$ErrorActionPreference = 'Stop'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
} else { (Resolve-Path $RepositoryRoot).Path }

$dotnet = 'C:\tmp\dotnet6\dotnet.exe'
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
$settingsPath = Join-Path $repoRoot 'apps/sg-superapp-api/appsettings.json'
$project = Join-Path $repoRoot 'apps/sg-superapp-api/sg-superapp-api.csproj'
if (-not (Test-Path -LiteralPath $dotnet -PathType Leaf) -or
    -not (Test-Path -LiteralPath $psql -PathType Leaf) -or
    -not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    Write-Output 'I9 MVP WORKFLOW BLOCKED: local prerequisites unavailable'; exit 2
}

$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$parts = @{}
foreach ($part in ([string]$settings.ConnectionStrings.Postgres -split ';')) {
    if ($part -match '^([^=]+)=(.*)$') { $parts[$matches[1].Trim()] = $matches[2] }
}
if (@('Host','Port','Database','Username','Password') | Where-Object { -not $parts[$_] }) {
    Write-Output 'I9 MVP WORKFLOW BLOCKED: local PostgreSQL configuration incomplete'; exit 2
}
$env:PGHOST=$parts.Host; $env:PGPORT=$parts.Port; $env:PGDATABASE=$parts.Database
$env:PGUSER=$parts.Username; $env:PGPASSWORD=$parts.Password

$passed = 0
function Q([bool]$value,[string]$label) { if (-not $value) { throw $label }; $script:passed++; Write-Output ($label + ' PASS') }

function Call([string]$method,[string]$uri,$headers,$body) {
    try {
        $arguments = @{ Uri = $uri; Method = $method; UseBasicParsing = $true; ContentType = 'application/json' }
        if ($null -ne $headers) { $arguments.Headers = $headers }
        if ($null -ne $body) { $arguments.Body = ($body | ConvertTo-Json -Depth 8) }
        $response = Invoke-WebRequest @arguments
        return @{ Status = [int]$response.StatusCode; Content = [string]$response.Content
                  ContentType = [string]$response.Headers['Content-Type'] }
    }
    catch {
        $response = $_.Exception.Response
        if ($null -eq $response) { throw }
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $text = $reader.ReadToEnd(); $reader.Dispose()
        return @{ Status = [int]$response.StatusCode; Content = $text; ContentType = [string]$response.ContentType }
    }
}

function Scalar([string]$sql) {
    $value = & $psql -X -w -Atqc $sql
    if ($LASTEXITCODE -ne 0) { throw "query failed: $sql" }
    return ([string]$value).Trim()
}

$schema = 'i9_mvpwf_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$apiProcess = $null
$fixtureFile = Join-Path ([System.IO.Path]::GetTempPath()) ($schema + '.sql')
try {
    & $dotnet build $project --configuration Release | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 MVP WORKFLOW FAIL: API build failed'; exit 1 }

    & $psql -X -w -v ON_ERROR_STOP=1 -c "CREATE SCHEMA $schema" | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 MVP WORKFLOW BLOCKED: cannot create temporal schema'; exit 2 }
    $env:PGOPTIONS = "--search_path=$schema,public"

    Get-ChildItem (Join-Path $repoRoot 'db/migrations') -Filter '*.sql' | Sort-Object Name | ForEach-Object {
        & $psql -X -w -v ON_ERROR_STOP=1 -f $_.FullName | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "migration failed: $($_.Name)" }
    }
    foreach ($seed in @('001_roles_and_permissions.sql','004_i2_security_users_permissions.sql',
                        '009_i9_scheduling_permissions.sql','010_i9_shift_templates.sql',
                        '011_i9_mvp_simulated_rule_profile.sql')) {
        & $psql -X -w -v ON_ERROR_STOP=1 -f (Join-Path $repoRoot "db/seeds/$seed") | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "seed failed: $seed" }
    }

    # Written to a file rather than passed with -c: PowerShell 5.1 strips double quotes on their way
    # to a native executable, which would silently corrupt every JSON literal below.
    $fixture = @'
INSERT INTO clients(code,name,status) VALUES('I9-WF-CLIENT','I9 Workflow Client','ACTIVO');
INSERT INTO service_projects(client_id,code,name,effective_from,status,created_at,updated_at)
 SELECT id,'PROJECT-A','Project A',date '2026-01-01','ACTIVO',now(),now() FROM clients WHERE code='I9-WF-CLIENT';
INSERT INTO service_positions(code,name,status) VALUES('I9-WF-POSITION','I9 Workflow Position','ACTIVO');
INSERT INTO employees(identification_type,identification_number,full_name,employment_status,job_title,hire_date)
 VALUES('CC','I9-WF-1','I9 Workflow Guard','ACTIVO','GUARDA',date '2026-01-01');
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-01',date '2026-09-01','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',TRUE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p WHERE p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-02',date '2026-09-02','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',TRUE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p WHERE s.period_start=date '2026-09-02'
 AND p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-03',date '2026-09-03','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',TRUE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p WHERE s.period_start=date '2026-09-03'
 AND p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at)
 SELECT sv.id,sp.id,s.period_start,time '08:00',time '20:00'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN service_positions sp WHERE sp.code='I9-WF-POSITION' AND s.period_start=date '2026-09-01';
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status)
 SELECT r.schedule_version_id,r.id,e.id,'ASIGNADA' FROM required_shifts r
 CROSS JOIN employees e WHERE e.identification_number='I9-WF-1';
INSERT INTO scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,a.id,sv.rule_profile_id,'I9-R02','EXCEPTION_REQUIRED','WARNING','I9_R02_MIN_REST',
  'Descanso minimo no alcanzado en escenario simulado.',jsonb_build_object('minimumRestHours',12),
  jsonb_build_object('restMinutes',600),repeat('a',64),TRUE,'PENDING','i9-mvpwf-001',now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 JOIN schedule_assignments a ON a.schedule_version_id=sv.id WHERE s.period_start=date '2026-09-01';
INSERT INTO scheduling_rule_evaluations(schedule_version_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,sv.rule_profile_id,'I9-R01','COMPLIANT','INFO','I9_R01_COMPLIANT',
  'Jornada conforme en escenario simulado.',jsonb_build_object('maxDailyHours',12),
  jsonb_build_object('dailyHours',8),repeat('b',64),FALSE,'NOT_REQUIRED','i9-mvpwf-002',now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id WHERE s.period_start=date '2026-09-01';
INSERT INTO scheduling_rule_evaluations(schedule_version_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,sv.rule_profile_id,'I9-R03','BLOCKED','BLOCKING','I9_R03_OVERLAP_APPROVED_BLOCKED',
  'Cruce con turno aprobado en escenario simulado.',jsonb_build_object('blockOnApproved',true),
  jsonb_build_object('overlapMinutes',60),repeat('c',64),FALSE,'NOT_REQUIRED','i9-mvpwf-003',now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id WHERE s.period_start=date '2026-09-02';
-- An assignment no rule ever evaluated, beside a version-level verdict that must not vouch for it.
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-04',date '2026-09-04','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-05',date '2026-09-05','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-06',date '2026-09-06','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-07',date '2026-09-07','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',TRUE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p WHERE s.period_start IN(date '2026-09-04',date '2026-09-05',date '2026-09-06')
 AND p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
-- Bound to an MVP profile yet not marked simulated: the schema admits this shape.
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',FALSE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p WHERE s.period_start=date '2026-09-07'
 AND p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at)
 SELECT sv.id,sp.id,s.period_start,time '08:00',time '20:00'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN service_positions sp WHERE sp.code='I9-WF-POSITION'
 AND s.period_start IN(date '2026-09-04',date '2026-09-05',date '2026-09-06',date '2026-09-07');
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status)
 SELECT r.schedule_version_id,r.id,e.id,'ASIGNADA' FROM required_shifts r
 JOIN schedule_versions sv ON sv.id=r.schedule_version_id JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN employees e WHERE e.identification_number='I9-WF-1'
 AND s.period_start IN(date '2026-09-04',date '2026-09-05',date '2026-09-06',date '2026-09-07');
-- 09-04: version-level COMPLIANT only. The assignment beside it was never evaluated.
INSERT INTO scheduling_rule_evaluations(schedule_version_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,sv.rule_profile_id,'I9-R01','COMPLIANT','INFO','I9_R01_COMPLIANT','Jornada conforme.',
  jsonb_build_object('maxDailyHours',12),jsonb_build_object('dailyHours',8),repeat('1',64),FALSE,'NOT_REQUIRED',
  'i9-mvpwf-004',now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id WHERE s.period_start=date '2026-09-04';
-- 09-05: a genuine block, recorded after the assignment exists. Nothing corrects it yet: the test
-- drives the correction over HTTP so the edit is real rather than implied by a backdated row.
INSERT INTO scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,a.id,sv.rule_profile_id,'I9-R03','BLOCKED','BLOCKING','I9_R03_OVERLAP_APPROVED_BLOCKED','Cruce inicial.',
  jsonb_build_object('blockOnApproved',true),jsonb_build_object('overlapMinutes',60),repeat('2',64),FALSE,'NOT_REQUIRED',
  'i9-mvpwf-005a',now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 JOIN schedule_assignments a ON a.schedule_version_id=sv.id WHERE s.period_start=date '2026-09-05';
-- 09-06: compliant now; the test edits the assignment and re-evaluates it over HTTP and SQL.
INSERT INTO scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,a.id,sv.rule_profile_id,'I9-R01','COMPLIANT','INFO','I9_R01_COMPLIANT','Jornada conforme.',
  jsonb_build_object('maxDailyHours',12),jsonb_build_object('dailyHours',8),repeat('4',64),FALSE,'NOT_REQUIRED',
  'i9-mvpwf-006',now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 JOIN schedule_assignments a ON a.schedule_version_id=sv.id WHERE s.period_start=date '2026-09-06';
-- A WARNING is the outcome of a disabled or unimplemented rule. Nothing may be built on it.
INSERT INTO scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,a.id,sv.rule_profile_id,'I9-R07','WARNING','ERROR','I9_R07_DISABLED_UNVERIFIED','Regla desactivada.',
  jsonb_build_object('changeInvalidatesApproval',true),jsonb_build_object('templateCode','T'),repeat('5',64),FALSE,
  'NOT_REQUIRED','i9-mvpwf-008',now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 JOIN schedule_assignments a ON a.schedule_version_id=sv.id WHERE s.period_start=date '2026-09-01'
 AND sv.status='PROPUESTA' AND false;
-- Two rules on ONE assignment, the demanding one sorting ABOVE a clean one. rule_code is the
-- ascending tiebreaker, so a partition that lost it keeps the LOWEST rule code: I9-R01 survives and
-- the I9-R07 decision vanishes. Ordered the other way round the fixture stays green under that
-- mutation, which is exactly how the first version of it failed to catch anything.
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-08',date '2026-09-08','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',TRUE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p WHERE s.period_start=date '2026-09-08'
 AND p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at)
 SELECT sv.id,sp.id,s.period_start,time '08:00',time '20:00'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN service_positions sp WHERE sp.code='I9-WF-POSITION' AND s.period_start=date '2026-09-08';
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status)
 SELECT r.schedule_version_id,r.id,e.id,'ASIGNADA' FROM required_shifts r
 JOIN schedule_versions sv ON sv.id=r.schedule_version_id JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN employees e WHERE e.identification_number='I9-WF-1' AND s.period_start=date '2026-09-08';
INSERT INTO scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,a.id,sv.rule_profile_id,'I9-R07','EXCEPTION_REQUIRED','WARNING','I9_R07_DEVIATION','Desvio de plantilla.',
  jsonb_build_object('changeInvalidatesApproval',true),jsonb_build_object('templateCode','T'),repeat('c',64),TRUE,'PENDING',
  'i9-mvpwf-020a',now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 JOIN schedule_assignments a ON a.schedule_version_id=sv.id WHERE s.period_start=date '2026-09-08';
INSERT INTO scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,a.id,sv.rule_profile_id,'I9-R01','COMPLIANT','INFO','I9_R01_COMPLIANT','Jornada conforme.',
  jsonb_build_object('maxDailyHours',12),jsonb_build_object('dailyHours',8),repeat('d',64),FALSE,
  'NOT_REQUIRED','i9-mvpwf-020b',now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 JOIN schedule_assignments a ON a.schedule_version_id=sv.id WHERE s.period_start=date '2026-09-08';
-- An R06 decision is validated by Talento Humano, so its evaluation never carries exception_allowed.
-- The approved decision below must still satisfy the gate; it could not until this was fixed.
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-09',date '2026-09-09','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',TRUE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p WHERE s.period_start=date '2026-09-09'
 AND p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at)
 SELECT sv.id,sp.id,s.period_start,time '08:00',time '20:00'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN service_positions sp WHERE sp.code='I9-WF-POSITION' AND s.period_start=date '2026-09-09';
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status)
 SELECT r.schedule_version_id,r.id,e.id,'ASIGNADA' FROM required_shifts r
 JOIN schedule_versions sv ON sv.id=r.schedule_version_id JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN employees e WHERE e.identification_number='I9-WF-1' AND s.period_start=date '2026-09-09';
INSERT INTO scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,a.id,sv.rule_profile_id,'I9-R06','EXCEPTION_REQUIRED','WARNING','I9_R06_UNVERIFIED','Requisito sin verificar.',
  jsonb_build_object('requiresHrValidation',true),jsonb_build_object('evidenceState','MISSING'),repeat('e',64),FALSE,
  'NOT_REQUIRED','i9-mvpwf-021',now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 JOIN schedule_assignments a ON a.schedule_version_id=sv.id WHERE s.period_start=date '2026-09-09';
INSERT INTO schedule_exceptions(schedule_version_id,assignment_id,exception_type,reason,responsible,
  evaluation_id,rule_code,scope_hash,motive_code,decision,decided_by,decided_at,decision_detail)
 SELECT e.schedule_version_id,e.assignment_id,'RULE_EXCEPTION','Validado por Talento Humano','TH',
  e.id,e.rule_code,e.scope_hash,'HR_VALIDATED_DEMO','APPROVED','operaciones.sg',now(),jsonb_build_object('source','MVP_TEST')
 FROM scheduling_rule_evaluations e WHERE e.correlation_id='i9-mvpwf-021';
'@
    Set-Content -LiteralPath $fixtureFile -Value $fixture -Encoding UTF8
    & $psql -X -w -v ON_ERROR_STOP=1 -f $fixtureFile | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'simulated MVP_TEST fixture failed' }

    $mainVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-09-01'"
    $blockedVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-09-02'"
    $unevaluatedVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-09-03'"
    $pendingEvaluation = Scalar "select id from scheduling_rule_evaluations where correlation_id='i9-mvpwf-001'"
    $assignmentId = Scalar "select id from schedule_assignments limit 1"

    $env:ConnectionStrings__Postgres = "Host=$($parts.Host);Port=$($parts.Port);Database=$($parts.Database);Username=$($parts.Username);Password=$($parts.Password);Search Path=$schema,public"
    $env:ASPNETCORE_URLS = "http://127.0.0.1:$Port"
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $dll = Join-Path $repoRoot 'apps/sg-superapp-api/bin/Release/net6.0/sg-superapp-api.dll'
    $apiProcess = Start-Process -FilePath $dotnet -ArgumentList $dll -PassThru -WindowStyle Hidden

    $base = "http://127.0.0.1:$Port/api"
    $ready = $false
    foreach ($attempt in 1..40) {
        if ($apiProcess.HasExited) { throw "the API process exited with code $($apiProcess.ExitCode)" }
        try { $null = Invoke-WebRequest -UseBasicParsing -Uri "$base/health" -TimeoutSec 3; $ready = $true; break }
        catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $ready) { throw 'the API never became reachable' }
    Q $true 'WF-T01 the API starts and resolves its dependencies'

    $login = Call 'Post' "$base/auth/login" $null @{ username='operaciones.sg'; password='Operaciones123' }
    if ($login.Status -ne 200) { throw "login failed with HTTP $($login.Status)" }
    $headers = @{ Authorization = "Bearer $(($login.Content | ConvertFrom-Json).sessionToken)" }

    $exceptionsUri = "$base/portal/scheduling/proposals/$mainVersion/exceptions"
    $decisionsBefore = [int](Scalar "select count(*) from schedule_exceptions")
    $approvalAuditBefore = [int](Scalar "select count(*) from audit_log where event_type='SCHEDULE_RULE_EXCEPTION_APPROVED'")

    # An absent or malformed scope is a malformed request: the caller never named a snapshot.
    foreach ($case in @(
        @{ Name='absent'; Scope=$null },
        @{ Name='empty'; Scope='' },
        @{ Name='blank'; Scope='   ' },
        @{ Name='short'; Scope=('a' * 63) },
        @{ Name='uppercase'; Scope=('A' * 64) },
        @{ Name='non-hex'; Scope=('z' * 64) })) {
        $body = @{ assignmentId=[long]$assignmentId; evaluationId=[long]$pendingEvaluation; ruleCode='I9-R02'
                   scopeHash=$case.Scope; motiveCode='OPERATIONAL_CONTINUITY_DEMO'; reason='Motivo simulado'
                   responsible='operaciones.sg'; resolutionDate='2026-09-10'; expectedVersion=1 }
        $result = Call 'Post' $exceptionsUri $headers $body
        Q ($result.Status -eq 400) "WF-T02 $($case.Name) scope is rejected as a malformed request"
        Q ($result.ContentType -like 'application/problem+json*') "WF-T02 $($case.Name) scope answers with problem+json"
    }

    # A well-formed scope that is not the one evaluated is a conflict, not a malformed request.
    $staleBody = @{ assignmentId=[long]$assignmentId; evaluationId=[long]$pendingEvaluation; ruleCode='I9-R02'
                    scopeHash=('d' * 64); motiveCode='OPERATIONAL_CONTINUITY_DEMO'; reason='Motivo simulado'
                    responsible='operaciones.sg'; resolutionDate='2026-09-10'; expectedVersion=1 }
    $stale = Call 'Post' $exceptionsUri $headers $staleBody
    Q ($stale.Status -eq 409) 'WF-T03 a scope that is not the evaluated one is a conflict'
    Q ($stale.ContentType -like 'application/problem+json*') 'WF-T03 the conflict answers with problem+json'

    Q ([int](Scalar "select count(*) from schedule_exceptions") -eq $decisionsBefore) 'WF-T04 every refusal leaves no decision behind'
    Q ([int](Scalar "select count(*) from audit_log where event_type='SCHEDULE_RULE_EXCEPTION_APPROVED'") -eq $approvalAuditBefore) 'WF-T04 every refusal leaves no approval audit behind'

    # A motive outside the versioned catalogue is refused even with the right scope.
    $badMotive = Call 'Post' $exceptionsUri $headers @{ assignmentId=[long]$assignmentId; evaluationId=[long]$pendingEvaluation
        ruleCode='I9-R02'; scopeHash=('a' * 64); motiveCode='NOT_IN_CATALOG'; reason='Motivo simulado'
        responsible='operaciones.sg'; resolutionDate='2026-09-10'; expectedVersion=1 }
    Q ($badMotive.Status -eq 409) 'WF-T05 a motive outside the versioned catalogue is refused'
    Q ([int](Scalar "select count(*) from schedule_exceptions") -eq $decisionsBefore) 'WF-T05 the refused motive leaves no decision'

    # The rule still awaits a decision, so the proposal cannot be approved.
    $earlyApprove = Call 'Post' "$base/portal/scheduling/proposals/$mainVersion/approve" $headers @{ expectedVersion=1 }
    Q ($earlyApprove.Status -eq 409) 'WF-T06 approval is refused while a rule still awaits its decision'
    Q ($earlyApprove.Content -match 'excepciones requeridas') 'WF-T06 the refusal names the pending decision'
    Q ($earlyApprove.ContentType -like 'application/problem+json*' -and $earlyApprove.Content -match 'RULE_EXCEPTION_REQUIRED') 'WF-T06 the refusal carries the machine-readable rule state'
    Q ((Scalar "select status from schedule_versions where id=$mainVersion") -eq 'PROPUESTA') 'WF-T06 the refused approval leaves the proposal untouched'

    # A blocked rule can never be approved, with or without a decision.
    $blockedApprove = Call 'Post' "$base/portal/scheduling/proposals/$blockedVersion/approve" $headers @{ expectedVersion=1 }
    Q ($blockedApprove.Status -eq 409) 'WF-T07 a blocked rule cannot be approved'
    Q ($blockedApprove.Content -match 'reglas bloqueadas') 'WF-T07 the refusal names the blocking rule'
    Q ($blockedApprove.ContentType -like 'application/problem+json*' -and $blockedApprove.Content -match 'RULE_BLOCKED') 'WF-T07 the refusal is reported as a blocked rule'

    # A simulated version with nothing evaluated is unverified, not clean.
    $emptyApprove = Call 'Post' "$base/portal/scheduling/proposals/$unevaluatedVersion/approve" $headers @{ expectedVersion=1 }
    Q ($emptyApprove.Status -eq 409) 'WF-T08 a simulated version with no evaluation cannot be approved'
    Q ($emptyApprove.Content -match 'no tiene evaluacion') 'WF-T08 the refusal says nothing was verified'
    Q ($emptyApprove.ContentType -like 'application/problem+json*' -and $emptyApprove.Content -match 'RULE_EVALUATION_MISSING') 'WF-T08 the refusal is reported as a missing evaluation'

    # With the exact evaluated scope and a catalogued motive, the decision is taken.
    $approvedException = Call 'Post' $exceptionsUri $headers @{ assignmentId=[long]$assignmentId
        evaluationId=[long]$pendingEvaluation; ruleCode='I9-R02'; scopeHash=('a' * 64)
        motiveCode='OPERATIONAL_CONTINUITY_DEMO'; reason='Continuidad operativa simulada'
        responsible='operaciones.sg'; resolutionDate='2026-09-10'; expectedVersion=1 }
    Q ($approvedException.Status -eq 200) 'WF-T09 the evaluated scope with a catalogued motive is accepted'
    Q ([int](Scalar "select count(*) from schedule_exceptions where evaluation_id=$pendingEvaluation and decision='APPROVED'") -eq 1) 'WF-T09 the decision is persisted against its evaluation'
    Q ([int](Scalar "select count(*) from audit_log where event_type='SCHEDULE_RULE_EXCEPTION_APPROVED'") -eq $approvalAuditBefore + 1) 'WF-T09 the decision is audited'

    # Now every rule has been decided, so the transition is allowed and recorded.
    $approve = Call 'Post' "$base/portal/scheduling/proposals/$mainVersion/approve" $headers @{ expectedVersion=1 }
    Q ($approve.Status -eq 200) 'WF-T10 a fully decided proposal is approved'
    $publish = Call 'Post' "$base/portal/scheduling/proposals/$mainVersion/publish" $headers @{ expectedVersion=1 }
    Q ($publish.Status -eq 200) 'WF-T10 a fully decided proposal is published'
    Q ((Scalar "select status from schedule_versions where id=$mainVersion") -eq 'PUBLICADA') 'WF-T10 the publication is persisted'
    $audit = Call 'Get' "$base/portal/scheduling/versions/$mainVersion/audit" $headers $null
    Q ($audit.Content -match 'SCHEDULE_PUBLISHED') 'WF-T10 the publication is audited'
    Q ($audit.Content -match 'ruleProfileId' -and $audit.Content -match 'simulated' -and $audit.Content -match 'decidedExceptions') 'WF-T10 the audit records the profile, the simulated mark and what was decided'

    # The two listing routes the scheduling screen cannot open without. They had no coverage at all
    # when they were added, which is the same gap that let them be missing in the first place: a
    # verifier asserted the client declared the functions, never that the routes answered. Deleting
    # either route, or its permission check, left the whole gate green.
    foreach ($route in @('projects', 'shift-templates')) {
        $granted = Call 'Get' "$base/portal/scheduling/$route" $headers $null
        Q ($granted.Status -eq 200) "WF-T14 $route answers a caller holding SCHEDULING/VIEW"

        $anonymous = Call 'Get' "$base/portal/scheduling/$route" $null $null
        Q ($anonymous.Status -eq 401) "WF-T14 $route refuses an unauthenticated caller"
    }
    Q ((Call 'Get' "$base/portal/scheduling/projects" $headers $null).Content -match 'PROJECT-A') 'WF-T14 the project listing carries the seeded project'
    Q ((Call 'Get' "$base/portal/scheduling/shift-templates" $headers $null).Content -match '"steps"') 'WF-T14 the template listing carries its steps'

    # Permission, not authentication: a signed-in user whose role lost SCHEDULING/VIEW is refused.
    & $psql -X -w -v ON_ERROR_STOP=1 -c "delete from role_permissions rp using roles r where rp.role_id=r.id and r.code='TH' and rp.module_code='SCHEDULING' and rp.action_code='VIEW'" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'could not revoke SCHEDULING/VIEW from TH' }
    $thLogin = Call 'Post' "$base/auth/login" $null @{ username='th.sg'; password='Th123456' }
    if ($thLogin.Status -eq 200) {
        $thHeaders = @{ Authorization = "Bearer $(($thLogin.Content | ConvertFrom-Json).sessionToken)" }
        foreach ($route in @('projects', 'shift-templates')) {
            $denied = Call 'Get' "$base/portal/scheduling/$route" $thHeaders $null
            Q ($denied.Status -eq 403) "WF-T14 $route refuses a signed-in caller without SCHEDULING/VIEW"
        }
    } else {
        throw "could not sign in as th.sg to test the denial path (HTTP $($thLogin.Status))"
    }

    # The eligibility verifier could never run without an API. It has one now, so it runs here
    # instead of being declared blocked, and its failure is this verifier's failure.
    $eligibility = & powershell -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $repoRoot 'scripts/dev/Verify-SgSuperAppI9Eligibility.ps1') -ApiBaseUrl $base 2>&1
    Q ($LASTEXITCODE -eq 0 -and (($eligibility -join "`n") -match 'I9 ELIGIBILITY PASS')) 'WF-T11 the eligibility frontier passes against the running API'

    # Replanning needs a published version, which only exists once the gates above have been passed.
    # Its own -VerificationSchema fixtures are skipped: that switch only accepts schema names of the
    # sg_i9_replan_ family, so the notification dedup assertion it guards does not run here.
    $replanning = & powershell -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $repoRoot 'scripts/dev/Verify-SgSuperAppI9Replanning.ps1') `
        -ApiBaseUrl $base -VersionId ([long]$mainVersion) 2>&1
    Q ($LASTEXITCODE -eq 0 -and (($replanning -join "`n") -match 'I9 REPLANNING PASS')) 'WF-T12 replanning passes against the published version'

    # The pre-MVP workflow verifier has been unexecutable since the exception frontier changed. It
    # runs here too, on its own periods so it cannot collide with this harness's schedules.
    $projectId = Scalar "select id from service_projects where code='PROJECT-A'"
    $workflow = & powershell -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $repoRoot 'scripts/dev/Verify-SgSuperAppI9Workflow.ps1') `
        -ApiBaseUrl $base -ProjectId ([long]$projectId) -PeriodStart '2026-10-01' -PeriodEnd '2026-10-31' 2>&1
    Q ($LASTEXITCODE -eq 0 -and (($workflow -join "`n") -match 'I9 WORKFLOW PASS')) 'WF-T13 the pre-MVP workflow verifier passes again'

    # An independent review drove these six states against the running API and found the gate blind
    # to the first, and unable to recover from the second and third. They are regressions now.
    $unevaluatedVersionId = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-09-04'"
    $recoveredVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-09-05'"
    $editedVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-09-06'"
    $unmarkedVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-09-07'"

    # A version-level verdict does not vouch for a guard no rule ever looked at.
    $unevaluated = Call 'Post' "$base/portal/scheduling/proposals/$unevaluatedVersionId/approve" $headers @{ expectedVersion=1 }
    Q ($unevaluated.Status -eq 409 -and $unevaluated.Content -match 'RULE_ASSIGNMENT_UNEVALUATED') 'WF-T14 an assignment no rule evaluated cannot be approved'
    Q ((Scalar "select status from schedule_versions where id=$unevaluatedVersionId") -eq 'PROPUESTA') 'WF-T14 the refusal leaves the proposal untouched'

    # A block stands until the schedule changes. Every verdict is computed from facts the caller
    # supplies, so if a newer evaluation simply replaced the older one, whoever wanted the approval
    # could post a clean fact set and walk a recorded block out of the way. An independent review
    # did exactly that against an earlier build; these three assertions are that exploit, inverted.
    $blockedAssignment = Scalar "select a.id from schedule_assignments a where a.schedule_version_id=$recoveredVersion"
    $stillBlocked = Call 'Post' "$base/portal/scheduling/proposals/$recoveredVersion/approve" $headers @{ expectedVersion=1 }
    Q ($stillBlocked.Status -eq 409 -and $stillBlocked.Content -match 'RULE_BLOCKED') 'WF-T15 a recorded block refuses the approval'

    & $psql -X -w -v ON_ERROR_STOP=1 -c "insert into scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,correlation_id,evaluated_at,audit_actor) select sv.id,$blockedAssignment,sv.rule_profile_id,'I9-R03','COMPLIANT','INFO','I9_R03_COMPLIANT','Reevaluado sin cambiar nada.',jsonb_build_object('blockOnApproved',true),jsonb_build_object('overlapMinutes',0),repeat('8',64),FALSE,'NOT_REQUIRED','i9-mvpwf-005b',now(),'operaciones.sg' from schedule_versions sv where sv.id=$recoveredVersion" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'could not record the re-evaluation' }
    $assertedClean = Call 'Post' "$base/portal/scheduling/proposals/$recoveredVersion/approve" $headers @{ expectedVersion=1 }
    Q ($assertedClean.Status -eq 409 -and $assertedClean.Content -match 'RULE_BLOCKED') 'WF-T15 re-asserting clean facts does not clear a block'

    # Correct the schedule for real, then evaluate what changed. Now the block is answered.
    $blockedGuard = Scalar "select employee_id from schedule_assignments where id=$blockedAssignment"
    $correction = Call 'Put' "$base/portal/scheduling/proposals/$recoveredVersion/assignments/$blockedAssignment" $headers @{ employeeId=[long]$blockedGuard; status='ASIGNADA'; reasons=@('Cruce corregido'); expectedVersion=1 }
    Q ($correction.Status -eq 200) 'WF-T15 the schedule is corrected'
    & $psql -X -w -v ON_ERROR_STOP=1 -c "insert into scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,correlation_id,evaluated_at,audit_actor) select sv.id,$blockedAssignment,sv.rule_profile_id,'I9-R03','COMPLIANT','INFO','I9_R03_COMPLIANT','Reevaluado tras corregir.',jsonb_build_object('blockOnApproved',true),jsonb_build_object('overlapMinutes',0),repeat('9',64),FALSE,'NOT_REQUIRED','i9-mvpwf-005c',now(),'operaciones.sg' from schedule_versions sv where sv.id=$recoveredVersion" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'could not re-evaluate the corrected assignment' }
    $recovered = Call 'Post' "$base/portal/scheduling/proposals/$recoveredVersion/approve" $headers @{ expectedVersion=1 }
    Q ($recovered.Status -eq 200) 'WF-T15 correcting the schedule and re-evaluating clears the block'

    # The same, for an edit: after re-evaluation the assignment is described again and may proceed.
    $editedAssignment = Scalar "select a.id from schedule_assignments a where a.schedule_version_id=$editedVersion"
    $editedGuard = Scalar "select employee_id from schedule_assignments where id=$editedAssignment"
    $edit = Call 'Put' "$base/portal/scheduling/proposals/$editedVersion/assignments/$editedAssignment" $headers @{ employeeId=[long]$editedGuard; status='ASIGNADA'; reasons=@('Revalidacion manual'); expectedVersion=1 }
    Q ($edit.Status -eq 200) 'WF-T16 the assignment is edited'
    $afterEditApprove = Call 'Post' "$base/portal/scheduling/proposals/$editedVersion/approve" $headers @{ expectedVersion=1 }
    Q ($afterEditApprove.Status -eq 409 -and $afterEditApprove.Content -match 'RULE_EVALUATION_SUPERSEDED') 'WF-T16 the edit supersedes the evaluation that described the assignment'
    & $psql -X -w -v ON_ERROR_STOP=1 -c "insert into scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,correlation_id,evaluated_at,audit_actor) select sv.id,$editedAssignment,sv.rule_profile_id,'I9-R01','COMPLIANT','INFO','I9_R01_COMPLIANT','Reevaluado tras la edicion.',jsonb_build_object('maxDailyHours',12),jsonb_build_object('dailyHours',8),repeat('6',64),FALSE,'NOT_REQUIRED','i9-mvpwf-006b',now(),'operaciones.sg' from schedule_versions sv where sv.id=$editedVersion" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'could not re-evaluate the edited assignment' }
    $reEvaluated = Call 'Post' "$base/portal/scheduling/proposals/$editedVersion/approve" $headers @{ expectedVersion=1 }
    Q ($reEvaluated.Status -eq 200) 'WF-T16 re-evaluating the edited assignment clears the refusal'

    # The gate keys on the rule profile, not on the simulated mark: a version bound to an MVP profile
    # is governed whether or not anyone remembered to set the flag.
    $unmarked = Call 'Post' "$base/portal/scheduling/proposals/$unmarkedVersion/approve" $headers @{ expectedVersion=1 }
    Q ($unmarked.Status -eq 409 -and $unmarked.Content -match 'RULE_EVALUATION_MISSING') 'WF-T17 a profile-bound version is gated even when it is not marked simulated'

    # A WARNING is what a disabled or unimplemented rule produces, and it accredits nothing. It is
    # reported as its own state, not as a hard block, because the remedy is different.
    & $psql -X -w -v ON_ERROR_STOP=1 -c "insert into scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,correlation_id,evaluated_at,audit_actor) select sv.id,a.id,sv.rule_profile_id,'I9-R07','WARNING','ERROR','I9_R07_DISABLED_UNVERIFIED','Regla desactivada.',jsonb_build_object('changeInvalidatesApproval',true),jsonb_build_object('templateCode','T'),repeat('7',64),FALSE,'NOT_REQUIRED','i9-mvpwf-008',now(),'operaciones.sg' from schedule_versions sv join schedule_assignments a on a.schedule_version_id=sv.id where sv.id=$unevaluatedVersionId" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'could not add the unverified rule' }
    $warned = Call 'Post' "$base/portal/scheduling/proposals/$unevaluatedVersionId/approve" $headers @{ expectedVersion=1 }
    Q ($warned.Status -eq 409 -and $warned.Content -match 'RULE_UNVERIFIED') 'WF-T18 an unverified rule is refused as its own state'
    Q ($warned.Content -notmatch 'RULE_BLOCKED') 'WF-T18 an unverified rule is not reported as a hard block'

    # Generation belongs to a proposal. Letting it run on an approved version would add assignments
    # the gate had already finished checking.
    # A real shift with no candidates: the engine returns a vacancy, so the request reaches
    # persistence and is judged there rather than being rejected as malformed.
    $recoveredShift = Scalar "select id from required_shifts where schedule_version_id=$recoveredVersion"
    $lateBody = @{ scheduleVersionId=[long]$recoveredVersion; idempotencyKey='wf-t19'
        weights=@{ continuity=1; equity=1; additionalHoursPenalty=0.1; distancePenalty=0.1
                   exceptionPenalty=5; stabilityPenalty=0.1 }
        shifts=@(@{ requiredShiftId=[long]$recoveredShift; positionId=1; date='2026-09-05'; startsAt='08:00'; candidates=@() }) }
    $lateGeneration = Call 'Post' "$base/portal/scheduling/recommendations/generate" $headers $lateBody
    Q ($lateGeneration.Status -eq 409) 'WF-T19 generation is refused on a version that is no longer a proposal'
    Q ([int](Scalar "select count(*) from schedule_generation_runs where schedule_version_id=$recoveredVersion and status='COMPLETADO'") -eq 0) 'WF-T19 the refused generation completes no run'

    # One assignment, two rules, the demanding one sorting below a clean one.
    $twoRuleVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-09-08'"
    $twoRule = Call 'Post' "$base/portal/scheduling/proposals/$twoRuleVersion/approve" $headers @{ expectedVersion=1 }
    Q ($twoRule.Status -eq 409 -and $twoRule.Content -match 'RULE_EXCEPTION_REQUIRED') 'WF-T20 a pending rule is not hidden by a clean one on the same assignment'

    # An approved R06 decision satisfies the gate even though its evaluation cannot carry
    # exception_allowed: Talento Humano validates that evidence, not the requesting actor.
    $hrVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-09-09'"
    $hrApprove = Call 'Post' "$base/portal/scheduling/proposals/$hrVersion/approve" $headers @{ expectedVersion=1 }
    Q ($hrApprove.Status -eq 200) 'WF-T21 an approved R06 decision is not a dead end'

    Q ($passed -eq 64) 'numbered workflow assertion count'
    Write-Output "I9 MVP WORKFLOW PASS $passed"
    exit 0
}
catch { Write-Output "I9 MVP WORKFLOW FAIL: $($_.Exception.Message)"; exit 1 }
finally {
    if ($null -ne $apiProcess -and -not $apiProcess.HasExited) {
        Stop-Process -Id $apiProcess.Id -Force -ErrorAction SilentlyContinue
        $apiProcess.WaitForExit(10000) | Out-Null
    }
    $env:ConnectionStrings__Postgres=$null; $env:ASPNETCORE_URLS=$null; $env:ASPNETCORE_ENVIRONMENT=$null
    if (Test-Path -LiteralPath $fixtureFile) { Remove-Item -LiteralPath $fixtureFile -Force }
    $env:PGOPTIONS=$null
    & $psql -X -w -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS $schema CASCADE" | Out-Null
    $clean = & $psql -X -w -Atqc "select to_regnamespace('$schema') is null"
    # Cleared last, because every psql call above still needs them. Dot-sourcing this script would
    # otherwise leave the database password behind in the caller's environment.
    $env:PGHOST=$null; $env:PGPORT=$null; $env:PGDATABASE=$null; $env:PGUSER=$null; $env:PGPASSWORD=$null
    if ($clean -ne 't') { Write-Output 'I9 MVP WORKFLOW FAIL: temporal schema cleanup'; exit 1 }
}
