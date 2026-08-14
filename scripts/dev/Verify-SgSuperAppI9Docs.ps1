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
