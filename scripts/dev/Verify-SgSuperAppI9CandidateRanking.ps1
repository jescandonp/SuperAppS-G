[CmdletBinding()]
param([string]$RepositoryRoot,[int]$Port = 5425)

# M4 (roadmap acordado 2026-09-01 tras el piloto real anonimizado): "Generar propuesta" ahora rankea a
# los candidatos que M3 evalua y persiste la asignacion real (o la vacante real, con su motivo) via
# SchedulingRecommendationEngine + PersistScheduleRecommendationAsync - piezas ya probadas de forma
# aislada en Verify-SgSuperAppI9MvpGeneration.ps1, aqui se les da entrada real desde la base de datos.
#
# Hallazgo real descubierto al construir este verificador (no un defecto de M4, un hueco de datos ya
# conocido que ahora tiene consecuencia visible): I9-R04 siempre sale WARNING cuando no hay integracion
# real con I2 (BuildCandidateFactsAsync envia noveltyEvaluations=[] a proposito, nunca inventa
# disponibilidad), y SchedulingEligibilityService proyecta WARNING como BLOQUEANTE ("un turno sin
# verificar no acredita nada"). Eso significa que, HOY, ningun candidato real puede terminar ASIGNADA
# via "Generar propuesta" - todo sale VACANTE. Este verificador no fuerza un ganador artificial (seria
# fabricar disponibilidad, lo que el diseno prohibe); en su lugar confirma que el cableado real de M4
# funciona correctamente incluso en este estado: dos candidatos con historial real distinto llegan
# ambos al motor via BuildCandidateFactsAsync + PersistEvaluationsAsync, sus veredictos reales se
# diferencian entre si (I9-R02 EXCEPTION_REQUIRED solo para quien tiene descanso real insuficiente), el
# placeholder de M2 (CANDIDATES_NOT_EVALUATED) ya no aparece, y un turno con cero candidatos reales
# sigue llegando al motor (Candidates=[]) en vez de desaparecer silenciosamente. La base temporal se
# elimina y la API se detiene siempre.

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
    Write-Output 'I9 CANDIDATE RANKING BLOCKED: local prerequisites unavailable'; exit 2
}

$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$parts = @{}
foreach ($part in ([string]$settings.ConnectionStrings.Postgres -split ';')) {
    if ($part -match '^([^=]+)=(.*)$') { $parts[$matches[1].Trim()] = $matches[2] }
}
if (@('Host','Port','Database','Username','Password') | Where-Object { -not $parts[$_] }) {
    Write-Output 'I9 CANDIDATE RANKING BLOCKED: local PostgreSQL configuration incomplete'; exit 2
}
$env:PGHOST=$parts.Host; $env:PGPORT=$parts.Port; $env:PGDATABASE=$parts.Database
$env:PGUSER=$parts.Username; $env:PGPASSWORD=$parts.Password

$passed = 0
function Q([bool]$value,[string]$label) { if (-not $value) { throw $label }; $script:passed++; Write-Output ($label + ' PASS') }

function Call([string]$method,[string]$uri,$headers,$body) {
    try {
        $arguments = @{ Uri = $uri; Method = $method; UseBasicParsing = $true; Headers = $headers; ContentType = 'application/json' }
        if ($null -ne $body) { $arguments.Body = ($body | ConvertTo-Json -Depth 8) }
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

$schema = 'i9_rank_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$apiProcess = $null
$fixtureFile = Join-Path ([System.IO.Path]::GetTempPath()) ($schema + '.sql')
try {
    & $dotnet build $project --configuration Release | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 CANDIDATE RANKING FAIL: API build failed'; exit 1 }

    & $psql -X -w -v ON_ERROR_STOP=1 -c "CREATE SCHEMA $schema" | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 CANDIDATE RANKING BLOCKED: cannot create temporal schema'; exit 2 }
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

    # I9-RANK-POS: dos candidatos vigentes, turno de 8h (08:00-16:00, igual a ordinaryDailyHours -> I9-R01
    #   sale COMPLIANT, no interfiere con la prueba). I9-RANK-1 no tiene historial (I9-R02 COMPLIANT via
    #   ancla de 30 dias); I9-RANK-2 tiene un turno real que termina a las 22:00 del 2026-09-01, a solo
    #   10h del turno propuesto (08:00 del 2026-09-02) -> I9-R02 EXCEPTION_REQUIRED, y ese mismo turno
    #   previo es lo que hace que WorkedPreviousCalendarDayAsync marque continuity=1 para I9-RANK-2.
    # I9-RANK-EMPTY-POS: cobertura configurada, cero employee_position_assignments -> el motor debe
    #   recibir este turno con Candidates=[] y no omitirlo.
    $fixture = @'
INSERT INTO clients(code,name,status) VALUES('I9-RANK-CLIENT','Cliente anonimo de ranking','ACTIVO');
INSERT INTO service_projects(client_id,code,name,effective_from,status,created_at,updated_at)
 SELECT id,'PROJECT-A','Proyecto anonimo de ranking',date '2026-01-01','ACTIVO',now(),now() FROM clients WHERE code='I9-RANK-CLIENT';
INSERT INTO service_positions(code,name,project_id,status)
 SELECT 'I9-RANK-POS','Puesto anonimo de ranking',id,'ACTIVO' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO service_positions(code,name,project_id,status)
 SELECT 'I9-RANK-EMPTY-POS','Puesto anonimo sin candidatos',id,'ACTIVO' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO service_positions(code,name,status) VALUES('I9-RANK-PREV-POS','Puesto anonimo previo','ACTIVO');
INSERT INTO employees(identification_type,identification_number,full_name,employment_status,job_title,hire_date)
 VALUES('CC','I9-RANK-1','Candidato anonimo uno','ACTIVO','GUARDA',date '2026-01-01'),
        ('CC','I9-RANK-2','Candidato anonimo dos','ACTIVO','GUARDA',date '2026-01-01');
INSERT INTO employee_position_assignments(employee_id,position_id,start_date,status)
 SELECT e.id, sp.id, date '2026-01-01', 'VIGENTE' FROM employees e, service_positions sp
 WHERE e.identification_number in ('I9-RANK-1','I9-RANK-2') AND sp.code='I9-RANK-POS';
INSERT INTO position_coverage_rules(position_id,template_id,weekday_scope,starts_at,ends_at,required_quantity,effective_from,status)
 SELECT sp.id, st.id, 'TODOS', '08:00', '16:00', 1, date '2026-09-01', 'ACTIVO'
 FROM service_positions sp, shift_templates st WHERE sp.code='I9-RANK-POS' AND st.code='2X2' AND st.version=1;
INSERT INTO position_coverage_rules(position_id,template_id,weekday_scope,starts_at,ends_at,required_quantity,effective_from,status)
 SELECT sp.id, st.id, 'TODOS', '09:00', '17:00', 1, date '2026-09-01', 'ACTIVO'
 FROM service_positions sp, shift_templates st WHERE sp.code='I9-RANK-EMPTY-POS' AND st.code='2X2' AND st.version=1;
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-01',date '2026-09-01','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by)
 SELECT s.id,1,'PUBLICADA','operaciones.sg' FROM schedules s JOIN service_projects sp ON sp.id=s.project_id WHERE sp.code='PROJECT-A';
INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at,required_quantity)
 SELECT sv.id, sp.id, date '2026-09-01', time '14:00', time '22:00', 1
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id JOIN service_projects p ON p.id=s.project_id,
 service_positions sp WHERE p.code='PROJECT-A' AND sp.code='I9-RANK-PREV-POS';
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status)
 SELECT rs.schedule_version_id, rs.id, e.id, 'ASIGNADA' FROM required_shifts rs
 JOIN employees e ON e.identification_number='I9-RANK-2'
 WHERE rs.shift_date=date '2026-09-01';
'@
    Set-Content -LiteralPath $fixtureFile -Value $fixture -Encoding UTF8
    & $psql -X -w -v ON_ERROR_STOP=1 -f $fixtureFile | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'anonymous ranking fixture failed' }

    $projectId = Scalar "select id from service_projects where code='PROJECT-A'"
    $rankPositionId = Scalar "select id from service_positions where code='I9-RANK-POS'"
    $emptyPositionId = Scalar "select id from service_positions where code='I9-RANK-EMPTY-POS'"

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
    Q $true 'RK-T01 the API starts against the isolated schema'

    $login = $null
    foreach ($attempt in 1..10) {
        $login = Call 'Post' "$base/auth/login" $null @{ username='operaciones.sg'; password='Operaciones123' }
        if ($login.Status -eq 200) { break }
        Start-Sleep -Milliseconds 750
    }
    if ($login.Status -ne 200) { throw "login failed with HTTP $($login.Status): $($login.Content)" }
    $headers = @{ Authorization = "Bearer $(($login.Content | ConvertFrom-Json).sessionToken)" }

    $generated = Call 'Post' "$base/portal/scheduling/projects/$projectId/proposals" $headers @{ periodStart='2026-09-02'; periodEnd='2026-09-02' }
    Q ($generated.Status -eq 201) "RK-T02 POST /proposals answers 201 ($($generated.Content))"
    $proposal = $generated.Content | ConvertFrom-Json
    $versionId = $proposal.versionId

    Q (@($proposal.assignments).Count -eq 2) 'RK-T03 one slot per position was generated'
    Q (@($proposal.assignments | Where-Object { $_.status -ne 'VACANTE' }).Count -eq 0) 'RK-T03 both slots are VACANTE (I9-R04 unconditionally warns with no real I2 integration yet, so nobody can be ASIGNADA today)'
    Q (@($proposal.assignments | Where-Object { $_.employeeId }).Count -eq 0) 'RK-T03 neither VACANTE slot carries a fabricated employeeId'

    $rankAssignment = $proposal.assignments | Where-Object { [string]$_.positionId -eq $rankPositionId }
    $emptyAssignment = $proposal.assignments | Where-Object { [string]$_.positionId -eq $emptyPositionId }
    Q ($null -ne $rankAssignment -and $null -ne $emptyAssignment) 'RK-T04 both positions are identifiable in the response'

    $rankMessages = @($rankAssignment.reasons | ForEach-Object { $_.message })
    Q (($rankMessages -notcontains 'NO_ELIGIBLE_CANDIDATES') -and ($rankMessages -notcontains 'CANDIDATES_NOT_EVALUATED')) 'RK-T05 the position with real candidates is never reduced to a zero-candidate or M2 placeholder reason'
    Q (($rankMessages | Where-Object { $_ -match 'I9_R04_UNVERIFIED' }).Count -gt 0) 'RK-T06 the real rule verdicts (I9-R04, unresolved without I2) reach the ranking engine, not a fabricated eligibility'
    Q (($rankMessages | Where-Object { $_ -match 'I9_R02_EXCEPTION_REQUIRED' }).Count -gt 0) 'RK-T07 the candidate with real insufficient rest contributes its own I9-R02 reason to the vacancy explanation'

    $emptyMessages = @($emptyAssignment.reasons | ForEach-Object { $_.message })
    Q (@($emptyMessages).Count -eq 1 -and $emptyMessages[0] -eq 'NO_ELIGIBLE_CANDIDATES') 'RK-T08 the position with zero real candidates still reaches the engine (Candidates=[]) instead of being silently dropped'

    $evaluationCount = [int](Scalar "select count(*) from scheduling_rule_evaluations where schedule_version_id=$versionId")
    Q ($evaluationCount -eq 14) 'RK-T09 both real candidates were evaluated against all seven rules (2 x 7 = 14 rows); the zero-candidate position produced none'

    Q ($proposal.vacancyCount -eq 2) 'RK-T10 schedule_versions.vacancy_count reflects both real vacancies (metrics refreshed after M4 wrote the real assignments)'
    Q ($proposal.coveragePercent -eq 0) 'RK-T10 coveragePercent stays honestly at 0 while nobody can be ASIGNADA'

    $asignadaCount = [int](Scalar "select count(*) from schedule_assignments where schedule_version_id=$versionId and status='ASIGNADA'")
    Q ($asignadaCount -eq 0) 'RK-T11 no ASIGNADA row exists yet for this version - documented data gap (I9-R04 needs real I2 integration), not a ranking bug'

    Q ($passed -eq 14) 'numbered candidate-ranking assertion count'
    Write-Output "I9 CANDIDATE RANKING PASS $passed"
    exit 0
}
catch { Write-Output "I9 CANDIDATE RANKING FAIL: $($_.Exception.Message)"; exit 1 }
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
    $env:PGHOST=$null; $env:PGPORT=$null; $env:PGDATABASE=$null; $env:PGUSER=$null; $env:PGPASSWORD=$null
    if ($clean -ne 't') { Write-Output 'I9 CANDIDATE RANKING FAIL: temporal schema cleanup'; exit 1 }
}
