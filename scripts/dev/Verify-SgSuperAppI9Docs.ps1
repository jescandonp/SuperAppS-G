[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-DocumentContains {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string[]]$Patterns
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing document: $RelativePath")
        return
    }

    $content = Get-Content -Raw -LiteralPath $path
    foreach ($pattern in $Patterns) {
        if ($content -notmatch $pattern) {
            $failures.Add("$RelativePath missing pattern: $pattern")
        }
    }
}

Assert-DocumentContains 'docs/CONSTITUTION.md' @(
    '(?im)\|\s*I9\s*\|\s*Programacion asistida de turnos',
    '(?i)control humano',
    '(?i)no (aprueba|publica).*(autonom|automatic)'
)

Assert-DocumentContains 'docs/ARCHITECTURE.md' @(
    '(?i)Programacion asistida de turnos',
    '(?i)PlantillaDeTurno',
    '(?i)VersionDeProgramacion',
    '(?i)ExcepcionDeProgramacion',
    '(?i)\bI2\b.*\bI3\b.*\bI5\b.*\bI6\b.*\bI7\b'
)

Assert-DocumentContains 'docs/TECNOLOGIA.md' @(
    '(?i)motor heuristico deterministico',
    '(?i)\.NET 6',
    '(?i)interno',
    '(?i)sin dependencia externa'
)

Assert-DocumentContains 'docs/DESIGN.md' @(
    '(?i)Enterprise Sentinel',
    '#003366',
    '#FFC700',
    '(?i)matriz mensual',
    '(?i)plantillas',
    '(?i)comparacion',
    '(?i)excepciones'
)

$specPath = 'docs/specs/2026-07-29-sg-superapp-spec-i9-programacion-turnos.md'
Assert-DocumentContains $specPath @(
    '(?im)Estado:\s*\*?\*?En revision',
    '(?i)alcance',
    '(?i)contratos funcionales',
    '(?i)estados',
    '(?i)permisos',
    '(?i)API conceptual',
    '(?i)criterios de aceptacion',
    '(?i)exclusiones',
    '(?i)no publica.*autonom'
)

$planPath = 'docs/plans/2026-07-29-sg-superapp-i9-programacion-turnos-plan.md'
Assert-DocumentContains $planPath @(
    '(?im)Gate 0.*En revision',
    '(?i)Tasks? tecnicas.*bloqueadas',
    '(?i)Task 2',
    '(?i)no iniciar'
)

$catalogPath = 'docs/operations/2026-07-29-i9-catalogo-reglas-programacion.md'
Assert-DocumentContains $catalogPath @(
    'BORRADOR_NO_EJECUTABLE',
    '(?i)jornada maxima',
    '(?i)descanso minimo',
    '(?i)cruces',
    '(?i)novedades',
    '(?i)ubicacion',
    '(?i)requisitos',
    '(?i)desviacion',
    '(?i)Operaciones',
    '(?i)Talento Humano',
    '(?i)Juridico'
)

foreach ($relativePath in @($specPath, $planPath, $catalogPath)) {
    $path = Join-Path $repoRoot $relativePath
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $content = Get-Content -Raw -LiteralPath $path
        if ($content -match '(?im)Estado:\s*\*?\*?Aprobada') {
            $failures.Add("$relativePath must not claim approval")
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'I9 DOCS FAIL'
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host 'I9 DOCS PASS'
