[CmdletBinding()]
param([string]$RepositoryRoot,[int]$Port = 5423)

# M2 (roadmap acordado 2026-09-01 tras el piloto real anonimizado): "Generar propuesta"
# (CreateScheduleProposalAsync) ahora expande required_shifts desde position_coverage_rules para el
# periodo pedido. Este verificador cubre exactamente esa expansion, incluidas sus guardas: solo
# puestos ACTIVO, solo cobertura ACTIVO y vigente para cada fecha, y solo weekday_scope='TODOS' (un
# ambito semanal parcial no tiene convencion definida en este codebase, asi que se omite en vez de
# adivinarse). El proyecto de esta fixture (PROJECT-EXP) no tiene ningun perfil de reglas ACTIVE
# configurado, asi que tras M4 cada turno expandido sigue llegando VACANTE, ahora por el motivo real
# (RULE_PROFILE_UNCONFIGURED, no el placeholder generico CANDIDATES_NOT_EVALUATED que M2 escribia antes
# de M4). La base temporal se elimina y la API se detiene siempre.

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
    Write-Output 'I9 REQUIRED SHIFTS EXPANSION BLOCKED: local prerequisites unavailable'; exit 2
}

$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$parts = @{}
foreach ($part in ([string]$settings.ConnectionStrings.Postgres -split ';')) {
    if ($part -match '^([^=]+)=(.*)$') { $parts[$matches[1].Trim()] = $matches[2] }
}
if (@('Host','Port','Database','Username','Password') | Where-Object { -not $parts[$_] }) {
    Write-Output 'I9 REQUIRED SHIFTS EXPANSION BLOCKED: local PostgreSQL configuration incomplete'; exit 2
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

$schema = 'i9_exp_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$apiProcess = $null
$fixtureFile = Join-Path ([System.IO.Path]::GetTempPath()) ($schema + '.sql')
try {
    & $dotnet build $project --configuration Release | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 REQUIRED SHIFTS EXPANSION FAIL: API build failed'; exit 1 }

    & $psql -X -w -v ON_ERROR_STOP=1 -c "CREATE SCHEMA $schema" | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 REQUIRED SHIFTS EXPANSION BLOCKED: cannot create temporal schema'; exit 2 }
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

    # Un proyecto con tres puestos que cada uno debe fallar la expansion por un motivo distinto salvo
    # el primero: PUESTO-A cubre todo el periodo (debe expandir); PUESTO-B esta INACTIVO (no debe
    # expandir); PUESTO-C tiene weekday_scope distinto de TODOS (no debe expandir); PUESTO-D tiene
    # cobertura vigente solo hasta antes del periodo pedido (no debe expandir).
    $fixture = @'
INSERT INTO clients(code,name,status) VALUES('I9-EXP-CLIENT','Cliente anonimo de expansion','ACTIVO');
INSERT INTO service_projects(client_id,code,name,effective_from,status,created_at,updated_at)
 SELECT id,'PROJECT-EXP','Proyecto anonimo de expansion',date '2026-01-01','ACTIVO',now(),now() FROM clients WHERE code='I9-EXP-CLIENT';
INSERT INTO service_positions(code,name,project_id,status)
 SELECT 'I9-EXP-A','Puesto A anonimo',id,'ACTIVO' FROM service_projects WHERE code='PROJECT-EXP';
INSERT INTO service_positions(code,name,project_id,status)
 SELECT 'I9-EXP-B','Puesto B anonimo (inactivo)',id,'INACTIVO' FROM service_projects WHERE code='PROJECT-EXP';
INSERT INTO service_positions(code,name,project_id,status)
 SELECT 'I9-EXP-C','Puesto C anonimo (ambito parcial)',id,'ACTIVO' FROM service_projects WHERE code='PROJECT-EXP';
INSERT INTO service_positions(code,name,project_id,status)
 SELECT 'I9-EXP-D','Puesto D anonimo (vencido)',id,'ACTIVO' FROM service_projects WHERE code='PROJECT-EXP';
INSERT INTO position_coverage_rules(position_id,template_id,weekday_scope,starts_at,ends_at,required_quantity,effective_from,status)
 SELECT sp.id, st.id, 'TODOS', '08:00', '20:00', 2, date '2026-09-01', 'ACTIVO'
 FROM service_positions sp, shift_templates st WHERE sp.code='I9-EXP-A' AND st.code='2X2' AND st.version=1;
INSERT INTO position_coverage_rules(position_id,template_id,weekday_scope,starts_at,ends_at,required_quantity,effective_from,status)
 SELECT sp.id, st.id, 'TODOS', '20:00', '08:00', 2, date '2026-09-01', 'ACTIVO'
 FROM service_positions sp, shift_templates st WHERE sp.code='I9-EXP-A' AND st.code='2X2' AND st.version=1;
INSERT INTO position_coverage_rules(position_id,template_id,weekday_scope,starts_at,ends_at,required_quantity,effective_from,status)
 SELECT sp.id, st.id, 'TODOS', '08:00', '20:00', 3, date '2026-09-01', 'ACTIVO'
 FROM service_positions sp, shift_templates st WHERE sp.code='I9-EXP-B' AND st.code='2X2' AND st.version=1;
INSERT INTO position_coverage_rules(position_id,template_id,weekday_scope,starts_at,ends_at,required_quantity,effective_from,status)
 SELECT sp.id, st.id, 'L-V', '08:00', '20:00', 4, date '2026-09-01', 'ACTIVO'
 FROM service_positions sp, shift_templates st WHERE sp.code='I9-EXP-C' AND st.code='2X2' AND st.version=1;
INSERT INTO position_coverage_rules(position_id,template_id,weekday_scope,starts_at,ends_at,required_quantity,effective_from,effective_to,status)
 SELECT sp.id, st.id, 'TODOS', '08:00', '20:00', 5, date '2026-01-01', date '2026-08-31', 'ACTIVO'
 FROM service_positions sp, shift_templates st WHERE sp.code='I9-EXP-D' AND st.code='2X2' AND st.version=1;
'@
    Set-Content -LiteralPath $fixtureFile -Value $fixture -Encoding UTF8
    & $psql -X -w -v ON_ERROR_STOP=1 -f $fixtureFile | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'anonymous expansion fixture failed' }

    $projectId = Scalar "select id from service_projects where code='PROJECT-EXP'"

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
    Q $true 'RS-T01 the API starts against the isolated schema'

    $loginBody = (@{ username='operaciones.sg'; password='Operaciones123' } | ConvertTo-Json)
    $login = Invoke-WebRequest -Uri "$base/auth/login" -Method Post -UseBasicParsing -ContentType 'application/json' -Body $loginBody
    if ([int]$login.StatusCode -ne 200) { throw "login failed with HTTP $($login.StatusCode)" }
    $headers = @{ Authorization = "Bearer $(($login.Content | ConvertFrom-Json).sessionToken)" }

    # Tres dias, 2X2 (D,D,N,N,X,X): PUESTO-A pide 2 concurrentes -> 3 dias * 2 turnos (D y N) * 2 cupos = 12.
    $generated = Call 'Post' "$base/portal/scheduling/projects/$projectId/proposals" $headers @{ periodStart='2026-09-01'; periodEnd='2026-09-03' }
    Q ($generated.Status -eq 201) "RS-T02 POST /proposals answers 201 ($($generated.Content))"
    $proposal = $generated.Content | ConvertFrom-Json
    $versionId = $proposal.versionId

    Q (@($proposal.assignments).Count -eq 12) 'RS-T02 only the ACTIVO position with TODOS coverage in vigency expands (2 slots x 2 shifts x 3 days)'
    Q (@($proposal.assignments | Where-Object { $_.status -ne 'VACANTE' }).Count -eq 0) 'RS-T03 every generated slot is VACANTE, never presumed ASIGNADA'
    Q (@($proposal.assignments | Where-Object { $_.positionId -ne $proposal.assignments[0].positionId }).Count -eq 0) 'RS-T04 no shift was generated for the inactive, partial-scope, or expired-coverage positions'
    # M4: PROJECT-EXP no tiene ningun perfil de reglas ACTIVE configurado (el unico sembrado,
    # I9-MVP-SIMULATED, esta scoped a PROJECT-A) - EvaluateCandidatesForRequiredShiftsAsync no evalua ni
    # rankea nada, pero sigue dejando una vacante real y visible por cada turno requerido (la garantia
    # que M2 ya ofrecia), con un motivo honesto en vez del antiguo placeholder generico.
    Q ($proposal.assignments[0].reasons[0].message -eq 'RULE_PROFILE_UNCONFIGURED') 'RS-T05 the vacancy reason names why: no active rule profile exists for this project yet'
    Q ($proposal.vacancyCount -eq 12) 'RS-T06 schedule_versions.vacancy_count reflects the generated vacancies (metrics were refreshed)'
    Q ($proposal.coveragePercent -eq 0) 'RS-T06 coveragePercent stays 0 until M3/M4 actually assign someone'

    $requiredShiftCount = [int](Scalar "select count(*) from required_shifts where schedule_version_id=$versionId")
    Q ($requiredShiftCount -eq 6) 'RS-T07 required_shifts has one row per position/day/shift-window (3 days x 2 windows)'

    # Regenerar sobre el mismo periodo crea una version nueva y expande de nuevo, sin heredar ni
    # duplicar contra la version anterior (cada version tiene sus propios required_shifts).
    $regenerated = Call 'Post' "$base/portal/scheduling/projects/$projectId/proposals" $headers @{ periodStart='2026-09-01'; periodEnd='2026-09-03' }
    Q ($regenerated.Status -eq 201) 'RS-T08 a second generation over the same period succeeds'
    $secondProposal = $regenerated.Content | ConvertFrom-Json
    Q ($secondProposal.versionId -ne $versionId) 'RS-T08 it is a distinct version'
    Q (@($secondProposal.assignments).Count -eq 12) 'RS-T08 the new version expands its own required_shifts independently'
    Q ([int](Scalar "select count(*) from required_shifts where schedule_version_id=$versionId") -eq $requiredShiftCount) 'RS-T08 the earlier version''s required_shifts are untouched'

    Q ($passed -eq 13) 'numbered expansion assertion count'
    Write-Output "I9 REQUIRED SHIFTS EXPANSION PASS $passed"
    exit 0
}
catch { Write-Output "I9 REQUIRED SHIFTS EXPANSION FAIL: $($_.Exception.Message)"; exit 1 }
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
    if ($clean -ne 't') { Write-Output 'I9 REQUIRED SHIFTS EXPANSION FAIL: temporal schema cleanup'; exit 1 }
}
