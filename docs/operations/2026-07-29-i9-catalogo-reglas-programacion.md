# Catalogo I9 De Reglas De Programacion

> Estado: **APROBADO_PARA_PARAMETRIZACION**
> Fecha: 2026-07-29
> Uso: levantamiento y validacion conjunta; no autoriza codigo ni ejecucion

## Evidencia De Roles Validadores

Fuente aportada por el usuario: organigrama S&G, codigo `GH-DE-01`, fecha
`24/07/2025`, version 4. En este artefacto son visibles los roles Director de
Operaciones, Director de Talento Humano y Asesor Juridico.

El organigrama identifica roles, pero no constituye aprobacion ni firma. Los
nombres y decisiones siguientes provienen exclusivamente de la confirmacion
explicita del usuario en esta conversacion del 2026-07-29.

## Regla De Uso

El catalogo no es ejecutable por el motor hasta completar y validar valores,
unidades, vigencia, alcance, mensajes, responsable y pruebas de cada regla. La
aprobacion permite avanzar Task 2 para realizar esa parametrizacion sin inventar
valores juridicos.

Cada fila requiere fuente, version, severidad, parametros y firmas. Los valores
legales numericos se diligencian solo con validacion de Juridico. Un campo
pendiente invalida la regla como entrada del motor.

| ID | Familia | Proposito verificable | Fuente/parametro pendiente | Severidad propuesta | Evidencia esperada | Estado |
|---|---|---|---|---|---|---|
| I9-R01 | Jornada maxima | Impedir o advertir que la carga acumulada exceda el limite aplicable | 8 h/dia y 42 h/semana ordinarias; vigilancia hasta 12 h/dia y 60 h/semana con acuerdo escrito; tratamiento posterior a 10 h/dia pendiente de concepto juridico | Aprobada con condicion juridica | Snapshot de turnos, acumulado semanal y acuerdo escrito | APROBADA_PARA_PARAMETRIZACION |
| I9-R02 | Descanso minimo | Validar intervalo entre fin e inicio de turnos consecutivos | Umbral S&G de 12 horas; intervalo menor genera excepcion pendiente de aprobacion, no bloqueo de propuesta | Aprobada con excepcion | Turnos, intervalo, motivo y aprobacion | APROBADA_PARA_PARAMETRIZACION |
| I9-R03 | Cruces | Bloquear solapamientos temporales del mismo guarda | Solapamiento real bloqueante; conflicto de traslado entre puestos genera excepcion aprobable vinculada a I9-R05 | Aprobada mixta | Intervalos, puestos, traslado, decision y auditoria | APROBADA_PARA_PARAMETRIZACION |
| I9-R04 | Novedades | Excluir o advertir indisponibilidad por novedad vigente | Tipos, estados y prioridad por parametrizar sin inventar valores | Aprobada | Novedad fuente y vigencia | APROBADA_PARA_PARAMETRIZACION |
| I9-R05 | Ubicacion | Evaluar compatibilidad territorial y tiempo de traslado | Zonas y criterio operativo por parametrizar sin inventar valores | Aprobada | Puestos, zonas y fuente | APROBADA_PARA_PARAMETRIZACION |
| I9-R06 | Requisitos | Verificar cursos, acreditaciones y condiciones del puesto | Catalogo I3/I5 y tratamiento versionado | Aprobada | Requisito y habilitacion | APROBADA_PARA_PARAMETRIZACION |
| I9-R07 | Desviacion de plantilla | Detectar cambios frente al ciclo aprobado y exigir motivo | Tolerancias y autorizador parametrizados antes de codificar | Aprobada | Plantilla, celda y motivo | APROBADA_PARA_PARAMETRIZACION |

## Decision De Parametrizacion I9-R01

Estado de I9-R01: **APROBADA_CONDICION_JURIDICA_NO_EJECUTABLE**
> Fecha de decision: 2026-08-13
> Evidencia: aprobacion explicita del usuario en esta conversacion.

- Jornada ordinaria: maximo 8 horas diarias y 42 horas semanales.
- Jornada especial de vigilancia: maximo 12 horas diarias y 60 horas semanales,
  incluidas las suplementarias, cuando exista acuerdo escrito registrado.
- El exceso sobre 8 horas diarias o 42 semanales se identifica y explica como
  tiempo suplementario.
- Se bloquea superar 12 horas diarias, superar 60 horas semanales o programar
  mas de 8 horas diarias sin acuerdo escrito.
- Ventana de acumulacion: semana calendario; debe conservarse como parametro
  versionado para admitir un alcance contractual distinto aprobado.
- Evidencia: turnos considerados, total diario, total semanal, acuerdo escrito,
  regla/version aplicada y mensaje explicable.

Condicion pendiente: Juridico debe definir como se armoniza el limite general
posterior a 10 horas diarias con la regla especial del sector de vigilancia.
Hasta registrar ese concepto, I9-R01 no puede pasar a estado ejecutable.

## Decision De Parametrizacion I9-R02

Estado de I9-R02: **APROBADA_COMO_EXCEPCION_NO_BLOQUEANTE**
Fecha de decision: 2026-08-13
Evidencia: aprobacion explicita del usuario en esta conversacion.

- Umbral preventivo S&G: 12 horas continuas entre el fin de un turno y el
  inicio del siguiente.
- Un intervalo igual o superior a 12 horas cumple la regla.
- Un intervalo inferior a 12 horas no bloquea la generacion de la propuesta;
  crea una excepcion `PENDIENTE` y mantiene visible la advertencia.
- La programacion que contiene la excepcion no puede aprobarse ni publicarse
  hasta que una persona con permiso `SCHEDULING/APPROVE_EXCEPTION` la apruebe.
- La aprobacion exige motivo, responsable, fecha, vigencia y auditoria. Un
  rechazo mantiene la asignacion no publicable y obliga a reprogramar.
- Cuando los turnos correspondan a puestos distintos, I9-R05 definira el tiempo
  de traslado que debe considerarse; hasta aprobar I9-R05 no se infiere un valor.
- El descanso semanal minimo se controla por separado y no se sustituye con esta
  excepcion entre turnos.

El umbral de 12 horas se registra como politica preventiva S&G aprobada por el
usuario, no como valor legal atribuido. La regla no pasa a ejecutable hasta
completar sus mensajes, pruebas de borde y evidencia de aprobacion institucional.

## Decision De Parametrizacion I9-R03

Estado de I9-R03: **APROBADA_MIXTA_NO_EJECUTABLE**
Fecha de decision: 2026-08-13
Evidencia: aprobacion explicita del usuario en esta conversacion.

- Existe solapamiento real cuando el inicio de un turno es anterior al fin de
  otro turno asignado al mismo guarda.
- El solapamiento real es bloqueante, no admite excepcion y deja la vacante
  visible para reprogramacion.
- Dos turnos son adyacentes cuando el segundo inicia exactamente al finalizar el
  primero; esa frontera no constituye por si sola un solapamiento.
- Turnos adyacentes en el mismo puesto pueden continuar como candidatos, sujetos
  a I9-R01 Jornada maxima e I9-R02 Descanso minimo.
- Turnos adyacentes o cercanos en puestos distintos pueden incluirse en la
  propuesta como excepcion `PENDIENTE`, pero no aprobarse ni publicarse hasta
  validar I9-R05 y obtener aprobacion con `SCHEDULING/APPROVE_EXCEPTION`.
- Hasta parametrizar I9-R05 no se infiere distancia ni tiempo de traslado.
- El calculo utiliza fecha y hora completas, incluidos turnos nocturnos y cambios
  de dia, mes y ano.
- Evidencia: guarda, turnos, puestos, intervalos, resultado del cruce, traslado,
  motivo, aprobador, fecha y auditoria.

I9-R03 no pasa a ejecutable hasta completar mensajes, pruebas de bordes
temporales, integracion con I9-R05 y evidencia de aprobacion institucional.

## Campos Obligatorios Por Regla Antes De Activarla

- identificador y version;
- fuente juridica, politica o contractual;
- fecha de vigencia;
- alcance por contrato/proyecto;
- severidad aprobada;
- parametros exactos y unidad;
- mensaje explicable;
- responsable de excepcion;
- evidencia de pruebas de borde;
- firmas de Operaciones, Talento Humano y Juridico.

## Ruta Y Firmas De Validacion

| Rol validador | Estado | Nombre | Cargo | Decision | Observaciones | Fecha | Evidencia/firma |
|---|---|---|---|---|---|---|---|
| Director de Operaciones | Aprobada | Jorge Guzman | Operaciones | Aprobada | Confirmada por el usuario | 2026-07-29 | Confirmacion explicita del usuario en esta conversacion; sin firma manuscrita ni documento externo |
| Director de Talento Humano | Aprobada | Carolina Rodriguez Russi | Talento Humano y Juridica | Aprobada | Confirmada por el usuario | 2026-07-29 | Confirmacion explicita del usuario en esta conversacion; sin firma manuscrita ni documento externo |
| Asesor Juridico | Aprobada | Carolina Rodriguez Russi | Talento Humano y Juridica | Aprobada | Confirmada por el usuario | 2026-07-29 | Confirmacion explicita del usuario en esta conversacion; sin firma manuscrita ni documento externo |

El catalogo queda `APROBADO_PARA_PARAMETRIZACION`; no se atribuye firma manuscrita ni
documento externo.

Acta para diligenciamiento:
`docs/operations/2026-07-29-i9-acta-validacion-gate0.md`.
