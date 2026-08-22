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
    Q ($blockedApprove.Content -match 'bloqueadas o sin verificar') 'WF-T07 the refusal names the blocking rule'
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

    Q ($passed -eq 40) 'numbered workflow assertion count'
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
    if ($clean -ne 't') { Write-Output 'I9 MVP WORKFLOW FAIL: temporal schema cleanup'; exit 1 }
}
