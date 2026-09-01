[CmdletBinding()]
param([string]$RepositoryRoot,[int]$Port = 5422)

# M1 (hallazgo 4.1 del piloto real anonimizado, 2026-08-31): ScheduleWorkflowResponse nunca incluyo
# assignments/exceptions, para ninguna operacion, asi que la matriz real jamas se pudo ver fuera de
# ?demo=scheduling. Este verificador cubre exactamente eso: que GET /proposals/{id} y
# GET /projects/{id}/schedules/{period} devuelvan las asignaciones y excepciones reales de una version
# ya sembrada, sin pasar por "Generar propuesta". La base temporal se elimina y la API se detiene
# siempre, igual que el resto de esta familia de verificadores.

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
    Write-Output 'I9 SCHEDULE VISIBILITY BLOCKED: local prerequisites unavailable'; exit 2
}

$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$parts = @{}
foreach ($part in ([string]$settings.ConnectionStrings.Postgres -split ';')) {
    if ($part -match '^([^=]+)=(.*)$') { $parts[$matches[1].Trim()] = $matches[2] }
}
if (@('Host','Port','Database','Username','Password') | Where-Object { -not $parts[$_] }) {
    Write-Output 'I9 SCHEDULE VISIBILITY BLOCKED: local PostgreSQL configuration incomplete'; exit 2
}
$env:PGHOST=$parts.Host; $env:PGPORT=$parts.Port; $env:PGDATABASE=$parts.Database
$env:PGUSER=$parts.Username; $env:PGPASSWORD=$parts.Password

$passed = 0
function Q([bool]$value,[string]$label) { if (-not $value) { throw $label }; $script:passed++; Write-Output ($label + ' PASS') }

function Call([string]$method,[string]$uri,$headers) {
    try {
        $response = Invoke-WebRequest -Uri $uri -Method $method -UseBasicParsing -Headers $headers
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

$schema = 'i9_vis_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$apiProcess = $null
$fixtureFile = Join-Path ([System.IO.Path]::GetTempPath()) ($schema + '.sql')
try {
    & $dotnet build $project --configuration Release | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 SCHEDULE VISIBILITY FAIL: API build failed'; exit 1 }

    & $psql -X -w -v ON_ERROR_STOP=1 -c "CREATE SCHEMA $schema" | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Output 'I9 SCHEDULE VISIBILITY BLOCKED: cannot create temporal schema'; exit 2 }
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

    # Anonymous fixture: un turno con dos candidatos, uno asignado (razones como string plano, la
    # forma real que SchedulingRecommendationEngine.Generate() escribe) y otro dejado VACANTE.
    $fixture = @'
INSERT INTO clients(code,name,status) VALUES('I9-VIS-CLIENT','Cliente anonimo de visibilidad','ACTIVO');
INSERT INTO service_projects(client_id,code,name,effective_from,status,created_at,updated_at)
 SELECT id,'PROJECT-VIS','Proyecto anonimo de visibilidad',date '2026-01-01','ACTIVO',now(),now() FROM clients WHERE code='I9-VIS-CLIENT';
INSERT INTO service_positions(code,name,status) VALUES('I9-VIS-POSITION','Puesto anonimo de visibilidad','ACTIVO');
INSERT INTO employees(identification_type,identification_number,full_name,employment_status,job_title,hire_date)
 VALUES('CC','I9-VIS-1','Guarda anonimo uno','ACTIVO','GUARDA',date '2026-01-01');
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-09-01',date '2026-09-01','operaciones.sg' FROM service_projects WHERE code='PROJECT-VIS';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',TRUE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p WHERE p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at,required_quantity)
 SELECT sv.id,sp.id,date '2026-09-01',time '08:00',time '20:00',2
 FROM schedule_versions sv JOIN schedules s ON s.id=sv.schedule_id
 CROSS JOIN service_positions sp WHERE sp.code='I9-VIS-POSITION';
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status,score,reasons)
 SELECT r.schedule_version_id,r.id,e.id,'ASIGNADA',87.5,'["SCORE=87.5000","CONTINUITY=1.0000"]'::jsonb
 FROM required_shifts r CROSS JOIN employees e WHERE e.identification_number='I9-VIS-1';
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status,reasons)
 SELECT r.schedule_version_id,r.id,NULL,'VACANTE','[{"code":"NO_ELIGIBLE_CANDIDATES","severity":"BLOCKING","message":"Sin candidatos elegibles."}]'::jsonb
 FROM required_shifts r;
'@
    Set-Content -LiteralPath $fixtureFile -Value $fixture -Encoding UTF8
    & $psql -X -w -v ON_ERROR_STOP=1 -f $fixtureFile | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'anonymous visibility fixture failed' }

    $versionId = Scalar "select sv.id from schedule_versions sv join schedules s on s.id=sv.schedule_id join service_projects sp on sp.id=s.project_id where sp.code='PROJECT-VIS'"
    $projectId = Scalar "select id from service_projects where code='PROJECT-VIS'"

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
    Q $true 'SV-T01 the API starts against the isolated schema'

    $loginBody = (@{ username='operaciones.sg'; password='Operaciones123' } | ConvertTo-Json)
    $login = Invoke-WebRequest -Uri "$base/auth/login" -Method Post -UseBasicParsing -ContentType 'application/json' -Body $loginBody
    if ([int]$login.StatusCode -ne 200) { throw "login failed with HTTP $($login.StatusCode)" }
    $headers = @{ Authorization = "Bearer $(($login.Content | ConvertFrom-Json).sessionToken)" }

    $byId = Call 'Get' "$base/portal/scheduling/proposals/$versionId" $headers
    Q ($byId.Status -eq 200) "SV-T02 GET /proposals/{versionId} answers 200 ($($byId.Content))"
    $proposal = $byId.Content | ConvertFrom-Json
    Q ($null -ne $proposal.assignments) 'SV-T02 the response carries an assignments field'
    Q (@($proposal.assignments).Count -eq 2) 'SV-T02 both seeded assignments are returned'
    $asignada = $proposal.assignments | Where-Object status -eq 'ASIGNADA'
    $vacante = $proposal.assignments | Where-Object status -eq 'VACANTE'
    Q ($null -ne $asignada -and $null -ne $asignada.employeeId) 'SV-T02 the filled slot carries an employeeId'
    Q ($asignada.shiftCode -eq 'D') 'SV-T02 a 08:00-20:00 shift is labelled D'
    Q ($null -eq $vacante.employeeId) 'SV-T02 the vacant slot carries no employeeId'
    Q (@($asignada.reasons).Count -eq 2 -and $asignada.reasons[0].severity -eq 'INFORMATIVA' -and $asignada.reasons[0].code -eq '') 'SV-T03 a plain-string reason is wrapped as an informational reason'
    Q ($asignada.reasons[0].message -eq 'SCORE=87.5000') 'SV-T03 the wrapped reason keeps the original text as its message'
    Q ($vacante.reasons[0].code -eq 'NO_ELIGIBLE_CANDIDATES' -and $vacante.reasons[0].severity -eq 'BLOCKING') 'SV-T03 an already-structured reason passes through unchanged'
    Q ($null -ne $proposal.exceptions -and @($proposal.exceptions).Count -eq 0) 'SV-T04 exceptions is an empty array, not absent, when none exist'

    $byPeriod = Call 'Get' "$base/portal/scheduling/projects/$projectId/schedules/2026-09-01" $headers
    Q ($byPeriod.Status -eq 200) "SV-T05 GET /projects/{id}/schedules/{period} answers 200 ($($byPeriod.Content))"
    $byPeriodProposal = $byPeriod.Content | ConvertFrom-Json
    Q ($byPeriodProposal.versionId -eq [int64]$versionId) 'SV-T05 it resolves to the same version seeded'
    Q (@($byPeriodProposal.assignments).Count -eq 2) 'SV-T05 it carries the same assignments as GET by versionId'

    $missing = Call 'Get' "$base/portal/scheduling/projects/$projectId/schedules/2026-08-01" $headers
    Q ($missing.Status -eq 404) 'SV-T06 a period with no schedule answers 404, not an empty 200'

    Q ($passed -eq 15) 'numbered visibility assertion count'
    Write-Output "I9 SCHEDULE VISIBILITY PASS $passed"
    exit 0
}
catch { Write-Output "I9 SCHEDULE VISIBILITY FAIL: $($_.Exception.Message)"; exit 1 }
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
    if ($clean -ne 't') { Write-Output 'I9 SCHEDULE VISIBILITY FAIL: temporal schema cleanup'; exit 1 }
}
