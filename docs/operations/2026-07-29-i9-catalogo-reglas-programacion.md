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
| I9-R01 | Jornada maxima | Impedir o advertir que la carga acumulada exceda el limite aplicable | 8 h/dia y 42 h/semana ordinarias; vigilancia hasta 12 h/dia y 60 h/semana con acuerdo escrito; toda jornada mayor a 10 y hasta 12 h requiere aprobacion | Aprobada con condicion juridica | Snapshot de turnos, acumulado semanal, acuerdo escrito y aprobacion | APROBADA_PARA_PARAMETRIZACION |
| I9-R02 | Descanso minimo | Validar intervalo entre fin e inicio de turnos consecutivos | Umbral S&G de 12 horas; intervalo menor genera excepcion pendiente de aprobacion, no bloqueo de propuesta | Aprobada con excepcion | Turnos, intervalo, motivo y aprobacion | APROBADA_PARA_PARAMETRIZACION |
| I9-R03 | Cruces | Bloquear solapamientos temporales del mismo guarda | Solapamiento real bloqueante; conflicto de traslado entre puestos genera excepcion aprobable vinculada a I9-R05 | Aprobada mixta | Intervalos, puestos, traslado, decision y auditoria | APROBADA_PARA_PARAMETRIZACION |
| I9-R04 | Novedades | Excluir o advertir indisponibilidad por novedad vigente | Confirmadas: bloqueo; pendientes/compatibles: excepcion aprobable; administrativas: informativas | Aprobada por clasificacion | Tipo, vigencia, estado, fuente, decision y auditoria | APROBADA_PARA_PARAMETRIZACION |
| I9-R05 | Ubicacion | Evaluar compatibilidad territorial y tiempo de traslado | Matriz versionada por proyecto/contrato; insuficiencia genera excepcion y prohibicion expresa bloquea | Aprobada por criterio | Origen, destino, tiempos, version, decision y auditoria | APROBADA_PARA_PARAMETRIZACION |
| I9-R06 | Requisitos | Verificar cursos, acreditaciones y condiciones del puesto | No bloquea propuesta; faltante, vencido o no verificado requiere excepcion antes de aprobar/publicar | Aprobada no bloqueante | Requisito, vigencia, evidencia, subsanacion, decision y auditoria | APROBADA_PARA_PARAMETRIZACION |
| I9-R07 | Desviacion de plantilla | Detectar cambios frente al ciclo aprobado y exigir motivo | Plantilla obligatoria por defecto; toda desviacion requiere aprobacion auditada | Aprobada con excepcion | Plantilla/version, guarda, celdas, valores, motivo, aprobador y fecha | APROBADA_PARA_PARAMETRIZACION |

## Decision De Parametrizacion I9-R01

Estado de I9-R01: **APROBADA_CONDICION_JURIDICA_NO_EJECUTABLE**
> Fecha de decision: 2026-08-13
> Evidencia: aprobacion explicita del usuario en esta conversacion.

- Jornada ordinaria: maximo 8 horas diarias y 42 horas semanales.
- Jornada especial de vigilancia: maximo 12 horas diarias y 60 horas semanales,
  incluidas las suplementarias, cuando la existencia del acuerdo escrito este
  marcada en el sistema.
- El exceso sobre 8 horas diarias o 42 semanales se identifica y explica como
  tiempo suplementario.
- Toda jornada superior a 10 y hasta 12 horas crea una excepcion `PENDIENTE`:
  no bloquea la generacion de la propuesta, pero esta no puede aprobarse ni
  publicarse hasta registrar la aprobacion del Director de Operaciones mediante
  `SCHEDULING/APPROVE_EXCEPTION`.
- Se bloquea superar 12 horas diarias, superar 60 horas semanales o programar
  mas de 8 horas diarias cuando la marca de existencia del acuerdo sea falsa o
  no este diligenciada.
- La marca de existencia del acuerdo conserva responsable y fecha. Se pueden
  adjuntar referencia, documento u otro soporte, pero son opcionales y su
  ausencia no bloquea por si sola la programacion.
- Ventana de acumulacion: semana calendario; debe conservarse como parametro
  versionado para admitir un alcance contractual distinto aprobado.
- Evidencia: turnos considerados, total diario, total semanal, acuerdo escrito,
  regla/version aplicada y mensaje explicable.

La exigencia de aprobacion para toda jornada superior a 10 y hasta 12 horas
proviene de la confirmacion del usuario, no de un concepto juridico aportado. El
usuario confirmo al Director de Operaciones como rol aprobador. Permanecen
pendientes la fuente y vigencia juridicas. Por decision
del usuario, el criterio aplica a todos los proyectos de vigilancia gestionados
por I9, sin un valor distinto por proyecto o contrato.
Hasta completarlos y validarlos, I9-R01 no
puede pasar a estado ejecutable.

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
  hasta que el Director de Operaciones, con permiso
  `SCHEDULING/APPROVE_EXCEPTION`, la apruebe.
- El criterio aplica a todos los proyectos de vigilancia gestionados por I9,
  sin un umbral distinto por proyecto o contrato.
- La aprobacion exige un motivo obligatorio tomado de un catalogo configurable,
  responsable, fecha, vigencia y auditoria. Un
  rechazo mantiene la asignacion no publicable y obliga a reprogramar.
- La autorizacion se limita al turno y excepcion evaluados; no crea una
  autorizacion permanente ni se reutiliza en otra asignacion.
- Catalogo inicial de motivos autorizados:
  - reemplazo urgente por ausencia o incapacidad;
  - continuidad temporal del servicio;
  - contingencia operativa del proyecto;
  - emergencia o fuerza mayor;
  - ajuste excepcional solicitado por el cliente; y
  - otro, con descripcion obligatoria.
- El catalogo de motivos debe conservar version y vigencia. La seleccion de un
  motivo no sustituye la aprobacion del Director de Operaciones.
- Cuando los turnos correspondan a puestos distintos, I9-R05 definira el tiempo
  de traslado que debe considerarse; hasta aprobar I9-R05 no se infiere un valor.
- El descanso semanal minimo se controla por separado y no se sustituye con esta
  excepcion entre turnos.

El umbral de 12 horas se registra como politica preventiva S&G aprobada por el
usuario, no como valor legal atribuido. La regla no pasa a ejecutable hasta
completar los mensajes, pruebas de borde y evidencia de
aprobacion institucional. Mientras tanto permanece desactivada o en modo
advertencia para el desarrollo.

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

## Decision De Parametrizacion I9-R04

Estado de I9-R04: **APROBADA_POR_CLASIFICACION_NO_EJECUTABLE**
Fecha de decision: 2026-08-13
Evidencia: aprobacion explicita del usuario en esta conversacion.

| Novedad | Tratamiento aprobado |
|---|---|
| Incapacidad vigente | Bloqueo absoluto durante su vigencia |
| Vacaciones aprobadas | Bloqueo absoluto durante su vigencia |
| Licencia o calamidad vigente | Bloqueo absoluto durante su vigencia |
| Suspension o retiro | Bloqueo absoluto desde su vigencia |
| Ausencia confirmada | Bloqueo absoluto durante su vigencia |
| Ausencia reportada pendiente de confirmar | Excepcion aprobable |
| Induccion o capacitacion coincidente | Excepcion aprobable |
| Disponible | No bloquea; puede mejorar priorizacion |
| Turno adicional | Excepcion aprobable, sujeta a I9-R01 e I9-R02 |
| Descuento o sancion administrativa | Informativa, salvo indisponibilidad formal |
| Novedad vencida o anulada | No afecta la programacion |

- Toda novedad debe registrar tipo, inicio, fin, estado, fuente y responsable.
- Una novedad sin vigencia completa genera advertencia y no se convierte
  automaticamente en bloqueo.
- Si coinciden varias novedades, prevalece: bloqueo absoluto, luego excepcion
  aprobable y finalmente informativa.
- Toda excepcion requiere motivo, aprobador, fecha, vigencia y auditoria antes
  de aprobar o publicar la programacion.
- La fuente, estado y version de la novedad quedan en el snapshot de evaluacion.

I9-R04 no pasa a ejecutable hasta mapear los codigos reales de novedades de S&G,
completar mensajes, pruebas de prioridad y evidencia institucional.

## Decision De Parametrizacion I9-R05

Estado de I9-R05: **APROBADA_POR_CRITERIO_NO_EJECUTABLE**
Fecha de decision: 2026-08-13
Evidencia: aprobacion explicita del usuario en esta conversacion.

- Cada puesto se relaciona con su proyecto, sede y zona operativa.
- Los tiempos requeridos se obtienen de una matriz versionada de traslados por
  proyecto o contrato; no existe un tiempo universal ni se infiere uno.
- La compatibilidad se cumple cuando el intervalo disponible es igual o mayor
  al tiempo requerido por la matriz vigente.
- Un tiempo insuficiente genera una excepcion `PENDIENTE`: no bloquea la
  generacion de la propuesta, pero impide aprobarla o publicarla hasta obtener
  motivo y aprobacion auditada mediante `SCHEDULING/APPROVE_EXCEPTION`.
- Si no existe un valor en la matriz, se genera advertencia y excepcion
  pendiente; nunca se asume un traslado de cero minutos.
- Una combinacion de origen y destino expresamente prohibida por el proyecto o
  contrato constituye bloqueo absoluto sin excepcion.
- La evidencia registra origen, destino, tiempo requerido, tiempo disponible,
  version de matriz, motivo, aprobador y decision.
- Trafico en tiempo real y calculo dinamico de rutas quedan fuera del MVP.

I9-R05 no pasa a ejecutable hasta cargar y validar la matriz real aplicable,
completar mensajes, pruebas de frontera e integracion con I9-R03 y aportar
evidencia institucional.

## Decision De Parametrizacion I9-R06

Estado de I9-R06: **APROBADA_NO_BLOQUEANTE_NO_EJECUTABLE**
Fecha de decision: 2026-08-13
Evidencia: aprobacion explicita del usuario en esta conversacion.

- Cada requisito se configura por puesto, proyecto y vigencia.
- Ningun incumplimiento bloquea la generacion de la propuesta.
- Un requisito vigente y acreditado se registra como cumplido.
- Un requisito faltante, vencido o no verificado crea una excepcion
  `PENDIENTE`; la propuesta no puede aprobarse ni publicarse hasta que la
  excepcion sea autorizada mediante `SCHEDULING/APPROVE_EXCEPTION`.
- Un requisito subsanable puede clasificarse como informativo solo mediante
  configuracion explicita y versionada; la ausencia de informacion nunca
  acredita su cumplimiento.
- La excepcion registra motivo, responsable de subsanacion, fecha limite,
  aprobador, decision y evidencia.
- El snapshot conserva los requisitos, vigencias, acreditaciones y fuentes
  efectivamente evaluados.

I9-R06 no pasa a ejecutable hasta mapear los catalogos reales de I3/I5,
responsables, mensajes, pruebas y evidencia institucional.

## Decision De Parametrizacion I9-R07

Estado de I9-R07: **APROBADA_CON_EXCEPCION_NO_EJECUTABLE**
Fecha de decision: 2026-08-13
Evidencia: aprobacion explicita del usuario en esta conversacion.

- La plantilla seleccionada (2X2, 4X2, 6X1 u otra aprobada) es obligatoria por
  defecto.
- Toda diferencia frente a la secuencia de su version vigente constituye una
  desviacion explicita.
- La desviacion no bloquea la generacion de la propuesta, pero crea una
  excepcion `PENDIENTE`; la programacion no puede aprobarse ni publicarse hasta
  que sea autorizada mediante `SCHEDULING/APPROVE_EXCEPTION`.
- Los cambios manuales reciben el mismo tratamiento que los generados por el
  motor.
- La evidencia registra plantilla y version, guarda, fechas y celdas afectadas,
  valor original, valor propuesto, motivo, aprobador y fecha de decision.
- Una excepcion de plantilla nunca permite eludir bloqueos absolutos de otras
  reglas.
- Un cambio de plantilla solo afecta borradores futuros y no modifica de forma
  silenciosa programaciones aprobadas.
- El snapshot conserva la plantilla, su version y las desviaciones evaluadas.

I9-R07 no pasa a ejecutable hasta definir y validar motivos autorizados,
responsables, mensajes, pruebas y evidencia institucional.

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
