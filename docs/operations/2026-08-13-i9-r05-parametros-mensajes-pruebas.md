# I9-R05 - Parametros, Mensajes Y Casos De Prueba

> Estado: **APROBADO_FUNCIONALMENTE_NO_EJECUTABLE**
> Fecha: 2026-08-13
> Regla: ubicacion y tiempo de traslado entre puestos.
> Evidencia: criterios y parametros detallados aprobados explicitamente por el usuario en esta conversacion.

## Criterios Base Ya Aprobados

- cada puesto pertenece a un proyecto, sede o zona identificable;
- el tiempo requerido proviene de una matriz versionada por proyecto o contrato;
- no existe un tiempo universal ni se presume cero cuando falta una relacion;
- si el intervalo disponible es igual o mayor al requerido, la validacion cumple;
- si el tiempo es insuficiente o falta la relacion, se genera una excepcion
  `PENDIENTE`: no bloquea generar la propuesta, pero impide aprobarla o publicarla;
- una combinacion expresamente prohibida es bloqueo absoluto sin excepcion; y
- trafico en tiempo real y calculo dinamico de rutas quedan fuera del MVP.

## Parametros Propuestos Para Aprobacion

1. **Aprobador:** Director de Operaciones con permiso `SCHEDULING/APPROVE_EXCEPTION`.
2. **Unidad:** minutos enteros no negativos.
3. **Direccionalidad:** cada fila representa un sentido; `A -> B` y `B -> A`
   pueden tener tiempos o restricciones diferentes.
4. **Vigencia:** cada version tiene proyecto o contrato, fecha/hora de inicio,
   fecha/hora opcional de fin, responsable y estado. Solo una version aplica a
   una evaluacion; la propuesta conserva su snapshot.
5. **Excepcion no reutilizable:** la aprobacion cubre exclusivamente al guarda,
   los dos turnos, origen, destino y fechas evaluadas.
6. **Mismo puesto exacto:** requiere cero minutos por identidad y no consulta
   una fila de traslado. Misma sede o zona con puestos diferentes no se asume
   como cero y debe existir en la matriz.
7. **Frontera:** tiempo disponible igual al requerido cumple; un minuto menos
   crea excepcion pendiente.
8. **Edicion manual:** cualquier cambio de guarda, puesto, fecha u hora vuelve a
   ejecutar I9-R03 e I9-R05 antes de guardar, aprobar o publicar.
9. **Prioridad:** I9-R03 y las combinaciones prohibidas prevalecen sobre toda
   excepcion de traslado.
10. **Modo de desarrollo:** desactivada o en advertencia mientras no exista una
    matriz institucional aprobada, pruebas ejecutadas y evidencia.

## Mensajes Funcionales Propuestos

| Codigo | Condicion | Severidad | Mensaje al usuario | Accion disponible |
|---|---|---|---|---|
| I9-R05-SAME | Mismo puesto exacto | CUMPLE | Los turnos corresponden al mismo puesto; no se requiere traslado. | Continuar validaciones |
| I9-R05-OK | Tiempo disponible igual o mayor | CUMPLE | El intervalo disponible cubre el tiempo de traslado configurado. | Continuar |
| I9-R05-INSUFFICIENT | Tiempo disponible menor | EXCEPCION_PENDIENTE | El intervalo no cubre el traslado configurado. Se requiere aprobacion del Director de Operaciones. | Ver detalle / Solicitar aprobacion / Reprogramar |
| I9-R05-MISSING | Relacion ausente | EXCEPCION_PENDIENTE | No existe un tiempo vigente para este origen y destino. No se asumira cero minutos. | Completar matriz / Solicitar aprobacion / Reprogramar |
| I9-R05-PROHIBITED | Combinacion prohibida | BLOQUEO_ABSOLUTO | Este traslado esta expresamente prohibido y no admite excepcion. | Ver restriccion / Reprogramar |
| I9-R05-PENDING | Excepcion sin decision | PENDIENTE_APROBACION | La propuesta puede conservarse, pero no aprobarse ni publicarse hasta resolver el traslado. | Aprobar / Rechazar, segun permiso |
| I9-R05-REJECTED | Excepcion rechazada | NO_APROBABLE | La excepcion de traslado fue rechazada. Reprograma la asignacion. | Ver decision / Reprogramar |
| I9-R05-APPROVED | Excepcion aprobada | CUMPLE_CON_EXCEPCION | El traslado fue autorizado exclusivamente para esta asignacion. | Continuar y conservar auditoria |
| I9-R05-NO-VERSION | Sin version vigente | ADVERTENCIA | No hay una version vigente de la matriz para el proyecto o contrato. | Configurar matriz / Solicitar aprobacion |

## Casos De Prueba Propuestos

| Caso | Preparacion | Resultado esperado |
|---|---|---|
| R05-T01 | Mismo puesto exacto en turnos adyacentes | CUMPLE con cero minutos por identidad |
| R05-T02 | Misma sede, puestos distintos, sin fila | Excepcion PENDIENTE; nunca presume cero |
| R05-T03 | A -> B requiere 30 min; disponibles 30 | CUMPLE por frontera igual |
| R05-T04 | A -> B requiere 30 min; disponibles 31 | CUMPLE |
| R05-T05 | A -> B requiere 30 min; disponibles 29 | Excepcion PENDIENTE; bloquea aprobar/publicar |
| R05-T06 | A -> B existe, B -> A no existe | B -> A genera excepcion PENDIENTE |
| R05-T07 | A -> B y B -> A tienen tiempos distintos | Usa la fila del sentido evaluado |
| R05-T08 | Relacion ausente de la version vigente | I9-R05-MISSING; no usa cero ni otra version |
| R05-T09 | No existe version vigente para proyecto/contrato | Advertencia y excepcion PENDIENTE |
| R05-T10 | Combinacion marcada prohibida | Bloqueo absoluto; no permite solicitar excepcion |
| R05-T11 | Director de Operaciones aprueba insuficiencia | Permite continuar solo para la asignacion evaluada |
| R05-T12 | Otro rol intenta aprobar | Acceso denegado; excepcion sigue pendiente |
| R05-T13 | Se intenta reutilizar aprobacion en otro guarda o turno | Rechaza reutilizacion |
| R05-T14 | Cambia hora, puesto u origen tras aprobar | Invalida decision anterior y reevalua I9-R03/R05 |
| R05-T15 | Existe solapamiento y traslado aprobable | I9-R03 mantiene bloqueo absoluto |
| R05-T16 | Matriz se actualiza despues de crear borrador | Borrador conserva snapshot; regenerar usa version vigente |
| R05-T17 | Tiempo requerido o disponible negativo | Rechaza datos; no evalua cumplimiento |
| R05-T18 | Tiempo requerido con fraccion de minuto | La regla rechaza el valor; el contrato recibe enteros |
| R05-T19 | Turnos cruzan medianoche/mes/ano | Calcula intervalo con fecha y hora completas |
| R05-T20 | Regla en modo advertencia durante desarrollo | No decide cumplimiento productivo ni cierra Gate 2 |

## Evidencia Por Evaluacion

- guarda, turnos, proyectos, puestos, origen y destino;
- inicio, fin y minutos disponibles;
- minutos requeridos o motivo de ausencia de fila;
- proyecto/contrato, version y vigencia de la matriz;
- indicador y fuente de combinacion prohibida;
- resultado, mensaje y correlacion de auditoria; y
- para excepciones: motivo, aprobador, decision, fecha y evidencia, sin reutilizacion.

## Condicion De Aprobacion

Este documento tiene aprobacion funcional del usuario, pero no activa I9-R05
ni cierra Gate 2. La regla requiere matriz institucional real,
implementacion mediante TDD, integracion comprobada con I9-R03, ejecucion
satisfactoria de pruebas y evidencia antes de proponerse como ejecutable.
