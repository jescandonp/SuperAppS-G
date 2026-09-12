[CmdletBinding()]
param([string]$RepositoryRoot,[int]$Port = 5424)

# M3 (roadmap acordado 2026-09-01 tras el piloto real anonimizado): "Generar propuesta" ahora evalua
# candidatos reales contra las siete reglas por cada turno requerido que M2 expande, con hechos
# calculados de datos ya persistidos (nunca inventados). Este verificador siembra un escenario chico
# pero real: dos candidatos para un mismo puesto, uno de ellos con un turno previo demasiado cercano
# (deberia salir I9-R02 EXCEPTION_REQUIRED) y otro sin historial (deberia salir I9-R02 COMPLIANT). Sin
# cobertura de novedades/requisitos configurada, R04/R06 deben salir sin presumir cumplimiento. La base
# temporal se elimina y la API se detiene siempre.

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
    Write-Output 'I9 CANDIDATE EVALUATION BLOCKED: local prerequisites unavailable'; exit 2
}

$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$parts = @{}
foreach ($part in ([string]$settings.ConnectionStrings.Postgres -split ';')) {
    if ($part -match '^([^=]+)=(.*)$') { $parts[$matches[1].Trim()] = $matches[2] }
}
if (@('Host','Port','Database','Username','Password') | Where-Object { -not $parts[$_] }) {
    Write-Output 'I9 CANDIDATE EVALUATION BLOCKED: local PostgreSQL configuration incomplete'; exit 2
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

$schema = 'i9_eval_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$apiProcess = $null
$fixtureFile = Join-Path ([System.IO.Path]::GetTempPath()) ($schema + '.sql')
try {
    & $dotnet build $project --configuration Release | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 CANDIDATE EVALUATION FAIL: API build failed'; exit 1 }

    & $psql -X -w -v ON_ERROR_STOP=1 -c "CREATE SCHEMA $schema" | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 CANDIDATE EVALUATION BLOCKED: cannot create temporal schema'; exit 2 }
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

    # Un puesto, dos candidatos con historial real distinto:
    #  - I9-EVAL-1 tiene un turno vivo que termina 2026-09-01 22:00, a solo 10h del propuesto (08:00 del
    #    2026-09-02) -> I9-R02 debe salir EXCEPTION_REQUIRED (perfil MVP_TEST exige minimo 12h de descanso).
    #  - I9-EVAL-2 no tiene historial -> I9-R02 debe salir COMPLIANT (ancla de 30 dias atras, descanso holgado).
    $fixture = @'
INSERT INTO clients(code,name,status) VALUES('I9-EVAL-CLIENT','Cliente anonimo de evaluacion','ACTIVO');
INSERT INTO service_projects(client_id,code,name,effective_from,status,created_at,updated_at)
 SELECT id,'PROJECT-A','Proyecto anonimo de evaluacion',date '2026-01-01','ACTIVO',now(),now() FROM clients WHERE code='I9-EVAL-CLIENT';
INSERT INTO service_positions(code,name,project_id,status)
 SELECT 'I9-EVAL-POS','Puesto anonimo de evaluacion',id,'ACTIVO' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO service_positions(code,name,status) VALUES('I9-EVAL-PREV-POS','Puesto anonimo previo','ACTIVO');
INSERT INTO employees(identification_type,identification_number,full_name,employment_status,job_title,hire_date)
 VALUES('CC','I9-EVAL-1','Candidato anonimo uno','ACTIVO','GUARDA',date '2026-01-01'),
        ('CC','I9-EVAL-2','Candidato anonimo dos','ACTIVO','GUARDA',date '2026-01-01');
INSERT INTO employee_position_assignments(employee_id,position_id,start_date,status)
 SELECT e.id, sp.id, date '2026-01-01', 'VIGENTE' FROM employees e, service_positions sp
 WHERE e.identification_number in ('I9-EVAL-1','I9-EVAL-2') AND sp.code='I9-EVAL-POS';
INSERT INTO position_coverage_rules(position_id,template_id,weekday_scope,starts_at,ends_at,required_quantity,effective_from,status)
 SELECT sp.id, st.id, 'TODOS', '08:00', '20:00', 1, date '2026-09-01', 'ACTIVO'
 FROM service_positions sp, shift_templates st WHERE sp.code='I9-EVAL-POS' AND st.code='2X2' AND st.version=1;
-- Turno previo real de I9-EVAL-1: una version PUBLICADA (no CANCELADA/REEMPLAZADA) con un turno que
-- termina a las 22:00 del 2026-09-01, a solo 10h del propuesto (08:00 del 2026-09-02).
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-08-31',date '2026-09-01','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by)
 SELECT s.id,1,'PUBLICADA','operaciones.sg' FROM schedules s JOIN service_projects sp ON sp.id=s.project_id WHERE sp.code='PROJECT-A';
INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at,required_quantity)
 SELECT sv.id, sp.id, date '2026-09-01', time '10:00', time '22:00', 1
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id JOIN service_projects p ON p.id=s.project_id,
 service_positions sp WHERE p.code='PROJECT-A' AND sp.code='I9-EVAL-PREV-POS';
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status)
 SELECT rs.schedule_version_id, rs.id, e.id, 'ASIGNADA' FROM required_shifts rs
 JOIN employees e ON e.identification_number='I9-EVAL-1'
 WHERE rs.shift_date=date '2026-09-01';
'@
    Set-Content -LiteralPath $fixtureFile -Value $fixture -Encoding UTF8
    & $psql -X -w -v ON_ERROR_STOP=1 -f $fixtureFile | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'anonymous evaluation fixture failed' }

    $projectId = Scalar "select id from service_projects where code='PROJECT-A'"
    $employee1 = Scalar "select id from employees where identification_number='I9-EVAL-1'"

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
    Q $true 'CE-T01 the API starts against the isolated schema'

    # El servicio de salud responde antes de que el pipeline de autenticacion este listo bajo carga; se
    # reintenta el login unas cuantas veces en vez de asumir que "sano" significa "todo listo".
    $login = $null
    foreach ($attempt in 1..10) {
        $login = Call 'Post' "$base/auth/login" $null @{ username='operaciones.sg'; password='Operaciones123' }
        if ($login.Status -eq 200) { break }
        Start-Sleep -Milliseconds 750
    }
    if ($login.Status -ne 200) { throw "login failed with HTTP $($login.Status): $($login.Content)" }
    $headers = @{ Authorization = "Bearer $(($login.Content | ConvertFrom-Json).sessionToken)" }

    $generated = Call 'Post' "$base/portal/scheduling/projects/$projectId/proposals" $headers @{ periodStart='2026-09-02'; periodEnd='2026-09-02' }
    Q ($generated.Status -eq 201) "CE-T02 POST /proposals answers 201 ($($generated.Content))"
    $versionId = ($generated.Content | ConvertFrom-Json).versionId

    # facts_snapshot solo lleva 'employeeId' para las reglas cuyo RootFactsByRule lo declara (R03-R06);
    # R01/R02/R07 no lo incluyen. 'assignmentId' si esta en las siete (se construyo como "CAND-<empleado>"
    # en BuildCandidateFactsAsync), asi que es el campo estable para identificar al candidato en cualquier regla.
    $evaluationsJson = & $psql -X -w -Atqc "select rule_code,outcome,message_code,assignment_id,facts_snapshot->>'assignmentId' from scheduling_rule_evaluations where schedule_version_id=$versionId order by 5,rule_code" -F '|'
    if ($LASTEXITCODE -ne 0) { throw 'could not read scheduling_rule_evaluations' }
    $rows = $evaluationsJson | ForEach-Object {
        $parts2 = $_ -split '\|'
        $candidateEmployeeId = if ($parts2[4] -match '^CAND-(\d+)$') { $matches[1] } else { $null }
        [pscustomobject]@{ Rule=$parts2[0]; Outcome=$parts2[1]; Message=$parts2[2]; BoundAssignmentId=$parts2[3]; CandidateEmployeeId=$candidateEmployeeId }
    }

    Q (@($rows).Count -eq 14) 'CE-T03 both candidates were evaluated against all seven rules (2 x 7 = 14 rows)'
    Q (@($rows | Where-Object BoundAssignmentId).Count -eq 0) 'CE-T03 no evaluation is bound to an assignment yet (assignmentId is null)'

    $employee1Rows = $rows | Where-Object CandidateEmployeeId -eq $employee1
    Q (@($employee1Rows).Count -eq 7) 'CE-T04 employee 1 is identifiable across all seven rules via facts_snapshot.assignmentId'
    $r02ForEmployee1 = $employee1Rows | Where-Object Rule -eq 'I9-R02'
    Q ($r02ForEmployee1.Outcome -eq 'EXCEPTION_REQUIRED') 'CE-T04 the candidate with a too-recent real prior shift gets I9-R02 EXCEPTION_REQUIRED, not fabricated compliance'

    $employee2Rows = $rows | Where-Object { $_.CandidateEmployeeId -and $_.CandidateEmployeeId -ne $employee1 }
    $r02ForEmployee2 = $employee2Rows | Where-Object Rule -eq 'I9-R02'
    Q ($r02ForEmployee2.Outcome -eq 'COMPLIANT') 'CE-T05 the candidate with no prior shift history gets I9-R02 COMPLIANT from the 30-day rest anchor'

    $r04 = $employee1Rows | Where-Object Rule -eq 'I9-R04'
    Q ($r04.Outcome -in @('WARNING','EXCEPTION_REQUIRED','BLOCKED') -and $r04.Message -match 'UNVERIFIED|UNKNOWN') 'CE-T06 I9-R04 never fabricates compliance when noveltyEvaluations is empty'
    $r06 = $employee1Rows | Where-Object Rule -eq 'I9-R06'
    Q ($r06.Outcome -ne 'COMPLIANT') 'CE-T06 I9-R06 never fabricates compliance when requirementEvaluations is empty (no requirements configured here, so NOT_APPLICABLE or similar is acceptable, COMPLIANT-by-omission is not)'

    Q ($passed -eq 9) 'numbered candidate-evaluation assertion count'
    Write-Output "I9 CANDIDATE EVALUATION PASS $passed"
    exit 0
}
catch { Write-Output "I9 CANDIDATE EVALUATION FAIL: $($_.Exception.Message)"; exit 1 }
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
    if ($clean -ne 't') { Write-Output 'I9 CANDIDATE EVALUATION FAIL: temporal schema cleanup'; exit 1 }
}
