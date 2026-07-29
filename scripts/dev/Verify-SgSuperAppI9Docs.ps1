[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
$defaultRepositoryRoot = Join-Path $PSScriptRoot '..\..'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path -LiteralPath $defaultRepositoryRoot).Path
}
else {
    (Resolve-Path -LiteralPath $RepositoryRoot).Path
}
$failures = New-Object 'System.Collections.Generic.List[string]'

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

function Assert-DocumentDoesNotContain {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string[]]$Patterns
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return
    }

    $content = Get-Content -Raw -LiteralPath $path
    foreach ($pattern in $Patterns) {
        if ($content -match $pattern) {
            $failures.Add("$RelativePath contains forbidden pattern: $pattern")
        }
    }
}

function Assert-PatternCount {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][int]$ExpectedCount
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return
    }

    $content = Get-Content -Raw -LiteralPath $path
    $actualCount = [regex]::Matches($content, $Pattern).Count
    if ($actualCount -ne $ExpectedCount) {
        $failures.Add("$RelativePath pattern count expected $ExpectedCount but was $actualCount`: $Pattern")
    }
}

Assert-DocumentContains 'docs/CONSTITUTION.md' @(
    '(?im)\|\s*I9\s*\|\s*Programacion asistida de turnos',
    '(?i)control humano',
    '(?i)no (aprueba|publica).*(autonom|automatic)',
    '(?i)docs/operations/',
    '(?is)catalogo.*subordinad.*CONSTITUTION.*ARCHITECTURE.*TECNOLOGIA.*DESIGN.*SPEC',
    '(?i)fuente ejecutable.*parametros operativos',
    '(?is)no\s+puede\s+contradecir.*autoridades\s+superiores',
    'docs/superpowers/plans/2026-07-29-sg-programacion-turnos-implementation-plan\.md',
    '(?i)APROBADO COMO HOJA DE RUTA DOCUMENTAL',
    '(?i)EJECUCION NO AUTORIZADA',
    '(?is)aprobacion\s+humana\s+de\s+la\s+SPEC.*aprobacion\s+y\s+firma\s+del\s+catalogo.*acto\s+explicito\s+de\s+cierre\s+de\s+Gate\s+0',
    '(?is)Task 2.*solo.*despues.*tres'
)
Assert-DocumentDoesNotContain 'docs/CONSTITUTION.md' @(
    '(?i)Aprobacion humana de SPEC y plan',
    '(?i)SPEC,\s*plan\s*y\s*catalogo.*(?:aprobad|firmad)',
    '(?im)^>?\s*Gate 0\s*:\s*\*?\*?(Aprobad[oa]|Cerrado|Completado)',
    '(?im)^\s*(El\s+)?Gate 0\s+(esta|queda|fue|se encuentra)\s+(aprobado|cerrado|completado)',
    '(?im)^\s*Task 2\s*:\s*\*?\*?(Autorizada|Iniciada|En ejecucion)',
    '(?im)^\s*Task 2\s+(esta|queda|fue|se encuentra)\s+(autorizada|iniciada|en ejecucion)',
    '(?im)^\s*(La\s+)?ejecucion tecnica\s+(esta|queda|fue|se encuentra)\s+autorizada'
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
    'Prototipos/stitch_ecosistema_digital_unificado/sentinel_enterprise/DESIGN\.md',
    '#003366',
    '#FFC700',
    '#F8F9FA',
    '#FFFFFF',
    '#E1E4E8',
    '(?i)4px.*8px',
    '(?i)Montserrat.*sans.*jerarquia',
    '(?i)Arial/Inter-compatible.*datos',
    '(?i)landing page.*decoracion.*valor operativo',
    '(?i)matriz mensual',
    '(?i)plantillas',
    '(?i)comparacion',
    '(?i)excepciones'
)

$specPath = 'docs/specs/2026-07-29-sg-superapp-spec-i9-programacion-turnos.md'
Assert-DocumentContains $specPath @(
    '(?m)^> Estado: \*\*En revision\*\*\s*$',
    '(?m)^> Gate: 0 documental; no autoriza implementacion\s*$',
    '(?i)alcance',
    '(?i)contratos funcionales',
    '(?i)estados',
    '(?i)permisos',
    '(?i)API conceptual',
    '(?i)criterios de aceptacion',
    '(?i)exclusiones',
    '(?i)no publica.*autonom',
    'docs/superpowers/plans/2026-07-29-sg-programacion-turnos-implementation-plan\.md',
    '(?i)APROBADO COMO HOJA DE RUTA DOCUMENTAL',
    '(?i)EJECUCION NO AUTORIZADA',
    '(?is)aprobacion\s+humana\s+de\s+la\s+SPEC.*aprobacion\s+y\s+firma\s+del\s+catalogo.*acto\s+explicito\s+de\s+cierre\s+de\s+Gate\s+0',
    '(?is)Task 2.*solo.*despues.*tres',
    'POST\s+/api/portal/scheduling/projects/\{id\}/versions',
    'GET\s+/api/portal/scheduling/versions/\{versionId\}',
    'PUT\s+/api/portal/scheduling/versions/\{versionId\}/assignments/\{id\}',
    'POST\s+/api/portal/scheduling/versions/\{versionId\}/approve',
    'POST\s+/api/portal/scheduling/versions/\{versionId\}/publish'
)
Assert-DocumentDoesNotContain $specPath @(
    '(?m)^> Estado: \*\*(Aprobada|Aprobado|Cerrado|APROBADO_EJECUTABLE)\*\*\s*$',
    '/api/portal/scheduling/proposals/\{versionId\}',
    '(?im)^(?!.*\bno\b).*autoriza(?:r|da|do)?\s+(?:la\s+)?implementacion',
    '(?im)^\s*Implementacion\s*:\s*(autorizada|autorizado)\b',
    '(?im)^\s*(La\s+)?implementacion\s+(queda|esta)\s+autorizad[ao]\b',
    '(?i)Aprobacion humana de SPEC y plan',
    '(?i)SPEC,\s*plan\s*y\s*catalogo.*(?:aprobad|firmad)',
    '(?im)^>?\s*Gate 0\s*:\s*\*?\*?(Aprobad[oa]|Cerrado|Completado)',
    '(?im)^\s*(El\s+)?Gate 0\s+(esta|queda|fue|se encuentra)\s+(aprobado|cerrado|completado)',
    '(?im)^\s*Task 2\s*:\s*\*?\*?(Autorizada|Iniciada|En ejecucion)',
    '(?im)^\s*Task 2\s+(esta|queda|fue|se encuentra)\s+(autorizada|iniciada|en ejecucion)',
    '(?im)^\s*(La\s+)?ejecucion tecnica\s+(esta|queda|fue|se encuentra)\s+autorizada'
)
Assert-PatternCount $specPath '(?m)^> Estado:' 1
Assert-PatternCount $specPath '(?m)^> Estado: \*\*En revision\*\*\s*$' 1

$planPath = 'docs/plans/2026-07-29-sg-superapp-i9-programacion-turnos-plan.md'
Assert-DocumentContains $planPath @(
    '(?m)^# Execution Log I9 - Gate 0 - Programacion Asistida De Turnos\s*$',
    '(?m)^> Tipo: \*\*Execution log documental de Gate 0\*\*\s*$',
    '(?m)^> Estado general: \*\*En revision\*\*\s*$',
    '(?m)^> Gate 0: \*\*En revision\*\*\s*$',
    '(?i)Tasks? tecnicas.*bloqueadas',
    '(?i)Task 2',
    '(?i)Task 2.*bloqueada',
    '(?i)no iniciar',
    'docs/superpowers/plans/2026-07-29-sg-programacion-turnos-implementation-plan\.md',
    '(?i)APROBADO COMO HOJA DE RUTA DOCUMENTAL',
    '(?i)EJECUCION NO AUTORIZADA',
    '(?is)aprobacion\s+humana\s+de\s+la\s+SPEC.*aprobacion\s+y\s+firma\s+del\s+catalogo.*acto\s+explicito\s+de\s+cierre\s+de\s+Gate\s+0',
    '(?is)Task 2.*solo.*despues.*tres'
)
Assert-DocumentDoesNotContain $planPath @(
    '(?m)^> Estado general: \*\*(Aprobada|Aprobado|Cerrado|APROBADO_EJECUTABLE)\*\*\s*$',
    '(?m)^> Gate 0: \*\*(Aprobada|Aprobado|Cerrado|APROBADO_EJECUTABLE)\*\*\s*$',
    '(?im)^(?!.*\b(no|bloquead)\b).*autoriza(?:r|da|do)?\s+(?:la\s+)?implementacion',
    '(?im)^\s*Implementacion\s*:\s*(autorizada|autorizado)\b',
    '(?im)^\s*(La\s+)?implementacion\s+(queda|esta)\s+autorizad[ao]\b',
    '(?i)Aprobacion humana de SPEC y plan',
    '(?i)SPEC,\s*plan\s*y\s*catalogo.*(?:aprobad|firmad)',
    '(?im)^>?\s*Gate 0\s*:\s*\*?\*?(Aprobad[oa]|Cerrado|Completado)',
    '(?im)^\s*(El\s+)?Gate 0\s+(esta|queda|fue|se encuentra)\s+(aprobado|cerrado|completado)',
    '(?im)^\s*Task 2\s*:\s*\*?\*?(Autorizada|Iniciada|En ejecucion)',
    '(?im)^\s*Task 2\s+(esta|queda|fue|se encuentra)\s+(autorizada|iniciada|en ejecucion)',
    '(?im)^\s*(La\s+)?ejecucion tecnica\s+(esta|queda|fue|se encuentra)\s+autorizada'
)
Assert-PatternCount $planPath '(?m)^> Estado general:' 1
Assert-PatternCount $planPath '(?m)^> Estado general: \*\*En revision\*\*\s*$' 1
Assert-PatternCount $planPath '(?m)^> Gate 0:' 1
Assert-PatternCount $planPath '(?m)^> Gate 0: \*\*En revision\*\*\s*$' 1

$catalogPath = 'docs/operations/2026-07-29-i9-catalogo-reglas-programacion.md'
Assert-DocumentContains $catalogPath @(
    '(?m)^> Estado: \*\*BORRADOR_NO_EJECUTABLE\*\*\s*$',
    '(?i)jornada maxima',
    '(?i)descanso minimo',
    '(?i)cruces',
    '(?i)novedades',
    '(?i)ubicacion',
    '(?i)requisitos',
    '(?i)desviacion',
    '(?i)Operaciones',
    '(?i)Talento Humano',
    '(?i)Juridico',
    '(?m)^\| Operaciones \| Pendiente \|',
    '(?m)^\| Talento Humano \| Pendiente \|',
    '(?m)^\| Juridico \| Pendiente \|'
)
Assert-DocumentDoesNotContain $catalogPath @(
    '(?m)^> Estado: \*\*(Aprobada|Aprobado|Cerrado|APROBADO_EJECUTABLE)\*\*\s*$',
    '(?im)^(?!.*\bno\b).*autoriza(?:r|da|do)?\s+(?:la\s+)?implementacion',
    '(?im)^\s*Implementacion\s*:\s*(autorizada|autorizado)\b',
    '(?im)^\s*(La\s+)?implementacion\s+(queda|esta)\s+autorizad[ao]\b',
    '(?im)^>?\s*Gate 0\s*:\s*\*?\*?(Aprobad[oa]|Cerrado|Completado)',
    '(?im)^\s*(El\s+)?Gate 0\s+(esta|queda|fue|se encuentra)\s+(aprobado|cerrado|completado)',
    '(?im)^\s*Task 2\s*:\s*\*?\*?(Autorizada|Iniciada|En ejecucion)',
    '(?im)^\s*Task 2\s+(esta|queda|fue|se encuentra)\s+(autorizada|iniciada|en ejecucion)',
    '(?im)^\s*(La\s+)?ejecucion tecnica\s+(esta|queda|fue|se encuentra)\s+autorizada'
)
Assert-PatternCount $catalogPath '(?m)^> Estado:' 1
Assert-PatternCount $catalogPath '(?m)^> Estado: \*\*BORRADOR_NO_EJECUTABLE\*\*\s*$' 1

$catalogFullPath = Join-Path $repoRoot $catalogPath
if (Test-Path -LiteralPath $catalogFullPath -PathType Leaf) {
    $catalogContent = Get-Content -Raw -LiteralPath $catalogFullPath
    $signatureMatches = [regex]::Matches(
        $catalogContent,
        '(?m)^\|\s*(Operaciones|Talento Humano|TH|Juridico(?:/laboral)?|Juridico laboral)\s*\|\s*([^|]+)\|'
    )
    if ($signatureMatches.Count -ne 3) {
        $failures.Add("$catalogPath signature row count expected 3 but was $($signatureMatches.Count)")
    }

    foreach ($expectedRole in @('Operaciones', 'TH', 'Juridico')) {
        $roleCount = 0
        foreach ($signatureMatch in $signatureMatches) {
            $rawRole = $signatureMatch.Groups[1].Value
            $normalizedRole = if ($rawRole -eq 'Operaciones') {
                'Operaciones'
            }
            elseif ($rawRole -eq 'Talento Humano' -or $rawRole -eq 'TH') {
                'TH'
            }
            else {
                'Juridico'
            }

            if ($normalizedRole -eq $expectedRole) {
                $roleCount++
                $signatureStatus = $signatureMatch.Groups[2].Value.Trim()
                if ($signatureStatus -ne 'Pendiente') {
                    $failures.Add("$catalogPath signature $expectedRole status must be Pendiente but was $signatureStatus")
                }
            }
        }
        if ($roleCount -ne 1) {
            $failures.Add("$catalogPath signature $expectedRole row count expected 1 but was $roleCount")
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'I9 DOCS FAIL'
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host 'I9 DOCS PASS'
