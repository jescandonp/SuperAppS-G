[CmdletBinding()]
param(
    [string]$Esquema = 'sg_i9_pruebas'
)

# Aplica el piloto funcional I9 (4 sitios reales, datos anonimizados) sobre un esquema de pruebas ya
# sembrado por Start-SgSuperAppI9Pruebas.ps1. No sustituye el escenario minimo de esa siembra: usa
# codigos propios (PILOTO-NUEVO-PLANEADOR, PILOTO-*) para no chocar con PROJECT-A.
#
# Requiere que el esquema ya exista y este completo (ejecute primero Probar-I9.cmd o
# Start-SgSuperAppI9Pruebas.ps1 -SoloDatos). El script se rehusa a correr sobre cualquier esquema
# que no empiece por sg_i9_, igual que el lanzador principal.

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
$sqlFile = Join-Path $repoRoot 'scripts\dev\sql\i9-piloto-real-anonimizado.sql'

if ($Esquema -cnotmatch '^sg_i9_[a-z0-9_]+\z') {
    Write-Host "El esquema '$Esquema' no es un esquema de pruebas valido (debe empezar por sg_i9_)." -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $sqlFile -PathType Leaf)) {
    Write-Host "No se encontro $sqlFile. Regenere con el script de anonimizacion." -ForegroundColor Red
    exit 2
}

$ajustes = Get-Content -LiteralPath (Join-Path $repoRoot 'apps\sg-superapp-api\appsettings.json') -Raw | ConvertFrom-Json
$partes = @{}
foreach ($p in ([string]$ajustes.ConnectionStrings.Postgres -split ';')) {
    if ($p -match '^([^=]+)=(.*)$') { $partes[$matches[1].Trim()] = $matches[2] }
}
$env:PGHOST = $partes.Host; $env:PGPORT = $partes.Port; $env:PGDATABASE = $partes.Database
$env:PGUSER = $partes.Username; $env:PGPASSWORD = $partes.Password
$env:PGOPTIONS = "--search_path=$Esquema,public"

Write-Host "Sembrando el piloto real anonimizado sobre $Esquema..." -ForegroundColor Cyan
& $psql -X -w -v ON_ERROR_STOP=1 -f $sqlFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "Fallo la siembra del piloto." -ForegroundColor Red
    exit 1
}
Write-Host "Piloto sembrado. Proyecto: PILOTO-NUEVO-PLANEADOR (Piloto Nuevo Planeador - Septiembre 2026)." -ForegroundColor Green

$env:PGOPTIONS = $null; $env:PGPASSWORD = $null; $env:PGHOST = $null; $env:PGPORT = $null
$env:PGDATABASE = $null; $env:PGUSER = $null
