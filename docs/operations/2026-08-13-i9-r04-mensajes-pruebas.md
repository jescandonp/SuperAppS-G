# I9-R04 - Mensajes Y Casos De Prueba

> Estado: **APROBADO_FUNCIONALMENTE_NO_EJECUTABLE**
> Fecha: 2026-08-13
> Regla: novedades e indisponibilidades del guarda.
> Evidencia: aprobacion explicita del usuario en esta conversacion.

## Mensajes Funcionales Propuestos

| Codigo | Condicion | Severidad | Mensaje al usuario | Accion disponible |
|---|---|---|---|---|
| I9-R04-OK | Sin novedad vigente que afecte | CUMPLE | No se encontraron novedades vigentes que impidan esta asignacion. | Continuar |
| I9-R04-BLOCK | Categoria de bloqueo vigente | BLOQUEO_ABSOLUTO | El guarda tiene una novedad vigente incompatible con el turno. Reprograma la asignacion. | Ver novedad / Reprogramar |
| I9-R04-EXCEPTION | Categoria que admite excepcion | EXCEPCION_PENDIENTE | La novedad permite generar la propuesta, pero requiere motivo y aprobacion del Director de Operaciones antes de aprobar o publicar. | Registrar motivo / Enviar a aprobacion |
| I9-R04-INFO | Novedad informativa | INFORMATIVA | Existe una novedad informativa que no bloquea esta propuesta. | Ver detalle / Continuar |
| I9-R04-UNKNOWN | Codigo o estado no mapeado | ADVERTENCIA | La novedad no tiene un mapeo aprobado. No se asumira disponibilidad ni bloqueo; valida el catalogo institucional. | Revisar mapeo |
| I9-R04-INCOMPLETE | Novedad sin vigencia completa | ADVERTENCIA | La novedad no tiene inicio, fin o estado suficientes para decidir automaticamente. | Completar datos |
| I9-R04-PENDING | Excepcion enviada | EXCEPCION_PENDIENTE | La excepcion por novedad esta pendiente de decision del Director de Operaciones. | Consultar estado |
| I9-R04-REJECTED | Excepcion rechazada | REPROGRAMACION_REQUERIDA | La excepcion fue rechazada. Reprograma antes de aprobar o publicar. | Reprogramar |
| I9-R04-APPROVED | Excepcion aprobada | EXCEPCION_APROBADA | Excepcion aprobada exclusivamente para esta novedad, turno y vigencia. | Continuar flujo |

El detalle explicable muestra codigo y estado originales, categoria interna,
vigencia, fuente, version del mapeo, tratamiento aplicado y decision, respetando
los permisos de consulta.

## Casos De Prueba Propuestos

| Caso | Preparacion | Resultado esperado |
|---|---|---|
| R04-T01 | INC vigente durante todo el turno | Bloqueo absoluto con INCAPACITY_ACTIVE |
| R04-T02 | V aprobada y vigente durante parte del turno | Bloqueo absoluto con VACATION_APPROVED_ACTIVE |
| R04-T03 | A con estado Confirmada | Bloqueo absoluto con ABSENCE_CONFIRMED |
| R04-T04 | A con estado Pendiente de confirmar | Genera excepcion PENDIENTE; no permite aprobar/publicar |
| R04-T05 | TA vigente | Genera excepcion y evalua adicionalmente I9-R01 e I9-R02 |
| R04-T06 | Licencia/calamidad con codigo institucional aun no mapeado | UNKNOWN y advertencia; no infiere bloqueo |
| R04-T07 | Capacitacion/induccion mapeada y coincidente | Excepcion PENDIENTE |
| R04-T08 | AVAILABLE vigente | No bloquea y puede mejorar prioridad |
| R04-T09 | ADMINISTRATIVE_EVENT sin indisponibilidad formal | Informativa; no bloquea |
| R04-T10 | ADMINISTRATIVE_EVENT con indisponibilidad formal aprobada | Aplica la categoria de indisponibilidad mapeada; no decide por texto libre |
| R04-T11 | EXPIRED_OR_CANCELLED | Sin efecto sobre la asignacion |
| R04-T12 | Codigo desconocido parecido a INC | UNKNOWN; no aproxima por texto, prefijo o semejanza |
| R04-T13 | D, N o X recibido como supuesto codigo de novedad | Rechaza entrada al contrato de novedades; son codigos de programacion |
| R04-T14 | Novedad sin fecha de inicio | Advertencia I9-R04-INCOMPLETE; no bloquea automaticamente |
| R04-T15 | Novedad sin fecha final cuando el tipo exige fin | Advertencia; solicita completar datos |
| R04-T16 | Novedad anulada que antes bloqueaba | EXPIRED_OR_CANCELLED; no conserva bloqueo historico en la nueva evaluacion |
| R04-T17 | Coinciden bloqueo, excepcion e informativa | Prevalece bloqueo absoluto |
| R04-T18 | Coinciden excepcion e informativa sin bloqueo | Prevalece excepcion PENDIENTE |
| R04-T19 | Rol distinto al Director de Operaciones intenta aprobar | Acceso denegado y evento auditado |
| R04-T20 | Director de Operaciones aprueba excepcion | Registra motivo, novedad, turno, vigencia, decision y auditoria |
| R04-T21 | Se intenta reutilizar aprobacion en otra novedad o turno | Rechaza reutilizacion y crea nueva excepcion PENDIENTE |
| R04-T22 | Cambia mappingVersion despues de aprobar la programacion | Snapshot historico conserva codigo, estado, categoria y version originales |
| R04-T23 | Dos mapeos activos para mismo sistema/codigo/estado | Rechaza configuracion ambigua antes de evaluar |
| R04-T24 | Regla desactivada durante desarrollo | No decide cumplimiento productivo; identifica modo no ejecutable |

## Prioridad De Decisiones

1. `BLOQUEO_ABSOLUTO` prevalece y no admite excepcion.
2. `EXCEPCION_PENDIENTE` prevalece sobre informacion y exige aprobacion.
3. `ADVERTENCIA` obliga a revisar datos o mapeo sin inferir un resultado.
4. `INFORMATIVA` no bloquea.
5. `SIN_EFECTO` no altera la propuesta.

Una aprobacion de excepcion nunca elude un bloqueo absoluto de I9-R01, I9-R03
o de otra categoria vigente de I9-R04.

## Evidencia Por Evaluacion

- identificador del guarda, turno y proyecto;
- codigo, estado y sistema fuente originales;
- categoria interna y tratamiento;
- inicio, fin y resultado de vigencia;
- version del mapeo;
- motivo, aprobador, fecha, vigencia y decision cuando exista excepcion;
- reglas relacionadas I9-R01/I9-R02/I9-R03; y
- correlacion de auditoria.

## Condicion De Aprobacion

Este artefacto no activa I9-R04. Los mensajes y casos tienen aprobacion
funcional del usuario; requieren implementacion posterior mediante TDD, carga
del catalogo institucional, ejecucion satisfactoria y evidencia institucional
antes de proponer la regla como ejecutable.
