# I9-R02 - Mensajes Y Casos De Prueba

> Estado: **PROPUESTA_PARA_VALIDACION_NO_EJECUTABLE**
> Fecha: 2026-08-13
> Regla: descanso preventivo minimo de 12 horas.

## Mensajes Funcionales Propuestos

| Codigo | Condicion | Severidad | Mensaje al usuario | Accion disponible |
|---|---|---|---|---|
| I9-R02-OK | Intervalo mayor o igual a 12 h | CUMPLE | Descanso validado: el intervalo entre turnos es de {horas_descanso} horas. | Continuar |
| I9-R02-WARN | Intervalo menor a 12 h | EXCEPCION_PENDIENTE | Descanso inferior al umbral preventivo de 12 horas. La propuesta puede generarse, pero requiere motivo y aprobacion del Director de Operaciones antes de aprobarse o publicarse. | Registrar motivo / Enviar a aprobacion |
| I9-R02-MOTIVE | No se selecciono motivo | DATO_REQUERIDO | Selecciona un motivo para solicitar la excepcion de descanso. | Seleccionar motivo |
| I9-R02-OTHER | Motivo Otro sin descripcion | DATO_REQUERIDO | Describe el motivo de la excepcion cuando selecciones Otro. | Completar descripcion |
| I9-R02-PENDING | Excepcion enviada y no resuelta | EXCEPCION_PENDIENTE | La excepcion de descanso esta pendiente de decision del Director de Operaciones. | Consultar estado |
| I9-R02-REJECTED | Excepcion rechazada | REPROGRAMACION_REQUERIDA | La excepcion de descanso fue rechazada. Reprograma el turno antes de aprobar o publicar. | Reprogramar |
| I9-R02-APPROVED | Excepcion aprobada para el turno | EXCEPCION_APROBADA | Excepcion aprobada exclusivamente para este turno. La autorizacion no puede reutilizarse. | Continuar flujo |

Los mensajes deben mostrar guarda, turnos comparados, horas calculadas, umbral,
motivo, estado y responsable de decision sin exponer datos personales fuera de
los permisos autorizados.

## Casos De Prueba Propuestos

| Caso | Preparacion | Resultado esperado |
|---|---|---|
| R02-T01 | Intervalo 12 h 00 min | CUMPLE; no crea excepcion |
| R02-T02 | Intervalo 12 h 01 min | CUMPLE; no crea excepcion |
| R02-T03 | Intervalo 11 h 59 min | Genera propuesta y excepcion PENDIENTE; no permite aprobar/publicar |
| R02-T04 | Intervalo 0 h por turnos adyacentes | Genera excepcion PENDIENTE; I9-R03 valida aparte que no exista solapamiento |
| R02-T05 | Intervalo negativo por solapamiento | I9-R03 aplica bloqueo absoluto; una excepcion R02 no lo elude |
| R02-T06 | Excepcion sin motivo | Rechaza envio a aprobacion con I9-R02-MOTIVE |
| R02-T07 | Motivo Otro sin descripcion | Rechaza envio con I9-R02-OTHER |
| R02-T08 | Motivo Otro con descripcion | Permite enviar; permanece PENDIENTE |
| R02-T09 | Usuario sin SCHEDULING/APPROVE_EXCEPTION intenta aprobar | Acceso denegado y evento auditado |
| R02-T10 | Rol distinto al Director de Operaciones intenta aprobar | Acceso denegado aunque posea otro permiso funcional |
| R02-T11 | Director de Operaciones aprueba | Registra motivo, aprobador, fecha, vigencia, turno y auditoria |
| R02-T12 | Se intenta reutilizar aprobacion en otro turno | Rechaza reutilizacion y crea nueva excepcion PENDIENTE |
| R02-T13 | Excepcion rechazada | Impide aprobar/publicar y exige reprogramacion |
| R02-T14 | Cambio de mes o ano entre turnos | Calcula intervalo con fecha y hora completas |
| R02-T15 | Turnos en puestos diferentes | Aplica tambien I9-R05; no presume tiempo de traslado |
| R02-T16 | Regla desactivada durante desarrollo | No decide cumplimiento productivo; conserva identificacion de modo no ejecutable |

## Datos De Evidencia Por Ejecucion

- identificador y version de I9-R02;
- identificadores de los turnos y del guarda;
- fin anterior, inicio siguiente e intervalo calculado;
- umbral aplicado;
- proyecto, motivo y descripcion cuando corresponda;
- estado de la excepcion;
- aprobador, fecha, vigencia y decision;
- correlacion de auditoria; y
- version del catalogo de motivos.

## Condicion De Aprobacion

Este artefacto no activa I9-R02. Requiere validacion funcional de mensajes y
casos por S&G, implementacion posterior mediante TDD y evidencia institucional
antes de proponer la regla como ejecutable.
