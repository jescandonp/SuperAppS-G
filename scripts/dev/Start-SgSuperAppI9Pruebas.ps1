[CmdletBinding()]
param(
    # Vuelve a crear el esquema de pruebas desde cero. Sin esto, lo que haya quedado de una sesion
    # anterior se conserva, que es lo normal para un ciclo funcional de varios dias.
    [switch]$Reset,
    # Solo prepara la base y no levanta nada, por si quiere revisar el estado antes de arrancar.
    [switch]$SoloDatos,
    [int]$PuertoApi = 5080,
    [int]$PuertoWeb = 3000,
    [string]$Esquema = 'sg_i9_pruebas'
)

# Levanta el entorno completo del MVP I9 para pruebas funcionales: base con datos simulados, API y
# cliente web. Todo ocurre sobre un esquema PostgreSQL propio y con nombre explicito, nunca sobre
# datos productivos. Cierre la ventana o pulse una tecla para detener los servicios.

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
$dotnet = 'C:\tmp\dotnet6\dotnet.exe'
$web = Join-Path $repoRoot 'apps\sg-superapp-web'
$apiProject = Join-Path $repoRoot 'apps\sg-superapp-api\sg-superapp-api.csproj'
$apiDll = Join-Path $repoRoot 'apps\sg-superapp-api\bin\Release\net6.0\sg-superapp-api.dll'
$apiProcess = $null
$webProcess = $null

function Paso([string]$texto) { Write-Host "  $texto" -ForegroundColor DarkGray }
function Bien([string]$texto) { Write-Host "  $texto" -ForegroundColor Green }
function Mal([string]$texto) { Write-Host "  $texto" -ForegroundColor Red }

# psql escribe sus NOTICE por stderr, y con ErrorActionPreference en Stop PowerShell convierte esa
# salida en un error terminante aunque el comando haya ido bien. Se aisla aqui para que el guion no
# muera por un aviso de "la extension ya existe".
# Los argumentos llegan como un arreglo explicito y no como parametros sueltos: en una funcion
# avanzada, un "-v" se enlaza a -Verbose y deja "ON_ERROR_STOP=1" huerfano, con lo que psql recibe
# una orden distinta de la escrita y falla sin decir por que.
function Sql([string[]]$Argumentos) {
    $previo = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $psql -X -w @Argumentos 2>&1 | Out-Null; return $LASTEXITCODE }
    finally { $ErrorActionPreference = $previo }
}

function SqlValor([string]$consulta) {
    $previo = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $valor = & $psql -X -w -Atqc $consulta 2>$null; return ([string]$valor).Trim() }
    finally { $ErrorActionPreference = $previo }
}

Write-Host ''
Write-Host '  S&G Super App - entorno de pruebas I9' -ForegroundColor Cyan
Write-Host '  Datos simulados MVP_TEST. No es un entorno productivo.' -ForegroundColor DarkGray
Write-Host ''

# --- Requisitos -----------------------------------------------------------------------------------
# Se comprueban todos antes de tocar nada, para que un requisito ausente no deje medio entorno en pie.
$faltantes = @()
if (-not (Test-Path -LiteralPath $psql -PathType Leaf)) { $faltantes += "PostgreSQL 18 (psql) en $psql" }
if (-not (Test-Path -LiteralPath $dotnet -PathType Leaf)) { $faltantes += ".NET 6 en $dotnet" }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { $faltantes += 'Node.js (node) en el PATH' }
if ($faltantes.Count -gt 0) {
    Mal 'Faltan requisitos:'
    $faltantes | ForEach-Object { Mal "   - $_" }
    Write-Host ''
    Read-Host '  Pulse Enter para cerrar'
    exit 2
}

# --- Puertos --------------------------------------------------------------------------------------
foreach ($puerto in @(@{ N = $PuertoApi; Q = 'la API' }, @{ N = $PuertoWeb; Q = 'el cliente web' })) {
    $enUso = Get-NetTCPConnection -LocalPort $puerto.N -State Listen -ErrorAction SilentlyContinue
    if ($enUso) {
        Mal "El puerto $($puerto.N), que necesita $($puerto.Q), ya esta ocupado."
        Mal "Cierre el proceso que lo usa (PID $($enUso.OwningProcess | Select-Object -First 1)) y vuelva a intentarlo."
        Write-Host ''
        Read-Host '  Pulse Enter para cerrar'
        exit 2
    }
}

# El cliente web pide la API en http://localhost:5080 y la politica CORS de la API solo admite el
# origen en el puerto 3000. Cambiar cualquiera de los dos hace que el inicio de sesion falle con un
# "Failed to fetch" que parece un problema de credenciales y no lo es.
if ($PuertoWeb -ne 3000) { Paso "Aviso: la API solo admite el origen en el puerto 3000; con $PuertoWeb el login fallara." }

# --- Base de datos --------------------------------------------------------------------------------
$ajustes = Get-Content -LiteralPath (Join-Path $repoRoot 'apps\sg-superapp-api\appsettings.json') -Raw | ConvertFrom-Json
$partes = @{}
foreach ($p in ([string]$ajustes.ConnectionStrings.Postgres -split ';')) {
    if ($p -match '^([^=]+)=(.*)$') { $partes[$matches[1].Trim()] = $matches[2] }
}
$env:PGHOST = $partes.Host; $env:PGPORT = $partes.Port; $env:PGDATABASE = $partes.Database
$env:PGUSER = $partes.Username; $env:PGPASSWORD = $partes.Password
$env:PGOPTIONS = $null

$existe = SqlValor "select to_regnamespace('$Esquema') is not null"
if ([string]::IsNullOrWhiteSpace($existe)) {
    Mal 'No fue posible conectar con PostgreSQL. Revise que el servicio este arriba.'
    Write-Host ''
    Read-Host '  Pulse Enter para cerrar'
    exit 2
}

if ($Reset -and $existe -eq 't') {
    Paso "Eliminando el esquema $Esquema por -Reset"
    if ((Sql @('-v', 'ON_ERROR_STOP=1', '-c', "DROP SCHEMA $Esquema CASCADE")) -ne 0) { Mal 'No fue posible eliminar el esquema'; exit 1 }
    $existe = 'f'
}

$sembrar = $existe -ne 't'
if ($sembrar) {
    Paso "Creando el esquema $Esquema"
    if ((Sql @('-v', 'ON_ERROR_STOP=1', '-c', "CREATE SCHEMA $Esquema")) -ne 0) { Mal 'No fue posible crear el esquema'; exit 1 }
}
$env:PGOPTIONS = "--search_path=$Esquema,public"

if ($sembrar) {
    Paso 'Aplicando migraciones'
    Get-ChildItem (Join-Path $repoRoot 'db\migrations') -Filter '*.sql' | Sort-Object Name | ForEach-Object {
        if ((Sql @('-q', '-v', 'ON_ERROR_STOP=1', '-f', $_.FullName)) -ne 0) { Mal "Fallo la migracion $($_.Name)"; exit 1 }
    }
    Paso 'Aplicando semillas'
    foreach ($semilla in @('001_roles_and_permissions.sql', '004_i2_security_users_permissions.sql',
                           '009_i9_scheduling_permissions.sql', '010_i9_shift_templates.sql',
                           '011_i9_mvp_simulated_rule_profile.sql')) {
        if ((Sql @('-q', '-v', 'ON_ERROR_STOP=1', '-f', (Join-Path $repoRoot "db\seeds\$semilla"))) -ne 0) { Mal "Fallo la semilla $semilla"; exit 1 }
    }

    # Escenario de prueba. El perfil sembrado rige desde 2026-08-21, asi que el periodo por defecto
    # de la pantalla debe caer dentro de su vigencia o el panel dira, con razon, que no hay perfil.
    # Se dejan los cuatro resultados que la interfaz sabe representar, sobre una misma asignacion.
    Paso 'Sembrando el escenario simulado de pruebas'
    $escenario = Join-Path ([System.IO.Path]::GetTempPath()) 'i9-pruebas-escenario.sql'
    @'
INSERT INTO clients(code,name,status) VALUES('I9-PRUEBAS','Cliente de pruebas I9','ACTIVO');
INSERT INTO service_projects(client_id,code,name,effective_from,status,created_at,updated_at)
 SELECT id,'PROJECT-A','Proyecto de pruebas I9',date '2026-01-01','ACTIVO',now(),now() FROM clients WHERE code='I9-PRUEBAS';
INSERT INTO service_positions(code,name,status) VALUES('I9-PRUEBAS-POS','Puesto de pruebas I9','ACTIVO');
INSERT INTO employees(identification_type,identification_number,full_name,employment_status,job_title,hire_date)
 VALUES('CC','I9-PRUEBAS-1','Guarda de pruebas uno','ACTIVO','GUARDA',date '2026-01-01'),
       ('CC','I9-PRUEBAS-2','Guarda de pruebas dos','ACTIVO','GUARDA',date '2026-01-01');
INSERT INTO schedules(project_id,period_start,period_end,created_by)
 SELECT id,date '2026-08-21',date '2026-08-21','operaciones.sg' FROM service_projects WHERE code='PROJECT-A';
INSERT INTO schedule_versions(schedule_id,version_number,status,created_by,simulated,rule_profile_id,rule_profile_version)
 SELECT s.id,1,'PROPUESTA','operaciones.sg',TRUE,p.id,p.version FROM schedules s
 CROSS JOIN scheduling_rule_profiles p WHERE p.profile_code='I9-MVP-SIMULATED' AND p.status='ACTIVE';
INSERT INTO required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at)
 SELECT sv.id,sp.id,date '2026-08-21',time '08:00',time '20:00'
 FROM schedule_versions sv CROSS JOIN service_positions sp WHERE sp.code='I9-PRUEBAS-POS';
INSERT INTO schedule_assignments(schedule_version_id,required_shift_id,employee_id,status)
 SELECT r.schedule_version_id,r.id,e.id,'ASIGNADA' FROM required_shifts r
 CROSS JOIN employees e WHERE e.identification_number='I9-PRUEBAS-1';
INSERT INTO scheduling_rule_evaluations(schedule_version_id,assignment_id,rule_profile_id,rule_code,outcome,severity,
  message_code,explanation,parameters_snapshot,facts_snapshot,scope_hash,exception_allowed,exception_status,
  correlation_id,evaluated_at,audit_actor)
 SELECT sv.id,a.id,sv.rule_profile_id,v.regla,v.resultado,v.severidad,v.codigo,v.texto,
  jsonb_build_object('demo',1),jsonb_build_object('demo',1),repeat(v.h,64),v.permite,v.estado,
  'i9-pruebas-'||v.regla,now(),'operaciones.sg'
 FROM schedule_versions sv JOIN schedule_assignments a ON a.schedule_version_id=sv.id
 CROSS JOIN (VALUES
  ('I9-R01','COMPLIANT','INFO','I9_R01_COMPLIANT','La jornada diaria y semanal se mantiene dentro de los limites del perfil simulado.','a',FALSE,'NOT_REQUIRED'),
  ('I9-R02','EXCEPTION_REQUIRED','WARNING','I9_R02_MIN_REST','El descanso entre turnos queda por debajo del minimo configurado en el perfil simulado.','b',TRUE,'PENDING'),
  ('I9-R03','BLOCKED','BLOCKING','I9_R03_OVERLAP_APPROVED_BLOCKED','La asignacion se cruza con un turno ya aprobado para el mismo guarda.','c',FALSE,'NOT_REQUIRED'),
  ('I9-R07','WARNING','ERROR','I9_R07_DISABLED_UNVERIFIED','La regla de plantillas esta desactivada en el perfil vigente, de modo que no acredita cumplimiento.','d',FALSE,'NOT_REQUIRED')
 ) AS v(regla,resultado,severidad,codigo,texto,h,permite,estado);
'@ | Set-Content -LiteralPath $escenario -Encoding UTF8
    $fallo = (Sql @('-q', '-v', 'ON_ERROR_STOP=1', '-f', $escenario)) -ne 0
    Remove-Item -LiteralPath $escenario -Force -ErrorAction SilentlyContinue
    if ($fallo) { Mal 'Fallo el escenario de pruebas'; exit 1 }
    Bien "Esquema $Esquema listo con datos simulados"
} else {
    Bien "Esquema $Esquema ya existia; se conserva lo que haya. Use -Reset para empezar de cero."
}

if ($SoloDatos) {
    Write-Host ''
    Bien 'Base preparada. No se levantaron servicios porque se indico -SoloDatos.'
    Write-Host ''
    Read-Host '  Pulse Enter para cerrar'
    exit 0
}

try {
    # --- API --------------------------------------------------------------------------------------
    Paso 'Compilando la API'
    $previo = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $dotnet build $apiProject --configuration Release 2>&1 | Out-Null
    $falloBuild = $LASTEXITCODE -ne 0
    $ErrorActionPreference = $previo
    if ($falloBuild) { Mal 'Fallo la compilacion de la API'; exit 1 }

    $env:ConnectionStrings__Postgres = "Host=$($partes.Host);Port=$($partes.Port);Database=$($partes.Database);Username=$($partes.Username);Password=$($partes.Password);Search Path=$Esquema,public"
    $env:ASPNETCORE_URLS = "http://localhost:$PuertoApi"
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    Paso "Levantando la API en http://localhost:$PuertoApi"
    $apiProcess = Start-Process -FilePath $dotnet -ArgumentList $apiDll -PassThru -WindowStyle Hidden

    $viva = $false
    foreach ($intento in 1..60) {
        if ($apiProcess.HasExited) { Mal "La API termino con codigo $($apiProcess.ExitCode)"; exit 1 }
        try { $null = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$PuertoApi/api/health" -TimeoutSec 2; $viva = $true; break }
        catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $viva) { Mal 'La API no respondio a tiempo'; exit 1 }
    Bien "API arriba en http://localhost:$PuertoApi"

    # --- Cliente web ------------------------------------------------------------------------------
    if (-not (Test-Path -LiteralPath (Join-Path $web 'node_modules\vite'))) {
        Paso 'Instalando dependencias del cliente web (solo la primera vez)'
        Push-Location $web
        $previo = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & npm install --no-audit --no-fund 2>&1 | Out-Null
        $falloNpm = $LASTEXITCODE -ne 0
        $ErrorActionPreference = $previo
        Pop-Location
        if ($falloNpm) { Mal 'Fallo npm install'; exit 1 }
    }

    Paso "Levantando el cliente web en http://localhost:$PuertoWeb"
    $webProcess = Start-Process -FilePath 'node' `
        -ArgumentList './node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', "$PuertoWeb" `
        -WorkingDirectory $web -PassThru -WindowStyle Hidden

    # Se sondea 127.0.0.1 y no localhost: en Windows localhost resuelve primero a ::1, y vite escucha
    # solo en IPv4, de modo que la comprobacion fallaba durante el minuto entero con el servidor ya
    # arriba. La politica CORS admite ambos origenes, asi que el navegador puede usar cualquiera.
    $vivaWeb = $false
    foreach ($intento in 1..60) {
        if ($webProcess.HasExited) { Mal 'El cliente web termino inesperadamente'; exit 1 }
        try { $null = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$PuertoWeb/" -TimeoutSec 2; $vivaWeb = $true; break }
        catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $vivaWeb) { Mal 'El cliente web no respondio a tiempo'; exit 1 }
    Bien "Cliente web arriba en http://localhost:$PuertoWeb"

    Write-Host ''
    Write-Host '  Todo listo.' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  Abra:        http://127.0.0.1:$PuertoWeb/module/scheduling"
    Write-Host '  Usuario:     operaciones.sg    Clave: Operaciones123'
    Write-Host '               admin.sg          Clave: Admin123'
    Write-Host '               th.sg             Clave: Th123456'
    Write-Host ''
    Write-Host '  Proyecto de pruebas: "Proyecto de pruebas I9"' -ForegroundColor DarkGray
    Write-Host '  Periodo con reglas vigentes: 2026-08-21 (el perfil rige desde esa fecha)' -ForegroundColor DarkGray
    Write-Host '  La pestana Reglas trae los cuatro resultados: conforme, excepcion, bloqueo y sin verificar.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Prueba clave: pulse Aprobar con la regla bloqueada en pantalla.' -ForegroundColor Yellow
    Write-Host '  El boton debe estar habilitado, y el rechazo debe venir del servidor con su motivo.' -ForegroundColor Yellow
    Write-Host ''
    Read-Host '  Pulse Enter para detener los servicios'
}
finally {
    Write-Host ''
    Paso 'Deteniendo servicios'
    foreach ($proceso in @($webProcess, $apiProcess)) {
        if ($null -ne $proceso -and -not $proceso.HasExited) {
            Stop-Process -Id $proceso.Id -Force -ErrorAction SilentlyContinue
            $proceso.WaitForExit(8000) | Out-Null
        }
    }
    $env:ConnectionStrings__Postgres = $null; $env:ASPNETCORE_URLS = $null; $env:ASPNETCORE_ENVIRONMENT = $null
    $env:PGOPTIONS = $null; $env:PGPASSWORD = $null; $env:PGHOST = $null; $env:PGPORT = $null
    $env:PGDATABASE = $null; $env:PGUSER = $null
    Bien "Servicios detenidos. El esquema $Esquema se conserva para la proxima sesion."
    Write-Host ''
}
