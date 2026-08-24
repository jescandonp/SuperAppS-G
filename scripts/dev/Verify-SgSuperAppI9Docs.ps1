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

function Assert-DocumentSectionContains {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$SectionPattern,
        [Parameter(Mandatory)][string[]]$Patterns
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing document: $RelativePath")
        return
    }

    $content = Get-Content -Raw -LiteralPath $path
    $sectionMatch = [regex]::Match($content, $SectionPattern)
    if (-not $sectionMatch.Success) {
        $failures.Add("$RelativePath missing section: $SectionPattern")
        return
    }

    foreach ($pattern in $Patterns) {
        if ($sectionMatch.Value -notmatch $pattern) {
            $failures.Add("$RelativePath section missing pattern: $pattern")
        }
    }
}

function Assert-DocumentSectionDoesNotContain {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$SectionPattern,
        [Parameter(Mandatory)][string[]]$Patterns
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing document: $RelativePath")
        return
    }

    $content = Get-Content -Raw -LiteralPath $path
    $sectionMatch = [regex]::Match($content, $SectionPattern)
    if (-not $sectionMatch.Success) {
        $failures.Add("$RelativePath missing section: $SectionPattern")
        return
    }

    foreach ($pattern in $Patterns) {
        if ($sectionMatch.Value -match $pattern) {
            $failures.Add("$RelativePath section contains forbidden pattern: $pattern")
        }
    }
}

function Assert-DocumentSectionPatternCount {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$SectionPattern,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][int]$ExpectedCount
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing document: $RelativePath")
        return
    }

    $content = Get-Content -Raw -LiteralPath $path
    $sectionMatch = [regex]::Match($content, $SectionPattern)
    if (-not $sectionMatch.Success) {
        $failures.Add("$RelativePath missing section: $SectionPattern")
        return
    }

    $actualCount = [regex]::Matches($sectionMatch.Value, $Pattern).Count
    if ($actualCount -ne $ExpectedCount) {
        $failures.Add("$RelativePath section pattern count expected $ExpectedCount but was $actualCount`: $Pattern")
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
    '(?m)^> Gate: 0 cerrado; Tasks 2 a 12 completadas; Task 13 en ejecucion\s*$',
    '(?m)^Estado de aplicacion: \*\*TASK_12_COMPLETADA_TASK_13_EN_EJECUCION\*\*\s*$',
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
    '(?m)^> Estado general: \*\*Gate 0 cerrado - Tasks 2 a 12 completadas - Task 13 en ejecucion\*\*\s*$',
    '(?m)^> Gate 0: \*\*Cerrado\*\*\s*$',
    '(?i)Task 4.*completada',
    '(?i)Task 13.*en ejecucion',
    '(?is)Tasks 2 a 12.*completadas',
    'docs/superpowers/plans/2026-07-29-sg-programacion-turnos-implementation-plan\.md',
    '(?i)APROBADO COMO HOJA DE RUTA DOCUMENTAL',
    '(?i)TASK 12 COMPLETADA',
    '(?i)TASK 13 EN EJECUCION',
    '(?is)SPEC.*aprobada.*2026-07-29.*usuario.*patrocinador funcional',
    '(?is)catalogo.*APROBADO_PARA_PARAMETRIZACION.*decisiones.*Aprobada',
    '(?m)^\| Gate / Retake \| Estado \| Condiciones cumplidas / proxima condicion \|\s*$',
    '(?m)^\| Gate 0 - autoridad documental \| Cerrado \| Catalogo aprobado para parametrizacion y firmado; no ejecutable; cierre ejecutivo registrado \|\s*$',
    '(?m)^\| Gate 1 / Tasks 2-4 - persistencia/configuracion \| Completado \| Persistencia, ciclos y CRUD de configuracion verificados bajo SDD/TDD \|\s*$',
    '(?m)^\| Gate 2 - reglas/motor \| Bloqueado \| Proxima condicion: completar y validar parametros de las 7 reglas \|\s*$',
    '(?is)Task 12.*completada.*Task 13.*en ejecucion',
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
Assert-PatternCount $planPath '(?m)^> Estado general: \*\*Gate 0 cerrado - Tasks 2 a 12 completadas - Task 13 en ejecucion\*\*\s*$' 1
Assert-PatternCount $planPath '(?m)^> Gate 0:' 1
Assert-PatternCount $planPath '(?m)^> Gate 0: \*\*Cerrado\*\*\s*$' 1
Assert-DocumentContains $planPath @(
    '(?is)2026-08-13.*aprobo expresamente la validacion visual',
    '(?is)BOTANIKA JULIO\.pdf.*BOTANIKA AGOSTO\.pdf.*datos simulados',
    '(?is)contenido visual identico.*ambos estan rotulados julio de 2026',
    '(?is)Task 13 permanece \*\*EN EJECUCION - NO CERRADA\*\*',
    '(?is)157 turnos D.*156 N.*165 descansos X.*8 ausencias A.*8 incapacidades INC.*una vacacion V.*un\s+turno\s+adicional TA'
)

$pilotPath = 'docs/reports/2026-07-29-sg-superapp-i9-pilot-baseline.md'
Assert-DocumentContains $pilotPath @(
    '(?m)^> Estado: \*\*HISTORICO_SIMULADO_RECIBIDO_PENDIENTE_DE_EJECUCION_I9\*\*\s*$',
    '(?is)ambos documentos.*contenido visual es identico.*rotulados `Julio de 2026`',
    '(?is)496 celdas.*157.*156.*165',
    '(?is)historico simulado y la aprobacion visual.*no cierran Task 13 ni Gate 5',
    '(?is)siete reglas normativas.*ejecutables'
)
Assert-DocumentDoesNotContain $pilotPath @(
    '(?m)^> Estado: \*\*PENDIENTE_DE_DATOS_Y_EJECUCION\*\*\s*$',
    '(?i)Gate 5 (esta|queda) (cerrado|aprobado)',
    '(?i)Task 13 (esta|queda) (cerrada|completada)',
    '(?i)reglas normativas (estan|quedan) ejecutables'
)

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
Assert-DocumentSectionContains $catalogPath '(?ms)^## Decision De Parametrizacion I9-R01\s*$.*?(?=^## Decision De Parametrizacion I9-R02\s*$)' @(
    '(?m)^## Decision De Parametrizacion I9-R01\s*$',
    '(?m)^Estado de I9-R01: \*\*APROBADA_CONDICION_JURIDICA_NO_EJECUTABLE\*\*\s*$',
    '(?is)8 horas diarias.*42 horas semanales.*12 horas diarias.*60 horas semanales',
    '(?is)existencia del acuerdo escrito este\s+marcada.*Se bloquea superar 12 horas diarias.*superar 60 horas semanales',
    '(?is)mas de 8 horas diarias cuando la marca.*sea falsa o\s+no este diligenciada',
    '(?is)marca de existencia del acuerdo conserva responsable y fecha.*referencia, documento u otro soporte.*opcionales.*ausencia no bloquea por si sola',
    '(?is)superior a 10 y hasta 12 horas crea una excepcion `PENDIENTE`.*no bloquea.*no puede aprobarse ni\s+publicarse.*Director de Operaciones.*SCHEDULING/APPROVE_EXCEPTION',
    '(?is)confirmacion del usuario, no de un concepto juridico',
    '(?is)usuario confirmo al Director de Operaciones como rol aprobador.*pendientes la fuente y vigencia juridicas.*todos los proyectos de vigilancia gestionados\s+por I9, sin un valor distinto por proyecto o contrato.*I9-R01 no\s+puede pasar a estado ejecutable'
)
Assert-DocumentDoesNotContain $catalogPath @(
    '(?i)I9-R01.*APROBADA_EJECUTABLE',
    '(?i)I9-R0[2-7].*APROBADA_CONDICION_JURIDICA_NO_EJECUTABLE'
)
Assert-DocumentContains $catalogPath @(
    '(?m)^## Decision De Parametrizacion I9-R02\s*$',
    '(?m)^Estado de I9-R02: \*\*APROBADA_COMO_EXCEPCION_NO_BLOQUEANTE\*\*\s*$',
    '(?is)12 horas continuas.*igual o superior a 12 horas cumple',
    '(?is)inferior a 12 horas no bloquea la generacion.*excepcion `PENDIENTE`',
    '(?is)no puede aprobarse ni publicarse.*Director de Operaciones.*SCHEDULING/APPROVE_EXCEPTION',
    '(?is)todos los proyectos de vigilancia gestionados por I9.*sin un umbral distinto',
    '(?is)motivo obligatorio.*catalogo configurable.*responsable, fecha, vigencia y auditoria',
    '(?is)autorizacion se limita al turno y excepcion evaluados.*no crea una\s+autorizacion permanente',
    '(?is)Catalogo inicial de motivos autorizados.*reemplazo urgente por ausencia o incapacidad.*continuidad temporal del servicio.*contingencia operativa del proyecto.*emergencia o fuerza mayor.*ajuste excepcional solicitado por el cliente.*otro, con descripcion obligatoria',
    '(?is)catalogo de motivos debe conservar version y vigencia.*no sustituye la aprobacion del Director de Operaciones',
    '(?is)politica preventiva S&G.*no como valor legal atribuido.*desactivada o en modo\s+advertencia',
    '(?is)I9-R05.*tiempo de traslado.*no se infiere un valor'
)
Assert-DocumentDoesNotContain $catalogPath @(
    '(?i)I9-R02.*APROBADA_EJECUTABLE'
)
Assert-DocumentContains $catalogPath @(
    '(?m)^## Decision De Parametrizacion I9-R03\s*$',
    '(?m)^Estado de I9-R03: \*\*APROBADA_MIXTA_NO_EJECUTABLE\*\*\s*$',
    '(?is)inicio de un turno es anterior al fin.*solapamiento real',
    '(?is)todos los proyectos y puestos.*borradores vigentes.*programaciones ya aprobadas.*mismo guarda',
    '(?is)intervalos semiabiertos `\[inicio, fin\)`.*frontera fin/inicio no constituye solapamiento',
    '(?is)solapamiento real es bloqueante, no admite excepcion.*vacante',
    '(?is)adyacentes.*exactamente al finalizar.*no constituye.*solapamiento',
    '(?is)puestos distintos.*excepcion `PENDIENTE`.*no aprobarse ni publicarse',
    '(?is)I9-R05.*SCHEDULING/APPROVE_EXCEPTION',
    '(?is)cambio manual vuelve a ejecutar I9-R03.*guardar,\s+aprobar o publicar',
    '(?is)excepcion de traslado de I9-R05 nunca permite autorizar un solapamiento',
    '(?is)fecha y hora completas.*turnos nocturnos.*cambios.*mes.*ano',
    '(?is)desactivada o en validacion simulada'
)
Assert-DocumentDoesNotContain $catalogPath @(
    '(?i)I9-R03.*APROBADA_EJECUTABLE'
)
Assert-DocumentContains $catalogPath @(
    '(?m)^## Decision De Parametrizacion I9-R04\s*$',
    '(?m)^Estado de I9-R04: \*\*APROBADA_POR_CLASIFICACION_NO_EJECUTABLE\*\*\s*$',
    '(?is)Incapacidad vigente \| Bloqueo absoluto.*Vacaciones aprobadas \| Bloqueo absoluto',
    '(?is)Ausencia confirmada \| Bloqueo absoluto.*Ausencia reportada pendiente de confirmar \| Excepcion aprobable',
    '(?is)Induccion o capacitacion coincidente \| Excepcion aprobable',
    '(?is)Turno adicional \| Excepcion aprobable, sujeta a I9-R01 e I9-R02',
    '(?is)Mapeo inicial aprobado desde el historico simulado.*INC \| Incapacidad vigente \| Bloqueo absoluto.*V \| Vacaciones aprobadas y vigentes \| Bloqueo absoluto.*A \| Ausencia \| Confirmada: bloqueo absoluto; pendiente de confirmar: excepcion aprobable.*TA \| Turno adicional \| Excepcion aprobable sujeta a I9-R01 e I9-R02',
    '(?is)D / N / X \| Dia / noche / descanso \| Codigos de programacion; no son novedades',
    '(?is)Descuento o sancion administrativa \| Informativa, salvo indisponibilidad formal',
    '(?is)tipo, inicio, fin, estado, fuente y responsable',
    '(?is)Director de Operaciones aprueba las excepciones de I9-R04.*SCHEDULING/APPROVE_EXCEPTION.*todos los proyectos',
    '(?is)codigo desconocido genera advertencia.*no se convierte automaticamente\s+en bloqueo, excepcion aprobada ni disponibilidad',
    '(?is)prevalece: bloqueo absoluto, luego excepcion.*finalmente informativa',
    '(?is)I9-R04 no pasa a ejecutable hasta confirmar la fuente y version.*licencia/calamidad.*suspension/retiro.*capacitacion/induccion.*novedades administrativas'
)
Assert-DocumentDoesNotContain $catalogPath @(
    '(?i)I9-R04.*APROBADA_EJECUTABLE'
)
Assert-DocumentContains $catalogPath @(
    '(?m)^## Decision De Parametrizacion I9-R05\s*$',
    '(?m)^Estado de I9-R05: \*\*APROBADA_POR_CRITERIO_NO_EJECUTABLE\*\*\s*$',
    '(?is)matriz versionada de traslados por.*proyecto o contrato.*no existe un tiempo universal',
    '(?is)intervalo disponible es igual o mayor.*tiempo requerido',
    '(?is)tiempo insuficiente genera una excepcion `PENDIENTE`.*no bloquea.*impide aprobarla o publicarla',
    '(?is)no existe un valor en la matriz.*nunca se asume un traslado de cero minutos',
    '(?is)combinacion.*expresamente prohibida.*bloqueo absoluto sin excepcion',
    '(?is)origen, destino, tiempo requerido, tiempo disponible.*version de matriz.*aprobador',
    '(?is)Trafico en tiempo real.*calculo dinamico de rutas.*fuera del MVP',
    '(?is)I9-R05 no pasa a ejecutable hasta cargar y validar la matriz real'
)
Assert-DocumentDoesNotContain $catalogPath @(
    '(?i)I9-R05.*APROBADA_EJECUTABLE'
)
Assert-DocumentContains $catalogPath @(
    '(?m)^## Decision De Parametrizacion I9-R06\s*$',
    '(?m)^Estado de I9-R06: \*\*APROBADA_NO_BLOQUEANTE_NO_EJECUTABLE\*\*\s*$',
    '(?is)Cada requisito se configura por puesto, proyecto y vigencia',
    '(?is)Ningun incumplimiento bloquea la generacion de la propuesta',
    '(?is)requisito faltante, vencido o no verificado.*excepcion\s+`PENDIENTE`.*no puede aprobarse ni publicarse',
    '(?is)SCHEDULING/APPROVE_EXCEPTION',
    '(?is)requisito subsanable.*informativo solo mediante.*configuracion explicita y versionada',
    '(?is)ausencia de informacion nunca.*acredita.*cumplimiento',
    '(?is)motivo, responsable de subsanacion, fecha limite.*aprobador.*evidencia',
    '(?is)snapshot conserva los requisitos, vigencias, acreditaciones y fuentes',
    '(?is)I9-R06 no pasa a ejecutable hasta mapear los catalogos reales de I3/I5'
)
Assert-DocumentDoesNotContain $catalogPath @(
    '(?i)I9-R06.*APROBADA_EJECUTABLE'
)
Assert-DocumentContains $catalogPath @(
    '(?m)^## Decision De Parametrizacion I9-R07\s*$',
    '(?m)^Estado de I9-R07: \*\*APROBADA_CON_EXCEPCION_NO_EJECUTABLE\*\*\s*$',
    '(?is)plantilla seleccionada.*2X2, 4X2, 6X1.*obligatoria por\s+defecto',
    '(?is)Toda diferencia.*version vigente.*desviacion explicita',
    '(?is)desviacion no bloquea la generacion.*excepcion `PENDIENTE`.*no puede aprobarse ni publicarse',
    '(?is)cambios manuales reciben el mismo tratamiento',
    '(?is)plantilla y version, guarda, fechas y celdas.*valor original, valor propuesto.*aprobador',
    '(?is)excepcion de plantilla nunca permite eludir bloqueos absolutos',
    '(?is)cambio de plantilla solo afecta borradores futuros.*no modifica.*programaciones aprobadas',
    '(?is)snapshot conserva la plantilla, su version y las desviaciones',
    '(?is)I9-R07 no pasa a ejecutable hasta definir y validar motivos autorizados'
)
Assert-DocumentDoesNotContain $catalogPath @(
    '(?i)I9-R07.*APROBADA_EJECUTABLE'
)

$parameterMatrixPath = 'docs/operations/2026-08-13-i9-matriz-parametrizacion-reglas.md'
Assert-DocumentContains $parameterMatrixPath @(
    '(?m)^> Estado: \*\*BORRADOR_PARA_DILIGENCIAMIENTO_NO_EJECUTABLE\*\*\s*$',
    '(?is)no autoriza ejecucion en el motor',
    '(?is)`PENDIENTE` nunca se\s+interpreta como cero, falso, vacio permitido o valor por defecto',
    '(?is)I9-R01.*I9-R02.*I9-R03.*I9-R04.*I9-R05.*I9-R06.*I9-R07',
    '(?is)Tratamiento mayor a 10 y hasta 12 h/dia \| Excepcion PENDIENTE con aprobacion obligatoria; no bloquea propuesta',
    '(?is)Rol aprobador de 10 a 12 h/dia \| Director de Operaciones \| Confirmacion explicita del usuario; permiso SCHEDULING/APPROVE_EXCEPTION',
    '(?is)Alcance \| Todos los proyectos de vigilancia gestionados por I9; sin valor distinto por proyecto/contrato \| Confirmacion explicita del usuario',
    '(?is)Existencia de acuerdo escrito \| Marca obligatoria para programar mas de 8 h; conserva responsable y fecha',
    '(?is)Referencia, documento u otro soporte del acuerdo \| Opcional; su ausencia no bloquea por si sola',
    '(?is)Tratamiento mayor a 12 h/dia \| Bloqueo absoluto',
    '(?is)Rol aprobador \| Director de Operaciones \| Confirmacion explicita del usuario',
    '(?is)Alcance \| Todos los proyectos de vigilancia gestionados por I9; umbral unico',
    '(?is)Vigencia de la autorizacion \| Solo el turno y excepcion evaluados; no reutilizable',
    '(?is)Motivos autorizados \| Reemplazo urgente; continuidad temporal; contingencia operativa; emergencia/fuerza mayor; solicitud excepcional del cliente; otro',
    '(?is)Motivo Otro \| Descripcion obligatoria \| Prueba de rechazo sin descripcion',
    '(?is)Efecto del motivo \| No sustituye la aprobacion del Director de Operaciones',
    '(?is)Modo durante desarrollo \| Desactivada o advertencia; no ejecutable en produccion',
    '(?is)Semantica del intervalo \| Semiabierto \[inicio, fin\)',
    '(?is)Cambios manuales \| Revalidacion obligatoria antes de guardar/aprobar/publicar',
    '(?is)Prioridad frente a R05 \| Excepcion de traslado nunca elude solapamiento',
    '(?is)Codigos que bloquean \| INC: incapacidad vigente; V: vacaciones aprobadas/vigentes; A confirmada: ausencia',
    '(?is)Codigos con excepcion \| A pendiente de confirmar; TA sujeto a I9-R01/I9-R02',
    '(?is)Codigos de programacion \| D dia; N noche; X descanso; no son novedades',
    '(?is)Codigo desconocido \| Advertencia; no infiere bloqueo, excepcion aprobada ni disponibilidad',
    '(?is)Origen, destino y tiempo requerido \| PENDIENTE',
    '(?is)Catalogo de requisitos por puesto \| PENDIENTE',
    '(?is)Motivos autorizados \| PENDIENTE',
    '(?is)Hasta ese cierre, las siete reglas permanecen no ejecutables y Gate 2 continua\s+bloqueado'
)
Assert-DocumentDoesNotContain $parameterMatrixPath @(
    '(?i)APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado',
    '(?i)PENDIENTE.*(?:=|se interpreta como)\s*(?:0|cero|false|falso)'
)

$legalProposalPath = 'docs/operations/2026-08-13-i9-propuesta-juridica-jornada.md'
Assert-DocumentContains $legalProposalPath @(
    '(?m)^> Estado: \*\*PROPUESTA_PENDIENTE_REVISION_JURIDICA_NO_EJECUTABLE\*\*\s*$',
    '(?is)Ley 1920 de 2018.*articulo 7.*escrito.*firma de ambas partes.*12 horas.*60 horas',
    '(?is)Ley 2101 de 2021.*42 horas',
    '(?is)Ley 2466 de 2025.*articulo 167A.*2 horas diarias y 12 semanales',
    '(?is)Juridica debe determinar.*armonizan.*Ley 1920.*articulo 167A',
    '(?is)marca del sistema.*no reemplaza el documento escrito ni las firmas',
    '(?is)revision juridica no bloquea el desarrollo',
    '(?is)I9-R01 permanece no ejecutable en produccion',
    '(?is)configuracion normativa se mantiene desactivada o en modo advertencia',
    '(?is)no se aprueba ni publica automaticamente'
)
Assert-DocumentDoesNotContain $legalProposalPath @(
    '(?i)CONCEPTO_JURIDICO_APROBADO',
    '(?i)I9-R01.*APROBADA_EJECUTABLE',
    '(?i)marca.*(?:reemplaza|equivale).*(?:acuerdo escrito|firmas)'
)

$r02TestProposalPath = 'docs/operations/2026-08-13-i9-r02-mensajes-pruebas.md'
Assert-DocumentContains $r02TestProposalPath @(
    '(?m)^> Estado: \*\*APROBADO_FUNCIONALMENTE_NO_EJECUTABLE\*\*\s*$',
    '(?m)^> Evidencia: aprobacion explicita del usuario en esta conversacion\.\s*$',
    '(?is)I9-R02-OK.*I9-R02-WARN.*I9-R02-MOTIVE.*I9-R02-OTHER.*I9-R02-PENDING.*I9-R02-REJECTED.*I9-R02-APPROVED',
    '(?m)^\| R02-T01 \| Intervalo 12 h 00 min \| CUMPLE; no crea excepcion \|\s*$',
    '(?m)^\| R02-T03 \| Intervalo 11 h 59 min \| Genera propuesta y excepcion PENDIENTE; no permite aprobar/publicar \|\s*$',
    '(?is)Motivo Otro sin descripcion.*Rechaza envio',
    '(?is)Rol distinto al Director de Operaciones intenta aprobar.*Acceso denegado',
    '(?is)reutilizar aprobacion en otro turno.*Rechaza reutilizacion',
    '(?is)Intervalo negativo por solapamiento.*I9-R03 aplica bloqueo absoluto',
    '(?is)Turnos en puestos diferentes.*I9-R05.*no presume tiempo de traslado',
    '(?is)Este artefacto no activa I9-R02.*aprobacion\s+funcional.*implementacion posterior mediante TDD.*evidencia institucional'
)
Assert-PatternCount $r02TestProposalPath '(?m)^\| R02-T(?:0[1-9]|1[0-6]) \|' 16
Assert-DocumentDoesNotContain $r02TestProposalPath @(
    '(?i)I9-R02.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado',
    '(?i)autorizacion.*reutilizable'
)

$r03TestProposalPath = 'docs/operations/2026-08-13-i9-r03-mensajes-pruebas.md'
Assert-DocumentContains $r03TestProposalPath @(
    '(?m)^> Estado: \*\*APROBADO_FUNCIONALMENTE_NO_EJECUTABLE\*\*\s*$',
    '(?m)^> Evidencia: aprobacion explicita del usuario en esta conversacion\.\s*$',
    '(?is)I9-R03-OK.*I9-R03-ADJACENT.*I9-R03-BLOCK.*I9-R03-APPROVED.*I9-R03-DRAFT.*I9-R03-TRANSFER.*I9-R03-EDIT',
    '(?m)^\| R03-T01 \| A termina 18:00; B inicia 18:00 \| No hay solapamiento; aplica intervalo \[inicio, fin\) \|\s*$',
    '(?m)^\| R03-T02 \| A termina 18:00; B inicia 17:59 \| Bloqueo absoluto por un minuto de solapamiento \|\s*$',
    '(?is)programacion aprobada.*Bloquea.*I9-R03-APPROVED',
    '(?is)borrador vigente.*Bloquea.*I9-R03-DRAFT',
    '(?is)Excepcion R05 aprobada pero existe cruce.*I9-R03 mantiene bloqueo absoluto',
    '(?is)Edicion manual introduce cruce.*rechaza guardar/aprobar/publicar',
    '(?is)Este artefacto no activa I9-R03.*aprobacion\s+funcional.*implementacion posterior mediante TDD.*evidencia institucional'
)
Assert-PatternCount $r03TestProposalPath '(?m)^\| R03-T(?:0[1-9]|1[0-5]) \|' 15
Assert-DocumentDoesNotContain $r03TestProposalPath @(
    '(?i)I9-R03.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado',
    '(?im)^(?!.*\bno\b).*solapamiento.*(?:admite|permite).*excepcion'
)

$r04CategoryContractPath = 'docs/operations/2026-08-13-i9-r04-contrato-categorias-novedad.md'
Assert-DocumentContains $r04CategoryContractPath @(
    '(?m)^> Estado: \*\*APROBADO_FUNCIONALMENTE_NO_EJECUTABLE\*\*\s*$',
    '(?m)^> Evidencia: aprobacion explicita del usuario en esta conversacion\.\s*$',
    '(?is)INCAPACITY_ACTIVE.*VACATION_APPROVED_ACTIVE.*LEAVE_OR_CALAMITY_ACTIVE.*SUSPENSION_OR_TERMINATION_ACTIVE.*ABSENCE_CONFIRMED.*ABSENCE_PENDING_CONFIRMATION.*TRAINING_OR_INDUCTION_OVERLAP.*AVAILABLE.*ADDITIONAL_SHIFT.*ADMINISTRATIVE_EVENT.*EXPIRED_OR_CANCELLED.*UNKNOWN',
    '(?is)identificadores son `UPPER_SNAKE_CASE`.*Nuevas categorias se agregan sin\s+cambiar el significado.*deprecacion y\s+migracion',
    '(?is)sourceSystem.*sourceCode.*sourceStatus.*semanticCategory.*mappingVersion.*effectiveFrom.*effectiveTo.*mappedBy.*approvedBy',
    '(?is)dos mapeos\s+activos.*sourceSystem \+ sourceCode \+ sourceStatus',
    '(?is)valor desconocido siempre se transforma en `UNKNOWN`.*nunca se aproxima',
    '(?is)INC \| Vigente \| INCAPACITY_ACTIVE.*V \| Aprobada y vigente \| VACATION_APPROVED_ACTIVE.*A \| Confirmada \| ABSENCE_CONFIRMED.*A \| Pendiente de confirmar \| ABSENCE_PENDING_CONFIRMATION.*TA \| Vigente \| ADDITIONAL_SHIFT',
    '(?is)`D`, `N` y `X` no ingresan.*codigos de programacion',
    '(?is)Solo existe una version activa.*snapshot conserva\s+codigo, estado, categoria y version',
    '(?is)permanece no ejecutable.*Gate 2 continua abierto'
)
Assert-PatternCount $r04CategoryContractPath '(?m)^\| (?:INCAPACITY_ACTIVE|VACATION_APPROVED_ACTIVE|LEAVE_OR_CALAMITY_ACTIVE|SUSPENSION_OR_TERMINATION_ACTIVE|ABSENCE_CONFIRMED|ABSENCE_PENDING_CONFIRMATION|TRAINING_OR_INDUCTION_OVERLAP|AVAILABLE|ADDITIONAL_SHIFT|ADMINISTRATIVE_EVENT|EXPIRED_OR_CANCELLED|UNKNOWN) \|' 12
Assert-DocumentDoesNotContain $r04CategoryContractPath @(
    '(?i)I9-R04.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado',
    '(?i)UNKNOWN.*(?:bloqueo absoluto|disponible)'
)

$r04TestProposalPath = 'docs/operations/2026-08-13-i9-r04-mensajes-pruebas.md'
Assert-DocumentContains $r04TestProposalPath @(
    '(?m)^> Estado: \*\*APROBADO_FUNCIONALMENTE_NO_EJECUTABLE\*\*\s*$',
    '(?m)^> Evidencia: aprobacion explicita del usuario en esta conversacion\.\s*$',
    '(?is)I9-R04-OK.*I9-R04-BLOCK.*I9-R04-EXCEPTION.*I9-R04-INFO.*I9-R04-UNKNOWN.*I9-R04-INCOMPLETE.*I9-R04-PENDING.*I9-R04-REJECTED.*I9-R04-APPROVED',
    '(?m)^\| R04-T04 \| A con estado Pendiente de confirmar \| Genera excepcion PENDIENTE; no permite aprobar/publicar \|\s*$',
    '(?m)^\| R04-T12 \| Codigo desconocido parecido a INC \| UNKNOWN; no aproxima por texto, prefijo o semejanza \|\s*$',
    '(?m)^\| R04-T13 \| D, N o X recibido como supuesto codigo de novedad \| Rechaza entrada al contrato de novedades; son codigos de programacion \|\s*$',
    '(?is)Coinciden bloqueo, excepcion e informativa.*Prevalece bloqueo absoluto',
    '(?is)Rol distinto al Director de Operaciones intenta aprobar.*Acceso denegado',
    '(?is)reutilizar aprobacion en otra novedad o turno.*Rechaza reutilizacion',
    '(?is)mappingVersion.*Snapshot historico conserva codigo, estado, categoria y version',
    '(?is)BLOQUEO_ABSOLUTO.*prevalece.*EXCEPCION_PENDIENTE.*ADVERTENCIA.*INFORMATIVA.*SIN_EFECTO',
    '(?is)aprobacion de excepcion nunca elude un bloqueo absoluto de I9-R01, I9-R03',
    '(?is)Este artefacto no activa I9-R04.*aprobacion\s+funcional.*implementacion posterior mediante TDD.*catalogo institucional.*evidencia institucional'
)
Assert-PatternCount $r04TestProposalPath '(?m)^\| R04-T(?:0[1-9]|1[0-9]|2[0-4]) \|' 24
Assert-DocumentDoesNotContain $r04TestProposalPath @(
    '(?i)I9-R04.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado',
    '(?i)UNKNOWN.*(?:bloqueo absoluto|disponible)',
    '(?im)^(?!.*\bno\b).*bloqueo absoluto.*(?:admite|permite).*excepcion'
)

$r05ProposalPath = 'docs/operations/2026-08-13-i9-r05-parametros-mensajes-pruebas.md'
Assert-DocumentContains $r05ProposalPath @(
    '(?m)^> Estado: \*\*APROBADO_FUNCIONALMENTE_NO_EJECUTABLE\*\*\s*$',
    '(?is)criterios y parametros detallados aprobados explicitamente por el usuario en esta conversacion',
    '(?is)Director de Operaciones.*SCHEDULING/APPROVE_EXCEPTION',
    '(?is)minutos enteros no negativos.*A -> B.*B -> A',
    '(?is)Excepcion no reutilizable.*guarda.*dos turnos.*origen.*destino',
    '(?is)Mismo puesto exacto.*cero minutos por identidad.*puestos diferentes.*no se asume',
    '(?is)I9-R05-SAME.*I9-R05-OK.*I9-R05-INSUFFICIENT.*I9-R05-MISSING.*I9-R05-PROHIBITED.*I9-R05-PENDING.*I9-R05-REJECTED.*I9-R05-APPROVED.*I9-R05-NO-VERSION',
    '(?m)^\| R05-T03 \| A -> B requiere 30 min; disponibles 30 \| CUMPLE por frontera igual \|\s*$',
    '(?m)^\| R05-T05 \| A -> B requiere 30 min; disponibles 29 \| Excepcion PENDIENTE; bloquea aprobar/publicar \|\s*$',
    '(?is)Combinacion marcada prohibida.*Bloqueo absoluto; no permite solicitar excepcion',
    '(?is)Otro rol intenta aprobar.*Acceso denegado',
    '(?is)reutilizar aprobacion.*Rechaza reutilizacion',
    '(?is)Existe solapamiento.*I9-R03 mantiene bloqueo absoluto',
    '(?is)aprobacion funcional del usuario.*no activa I9-R05.*ni cierra Gate 2.*implementacion mediante TDD'
)
Assert-PatternCount $r05ProposalPath '(?m)^\| R05-T(?:0[1-9]|1[0-9]|20) \|' 20
Assert-DocumentDoesNotContain $r05ProposalPath @(
    '(?i)I9-R05.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado',
    '(?m)^> Estado: \*\*PROPUESTA_PARA_VALIDACION_NO_EJECUTABLE\*\*\s*$',
    '(?im)^(?!.*\bno\b).*combinacion.*prohibida.*(?:admite|permite).*excepcion'
)

$r06ProposalPath = 'docs/operations/2026-08-14-i9-r06-parametros-mensajes-pruebas.md'
Assert-DocumentContains $r06ProposalPath @(
    '(?m)^> Estado: \*\*APROBADO_FUNCIONALMENTE_NO_EJECUTABLE\*\*\s*$',
    '(?is)criterios y parametros detallados aprobados explicitamente por el usuario en esta conversacion',
    '(?is)COURSE.*ACCREDITATION.*CERTIFICATION.*LICENSE_OR_PERMIT.*OTHER_REQUIREMENT',
    '(?is)vigente desde el\s+inicio hasta el fin completo del turno',
    '(?is)COMPLIANT.*MISSING.*EXPIRED.*UNVERIFIED.*INFORMATIVE_REMEDIABLE',
    '(?is)Sin periodo de gracia universal.*unidad, valor, fuente y vigencia',
    '(?is)Talento Humano valida.*Director de Operaciones aprueba.*SCHEDULING/APPROVE_EXCEPTION',
    '(?is)Subsanable informativo.*responsable de\s+subsanacion.*fecha limite.*No equivale a cumplimiento',
    '(?is)Excepcion no reutilizable.*guarda.*requisito.*puesto.*turno.*version',
    '(?is)I9-R06-OK.*I9-R06-MISSING.*I9-R06-EXPIRED.*I9-R06-UNVERIFIED.*I9-R06-REMEDIABLE.*I9-R06-INCOMPLETE.*I9-R06-PENDING.*I9-R06-REJECTED.*I9-R06-APPROVED',
    '(?m)^\| R06-T04 \| Requisito vence durante el turno \| Excepcion PENDIENTE; no se considera vigente \|\s*$',
    '(?is)Talento Humano valida evidencia.*no sustituye aprobacion operativa',
    '(?is)Director de Operaciones intenta aprobar sin validacion TH.*Rechaza flujo',
    '(?is)reutiliza aprobacion.*Rechaza reutilizacion',
    '(?is)bloqueo absoluto R01/R03/R05.*Mantiene el bloqueo absoluto',
    '(?is)Decisiones Aprobadas Funcionalmente.*Talento Humano valida.*Director de Operaciones aprueba',
    '(?is)aprobacion funcional del usuario.*no activa I9-R06.*ni cierra Gate 2.*implementacion mediante TDD'
)
Assert-PatternCount $r06ProposalPath '(?m)^\| R06-T(?:0[1-9]|1[0-9]|2[0-3]) \|' 23
Assert-DocumentDoesNotContain $r06ProposalPath @(
    '(?i)I9-R06.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado',
    '(?m)^> Estado: \*\*PROPUESTA_PARA_VALIDACION_NO_EJECUTABLE\*\*\s*$',
    '(?im)^(?!.*\b(?:no|nunca)\b).*ausencia de informacion.*acredita.*cumplimiento'
)
Assert-DocumentSectionContains $planPath '(?ms)^### Parametrizacion I9-R06\s*$.*?(?=^### Parametrizacion I9-R07\s*$)' @(
    '(?m)^#### Parametros, Mensajes Y Pruebas I9-R06 Aprobados\s*$',
    'docs/operations/2026-08-14-i9-r06-parametros-mensajes-pruebas\.md',
    '(?is)Talento Humano.*Director de Operaciones',
    'APROBADO_FUNCIONALMENTE_NO_EJECUTABLE',
    '(?is)no activa I9-R06 ni cierra Gate 2',
    '(?is)catalogos reales I3/I5.*mapeos institucionales.*fuente/version.*implementacion TDD.*evidencia'
)
Assert-DocumentDoesNotContain $planPath @(
    '(?ms)^### Parametrizacion I9-R04\s*$(?:(?!^### ).)*^#### (?:Propuesta De )?Parametros, Mensajes Y Pruebas I9-R06'
)

$r07ProposalPath = 'docs/operations/2026-08-14-i9-r07-parametros-mensajes-pruebas.md'
Assert-DocumentContains $r07ProposalPath @(
    '(?m)^> Estado: \*\*APROBADO_FUNCIONALMENTE_NO_EJECUTABLE\*\*\s*$',
    '(?is)criterios y parametros detallados aprobados explicitamente por el usuario en esta conversacion',
    '(?is)Director de Operaciones.*SCHEDULING/APPROVE_EXCEPTION',
    '(?is)OPERATIONAL_CONTINGENCY.*URGENT_REPLACEMENT.*EXCEPTIONAL_CLIENT_REQUEST.*TEMPORARY_TEMPLATE_TRANSITION.*SPECIAL_COVERAGE.*OTHER',
    '(?is)OTHER.*exige descripcion obligatoria.*nunca sustituye la aprobacion',
    '(?is)Agrupacion controlada.*mismo\s+guarda y version.*No cubre celdas futuras.*otros guardas',
    '(?is)No reutilizacion.*cambio de guarda.*periodo.*plantilla.*version.*celda.*valor',
    '(?is)Comparacion deterministica.*ciclo, anclaje y version seleccionados',
    '(?is)programacion publicada no se modifica.*nueva version.*reprogramacion trazable',
    '(?is)I9-R07-OK.*I9-R07-DEVIATION.*I9-R07-MOTIVE.*I9-R07-OTHER.*I9-R07-PENDING.*I9-R07-REJECTED.*I9-R07-APPROVED.*I9-R07-STALE.*I9-R07-NO-TEMPLATE',
    '(?m)^\| R07-T02 \| Una celda cambia D por N \| Excepcion PENDIENTE; identifica valor esperado y propuesto \|\s*$',
    '(?is)Rol sin permiso intenta aprobar.*Acceso denegado',
    '(?is)reutilizar aprobacion para otro guarda.*Rechaza reutilizacion',
    '(?is)bloqueo absoluto R01/R03/R05.*Mantiene bloqueo absoluto',
    '(?is)Decisiones Aprobadas Funcionalmente.*Director de Operaciones es el aprobador',
    '(?is)aprobacion funcional del usuario.*no activa I9-R07.*ni cierra Gate 2.*implementacion mediante TDD'
)
Assert-PatternCount $r07ProposalPath '(?m)^\| R07-T(?:0[1-9]|1[0-9]|2[0-3]) \|' 23
Assert-DocumentDoesNotContain $r07ProposalPath @(
    '(?i)I9-R07.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado',
    '(?m)^> Estado: \*\*PROPUESTA_PARA_VALIDACION_NO_EJECUTABLE\*\*\s*$',
    '(?im)^(?!.*\bno\b).*excepcion de plantilla.*elude.*bloqueo absoluto'
)
Assert-DocumentSectionContains $planPath '(?ms)^### Parametrizacion I9-R07\s*$.*?(?=^### Apertura Subgate 2A.*$)' @(
    '(?m)^#### Propuesta De Parametros, Mensajes Y Pruebas I9-R07\s*$',
    'docs/operations/2026-08-14-i9-r07-parametros-mensajes-pruebas\.md',
    'APROBADO_FUNCIONALMENTE_NO_EJECUTABLE',
    '(?is)no activa I9-R07.*cierra Gate 2'
)

$subgate2APlanPath = 'docs/operations/2026-08-14-i9-plan-cierre-brechas-subgate2a.md'
Assert-DocumentContains $subgate2APlanPath @(
    '(?m)^> Estado: \*\*APROBADO_COMO_RUTA_NO_AUTORIZA_IMPLEMENTACION\*\*\s*$',
    '(?m)^> Aprobacion: confirmacion explicita del usuario en esta conversacion; no equivale a autorizacion de implementacion\.\s*$',
    '(?is)no completa los\s+insumos.*no presume su contenido.*no asigna fechas.*no autoriza implementar ni\s+activar reglas',
    '(?is)I9-R01.*I9-R02.*I9-R03.*I9-R04.*I9-R05.*I9-R06.*I9-R07',
    '(?m)^### WP-I9-A - Concepto Juridico R01\s*$',
    '(?m)^### WP-I9-B - Catalogos Operativos R02 Y R07\s*$',
    '(?m)^### WP-I9-C - Catalogo De Novedades R04\s*$',
    '(?m)^### WP-I9-D - Matriz De Traslados R05\s*$',
    '(?m)^### WP-I9-E - Requisitos Del Puesto R06\s*$',
    '(?is)Juridica.*Talento Humano.*Director de Operaciones',
    '(?is)Contratos versionados.*WP-I9-A a WP-I9-E.*I9-R01 e I9-R02.*I9-R03 e I9-R05.*I9-R04 e I9-R06.*I9-R07.*Regresion integral',
    '(?m)^### Checkpoint 1 - Autoridad Y Datos\s*$',
    '(?m)^### Checkpoint 2 - Contratos\s*$',
    '(?m)^### Checkpoint 3 - Reglas\s*$',
    '(?m)^### Checkpoint 4 - Gate 2\s*$',
    '(?is)Solo entonces puede proponerse el cierre de Gate 2; no es automatico',
    '(?is)Decision Registrada.*aprobo explicitamente.*cinco paquetes institucionales.*orden tecnico.*cuatro checkpoints.*no autoriza implementar ni activar reglas',
    '(?is)ninguna\s+tarea tecnica comienza sin autorizacion SDD posterior.*dependencia\s+institucional.*evidencia suficiente'
)
Assert-PatternCount $subgate2APlanPath '(?m)^### WP-I9-[A-E] - ' 5
Assert-PatternCount $subgate2APlanPath '(?m)^\| [1-6] \| ' 6
Assert-DocumentDoesNotContain $subgate2APlanPath @(
    '(?i)APROBADO_EJECUTABLE',
    '(?i)Gate 2.*(?:Cerrado|Aprobado)',
    '(?im)^> Estado: \*\*APROBADO_EJECUTABLE',
    '(?im)^(?!.*\bno\b).*autoriza (?:la )?(?:implementacion|activacion)',
    '(?i)fecha (?:compromiso|limite):\s*\d{4}-\d{2}-\d{2}'
)
Assert-DocumentContains $parameterMatrixPath @(
    'docs/operations/2026-08-14-i9-plan-cierre-brechas-subgate2a\.md',
    'APROBADO_COMO_RUTA_NO_AUTORIZA_IMPLEMENTACION',
    '(?is)no activa reglas y no\s+cierra Gate 2'
)
Assert-DocumentSectionContains $planPath '(?ms)^### Apertura Subgate 2A.*$.*?(?=^### Propuesta Juridica No Bloqueante I9-R01\s*$)' @(
    '(?m)^#### Propuesta De Cierre De Brechas Del Subgate 2A\s*$',
    'docs/operations/2026-08-14-i9-plan-cierre-brechas-subgate2a\.md',
    'APROBADO_COMO_RUTA_NO_AUTORIZA_IMPLEMENTACION',
    '(?is)no activa reglas y no\s+cierra Gate 2'
)

$wpI9ALegalFormPath = 'docs/operations/2026-08-14-i9-wp-a-formato-concepto-juridico-r01.md'
Assert-DocumentContains $wpI9ALegalFormPath @(
    '(?m)^> Estado: \*\*LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_JURIDICA_NO_EJECUTABLE\*\*\s*$',
    '(?is)no constituye concepto, firma, aprobacion ni autorizacion de implementacion',
    '(?is)Juridica verifica las fuentes oficiales.*fecha real de consulta',
    '(?is)Ley 1920 de 2018.*suin-juriscol.*Ley 2101 de 2021.*funcionpublica.*articulo 167A.*secretariasenado',
    '(?is)inclusion no certifica vigencia.*Juridica debe verificar texto, aplicabilidad.*modificaciones',
    '(?is)J-R01-01.*J-R01-02.*J-R01-03.*J-R01-04.*J-R01-05.*J-R01-06.*J-R01-07.*J-R01-08.*J-R01-09.*J-R01-10',
    '(?is)CONFIRMAR.*AJUSTAR.*RECHAZAR.*NO_APLICA_CON_FUNDAMENTO.*no anticipa ninguna decision',
    '(?is)marca de I9 no reemplaza el documento escrito ni las firmas',
    '(?is)8 horas exactas.*Mas de 8 y hasta 10 horas.*Mas de 10 y hasta 12 horas.*Mas de 12 horas.*42 horas semanales exactas.*Mas de 42 y hasta 60 horas.*Mas de 60 horas.*Acuerdo no marcado',
    '(?is)Decision global: APROBADO / APROBADO_CON_AJUSTES / NO_APROBADO / REQUIERE_INFORMACION.*PENDIENTE',
    '(?is)Checklist De Completitud.*J-R01-01 a J-R01-10.*decision global.*evidencia',
    '(?is)WP-I9-A solo puede marcarse completado.*evidencia institucional.*no activa\s+I9-R01 ni autoriza implementacion'
)
Assert-PatternCount $wpI9ALegalFormPath '(?m)^\| J-R01-(?:0[1-9]|10) \|' 10
Assert-PatternCount $wpI9ALegalFormPath '(?m)^- \[ \] ' 8
Assert-DocumentDoesNotContain $wpI9ALegalFormPath @(
    '(?i)CONCEPTO_JURIDICO_APROBADO',
    '(?i)I9-R01.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*(?:Cerrado|Aprobado)',
    '(?im)^\| Decision global:.*\|\s*(?:APROBADO|APROBADO_CON_AJUSTES|NO_APROBADO|REQUIERE_INFORMACION)\s*\|',
    '(?im)^\| (?:Nombre de quien analiza|Nombre de quien aprueba|Fecha de emision|Evidencia o ubicacion institucional) \| (?!PENDIENTE\s*\|).+$'
)
Assert-DocumentContains $subgate2APlanPath @(
    'docs/operations/2026-08-14-i9-wp-a-formato-concepto-juridico-r01\.md',
    'LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_JURIDICA_NO_EJECUTABLE',
    '(?is)preparacion no completa WP-I9-A ni autoriza implementacion'
)
Assert-DocumentContains $parameterMatrixPath @(
    'docs/operations/2026-08-14-i9-wp-a-formato-concepto-juridico-r01\.md',
    '(?is)todos los campos de decision permanecen\s+`PENDIENTE`.*no constituye concepto ni cierre de WP-I9-A'
)

$wpI9BCatalogFormPath = 'docs/operations/2026-08-14-i9-wp-b-formato-catalogos-motivos-r02-r07.md'
Assert-DocumentContains $wpI9BCatalogFormPath @(
    '(?m)^> Estado: \*\*LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_OPERACIONES_NO_EJECUTABLE\*\*\s*$',
    '(?is)no constituye catalogo institucional aprobado ni autoriza implementacion, excepciones o activacion de reglas',
    '(?is)motivos funcionales ya aprobados.*sin\s+inventar codigos institucionales',
    '(?is)OTHER.*Otro siempre exige descripcion.*nunca\s+sustituye la aprobacion del Director de Operaciones',
    '(?is)Reemplazo urgente por ausencia o incapacidad.*Continuidad temporal del servicio.*Contingencia operativa.*Emergencia o fuerza mayor.*Solicitud excepcional del cliente.*Otro - descripcion obligatoria',
    '(?is)OPERATIONAL_CONTINGENCY.*URGENT_REPLACEMENT.*EXCEPTIONAL_CLIENT_REQUEST.*TEMPORARY_TEMPLATE_TRANSITION.*SPECIAL_COVERAGE.*OTHER - descripcion obligatoria',
    '(?is)CAT-I9-B-01.*CAT-I9-B-02.*CAT-I9-B-03.*CAT-I9-B-04.*CAT-I9-B-05.*CAT-I9-B-06.*CAT-I9-B-07.*CAT-I9-B-08.*CAT-I9-B-09.*CAT-I9-B-10',
    '(?is)Decision Institucional Por Catalogo.*R02 - motivos de descanso excepcional.*R07 - motivos de desviacion de plantilla',
    '(?is)Checklist De Completitud.*seis filas R02.*seis filas R07.*CAT-I9-B-01 a CAT-I9-B-10',
    '(?is)WP-I9-B solo puede marcarse completado.*dos catalogos.*versionados, vigentes.*evidencia institucional.*no activa I9-R02 o I9-R07 ni autoriza implementacion'
)
Assert-PatternCount $wpI9BCatalogFormPath '(?m)^\| CAT-I9-B-(?:0[1-9]|10) \|' 10
Assert-PatternCount $wpI9BCatalogFormPath '(?m)^- \[ \] ' 10
Assert-DocumentDoesNotContain $wpI9BCatalogFormPath @(
    '(?i)APROBADO_EJECUTABLE',
    '(?i)Gate 2.*(?:Cerrado|Aprobado)',
    '(?im)^\| (?:R02 - motivos de descanso excepcional|R07 - motivos de desviacion de plantilla) \|\s*(?:APROBADO|APROBADO_CON_AJUSTES|NO_APROBADO|REQUIERE_INFORMACION)\s*\|',
    '(?im)^\| (?:Identificador institucional del catalogo|Version|Fecha de inicio de vigencia|Responsable de mantenimiento|Aprobador institucional) \| (?!PENDIENTE\s*\|).+$'
)
Assert-DocumentContains $subgate2APlanPath @(
    'docs/operations/2026-08-14-i9-wp-b-formato-catalogos-motivos-r02-r07\.md',
    'LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_OPERACIONES_NO_EJECUTABLE',
    '(?is)preparacion no completa WP-I9-B ni autoriza implementacion'
)
Assert-DocumentContains $parameterMatrixPath @(
    'docs/operations/2026-08-14-i9-wp-b-formato-catalogos-motivos-r02-r07\.md',
    '(?is)codigos/version/vigencia permanecen PENDIENTE'
)

$wpI9CMappingFormPath = 'docs/operations/2026-08-14-i9-wp-c-formato-catalogo-mapeo-novedades-r04.md'
Assert-DocumentContains $wpI9CMappingFormPath @(
    '(?m)^> Estado: \*\*LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_TH_OPERACIONES_NO_EJECUTABLE\*\*\s*$',
    '(?is)no constituye catalogo institucional aprobado ni autoriza implementacion, excepciones o activacion de I9-R04',
    '(?is)sin inventar codigos institucionales.*Talento Humano y Operaciones',
    '(?is)valor desconocido permanece `UNKNOWN`.*no se aproxima por texto, prefijo,\s+semejanza',
    '(?is)`D`, `N` y `X` son codigos de programacion,\s+no codigos de novedades',
    '(?is)sourceSystem.*sourceCode.*sourceStatus.*semanticCategory.*mappingVersion.*effectiveFrom.*effectiveTo.*mappedBy.*approvedBy',
    '(?is)historico simulado aprobado como referencia\s+funcional.*No son codigos oficiales.*pendientes de confirmacion institucional',
    '(?m)^\| INC \| Vigente \| INCAPACITY_ACTIVE \| PENDIENTE \| PENDIENTE \|\s*$',
    '(?m)^\| V \| Aprobada y vigente \| VACATION_APPROVED_ACTIVE \| PENDIENTE \| PENDIENTE \|\s*$',
    '(?m)^\| A \| Confirmada \| ABSENCE_CONFIRMED \| PENDIENTE \| PENDIENTE \|\s*$',
    '(?m)^\| A \| Pendiente de confirmar \| ABSENCE_PENDING_CONFIRMATION \| PENDIENTE \| PENDIENTE \|\s*$',
    '(?m)^\| TA \| Vigente \| ADDITIONAL_SHIFT \| PENDIENTE \| PENDIENTE \|\s*$',
    '(?is)una sola version activa sin solapamientos.*fronteras con\s+I3/I5.*Talento Humano y Operaciones registraron su aprobacion',
    '(?is)I9-R04 permanece no ejecutable.*Gate 2 sigue\s+bloqueado'
)
Assert-PatternCount $wpI9CMappingFormPath '(?m)^\| (?:INCAPACITY_ACTIVE|VACATION_APPROVED_ACTIVE|LEAVE_OR_CALAMITY_ACTIVE|SUSPENSION_OR_TERMINATION_ACTIVE|ABSENCE_CONFIRMED|ABSENCE_PENDING_CONFIRMATION|TRAINING_OR_INDUCTION_OVERLAP|AVAILABLE|ADDITIONAL_SHIFT|ADMINISTRATIVE_EVENT|EXPIRED_OR_CANCELLED|UNKNOWN) \|' 12
Assert-PatternCount $wpI9CMappingFormPath '(?m)^\d+\. `CAT-I9-C-(?:0[1-9]|1[0-2])`:' 12
Assert-PatternCount $wpI9CMappingFormPath '(?m)^- \[ \] ' 12
Assert-DocumentDoesNotContain $wpI9CMappingFormPath @(
    '(?i)I9-R04.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado',
    '(?im)^\| (?:Talento Humano|Operaciones) \| (?!PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \|).+$',
    '(?im)^\| (?:INC|V|A|TA) \|.*\| (?:APROBADO|CONFIRMADO) \|'
)
Assert-DocumentContains $subgate2APlanPath @(
    'docs/operations/2026-08-14-i9-wp-c-formato-catalogo-mapeo-novedades-r04\.md',
    'LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_TH_OPERACIONES_NO_EJECUTABLE',
    '(?is)codigos reales, versiones, vigencias y decisiones permanecen `PENDIENTE`.*preparacion no completa WP-I9-C ni autoriza implementacion'
)
Assert-DocumentContains $parameterMatrixPath @(
    'docs/operations/2026-08-14-i9-wp-c-formato-catalogo-mapeo-novedades-r04\.md',
    '(?is)codigos reales, version, vigencia y decisiones permanecen PENDIENTE'
)

$wpI9DTransferMatrixPath = 'docs/operations/2026-08-14-i9-wp-d-formato-matriz-traslados-r05.md'
Assert-DocumentContains $wpI9DTransferMatrixPath @(
    '(?m)^> Estado: \*\*LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_OPERACIONES_NO_EJECUTABLE\*\*\s*$',
    '(?is)no constituye matriz institucional aprobada ni autoriza implementacion, excepciones o activacion de I9-R05',
    '(?is)sin inventar proyectos, contratos, puestos,\s+tiempos ni restricciones',
    '(?is)cada fila representa un solo sentido: `A -> B` y `B -> A` son\s+relaciones independientes',
    '(?is)minutos enteros no negativos.*relacion ausente\s+nunca se interpreta como cero',
    '(?is)cero minutos por\s+identidad.*mismo puesto exacto.*puestos diferentes.*requieren una fila explicita',
    '(?is)projectOrContractId.*originPositionId.*destinationPositionId.*requiredMinutes.*prohibited.*restrictionSource.*matrixVersion.*effectiveFrom.*effectiveTo.*recordedBy',
    '(?is)Fila existente.*Evalua la frontera configurada.*Fila ausente.*Excepcion PENDIENTE; nunca usa cero.*Combinacion prohibida.*Bloqueo absoluto sin excepcion',
    '(?is)Director de Operaciones registro su\s+aprobacion con evidencia.*I9-R05 permanece no ejecutable.*Gate 2 sigue bloqueado'
)
Assert-PatternCount $wpI9DTransferMatrixPath '(?m)^\d+\. `MAT-I9-D-(?:0[1-9]|1[0-2])`:' 12
Assert-PatternCount $wpI9DTransferMatrixPath '(?m)^- \[ \] ' 12
Assert-PatternCount $wpI9DTransferMatrixPath '(?m)^\| (?:Fila existente|Fila ausente|Combinacion prohibida) \|' 3
Assert-DocumentDoesNotContain $wpI9DTransferMatrixPath @(
    '(?i)I9-R05.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado',
    '(?im)^\| Director de Operaciones \| (?!PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \|).+$',
    '(?im)^\| (?!PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \| PENDIENTE \|).+\|\s*\d+\s*\|\s*(?:SI|NO)\s*\|'
)
Assert-DocumentContains $subgate2APlanPath @(
    'docs/operations/2026-08-14-i9-wp-d-formato-matriz-traslados-r05\.md',
    'LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_OPERACIONES_NO_EJECUTABLE',
    '(?is)proyectos, puestos, tiempos, prohibiciones, version, vigencia y decision\s+permanecen `PENDIENTE`.*preparacion no completa WP-I9-D ni autoriza\s+implementacion'
)
Assert-DocumentContains $parameterMatrixPath @(
    'docs/operations/2026-08-14-i9-wp-d-formato-matriz-traslados-r05\.md',
    '(?is)proyectos, puestos, tiempos, prohibiciones, version, vigencia y decision permanecen PENDIENTE'
)

$wpI9EPositionRequirementsPath = 'docs/operations/2026-08-14-i9-wp-e-formato-requisitos-puesto-r06.md'
$wpI9EControlSection = '(?ms)^## Estado Y Decision De Control\s*$.*?(?=^## Identificacion Y Gobierno Del Catalogo\s*$)'
$wpI9EContractSection = '(?ms)^## Contrato De Integracion I3/I5\s*$.*?(?=^## Evaluaciones Individuales I3/I5\s*$)'
$wpI9EEvaluationSection = '(?ms)^## Evaluaciones Individuales I3/I5\s*$.*?(?=^## Categorias Canonicas Y Cobertura\s*$)'
$wpI9EMappingSection = '(?ms)^## Tabla De Mapeo Institucional\s*$.*?(?=^## Configuracion De Subsanabilidad\s*$)'
$wpI9ERemediationSection = '(?ms)^## Configuracion De Subsanabilidad\s*$.*?(?=^## Dataset Anonimo De Validacion\s*$)'
$wpI9EDatasetSection = '(?ms)^## Dataset Anonimo De Validacion\s*$.*?(?=^## Reglas De Integridad Y Seguridad\s*$)'
$wpI9EDecisionSection = '(?ms)^## Decision Institucional\s*$.*?(?=^## Checklist De Cierre WP-I9-E\s*$)'
$wpI9EExitSection = '(?ms)^## Criterio De Salida\s*$.*\z'
$wpI9EEvaluationPopulatedRowPattern = '(?m)^\|(?!\s*(?:evaluationId|---)\s*\|)(?!\s*PENDIENTE(?:\s*\|\s*PENDIENTE){11}\s*\|\s*$)(?:[^|\r\n]*\|){12}\s*$'
$wpI9EEvaluationMissingEmployeeIdPattern = '(?m)^\|\s*[^|\r\n]+\|\s*\|(?:[^|\r\n]*\|){10}\s*$'
$wpI9EMappingPopulatedRowPattern = '(?m)^\|(?!\s*(?:mappingId|---)\s*\|)(?!\s*PENDIENTE(?:\s*\|\s*PENDIENTE){19}\s*\|\s*$)(?:[^|\r\n]*\|){20}\s*$'
$wpI9EDatasetMissingEmployeeIdPattern = '(?m)^\|\s*(?:Requisito vigente|Requisito faltante|Requisito vencido|Codigo o estado desconocido|Subsanable informativo)\s*\|\s*\|'
$wpI9EContractHeaderPattern = '(?m)^\| Sistema fuente \| Version del contrato \| Interfaz o ruta \| sourceEmployeeKeyField \| Identificador de puesto \| Codigo de requisito \| Estado \| Evidencia \| Vigencia \| Responsable tecnico \| Evidencia del contrato \|\s*$'
$wpI9EContractPopulatedRowPattern = '(?m)^\|(?!\s*(?:Sistema fuente|---)\s*\|)(?!\s*PENDIENTE(?:\s*\|\s*PENDIENTE){10}\s*\|\s*$)(?:[^|\r\n]*\|){11}\s*$'
$wpI9EContractPiiEmployeeKeyPattern = '(?im)^\|(?:[^|\r\n]*\|){3}\s*(?:(?:source|employee|empleado)?[\s_.-]*(?:numero[\s_.-]*documento|documento(?:[\s_.-]*identidad)?|nombre(?:[\s_.-]*completo)?|correo(?:[\s_.-]*electronico)?|e[\s_.-]*mail|telefono|celular))\s*\|'
$wpI9EDecisionPopulatedRolePattern = '(?m)^\|\s*(?:Talento Humano|Director de Operaciones)\s*\|(?!\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*$).+$'
$wpI9EControlRequiredPatterns = @(
    '(?m)^\| TECHNICAL_IMPLEMENTATION_AUTHORIZED \| NO \|\s*$',
    '(?m)^\| I9_R06_ACTIVE \| NO \|\s*$',
    '(?m)^\| TASK_13_STATUS \| OPEN \|\s*$',
    '(?m)^\| GATE_2_STATUS \| BLOCKED \|\s*$'
)
$wpI9ELogControlRequiredPatterns = @(
    'TECHNICAL_IMPLEMENTATION_AUTHORIZED=NO',
    'I9_R06_ACTIVE=NO',
    'TASK_13_STATUS=OPEN',
    'GATE_2_STATUS=BLOCKED'
)
$wpI9ESemanticContradictionPatterns = @(
    '(?is)\bI9-R06\b\s+autoriza\s+(?:la\s+)?implementacion\s+tecnica\b',
    '(?is)\bimplementacion\s+tecnica\s+de\s+\bI9-R06\b\s+queda\s+autorizada\b',
    '(?is)\bI9-R06\b\s+queda\s+autorizado\s+para\s+la\s+implementacion\s+tecnica\b',
    '(?is)\bautorizacion\s+para\s+la\s+implementacion\s+tecnica\s+de\s+\bI9-R06\b',
    '(?is)\bI9-R06\b\s+(?:se\s+)?activa\b',
    '(?is)\bse\s+activa\s+\bI9-R06\b',
    '(?is)\bI9-R06\b\s+puede\s+activarse\s+ahora\b',
    '(?is)\bI9-R06\b\s+se\s+debe\s+activar\b',
    '(?is)\bI9-R06\b\s+queda\s+(?:activada|habilitada)\b',
    '(?is)\bTask 13\b\s+(?:se\s+)?cierra\b',
    '(?is)\bse\s+cierra\s+\bTask 13\b',
    '(?is)\bTask 13\b\s+queda\s+(?:cerrada|completada)\b',
    '(?is)\bTask 13\b\s+se\s+completa\b',
    '(?is)\bGate 2\b\s+(?:queda\s+)?(?:cerrado|cerrada|aprobado|aprobada)\b'
)
Assert-DocumentContains $wpI9EPositionRequirementsPath @(
    '(?m)^> Estado: \*\*LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_TH_OPERACIONES_NO_EJECUTABLE\*\*\s*$',
    '(?is)no constituye catalogo institucional aprobado ni autoriza implementacion, excepciones o activacion de I9-R06',
    '(?is)sin inventar codigos, estados, evidencias,\s+vigencias, responsables nominales ni fechas limite',
    '(?is)Talento Humano valida.*Director de Operaciones aprueba la excepcion operativa',
    '(?is)ausencia de informacion nunca acredita\s+cumplimiento.*codigo o estado\s+desconocido permanece `UNVERIFIED`',
    '(?is)COURSE.*ACCREDITATION.*CERTIFICATION.*LICENSE_OR_PERMIT.*OTHER_REQUIREMENT'
)
Assert-DocumentSectionContains $wpI9EPositionRequirementsPath $wpI9EControlSection $wpI9EControlRequiredPatterns
Assert-DocumentSectionContains $wpI9EPositionRequirementsPath $wpI9EContractSection @(
    '(?is)una fila por sistema y version de contrato.*interfaz,\s+ruta o campo no documentado.*`PENDIENTE`',
    '(?is)contrato debe exponer los campos.*registro individual',
    '(?is)`sourceEmployeeKeyField` identifica el nombre del campo fuente.*obtener o resolver el `employeeId` no nominal de I2.*permanece\s+`PENDIENTE`.*no puede reemplazarse por nombre, numero de documento, correo,\s+telefono ni otro dato personal',
    $wpI9EContractHeaderPattern,
    '(?m)^\| PENDIENTE(?: \| PENDIENTE){10} \|\s*$'
)
Assert-DocumentSectionContains $wpI9EPositionRequirementsPath $wpI9EEvaluationSection @(
    '(?is)clave\s+propia `evaluationId`.*`employeeId` es la referencia no nominal de I2.*no contiene nombre, documento\s+de identidad ni otro dato personal',
    '(?is)vincula empleado, requisito,\s+puesto o alcance, evidencia, vigencia y snapshot.*sin modificar el mapeo\s+canonico',
    '(?m)^\| evaluationId \| employeeId \| sourceSystem \| sourceRequirementCode \| sourceStatus \| positionOrScopeId \| evidenceType \| evidenceReference \| effectiveFrom \| effectiveTo \| snapshotVersion \| evaluatedAt \|\s*$',
    '(?m)^\| PENDIENTE(?: \| PENDIENTE){11} \|\s*$'
)
Assert-DocumentSectionContains $wpI9EPositionRequirementsPath $wpI9EMappingSection @(
    '(?is)cada fila\s+conserva su trazabilidad completa y un identificador unico',
    '(?is)sistema, codigo, estado, alcance y\s+periodo.*sin depender de un empleado',
    '(?is)mappingId.*sourceSystem.*sourceRequirementCode.*sourceStatus.*canonicalCategory.*mappingVersion.*effectiveFrom.*effectiveTo.*evidenceType.*verifiedBy.*validationDate.*approvedBy.*approvalDate.*mappingEvidence',
    '(?m)^\| mappingId \| sourceSystem \| sourceRequirementCode \| sourceStatus \| canonicalCategory \| requirementName \| positionOrScopeId \| evidenceType \| evidenceStatus \| effectiveFrom \| effectiveTo \| mappingVersion \| subsanable \| remediationOwner \| remediationDeadline \| verifiedBy \| validationDate \| approvedBy \| approvalDate \| mappingEvidence \|\s*$'
)
Assert-DocumentSectionContains $wpI9EPositionRequirementsPath $wpI9ERemediationSection @(
    '(?is)`subsanable` requiere configuracion explicita y versionada.*responsable de subsanacion y la fecha limite.*ausencia invalida la configuracion',
    '(?m)^\| Codigo real \| Estado real \| Subsanable \| Tratamiento autorizado \| Responsable de subsanacion \| Fecha limite \| Fuente \| Version \| Validacion TH \|\s*$',
    '(?m)^\| PENDIENTE(?: \| PENDIENTE){8} \|\s*$'
)
Assert-DocumentSectionContains $wpI9EPositionRequirementsPath $wpI9EDatasetSection @(
    '(?is)`employeeId` anonimo.*no incluir datos personales ni\s+evidencia sensible.*correlaciona requisito y guarda sin registrar su\s+nombre o documento',
    '(?m)^\| Caso requerido \| employeeId anonimo \| Codigo/estado anonimo \| Evidencia/vigencia anonima \| Configuracion de subsanabilidad \| Resultado esperado \| Evidencia \|\s*$',
    '(?is)Requisito vigente.*COMPLIANT.*Requisito faltante.*MISSING.*Requisito vencido.*EXPIRED.*Codigo o estado desconocido.*UNVERIFIED.*Subsanable informativo.*INFORMATIVE_REMEDIABLE'
)
Assert-DocumentSectionContains $wpI9EPositionRequirementsPath $wpI9EDecisionSection @(
    '(?m)^\|\s*Talento Humano\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*$',
    '(?m)^\|\s*Director de Operaciones\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*PENDIENTE\s*\|\s*$'
)
Assert-DocumentSectionContains $wpI9EPositionRequirementsPath $wpI9EExitSection @(
    '(?is)WP-I9-E solo puede proponerse como completo.*catalogos reales I3/I5.*contrato de integracion.*Talento Humano.*Director de Operaciones',
    '(?is)I9-R06 permanece no ejecutable.*Gate 2 sigue bloqueado'
)
Assert-PatternCount $wpI9EPositionRequirementsPath '(?m)^\d+\. `REQ-I9-E-(?:0[1-9]|1[0-2])`:' 12
Assert-PatternCount $wpI9EPositionRequirementsPath '(?m)^- \[ \] ' 12
Assert-DocumentSectionPatternCount $wpI9EPositionRequirementsPath $wpI9EDatasetSection '(?m)^\| (?:Requisito vigente|Requisito faltante|Requisito vencido|Codigo o estado desconocido|Subsanable informativo) \|' 5
Assert-DocumentSectionPatternCount $wpI9EPositionRequirementsPath $wpI9EContractSection '(?m)^\|\s*PENDIENTE(?:\s*\|\s*PENDIENTE){10}\s*\|\s*$' 1
Assert-DocumentSectionPatternCount $wpI9EPositionRequirementsPath $wpI9EEvaluationSection '(?m)^\|\s*PENDIENTE(?:\s*\|\s*PENDIENTE){11}\s*\|\s*$' 1
Assert-DocumentSectionPatternCount $wpI9EPositionRequirementsPath $wpI9EMappingSection '(?m)^\|\s*PENDIENTE(?:\s*\|\s*PENDIENTE){19}\s*\|\s*$' 1
Assert-DocumentSectionDoesNotContain $wpI9EPositionRequirementsPath $wpI9EContractSection @(
    $wpI9EContractPopulatedRowPattern,
    $wpI9EContractPiiEmployeeKeyPattern
)
Assert-DocumentSectionDoesNotContain $wpI9EPositionRequirementsPath $wpI9EEvaluationSection @(
    $wpI9EEvaluationPopulatedRowPattern,
    $wpI9EEvaluationMissingEmployeeIdPattern
)
Assert-DocumentSectionDoesNotContain $wpI9EPositionRequirementsPath $wpI9EMappingSection @(
    '(?i)\bemployeeId\b',
    $wpI9EMappingPopulatedRowPattern
)
Assert-DocumentSectionDoesNotContain $wpI9EPositionRequirementsPath $wpI9EDatasetSection @(
    $wpI9EDatasetMissingEmployeeIdPattern
)
Assert-DocumentSectionDoesNotContain $wpI9EPositionRequirementsPath $wpI9EDecisionSection @(
    $wpI9EDecisionPopulatedRolePattern
)
Assert-DocumentDoesNotContain $wpI9EPositionRequirementsPath (@(
    '(?i)I9-R06.*APROBADA_EJECUTABLE',
    '(?i)Gate 2.*Cerrado'
) + $wpI9ESemanticContradictionPatterns)
Assert-DocumentContains $subgate2APlanPath @(
    'docs/operations/2026-08-14-i9-wp-e-formato-requisitos-puesto-r06\.md',
    'LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_TH_OPERACIONES_NO_EJECUTABLE',
    '(?is)codigos, categorias, estados, evidencias, vigencias, subsanabilidad,\s+responsables y fechas limite permanecen `PENDIENTE`.*preparacion no completa WP-I9-E ni autoriza implementacion'
)
Assert-DocumentContains $parameterMatrixPath @(
    'docs/operations/2026-08-14-i9-wp-e-formato-requisitos-puesto-r06\.md',
    '(?is)codigos, categorias, estados, evidencia, vigencias, subsanabilidad, responsables y fechas limite permanecen PENDIENTE'
)
Assert-DocumentSectionContains $planPath '(?ms)^### Parametrizacion I9-R06\s*$.*?(?=^### Parametrizacion I9-R07\s*$)' (@(
    '(?m)^#### Formato Institucional WP-I9-E Preparado\s*$',
    'docs/operations/2026-08-14-i9-wp-e-formato-requisitos-puesto-r06\.md',
    'LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_TH_OPERACIONES_NO_EJECUTABLE',
    '(?is)Task 13.*continua abierta.*Gate 2.*continua bloqueado',
    '(?is)no completa WP-I9-E.*no\s+autoriza implementacion'
) + $wpI9ELogControlRequiredPatterns)
Assert-DocumentSectionDoesNotContain $planPath '(?ms)^### Parametrizacion I9-R06\s*$.*?(?=^### Parametrizacion I9-R07\s*$)' $wpI9ESemanticContradictionPatterns

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

# --- MVP closure evidence ------------------------------------------------------------------------
# The closure report must keep saying what is not done. A report that lost its open points, or that
# declared the MVP closed on its own, would be the document quietly outrunning the work.
$closurePath = Join-Path $repoRoot 'docs/reports/2026-08-17-sg-superapp-i9-mvp-closure.md'
if (-not (Test-Path -LiteralPath $closurePath)) {
    $failures.Add('docs/reports/2026-08-17-sg-superapp-i9-mvp-closure.md is missing')
} else {
    $closure = Get-Content -LiteralPath $closurePath -Raw
    foreach ($required in @(
        @{ Label = 'states it does not close the MVP'; Pattern = 'Este documento no cierra el MVP' },
        @{ Label = 'keeps the open points'; Pattern = '(?s)## 4\. Puntos abiertos' },
        @{ Label = 'leaves closure to the user'; Pattern = 'autorizaci(o|ó)n expl(i|í)cita del usuario' },
        @{ Label = 'keeps the simulated scope explicit'; Pattern = 'SIMULATED.*MVP_TEST' },
        @{ Label = 'states the production limit'; Pattern = 'no afirma pol(i|í)tica institucional ni opera en producci(o|ó)n' },
        @{ Label = 'records the executed verifiers'; Pattern = 'I9 MVP RULES PASS' },
        @{ Label = 'marks the review debt'; Pattern = 'sin revisi(o|ó)n independiente' })) {
        if ($closure -notmatch $required.Pattern) {
            $failures.Add("MVP closure report no longer $($required.Label)")
        }
    }
    # The gate row for the user's authorisation may not be ticked by a document. The first version
    # of this looked for 'Sí' straight after the pipe, which the table's own house style defeats -
    # every other verdict in it is bolded, so '**Sí**' sailed through. It now requires the value to
    # be Pendiente, with or without emphasis, which no edit can satisfy while claiming otherwise.
    $authorisationRow = [regex]::Match($closure, '(?m)^\|\s*El usuario autoriza expl(i|í)citamente el cierre\s*\|([^|]*)\|')
    if (-not $authorisationRow.Success) {
        $failures.Add('MVP closure report no longer carries the user authorisation row')
    } elseif ($authorisationRow.Groups[2].Value -notmatch '^\s*\*{0,2}Pendiente\*{0,2}\s*$') {
        $failures.Add('MVP closure report does not leave the user authorisation Pendiente; only the user can grant it')
    }

    # Keeping the heading while emptying the section passed too, so the items are counted. The
    # comparison used to be -lt 7, which is a floor and not a count: an independent review deleted
    # the two points that the reviews had just proved were missing, renumbered, and this stayed
    # green because eight minus two is still above seven. Points can be dropped without being
    # resolved under a floor. The number is now pinned, so resolving one is a change to the report
    # AND to this line, deliberately, and both show up in the same diff.
    $expectedOpenItems = 10
    $openSection = [regex]::Match($closure, '(?s)## 4\. Puntos abiertos.*?(?=\n## )')
    $openItems = if ($openSection.Success) { ([regex]::Matches($openSection.Value, '(?m)^\d+\.\s')).Count } else { 0 }
    if ($openItems -ne $expectedOpenItems) {
        $failures.Add("MVP closure report lists $openItems open points; this gate is pinned to $expectedOpenItems. Resolving or adding one means changing both.")
    }

    # A document may not declare the closure it exists to withhold.
    if ($closure -match '(?i)(el MVP queda cerrado|MVP cerrado y autorizado|autorizaci(o|ó)n del usuario fue otorgada)') {
        $failures.Add('MVP closure report declares the MVP closed; that is the user decision, not the document')
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'I9 DOCS FAIL'
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host 'I9 DOCS PASS'
