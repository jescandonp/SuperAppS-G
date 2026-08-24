[CmdletBinding()]
param([string]$RepositoryRoot,[int]$Port = 5421)

# The hermetic closure suite for the MVP rule engine. It exists mainly to cover the one path nothing
# else did: POST /api/portal/scheduling/rules/evaluate over HTTP. Every other verifier hand-seeds
# scheduling_rule_evaluations with psql, so until now the route that actually produces a verdict -
# from facts a caller supplies, under SCHEDULING/GENERATE - had no runtime coverage at all.
# The temporary schema is always dropped and the API process is always stopped.

$ErrorActionPreference = 'Stop'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
} else { (Resolve-Path $RepositoryRoot).Path }

$dotnet = 'C:\tmp\dotnet6\dotnet.exe'
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
$settingsPath = Join-Path $repoRoot 'apps/sg-superapp-api/appsettings.json'
$project = Join-Path $repoRoot 'apps/sg-superapp-api/sg-superapp-api.csproj'
if (-not (Test-Path -LiteralPath $dotnet -PathType Leaf) -or -not (Test-Path -LiteralPath $psql -PathType Leaf) -or
    -not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    Write-Output 'I9 MVP INTEGRATION BLOCKED: local prerequisites unavailable'; exit 2
}

$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$parts = @{}
foreach ($part in ([string]$settings.ConnectionStrings.Postgres -split ';')) {
    if ($part -match '^([^=]+)=(.*)$') { $parts[$matches[1].Trim()] = $matches[2] }
}
if (@('Host','Port','Database','Username','Password') | Where-Object { -not $parts[$_] }) {
    Write-Output 'I9 MVP INTEGRATION BLOCKED: local PostgreSQL configuration incomplete'; exit 2
}
$env:PGHOST=$parts.Host; $env:PGPORT=$parts.Port; $env:PGDATABASE=$parts.Database
$env:PGUSER=$parts.Username; $env:PGPASSWORD=$parts.Password

$passed = 0
function Q([bool]$value,[string]$label) { if (-not $value) { throw $label }; $script:passed++; Write-Output ($label + ' PASS') }

function Call([string]$method,[string]$uri,$headers,$body) {
    try {
        $arguments = @{ Uri = $uri; Method = $method; UseBasicParsing = $true; ContentType = 'application/json' }
        if ($null -ne $headers) { $arguments.Headers = $headers }
        if ($null -ne $body) { $arguments.Body = ($body | ConvertTo-Json -Depth 12) }
        $response = Invoke-WebRequest @arguments
        return @{ Status = [int]$response.StatusCode; Content = [string]$response.Content }
    }
    catch {
        $response = $_.Exception.Response
        if ($null -eq $response) { throw }
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $text = $reader.ReadToEnd(); $reader.Dispose()
        return @{ Status = [int]$response.StatusCode; Content = $text }
    }
}

function Scalar([string]$sql) {
    $value = & $psql -X -w -Atqc $sql
    if ($LASTEXITCODE -ne 0) { throw "query failed: $sql" }
    return ([string]$value).Trim()
}

$schema = 'i9_mvpint_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$apiProcess = $null
$fixtureFile = Join-Path ([System.IO.Path]::GetTempPath()) ($schema + '.sql')
$exportFile = Join-Path ([System.IO.Path]::GetTempPath()) ($schema + '.xlsx')
# Declared here rather than beside its use, so the finally block below can remove it even when
# an assertion fails between writing it and the cleanup that used to live inside the try.
$pdfFile = Join-Path ([System.IO.Path]::GetTempPath()) ($schema + '.pdf')
try {
    & $dotnet build $project --configuration Release | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 MVP INTEGRATION FAIL: API build failed'; exit 1 }

    & $psql -X -w -v ON_ERROR_STOP=1 -c "CREATE SCHEMA $schema" | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 MVP INTEGRATION BLOCKED: cannot create temporal schema'; exit 2 }
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
    & $psql -X -w -v ON_ERROR_STOP=1 -f (Join-Path $repoRoot 'db/tests/008_i9_mvp_rule_profiles_contract.sql') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'the MVP_TEST rule profile contract failed' }

    # Anonymous fixture: no real client, project, position or guard appears anywhere in it.
    $fixture = @'
INSERT INTO clients(code,name,status) VALUES('I9-INT-CLIENT','Cliente anonimo de cierre','ACTIVO');
INSERT INTO service_projects(client_id,code,name,effective_from,status,created_at,updated_at)
 SELECT id,'PROJECT-A','Proyecto anonimo de cierre',date '2026-01-01','ACTIVO',now(),now() FROM clients WHERE code='I9-INT-CLIENT';
INSERT INTO service_positions(code,name,status) VALUES('I9-INT-POSITION','Puesto anonimo de cierre','ACTIVO');
INSERT INTO employees(identification_type,identification_number,full_name,employment_status,job_title,hire_date)
 VALUES('CC','I9-INT-1','Guarda anonimo de cierre','ACTIVO','GUARDA',date '2026-01-01');
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-08-21',date '2026-08-21','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-08-22',date '2026-08-22','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',TRUE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p WHERE p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at)
 SELECT sv.id,sp.id,s.period_start,time '08:00',time '20:00'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN service_positions sp WHERE sp.code='I9-INT-POSITION';
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status)
 SELECT r.schedule_version_id,r.id,e.id,'ASIGNADA' FROM required_shifts r
 CROSS JOIN employees e WHERE e.identification_number='I9-INT-1';
-- Una tercera version que la base permite y que el fixture nunca habia producido: perfil versionado
-- SIN marca de simulado. Es la forma exacta sobre la que el encabezado de exportacion mentia, y su
-- ausencia dejaba el arreglo sin nada que lo defendiera.
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-08-23',date '2026-08-23','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',FALSE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p
 WHERE s.period_start=date '2026-08-23' AND p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at)
 SELECT sv.id,sp.id,s.period_start,time '08:00',time '20:00'
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN service_positions sp WHERE s.period_start=date '2026-08-23' AND sp.code='I9-INT-POSITION';
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status)
 SELECT r.schedule_version_id,r.id,e.id,'ASIGNADA' FROM required_shifts r
 JOIN schedule_versions sv ON sv.id=r.schedule_version_id
 JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN employees e WHERE s.period_start=date '2026-08-23' AND e.identification_number='I9-INT-1';
'@
    Set-Content -LiteralPath $fixtureFile -Value $fixture -Encoding UTF8
    & $psql -X -w -v ON_ERROR_STOP=1 -f $fixtureFile | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'anonymous SIMULATED / MVP_TEST fixture failed' }

    $evaluatedVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-08-21'"
    $exportVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-08-22'"
    $evaluatedAssignment = Scalar "select id from schedule_assignments where schedule_version_id=$evaluatedVersion"
    $plainVersion = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id where s.period_start=date '2026-08-23'"
    $profileId = Scalar "select id from scheduling_rule_profiles where profile_code='I9-MVP-SIMULATED' and status='ACTIVE'"

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
    Q $true 'MI-T01 the API starts against the isolated schema'

    $login = Call 'Post' "$base/auth/login" $null @{ username='operaciones.sg'; password='Operaciones123' }
    if ($login.Status -ne 200) { throw "login failed with HTTP $($login.Status)" }
    $headers = @{ Authorization = "Bearer $(($login.Content | ConvertFrom-Json).sessionToken)" }

    # Anonymous facts. Nothing here identifies a person or a site: codes only, as the rule contract
    # requires, and every one of the seven rules has something to read.
    $cells = @(@{ employeeId='GUARD-1'; date='2026-08-21'; cell='C1'; shiftCode='D' })
    $facts = @{
        dailyHours = 8; weeklyHours = 42; writtenAgreement = $false
        previousShiftEnd = '2026-08-20T20:00:00-05:00'
        proposedShiftStart = '2026-08-21T08:00:00-05:00'; proposedShiftEnd = '2026-08-21T20:00:00-05:00'
        assignmentId = 'ASSIGN-1'; scheduleVersionId = 'SCHEDULE-1'; employeeId = 'GUARD-1'
        positionCode = 'POSITION-1'; shiftId = 'SHIFT-1'
        shiftStart = '2026-08-21T08:00:00-05:00'; shiftEnd = '2026-08-21T20:00:00-05:00'
        existingIntervals = @()
        previousAssignmentId = 'ASSIGN-0'; originPositionCode = 'POSITION-1'; destinationPositionCode = 'POSITION-1'
        previousShiftStart = '2026-08-20T08:00:00-05:00'
        templateCode = '2X2'; templateVersion = '1'; anchorDate = '2026-08-21'
        expectedCells = $cells; proposedCells = $cells
        noveltyEvaluations = @(); requirementEvaluations = @()
    }
    $request = @{ ruleProfileId = [long]$profileId; projectCode = 'PROJECT-A'; period = '2026-08-21'; environmentScope = 'MVP_TEST'; facts = $facts }
    $evaluateUri = "$base/portal/scheduling/rules/evaluate?scheduleVersionId=$evaluatedVersion&assignmentId=$evaluatedAssignment"

    $first = Call 'Post' $evaluateUri $headers $request
    Q ($first.Status -eq 200) "MI-T02 the seven rules are evaluated over HTTP (status $($first.Status): $($first.Content))"
    $batch = $first.Content | ConvertFrom-Json
    foreach ($rule in @('I9-R01','I9-R02','I9-R03','I9-R04','I9-R05','I9-R06','I9-R07')) {
        Q (@($batch.evaluations | Where-Object ruleCode -eq $rule).Count -eq 1) "MI-T02 $rule was evaluated"
    }
    Q ($batch.simulated -eq $true) 'MI-T02 the batch is marked SIMULATED'
    Q ($batch.profileVersion -gt 0) 'MI-T02 the batch declares the profile version it came from'
    Q (@($batch.evaluations | Where-Object { $_.scopeHash -notmatch '^[0-9a-f]{64}$' }).Count -eq 0) 'MI-T02 every verdict carries a well formed scope'
    Q ([int](Scalar "select count(*) from scheduling_rule_evaluations where schedule_version_id=$evaluatedVersion") -eq 7) 'MI-T02 the seven verdicts are persisted'
    # Counting rows let every rule silently degrade to its unavailable-evaluator fallback while the
    # suite still read as covering seven rules. Under fail-closed that is the one state to shout
    # about: it means nothing was actually decided.
    Q (@($batch.evaluations | Where-Object { $_.messageCode -match 'EVALUATOR_UNAVAILABLE' }).Count -eq 0) 'MI-T02 no rule fell back to an unavailable evaluator'

    # PRODUCTION is refused outright: this MVP never asserts institutional policy. The status code
    # alone proved nothing - with the guard deleted a 409 still arrived, from the profile lookup
    # failing to find an ACTIVE PRODUCTION profile. That is an accident of the fixture, not a
    # policy, and it would evaporate the day someone seeds one. The refusal must be the guard's.
    $production = Call 'Post' $evaluateUri $headers (@{ ruleProfileId = [long]$profileId; projectCode = 'PROJECT-A'; period = '2026-08-21'; environmentScope = 'PRODUCTION'; facts = $facts })
    Q ($production.Status -eq 409) 'MI-T03 a PRODUCTION scope is rejected'
    Q ($production.Content -match 'persistencia de evaluaciones productivas no esta habilitada') 'MI-T03 the refusal is the production policy, not a missing profile'
    Q ([int](Scalar "select count(*) from scheduling_rule_evaluations where schedule_version_id=$evaluatedVersion") -eq 7) 'MI-T03 the rejected PRODUCTION request persists nothing'

    # Double execution: the history is append-only, so a second run adds rows rather than replacing
    # them - and the scope each verdict was decided under must be identical, or the snapshot is not
    # a function of the inputs and no earlier approval could ever be trusted.
    $second = Call 'Post' $evaluateUri $headers $request
    Q ($second.Status -eq 200) 'MI-T04 the same evaluation runs a second time'
    $secondBatch = $second.Content | ConvertFrom-Json
    $firstScopes = ($batch.evaluations | Sort-Object ruleCode | ForEach-Object { "$($_.ruleCode)=$($_.scopeHash)" }) -join ','
    $secondScopes = ($secondBatch.evaluations | Sort-Object ruleCode | ForEach-Object { "$($_.ruleCode)=$($_.scopeHash)" }) -join ','
    Q ($firstScopes -eq $secondScopes) 'MI-T04 the second execution derives the same scope for every rule'
    Q ([int](Scalar "select count(*) from scheduling_rule_evaluations where schedule_version_id=$evaluatedVersion") -eq 14) 'MI-T04 the double execution appends rather than replaces'
    # Stability alone is satisfied by a constant, and a constant scope would let one approved
    # exception silently vouch for every other scenario. The snapshot must also MOVE when the facts
    # move, so the same rule is evaluated against changed facts and its scope compared.
    $movedFacts = $facts.Clone()
    $movedFacts.dailyHours = 11
    $moved = Call 'Post' $evaluateUri $headers (@{ ruleProfileId = [long]$profileId; projectCode = 'PROJECT-A'; period = '2026-08-21'; environmentScope = 'MVP_TEST'; facts = $movedFacts })
    Q ($moved.Status -eq 200) 'MI-T04 changed facts are evaluated'
    $movedR01 = (($moved.Content | ConvertFrom-Json).evaluations | Where-Object ruleCode -eq 'I9-R01').scopeHash
    $firstR01 = ($batch.evaluations | Where-Object ruleCode -eq 'I9-R01').scopeHash
    Q ($movedR01 -ne $firstR01) 'MI-T04 a change in the facts a rule reads moves its scope'

    # Precedence: a blocked rule decides, whatever the others say.
    $blockedFacts = $facts.Clone()
    $blockedFacts.existingIntervals = @(@{ employeeId='GUARD-1'; status='APPROVED'; start='2026-08-21T09:00:00-05:00'; end='2026-08-21T10:00:00-05:00' })
    $blocked = Call 'Post' $evaluateUri $headers (@{ ruleProfileId = [long]$profileId; projectCode = 'PROJECT-A'; period = '2026-08-21'; environmentScope = 'MVP_TEST'; facts = $blockedFacts })
    Q ($blocked.Status -eq 200) 'MI-T05 an overlapping shift is evaluated'
    $blockedBatch = $blocked.Content | ConvertFrom-Json
    Q ($blockedBatch.summary.blocked -ge 1) 'MI-T05 the overlap is reported as blocked'
    Q ($blockedBatch.summary.canApproveOrPublish -eq $false) 'MI-T05 a blocked rule decides over the compliant ones'

    # Invalidation: editing the assignment leaves every verdict describing something that changed.
    $guard = Scalar "select employee_id from schedule_assignments where id=$evaluatedAssignment"
    $edit = Call 'Put' "$base/portal/scheduling/proposals/$evaluatedVersion/assignments/$evaluatedAssignment" $headers @{ employeeId=[long]$guard; status='ASIGNADA'; reasons=@('Ajuste manual'); expectedVersion=1 }
    Q ($edit.Status -eq 200) 'MI-T06 the assignment is edited'
    $afterEdit = Call 'Post' "$base/portal/scheduling/proposals/$evaluatedVersion/approve" $headers @{ expectedVersion=1 }
    Q ($afterEdit.Status -eq 409) 'MI-T06 the edit invalidates the verdicts that described the assignment'
    Q ($afterEdit.Content -match 'RULE_EVALUATION_SUPERSEDED|RULE_BLOCKED') 'MI-T06 the refusal names a state, not a sentence'

    # Exports carry the profile and the simulated mark, on the document and in the audit trail.
    # The base fixture already gave this version its shift and its assignment; only the verdict is
    # missing. Re-inserting the shift would collide with required_shifts_natural_key.
    & $psql -X -w -v ON_ERROR_STOP=1 -c "insert into scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,correlation_id,evaluated_at,audit_actor) select $exportVersion,a.id,$profileId,'I9-R01','COMPLIANT','INFO','I9_R01_COMPLIANT','Jornada conforme.',jsonb_build_object('maxDailyHours',12),jsonb_build_object('dailyHours',8),repeat('f',64),FALSE,'NOT_REQUIRED','i9-mvpint-export',now(),'operaciones.sg' from schedule_assignments a where a.schedule_version_id=$exportVersion" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'could not prepare the export fixture' }
    $approveExport = Call 'Post' "$base/portal/scheduling/proposals/$exportVersion/approve" $headers @{ expectedVersion=1 }
    Q ($approveExport.Status -eq 200) "MI-T07 a fully decided version is approved ($($approveExport.Content))"
    $publishExport = Call 'Post' "$base/portal/scheduling/proposals/$exportVersion/publish" $headers @{ expectedVersion=1 }
    Q ($publishExport.Status -eq 200) 'MI-T07 the version is published'

    Invoke-WebRequest -UseBasicParsing -Uri "$base/portal/scheduling/versions/$exportVersion/export.xlsx" -Headers $headers -OutFile $exportFile | Out-Null
    Q (Test-Path -LiteralPath $exportFile) 'MI-T08 the spreadsheet export is produced'
    $exportText = [System.IO.File]::ReadAllBytes($exportFile)
    Q ($exportText.Length -gt 0) 'MI-T08 the export is not empty'
    $auditDetail = Scalar "select detail::text from audit_log where event_type='SCHEDULE_EXPORTED' and entity_id='$exportVersion' order by id desc limit 1"
    Q ($auditDetail -match '"simulated": true') 'MI-T08 the export audit records the simulated mark'
    Q ($auditDetail -match '"ruleProfileId"') 'MI-T08 the export audit records the rule profile'
    $transitionDetail = Scalar "select detail::text from audit_log where event_type='SCHEDULE_PUBLISHED' and entity_id='$exportVersion' order by id desc limit 1"
    Q ($transitionDetail -match '"simulated": true' -and $transitionDetail -match '"ruleProfileId"') 'MI-T08 the publication audit records the profile and the simulated mark'

    # The audit trail is not enough: once an export leaves the application it is read on its own.
    # A simulated roster that does not say so on its face is indistinguishable from a real one.
    Invoke-WebRequest -UseBasicParsing -Uri "$base/portal/scheduling/versions/$exportVersion/export.pdf" -Headers $headers -OutFile $pdfFile | Out-Null
    $pdfText = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($pdfFile))
    Q ($pdfText -match 'DATOS SIMULADOS') 'MI-T09 the exported document states the simulated origin on its face'
    Q ($pdfText -match 'perfil') 'MI-T09 the exported document names the rule profile behind it'
    # The spreadsheet is the copy people forward and edit, so it is the one that most needs to say
    # what it is. Only the PDF was checked, and dropping the header from BuildXlsx survived.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($exportFile)
    try {
        $sheet = $archive.Entries | Where-Object { $_.FullName -like '*sheet1.xml' }
        $reader = New-Object System.IO.StreamReader($sheet.Open())
        $sheetXml = $reader.ReadToEnd(); $reader.Dispose()
    } finally { $archive.Dispose() }
    Q ($sheetXml -match 'DATOS SIMULADOS') 'MI-T09 the spreadsheet states the simulated origin too'
    if (Test-Path -LiteralPath $pdfFile) { Remove-Item -LiteralPath $pdfFile -Force }

    # MI-T10. Every version exported above carries the simulated mark AND a profile, which is the one
    # shape the broken header and the fixed header printed identically. Restoring the pre-fix code
    # verbatim left this suite at PASS, so the fix it was written to protect was undefended. This
    # exports the shape the schema permits and the fixture never produced: a versioned profile with
    # no simulated mark. The clause that used to lie is the one asserted.
    & $psql -X -w -v ON_ERROR_STOP=1 -c "insert into scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,correlation_id,evaluated_at,audit_actor) select $plainVersion,a.id,$profileId,'I9-R01','COMPLIANT','INFO','I9_R01_COMPLIANT','Jornada conforme.',jsonb_build_object('maxDailyHours',12),jsonb_build_object('dailyHours',8),repeat('e',64),FALSE,'NOT_REQUIRED','i9-mvpint-plain',now(),'operaciones.sg' from schedule_assignments a where a.schedule_version_id=$plainVersion" 2>&1 | Out-Null
    $approvePlain = Call 'Post' "$base/portal/scheduling/proposals/$plainVersion/approve" $headers @{ expectedVersion=1 }
    Q ($approvePlain.Status -eq 200) 'MI-T10 a decided version with a profile and no simulated mark is approved'
    $publishPlain = Call 'Post' "$base/portal/scheduling/proposals/$plainVersion/publish" $headers @{ expectedVersion=1 }
    Q ($publishPlain.Status -eq 200) 'MI-T10 that version is published'
    $plainPdf = Join-Path ([System.IO.Path]::GetTempPath()) ($schema + '-plain.pdf')
    Invoke-WebRequest -UseBasicParsing -Uri "$base/portal/scheduling/versions/$plainVersion/export.pdf" -Headers $headers -OutFile $plainPdf | Out-Null
    # ASCII y no Latin1: Encoding::Latin1 llega con .NET 5 y aqui es $null en Windows PowerShell 5.1.
    $plainText = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($plainPdf))
    Q ($plainText -notmatch 'DATOS SIMULADOS') 'MI-T10 a version without the simulated mark is not called simulated'
    Q ($plainText -match 'sin perfil de reglas versionado' -eq $false) 'MI-T10 a version carrying a profile is never said to lack one'
    Q ($plainText -match 'perfil \d+ version \d+') 'MI-T10 the document names the profile it does carry'
    if (Test-Path -LiteralPath $plainPdf) { Remove-Item -LiteralPath $plainPdf -Force }

    Q ($passed -eq 43) 'numbered integration assertion count'
    Write-Output "I9 MVP INTEGRATION PASS $passed"
    exit 0
}
catch { Write-Output "I9 MVP INTEGRATION FAIL: $($_.Exception.Message)"; exit 1 }
finally {
    if ($null -ne $apiProcess -and -not $apiProcess.HasExited) {
        Stop-Process -Id $apiProcess.Id -Force -ErrorAction SilentlyContinue
        $apiProcess.WaitForExit(10000) | Out-Null
    }
    $env:ConnectionStrings__Postgres=$null; $env:ASPNETCORE_URLS=$null; $env:ASPNETCORE_ENVIRONMENT=$null
    foreach ($path in @($fixtureFile, $exportFile, $pdfFile)) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
    $env:PGOPTIONS=$null
    & $psql -X -w -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS $schema CASCADE" | Out-Null
    $clean = & $psql -X -w -Atqc "select to_regnamespace('$schema') is null"
    $env:PGHOST=$null; $env:PGPORT=$null; $env:PGDATABASE=$null; $env:PGUSER=$null; $env:PGPASSWORD=$null
    if ($clean -ne 't') { Write-Output 'I9 MVP INTEGRATION FAIL: temporal schema cleanup'; exit 1 }
}
