# I9-R03 - Mensajes Y Casos De Prueba

> Estado: **APROBADO_FUNCIONALMENTE_NO_EJECUTABLE**
> Fecha: 2026-08-13
> Regla: cruces temporales del mismo guarda.
> Evidencia: aprobacion explicita del usuario en esta conversacion.

## Mensajes Funcionales Propuestos

| Codigo | Condicion | Severidad | Mensaje al usuario | Accion disponible |
|---|---|---|---|---|
| I9-R03-OK | Sin solapamiento | CUMPLE | No se encontraron cruces de horario para el guarda. | Continuar |
| I9-R03-ADJACENT | Frontera fin/inicio compartida | CUMPLE_CON_VALIDACIONES | Los turnos son adyacentes y no se solapan. Se evaluaran descanso y traslado. | Continuar validaciones |
| I9-R03-BLOCK | Solapamiento real | BLOQUEO_ABSOLUTO | El guarda ya tiene un turno que coincide con este horario. Ajusta la asignacion; este cruce no admite excepcion. | Ver conflicto / Reprogramar |
| I9-R03-APPROVED | Conflicto con programacion aprobada | BLOQUEO_ABSOLUTO | La asignacion se cruza con una programacion aprobada del guarda y no puede guardarse. | Ver programacion / Reprogramar |
| I9-R03-DRAFT | Conflicto con borrador vigente | BLOQUEO_ABSOLUTO | La asignacion se cruza con otro borrador vigente del guarda. | Ver borrador / Reprogramar |
| I9-R03-TRANSFER | Sin cruce y puestos distintos | VALIDACION_ADICIONAL | No hay solapamiento. I9-R05 debe validar el tiempo de traslado entre puestos. | Evaluar traslado |
| I9-R03-EDIT | Edicion manual crea cruce | BLOQUEO_ABSOLUTO | El cambio manual produce un cruce de horario y no puede guardarse. | Deshacer / Reprogramar |

El detalle explicable muestra los dos intervalos, puestos, proyectos, estado de
la programacion y regla/version aplicada, respetando los permisos de consulta.

## Casos De Prueba Propuestos

| Caso | Preparacion | Resultado esperado |
|---|---|---|
| R03-T01 | A termina 18:00; B inicia 18:00 | No hay solapamiento; aplica intervalo [inicio, fin) |
| R03-T02 | A termina 18:00; B inicia 17:59 | Bloqueo absoluto por un minuto de solapamiento |
| R03-T03 | B esta completamente contenido en A | Bloqueo absoluto |
| R03-T04 | A y B tienen inicio y fin iguales | Bloqueo absoluto |
| R03-T05 | B inicia antes de A y termina dentro de A | Bloqueo absoluto |
| R03-T06 | Turno nocturno cruza medianoche | Calcula con fecha y hora completas y bloquea si coincide |
| R03-T07 | Turnos cruzan fin de mes | Calcula correctamente sin reiniciar el dia |
| R03-T08 | Turnos cruzan fin de ano | Calcula correctamente sin reiniciar mes/ano |
| R03-T09 | Conflicto con programacion aprobada | Bloquea y muestra I9-R03-APPROVED |
| R03-T10 | Conflicto con borrador vigente | Bloquea y muestra I9-R03-DRAFT |
| R03-T11 | Mismo horario para otro guarda | I9-R03 no bloquea por identidad distinta |
| R03-T12 | Sin cruce y puestos distintos | Invoca I9-R05; no presume traslado |
| R03-T13 | Excepcion R05 aprobada pero existe cruce | I9-R03 mantiene bloqueo absoluto |
| R03-T14 | Edicion manual introduce cruce | Revalida y rechaza guardar/aprobar/publicar |
| R03-T15 | Regla desactivada durante desarrollo | No decide cumplimiento productivo; identifica modo no ejecutable |

## Evidencia Por Evaluacion

- identificador del guarda y de ambos turnos;
- inicio y fin completos de cada intervalo;
- puesto, proyecto y estado de cada programacion;
- tipo de conflicto y minutos de interseccion;
- regla y version aplicadas;
- resultado, mensaje y correlacion de auditoria; y
- referencia a I9-R05 cuando corresponda.

## Condicion De Aprobacion

Este artefacto no activa I9-R03. Los mensajes y casos tienen aprobacion
funcional del usuario; requieren implementacion posterior mediante TDD,
ejecucion satisfactoria y evidencia institucional antes de proponer la regla
como ejecutable.
