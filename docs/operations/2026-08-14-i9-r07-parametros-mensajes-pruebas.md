# I9-R07 - Parametros, Mensajes Y Casos De Prueba

> Estado: **PROPUESTA_PARA_VALIDACION_NO_EJECUTABLE**
> Fecha: 2026-08-14
> Regla: desviaciones frente a plantillas de turnos aprobadas.
> Evidencia: criterio base aprobado por el usuario; parametros detallados pendientes de aprobacion.

## Criterios Base Ya Aprobados

- la plantilla 2X2, 4X2, 6X1 u otra aprobada es obligatoria por defecto;
- toda diferencia frente a la version seleccionada es una desviacion explicita;
- la desviacion no bloquea generar la propuesta, pero crea una excepcion
  `PENDIENTE` que impide aprobar o publicar;
- los cambios manuales reciben el mismo tratamiento que los generados por el
  motor;
- ninguna excepcion de plantilla elude bloqueos absolutos;
- el cambio de plantilla solo afecta borradores futuros; y
- el snapshot conserva plantilla, version, celdas y desviaciones evaluadas.

## Parametros Propuestos Para Aprobacion

1. **Aprobador:** Director de Operaciones mediante
   `SCHEDULING/APPROVE_EXCEPTION`.
2. **Motivos iniciales:** `OPERATIONAL_CONTINGENCY`, `URGENT_REPLACEMENT`,
   `EXCEPTIONAL_CLIENT_REQUEST`, `TEMPORARY_TEMPLATE_TRANSITION`,
   `SPECIAL_COVERAGE` y `OTHER`.
3. **Motivo Otro:** `OTHER` exige descripcion obligatoria; seleccionar un motivo
   nunca sustituye la aprobacion.
4. **Alcance exacto:** la excepcion identifica proyecto, periodo, version de
   programacion, plantilla/version, guarda y celdas afectadas.
5. **Agrupacion controlada:** una decision puede cubrir varias celdas del mismo
   guarda y version si todas se enumeran en el snapshot. No cubre celdas futuras
   ni otros guardas.
6. **No reutilizacion:** cualquier cambio de guarda, periodo, plantilla, version,
   celda o valor invalida la aprobacion y exige revalidacion.
7. **Comparacion deterministica:** cada celda propuesta se compara con el valor
   esperado del ciclo, anclaje y version seleccionados; no se infiere una
   plantilla distinta para evitar la desviacion.
8. **Prioridad:** bloqueos absolutos I9-R01, I9-R03, I9-R05 u otros conservan su
   efecto aunque la desviacion de plantilla sea aprobada.
9. **Inmutabilidad:** una programacion publicada no se modifica; una correccion
   crea una nueva version o flujo de reprogramacion trazable.
10. **Modo de desarrollo:** desactivada o en advertencia mientras motivos,
    responsable, fuente/version institucional, TDD y evidencia no esten
    completos.

## Mensajes Funcionales Propuestos

| Codigo | Condicion | Severidad | Mensaje al usuario | Accion disponible |
|---|---|---|---|---|
| I9-R07-OK | Asignacion coincide con la plantilla | CUMPLE | La secuencia coincide con la plantilla y version seleccionadas. | Continuar |
| I9-R07-DEVIATION | Una o mas celdas difieren | EXCEPCION_PENDIENTE | La asignacion se aparta de la plantilla obligatoria y requiere motivo y aprobacion. | Ver diferencias / Solicitar aprobacion / Restaurar plantilla |
| I9-R07-MOTIVE | Motivo ausente | DATOS_INCOMPLETOS | Selecciona un motivo autorizado para tramitar la desviacion. | Seleccionar motivo |
| I9-R07-OTHER | Otro sin descripcion | DATOS_INCOMPLETOS | Describe la razon de la desviacion. | Completar descripcion |
| I9-R07-PENDING | Excepcion sin decision | PENDIENTE_APROBACION | La propuesta puede conservarse, pero no aprobarse ni publicarse hasta resolver la desviacion. | Aprobar / Rechazar, segun permiso |
| I9-R07-REJECTED | Excepcion rechazada | NO_APROBABLE | La desviacion fue rechazada. Restaura la plantilla o ajusta la programacion. | Ver decision / Restaurar / Reprogramar |
| I9-R07-APPROVED | Excepcion aprobada | CUMPLE_CON_EXCEPCION | La desviacion fue autorizada exclusivamente para las celdas registradas. | Continuar y conservar auditoria |
| I9-R07-STALE | Cambio posterior a la aprobacion | REVALIDACION_REQUERIDA | La programacion cambio y la aprobacion anterior ya no aplica. | Revalidar / Solicitar nueva aprobacion |
| I9-R07-NO-TEMPLATE | Plantilla o version no disponible | CONFIGURACION_INCOMPLETA | No existe una plantilla vigente y aprobada para realizar la comparacion. | Seleccionar o configurar plantilla |

## Casos De Prueba Propuestos

| Caso | Preparacion | Resultado esperado |
|---|---|---|
| R07-T01 | Secuencia coincide exactamente con plantilla/version | CUMPLE; no crea excepcion |
| R07-T02 | Una celda cambia D por N | Excepcion PENDIENTE; identifica valor esperado y propuesto |
| R07-T03 | Una celda cambia D o N por X | Excepcion PENDIENTE |
| R07-T04 | Se agrega turno donde la plantilla indica X | Excepcion PENDIENTE y revalidacion de otras reglas |
| R07-T05 | El motor produce la desviacion | Mismo tratamiento que una edicion manual |
| R07-T06 | Edicion manual produce la desviacion | Revalida antes de guardar/aprobar/publicar |
| R07-T07 | Desviacion sin motivo | Rechaza solicitud de aprobacion |
| R07-T08 | Motivo OTHER sin descripcion | Rechaza solicitud de aprobacion |
| R07-T09 | Motivo autorizado seleccionado | Excepcion sigue pendiente hasta decision del aprobador |
| R07-T10 | Director de Operaciones aprueba celdas enumeradas | Permite continuar solo para ese snapshot |
| R07-T11 | Rol sin permiso intenta aprobar | Acceso denegado |
| R07-T12 | Se intenta reutilizar aprobacion para otro guarda | Rechaza reutilizacion |
| R07-T13 | Se agrega una celda despues de aprobar grupo | Invalida aprobacion y exige nueva decision |
| R07-T14 | Cambia plantilla o version seleccionada | Recalcula diferencias e invalida aprobacion anterior |
| R07-T15 | Cambia el anclaje del ciclo | Recalcula toda la secuencia afectada |
| R07-T16 | Nueva version de plantilla entra en vigencia | Solo nuevos borradores usan la nueva version |
| R07-T17 | Programacion ya publicada | No modifica; exige version o reprogramacion trazable |
| R07-T18 | Desviacion aprobada coincide con bloqueo absoluto R01/R03/R05 | Mantiene bloqueo absoluto |
| R07-T19 | Plantilla no aprobada o version inexistente | Configuracion incompleta; no presume cumplimiento |
| R07-T20 | Snapshot historico tras cambio de plantilla | Conserva version, anclaje, valores y desviaciones originales |
| R07-T21 | Varias celdas del mismo guarda enumeradas | Puede tramitar una decision agrupada exacta |
| R07-T22 | Grupo incluye celdas de dos guardas | Requiere excepciones separadas por guarda |
| R07-T23 | Regla en modo advertencia durante desarrollo | No decide cumplimiento productivo ni cierra Gate 2 |

## Evidencia Por Evaluacion

- proyecto, periodo, version de programacion y guarda;
- plantilla, version, anclaje y secuencia esperada;
- fechas/celdas, valor esperado y valor propuesto;
- origen del cambio: motor o edicion manual;
- motivo, descripcion y snapshot exacto de alcance;
- aprobador, decision, observaciones, fecha y evidencia; y
- resultado, mensaje y correlacion de auditoria.

## Decisiones Pendientes De Aprobacion

1. confirmar al Director de Operaciones como aprobador;
2. aprobar el catalogo inicial de seis motivos, incluido `OTHER` con descripcion;
3. confirmar agrupacion solo para celdas enumeradas del mismo guarda/version;
4. confirmar no reutilizacion, comparacion deterministica e inmutabilidad; y
5. aprobar los nueve mensajes y veintitres casos de prueba.

## Condicion De Aprobacion

Este documento es una propuesta para validacion. Su aprobacion funcional no
activa I9-R07 ni cierra Gate 2. La regla requiere catalogo institucional de
motivos, fuente/version, implementacion mediante TDD, ejecucion satisfactoria de
pruebas y evidencia antes de proponerse como ejecutable.
