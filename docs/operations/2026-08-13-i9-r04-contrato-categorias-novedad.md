# I9-R04 - Contrato Interno De Categorias De Novedad

> Estado: **APROBADO_FUNCIONALMENTE_NO_EJECUTABLE**
> Fecha: 2026-08-13
> Evidencia: aprobacion explicita del usuario en esta conversacion.

## Proposito

Desacoplar el motor I9 de los codigos externos de novedades. Los sistemas fuente
pueden cambiar sus codigos sin modificar la semantica del motor, siempre que el
mapeo sea versionado, validado en la frontera de entrada y aprobado.

Este contrato no inventa codigos institucionales ni activa I9-R04. Solo define
las categorias internas estables ya aprobadas funcionalmente.

## Categorias Canonicas

| Identificador interno | Categoria funcional | Tratamiento base |
|---|---|---|
| INCAPACITY_ACTIVE | Incapacidad vigente | Bloqueo absoluto |
| VACATION_APPROVED_ACTIVE | Vacaciones aprobadas y vigentes | Bloqueo absoluto |
| LEAVE_OR_CALAMITY_ACTIVE | Licencia o calamidad vigente | Bloqueo absoluto |
| SUSPENSION_OR_TERMINATION_ACTIVE | Suspension o retiro vigente | Bloqueo absoluto |
| ABSENCE_CONFIRMED | Ausencia confirmada | Bloqueo absoluto |
| ABSENCE_PENDING_CONFIRMATION | Ausencia pendiente de confirmar | Excepcion pendiente |
| TRAINING_OR_INDUCTION_OVERLAP | Capacitacion o induccion coincidente | Excepcion pendiente |
| AVAILABLE | Disponible | No bloquea; puede mejorar prioridad |
| ADDITIONAL_SHIFT | Turno adicional | Excepcion pendiente sujeta a I9-R01/I9-R02 |
| ADMINISTRATIVE_EVENT | Novedad administrativa | Informativa salvo indisponibilidad formal |
| EXPIRED_OR_CANCELLED | Novedad vencida o anulada | Sin efecto |
| UNKNOWN | Codigo o estado no mapeado | Advertencia; no infiere disponibilidad ni bloqueo |

Los identificadores son `UPPER_SNAKE_CASE`, no contienen significado del sistema
fuente y no se reutilizan para otra categoria. Nuevas categorias se agregan sin
cambiar el significado de las existentes; una retirada exige deprecacion y
migracion explicitas.

## Contrato De Mapeo En La Frontera

Cada entrada externa se valida antes de llegar al motor y conserva:

| Campo | Obligatorio | Regla |
|---|---|---|
| sourceSystem | Si | Identifica el sistema fuente |
| sourceCode | Si | Codigo original sin reinterpretarlo |
| sourceStatus | Si | Estado original usado para distinguir, por ejemplo, ausencia confirmada o pendiente |
| semanticCategory | Si | Uno de los identificadores internos; `UNKNOWN` si no existe mapeo aprobado |
| mappingVersion | Si | Version unica activa del catalogo |
| effectiveFrom | Si | Inicio de vigencia del mapeo |
| effectiveTo | No | Fin de vigencia; nulo mientras este activo |
| mappedBy | Si | Responsable que registro el mapeo |
| approvedBy | Si | Responsable que aprobo el mapeo |

No se acepta un codigo vacio, una categoria fuera del catalogo ni dos mapeos
activos para la misma combinacion `sourceSystem + sourceCode + sourceStatus`.
Un valor desconocido siempre se transforma en `UNKNOWN`; nunca se aproxima por
texto, prefijo o semejanza.

## Mapeo Inicial Aprobado

| Codigo fuente visible | Estado fuente requerido | Categoria interna |
|---|---|---|
| INC | Vigente | INCAPACITY_ACTIVE |
| V | Aprobada y vigente | VACATION_APPROVED_ACTIVE |
| A | Confirmada | ABSENCE_CONFIRMED |
| A | Pendiente de confirmar | ABSENCE_PENDING_CONFIRMATION |
| TA | Vigente | ADDITIONAL_SHIFT |

`D`, `N` y `X` no ingresan a este contrato porque son codigos de programacion y
no novedades. Los codigos institucionales de las demas categorias permanecen
`PENDIENTE`; no se generan equivalencias automaticas.

## Versionado Y Auditoria

- Solo existe una version activa del mapeo para cada sistema fuente.
- Una nueva version no modifica evaluaciones historicas; cada snapshot conserva
  codigo, estado, categoria y version aplicados.
- Cambiar un mapeo exige responsable, aprobador, motivo, fecha y vigencia.
- El Director de Operaciones aprueba las excepciones de programacion; la
  aprobacion del catalogo de mapeo requiere validacion de Talento Humano y
  Operaciones.

## Condicion De Activacion

El contrato permanece no ejecutable hasta cargar y validar los codigos reales,
aprobar la version institucional, implementar validacion de frontera y ejecutar
pruebas positivas y negativas. Gate 2 continua abierto.
