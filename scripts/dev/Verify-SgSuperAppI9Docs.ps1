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
    '(?i)TASK 2 AUTORIZADA',
    '(?i)NO INICIADA',
    '(?is)catalogo.*APROBADO_PARA_PARAMETRIZACION.*Gate 0.*cerrado',
    '(?is)Camilo\s+Piedrahita.*Gerente\s+General.*cierre',
    '(?is)Carolina\s+Rodriguez\s+Russi.*Talento\s+Humano\s+y\s+Juridica',
    '(?is)Jorge\s+Guzman.*Operaciones'
)
Assert-DocumentDoesNotContain 'docs/CONSTITUTION.md' @(
    '(?i)Aprobacion humana de SPEC y plan',
    '(?is)pendientes\s+de\s+Gate\s+0.*aprobacion\s+humana\s+de\s+la\s+SPEC',
    '(?i)SPEC,\s*plan\s*y\s*catalogo.*(?:aprobad|firmad)',
    '(?im)^\s*Task 2\s*:\s*\*?\*?(Iniciada|En ejecucion)',
    '(?im)^\s*Task 2\s+(esta|queda|fue|se encuentra)\s+(iniciada|en ejecucion)'
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
    '(?m)^> Estado: \*\*Aprobada\*\*\s*$',
    '(?is)aprobada.*2026-07-29.*usuario.*patrocinador funcional',
    '(?m)^> Gate: 0 cerrado; Tasks 2, 3 y 4 completadas; Task 5 pendiente\s*$',
    '(?m)^Estado de aplicacion: \*\*TASK_4_COMPLETADA_TASK_5_PENDIENTE\*\*\s*$',
    '(?i)alcance',
    '(?i)contratos funcionales',
    '(?i)estados',
    '(?i)permisos',
    '(?i)API conceptual',
    '(?i)criterios de aceptacion',
    '(?i)exclusiones',
    '(?is)catalogo.*no\s+(?:es\s+)?ejecutable.*valores.*unidades.*vigencia.*alcance.*mensajes.*responsable.*pruebas',
    '(?is)catalogo\s+I9.*pendiente.*valores.*unidades.*vigencia.*alcance.*mensajes.*responsable.*pruebas',
    '(?i)no publica.*autonom',
    'docs/superpowers/plans/2026-07-29-sg-programacion-turnos-implementation-plan\.md',
    '(?i)APROBADO COMO HOJA DE RUTA DOCUMENTAL',
    'APROBADO_PARA_PARAMETRIZACION',
    '(?is)Gate 0.*cerrado.*Camilo Piedrahita.*Gerente General',
    '(?is)Task 2.*autorizada.*no iniciada',
    'POST\s+/api/portal/scheduling/projects/\{id\}/versions',
    'GET\s+/api/portal/scheduling/versions/\{versionId\}',
    'PUT\s+/api/portal/scheduling/versions/\{versionId\}/assignments/\{id\}',
    'POST\s+/api/portal/scheduling/versions/\{versionId\}/approve',
    'POST\s+/api/portal/scheduling/versions/\{versionId\}/publish'
)
Assert-DocumentDoesNotContain $specPath @(
    '(?m)^> Estado: \*\*(En revision|Aprobado|Cerrado|APROBADO_EJECUTABLE)\*\*\s*$',
    '(?is)catalogo\s+I9\s+cumple\s+esa\s+condicion',
    '(?is)catalogo.*fuente\s+ejecutable.*cumple\s+esa\s+condicion',
    '/api/portal/scheduling/proposals/\{versionId\}',
    '(?im)^(?!.*\bno\b).*autoriza(?:r|da|do)?\s+(?:la\s+)?implementacion',
    '(?im)^\s*Implementacion\s*:\s*(autorizada|autorizado)\b',
    '(?im)^\s*(La\s+)?implementacion\s+(queda|esta)\s+autorizad[ao]\b',
    '(?i)Aprobacion humana de SPEC y plan',
    '(?i)SPEC,\s*plan\s*y\s*catalogo.*(?:aprobad|firmad)',
    '(?im)^>?\s*Gate 0\s*:\s*\*?\*?(Aprobad[oa]|Cerrado|Completado)',
    '(?im)^\s*(El\s+)?Gate 0\s+(esta|queda|fue|se encuentra)\s+(aprobado|cerrado|completado)',
    '(?i)BORRADOR_NO_EJECUTABLE',
    '(?i)EJECUCION NO AUTORIZADA',
    '(?im)^\s*Task 2\s*:\s*\*?\*?(Iniciada|En ejecucion)',
    '(?im)^\s*Task 2\s+(esta|queda|fue|se encuentra)\s+(iniciada|en ejecucion)'
)
Assert-PatternCount $specPath '(?m)^> Estado:' 1
Assert-PatternCount $specPath '(?m)^> Estado: \*\*Aprobada\*\*\s*$' 1

$planPath = 'docs/plans/2026-07-29-sg-superapp-i9-programacion-turnos-plan.md'
Assert-DocumentContains $planPath @(
    '(?m)^# Execution Log I9 - Gate 0 - Programacion Asistida De Turnos\s*$',
    '(?m)^> Tipo: \*\*Execution log documental de Gate 0\*\*\s*$',
    '(?m)^> Estado general: \*\*Gate 0 cerrado - Tasks 2, 3 y 4 completadas - Task 5 pendiente\*\*\s*$',
    '(?m)^> Gate 0: \*\*Cerrado\*\*\s*$',
    '(?i)Task 4.*completada',
    '(?i)Task 5.*pendiente',
    '(?is)Tasks 2, 3 y 4.*completadas',
    'docs/superpowers/plans/2026-07-29-sg-programacion-turnos-implementation-plan\.md',
    '(?i)APROBADO COMO HOJA DE RUTA DOCUMENTAL',
    '(?i)TASK 4 COMPLETADA',
    '(?i)TASK 5 PENDIENTE',
    '(?is)SPEC.*aprobada.*2026-07-29.*usuario.*patrocinador funcional',
    '(?is)catalogo.*APROBADO_PARA_PARAMETRIZACION.*decisiones.*Aprobada',
    '(?m)^\| Gate / Retake \| Estado \| Condiciones cumplidas / proxima condicion \|\s*$',
    '(?m)^\| Gate 0 - autoridad documental \| Cerrado \| Catalogo aprobado para parametrizacion y firmado; no ejecutable; cierre ejecutivo registrado \|\s*$',
    '(?m)^\| Gate 1 / Tasks 2-4 - persistencia/configuracion \| Completado \| Persistencia, ciclos y CRUD de configuracion verificados bajo SDD/TDD \|\s*$',
    '(?m)^\| Gate 2 - reglas/motor \| Bloqueado \| Proxima condicion: completar y validar parametros de las 7 reglas \|\s*$',
    '(?is)Task 4.*completada.*Task 5.*pendiente',
    '(?is)Camilo\s+Piedrahita.*Gerente\s+General.*cierre',
    '(?i)GH-DE-01',
    '24/07/2025',
    '(?i)version 4',
    '(?is)organigrama.*identifica.*roles.*no.*aprobacion.*firma',
    'docs/operations/2026-07-29-i9-acta-validacion-gate0\.md'
)
Assert-DocumentDoesNotContain $planPath @(
    '(?m)^> Estado general: \*\*En revision\*\*\s*$',
    '(?m)^> Gate 0: \*\*En revision\*\*\s*$',
    '(?i)catalogo\s+aprobado/ejecutable',
    '(?m)^\| Gate 0 - autoridad documental \| Cerrado \| Catalogo aprobado y firmado;',
    '(?m)^\| Gate \| Estado \| Condicion pendiente \|\s*$',
    '(?m)^\| Gate 1 - persistencia/configuracion \| Bloqueado \| Gate 0 cerrado \|\s*$',
    '(?im)^(?!.*\b(no|bloquead)\b).*autoriza(?:r|da|do)?\s+(?:la\s+)?implementacion',
    '(?im)^\s*Implementacion\s*:\s*(autorizada|autorizado)\b',
    '(?im)^\s*(La\s+)?implementacion\s+(queda|esta)\s+autorizad[ao]\b',
    '(?i)Aprobacion humana de SPEC y plan',
    '(?m)^\| Gate 0 - autoridad documental \| En revision \|.*SPEC aprobada.*\|\s*$',
    '(?i)SPEC,\s*plan\s*y\s*catalogo.*(?:aprobad|firmad)',
    '(?i)BORRADOR_NO_EJECUTABLE',
    '(?is)Permanecen\s+pendientes.*catalogo.*cierre\s+de\s+Gate\s+0',
    '(?i)EJECUCION NO AUTORIZADA',
    '(?im)^\s*Task 2\s*:\s*\*?\*?(Iniciada|En ejecucion)',
    '(?im)^\s*Task 2\s+(esta|queda|fue|se encuentra)\s+(iniciada|en ejecucion)'
)
Assert-PatternCount $planPath '(?m)^> Estado general:' 1
Assert-PatternCount $planPath '(?m)^> Estado general: \*\*Gate 0 cerrado - Tasks 2, 3 y 4 completadas - Task 5 pendiente\*\*\s*$' 1
Assert-PatternCount $planPath '(?m)^> Gate 0:' 1
Assert-PatternCount $planPath '(?m)^> Gate 0: \*\*Cerrado\*\*\s*$' 1

$catalogPath = 'docs/operations/2026-07-29-i9-catalogo-reglas-programacion.md'
Assert-DocumentContains $catalogPath @(
    '(?m)^> Estado: \*\*APROBADO_PARA_PARAMETRIZACION\*\*\s*$',
    '(?i)jornada maxima',
    '(?i)descanso minimo',
    '(?i)cruces',
    '(?i)novedades',
    '(?i)ubicacion',
    '(?i)requisitos',
    '(?i)desviacion',
    '(?is)no\s+(?:es\s+)?ejecutable.*valores.*unidades.*vigencia.*alcance.*mensajes.*responsable.*pruebas',
    '(?i)Operaciones',
    '(?i)Talento Humano',
    '(?i)Juridico',
    '(?i)GH-DE-01',
    '24/07/2025',
    '(?i)version 4',
    '(?is)organigrama.*identifica.*roles.*no.*aprobacion.*firma',
    '(?m)^\| Director de Operaciones \| Aprobada \| Jorge Guzman \| Operaciones \| Aprobada \|',
    '(?m)^\| Director de Talento Humano \| Aprobada \| Carolina Rodriguez Russi \| Talento Humano y Juridica \| Aprobada \|',
    '(?m)^\| Asesor Juridico \| Aprobada \| Carolina Rodriguez Russi \| Talento Humano y Juridica \| Aprobada \|'
)
Assert-DocumentDoesNotContain $catalogPath @(
    '(?m)^> Estado: \*\*BORRADOR_NO_EJECUTABLE\*\*\s*$',
    '(?i)APROBADO_EJECUTABLE',
    '(?im)^(?!.*\bno\b).*autoriza(?:r|da|do)?\s+(?:la\s+)?implementacion',
    '(?im)^\s*Implementacion\s*:\s*(autorizada|autorizado)\b',
    '(?im)^\s*(La\s+)?implementacion\s+(queda|esta)\s+autorizad[ao]\b',
    '(?im)^\s*Task 2\s*:\s*\*?\*?(Iniciada|En ejecucion)',
    '(?im)^\s*Task 2\s+(esta|queda|fue|se encuentra)\s+(iniciada|en ejecucion)',
    '(?i)(firma manuscrita adjunta|documento externo adjunto)'
)
Assert-PatternCount $catalogPath '(?m)^> Estado:' 1
Assert-PatternCount $catalogPath '(?m)^> Estado: \*\*APROBADO_PARA_PARAMETRIZACION\*\*\s*$' 1

$catalogFullPath = Join-Path $repoRoot $catalogPath
if (Test-Path -LiteralPath $catalogFullPath -PathType Leaf) {
    $catalogContent = Get-Content -Raw -LiteralPath $catalogFullPath
    $signatureMatches = [regex]::Matches(
        $catalogContent,
        '(?m)^\|\s*(Director de Operaciones|Director de Talento Humano|Asesor Juridico)\s*\|\s*([^|]+)\|'
    )
    if ($signatureMatches.Count -ne 3) {
        $failures.Add("$catalogPath signature row count expected 3 but was $($signatureMatches.Count)")
    }

    foreach ($expectedRole in @('Director de Operaciones', 'Director de Talento Humano', 'Asesor Juridico')) {
        $roleCount = 0
        foreach ($signatureMatch in $signatureMatches) {
            $rawRole = $signatureMatch.Groups[1].Value
            if ($rawRole -eq $expectedRole) {
                $roleCount++
                $signatureStatus = $signatureMatch.Groups[2].Value.Trim()
                if ($signatureStatus -ne 'Aprobada') {
                    $failures.Add("$catalogPath signature $expectedRole status must be Aprobada but was $signatureStatus")
                }
            }
        }
        if ($roleCount -ne 1) {
            $failures.Add("$catalogPath signature $expectedRole row count expected 1 but was $roleCount")
        }
    }

    $ruleMatches = [regex]::Matches(
        $catalogContent,
        '(?m)^\|\s*(I9-R0[1-7])\s*\|(?:[^|]*\|){5}\s*([^|]+)\|\s*$'
    )
    if ($ruleMatches.Count -ne 7) {
        $failures.Add("$catalogPath rule row count expected 7 but was $($ruleMatches.Count)")
    }
    foreach ($ruleNumber in 1..7) {
        $ruleId = 'I9-R0' + $ruleNumber
        $matchesForRule = @($ruleMatches | Where-Object { $_.Groups[1].Value -eq $ruleId })
        if ($matchesForRule.Count -ne 1) {
            $failures.Add("$catalogPath rule $ruleId row count expected 1 but was $($matchesForRule.Count)")
        }
        elseif ($matchesForRule[0].Groups[2].Value.Trim() -ne 'APROBADA_PARA_PARAMETRIZACION') {
            $failures.Add("$catalogPath rule $ruleId must be APROBADA_PARA_PARAMETRIZACION")
        }
    }
}

$validationActPath = 'docs/operations/2026-07-29-i9-acta-validacion-gate0.md'
Assert-DocumentContains $validationActPath @(
    '(?m)^> Estado: \*\*APROBADA\*\*\s*$',
    '(?i)GH-DE-01',
    '24/07/2025',
    '(?i)version 4',
    '(?m)^El organigrama identifica roles, pero no constituye aprobacion ni firma\.',
    '(?m)^\| Director de Operaciones \| Aprobada \| Jorge Guzman \| Operaciones \| Aprobada \|',
    '(?m)^\| Director de Talento Humano \| Aprobada \| Carolina Rodriguez Russi \| Talento Humano y Juridica \| Aprobada \|',
    '(?m)^\| Asesor Juridico \| Aprobada \| Carolina Rodriguez Russi \| Talento Humano y Juridica \| Aprobada \|',
    '(?i)nombre',
    '(?i)cargo',
    '(?i)decision',
    '(?i)observaciones',
    '(?i)fecha',
    '(?i)evidencia/firma',
    'APROBADO_PARA_PARAMETRIZACION',
    '(?i)Gate 0.*Cerrado',
    '(?i)Task 2.*autorizada.*no iniciada',
    '(?is)Camilo Piedrahita.*Gerente General.*cierre',
    '(?i)confirmacion explicita del usuario en esta conversacion',
    '(?i)no.*firma manuscrita.*documento externo'
)
Assert-DocumentDoesNotContain $validationActPath @(
    '(?m)^> Estado: \*\*PENDIENTE_DE_FIRMAS\*\*\s*$',
    '(?i)BORRADOR_NO_EJECUTABLE',
    '(?i)APROBADO_EJECUTABLE',
    '(?i)APROBADO_EJECUTABLE',
    '(?im)^\s*Task 2\s*:\s*\*?\*?(Iniciada|En ejecucion)',
    '(?im)^\s*Task 2\s+(esta|queda|fue|se encuentra)\s+(iniciada|en ejecucion)',
    '(?i)evidencia/firma\s*:\s*(firma manuscrita|documento externo)'
)
Assert-PatternCount $validationActPath '(?m)^> Estado:' 1
Assert-PatternCount $validationActPath '(?m)^> Estado: \*\*APROBADA\*\*\s*$' 1

$validationActFullPath = Join-Path $repoRoot $validationActPath
if (Test-Path -LiteralPath $validationActFullPath -PathType Leaf) {
    $validationActContent = Get-Content -Raw -LiteralPath $validationActFullPath
    $validationRoleMatches = [regex]::Matches(
        $validationActContent,
        '(?m)^\|\s*(Director de Operaciones|Director de Talento Humano|Asesor Juridico)\s*\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|\s*$'
    )
    if ($validationRoleMatches.Count -ne 3) {
        $failures.Add("$validationActPath role row count expected 3 but was $($validationRoleMatches.Count)")
    }

    foreach ($expectedRole in @('Director de Operaciones', 'Director de Talento Humano', 'Asesor Juridico')) {
        $roleMatches = @($validationRoleMatches | Where-Object { $_.Groups[1].Value -eq $expectedRole })
        if ($roleMatches.Count -ne 1) {
            $failures.Add("$validationActPath role $expectedRole row count expected 1 but was $($roleMatches.Count)")
        }
        elseif ($roleMatches[0].Groups[2].Value.Trim() -ne 'Aprobada') {
            $failures.Add("$validationActPath role $expectedRole status must be Aprobada")
        }
        else {
            foreach ($field in @(
                @{ Name = 'Nombre'; Group = 3 },
                @{ Name = 'Cargo'; Group = 4 },
                @{ Name = 'Decision'; Group = 5 },
                @{ Name = 'Observaciones'; Group = 6 },
                @{ Name = 'Fecha'; Group = 7 },
                @{ Name = 'Evidencia/Firma'; Group = 8 }
            )) {
                if ([string]::IsNullOrWhiteSpace($roleMatches[0].Groups[$field.Group].Value)) {
                    $failures.Add("$validationActPath role $expectedRole field $($field.Name) must be populated while status is Aprobada")
                }
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'I9 DOCS FAIL'
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host 'I9 DOCS PASS'
