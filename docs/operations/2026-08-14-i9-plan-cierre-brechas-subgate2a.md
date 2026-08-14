# I9 - Plan De Cierre De Brechas Del Subgate 2A

> Estado: **APROBADO_COMO_RUTA_NO_AUTORIZA_IMPLEMENTACION**
> Fecha: 2026-08-14
> Alcance: ordenar los insumos y verificaciones pendientes de I9-R01 a I9-R07.
> Evidencia: consolidacion de la matriz de parametrizacion y decisiones funcionales aprobadas.
> Aprobacion: confirmacion explicita del usuario en esta conversacion; no equivale a autorizacion de implementacion.

## Objetivo

Cerrar de forma trazable los campos institucionales, juridicos y tecnicos que
mantienen las siete reglas como no ejecutables. Este plan no completa los
insumos, no presume su contenido, no asigna fechas y no autoriza implementar ni
activar reglas.

## Estado Consolidado

| Regla | Definicion funcional | Brecha institucional principal | Brecha tecnica posterior | Responsable de validacion | Estado actual |
|---|---|---|---|---|---|
| I9-R01 | Aprobada con condicion juridica | Concepto sobre armonizacion normativa, fuente, vigencia y conservacion del acuerdo | Mensajes/pruebas de bordes 8/10/12 h y 42/60 h; TDD y evidencia | Juridica y Operaciones | NO_EJECUTABLE |
| I9-R02 | Parametros, motivos, mensajes y pruebas aprobados | Politica S&G y catalogo de motivos con version/vigencia | TDD, integracion R01/R03/R05 y evidencia | Director de Operaciones | NO_EJECUTABLE |
| I9-R03 | Parametros, mensajes y pruebas aprobados | Confirmacion de fuente/version operativa si aplica | TDD, integracion obligatoria con R05 y evidencia | Operaciones | NO_EJECUTABLE |
| I9-R04 | Contrato, mapeo inicial, mensajes y pruebas aprobados | Catalogo institucional de novedades, codigos/estados restantes y version | Adaptadores I3/I5, TDD y evidencia | Talento Humano y Operaciones | NO_EJECUTABLE |
| I9-R05 | Parametros, mensajes y pruebas aprobados | Matriz real por proyecto/contrato, vigencia y combinaciones prohibidas | TDD, integracion R03 y evidencia | Director de Operaciones | NO_EJECUTABLE |
| I9-R06 | Parametros, mensajes y pruebas aprobados | Catalogos I3/I5, mapeos, vigencias y responsables de subsanacion | Adaptadores, TDD y evidencia | Talento Humano valida; Director de Operaciones aprueba | NO_EJECUTABLE |
| I9-R07 | Motivos iniciales, parametros, mensajes y pruebas aprobados | Catalogo institucional de motivos, fuente, version y vigencia | TDD, snapshot/inmutabilidad y evidencia | Director de Operaciones | NO_EJECUTABLE |

## Paquetes De Trabajo Institucional

### WP-I9-A - Concepto Juridico R01

**Responsable de validacion:** Juridica.

**Insumos requeridos:**

- concepto sobre la convivencia de la Ley 1920 de 2018 y el articulo 167A del
  Codigo Sustantivo del Trabajo modificado por la Ley 2466 de 2025;
- fuentes oficiales, fecha/version y vigencia aplicable;
- criterio institucional de conservacion del acuerdo escrito; y
- decision sobre mensajes y pruebas de fronteras diaria/semanal.

**Criterio de salida:** documento identificado, versionado y aprobado por el
rol competente; la marca del sistema no reemplaza escrito ni firmas.

**Formato preparado:**
`docs/operations/2026-08-14-i9-wp-a-formato-concepto-juridico-r01.md`, con
estado `LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_JURIDICA_NO_EJECUTABLE`. Su
preparacion no completa WP-I9-A ni autoriza implementacion.

### WP-I9-B - Catalogos Operativos R02 Y R07

**Responsable de validacion:** Director de Operaciones.

**Insumos requeridos:**

- catalogo institucional versionado de motivos de descanso excepcional R02;
- catalogo institucional versionado de motivos de desviacion R07;
- vigencia, alcance, responsable de mantenimiento y estados; y
- confirmacion de que `OTHER` exige descripcion y no sustituye aprobacion.

**Criterio de salida:** una version vigente por catalogo, sin codigos inventados
ni motivos implicitos.

**Formato preparado:**
`docs/operations/2026-08-14-i9-wp-b-formato-catalogos-motivos-r02-r07.md`, con
estado `LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_OPERACIONES_NO_EJECUTABLE`. Su
preparacion no completa WP-I9-B ni autoriza implementacion.

### WP-I9-C - Catalogo De Novedades R04

**Responsables de validacion:** Talento Humano y Operaciones.

**Insumos requeridos:**

- sistema fuente y codigos/estados reales para las doce categorias canonicas;
- mapeos pendientes de licencia/calamidad, suspension/retiro,
  capacitacion/induccion, disponible y novedad administrativa;
- vigencias, version activa, responsables y reglas de deprecacion; y
- evidencia de que valores desconocidos permanecen `UNKNOWN`.

**Criterio de salida:** mapeo completo, versionado, sin solapamientos activos y
validado en la frontera con I3/I5.

**Formato preparado:**
`docs/operations/2026-08-14-i9-wp-c-formato-catalogo-mapeo-novedades-r04.md`,
con estado
`LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_TH_OPERACIONES_NO_EJECUTABLE`. Los
codigos reales, versiones, vigencias y decisiones permanecen `PENDIENTE`; su
preparacion no completa WP-I9-C ni autoriza implementacion.

### WP-I9-D - Matriz De Traslados R05

**Responsable de validacion:** Director de Operaciones.

**Insumos requeridos:**

- identificadores reales de proyecto/contrato, puesto, origen y destino;
- tiempos enteros en minutos y direccion de cada relacion;
- combinaciones expresamente prohibidas y su fuente;
- version, vigencia, responsable y criterio de cambio; y
- dataset anonimo de prueba con fila existente, ausente y prohibida.

**Criterio de salida:** matriz versionada y validada; una ausencia nunca se
interpreta como cero.

### WP-I9-E - Requisitos Del Puesto R06

**Responsables de validacion:** Talento Humano valida; Director de Operaciones
aprueba la excepcion operativa.

**Insumos requeridos:**

- catalogos reales de requisitos de I3/I5 y su contrato de integracion;
- codigos, categorias, estados, evidencia y vigencias;
- configuracion explicita de subsanabilidad;
- responsable de subsanacion y fecha limite; y
- version, alcance y responsable de mantenimiento.

**Criterio de salida:** todos los codigos reales estan mapeados o producen
`UNVERIFIED`; la ausencia de informacion no acredita cumplimiento.

## Orden Tecnico Posterior

El trabajo tecnico comienza solamente despues de aprobar este plan y recibir el
insumo institucional de la regla correspondiente.

| Orden | Tarea tecnica | Dependencias | Aceptacion | Verificacion |
|---:|---|---|---|---|
| 1 | Contratos versionados y validadores de configuracion | WP-I9-A a WP-I9-E segun regla | Rechaza datos incompletos, duplicados o sin vigencia | RED/GREEN de contrato y configuracion |
| 2 | I9-R01 e I9-R02 | WP-I9-A y WP-I9-B | Bordes diarios/semanales y descanso producen resultado explicable | TDD unitario e integracion |
| 3 | I9-R03 e I9-R05 | WP-I9-D | Solapamiento absoluto y traslado direccional conservan prioridad | TDD unitario, integracion y fronteras |
| 4 | I9-R04 e I9-R06 | WP-I9-C y WP-I9-E | Adaptadores desconocidos son seguros; excepciones no se reutilizan | TDD de adaptadores, vigencias y workflow |
| 5 | I9-R07 | WP-I9-B | Snapshot de plantilla detecta y audita desviaciones | TDD de ciclos, edicion e inmutabilidad |
| 6 | Regresion integral I9-R01 a R07 | Tareas 1 a 5 | Ninguna excepcion elude bloqueos absolutos | Suite hermetica y evidencia anonimizada |

Cada tarea tecnica debe convertirse en una tarea SDD independiente, con un
maximo aproximado de cinco archivos, RED previo, GREEN verificable y revision
humana antes de avanzar al siguiente checkpoint.

## Checkpoints

### Checkpoint 1 - Autoridad Y Datos

- [ ] WP-I9-A a WP-I9-E tienen fuente, version/vigencia y responsable.
- [ ] No quedan valores institucionales inferidos ni `PENDIENTE` interpretados.
- [ ] Juridica, Talento Humano y Operaciones validan lo que les corresponde.

### Checkpoint 2 - Contratos

- [ ] Los catalogos y matrices incompletos fallan de forma segura.
- [ ] Las versiones activas son unicas y los snapshots son inmutables.
- [ ] Los permisos y rutas de aprobacion coinciden con lo aprobado.

### Checkpoint 3 - Reglas

- [ ] Mensajes y pruebas aprobados estan implementados mediante TDD.
- [ ] R01/R03/R05 conservan sus bloqueos absolutos.
- [ ] Las excepciones R02/R04/R05/R06/R07 no son reutilizables.

### Checkpoint 4 - Gate 2

- [ ] Suite hermetica completa en verde y evidencia anonimizada.
- [ ] Matriz de parametrizacion sin campos obligatorios pendientes.
- [ ] Decision humana explicita para cada cambio de estado.
- [ ] Solo entonces puede proponerse el cierre de Gate 2; no es automatico.

## Riesgos Y Controles

| Riesgo | Impacto | Control |
|---|---|---|
| Activar una regla con catalogo incompleto | Alto | Estado no ejecutable y prueba negativa por regla |
| Confundir aprobacion funcional con politica institucional | Alto | Fuente/version y aprobacion del rol competente obligatorias |
| Reutilizar excepciones | Alto | Alcance exacto y snapshot inmutable por asignacion |
| Cambiar historicos al actualizar catalogos | Alto | Versiones y snapshots; cambios solo en evaluaciones futuras |
| Inventar fechas o responsables | Alto | Campos permanecen pendientes hasta evidencia explicita |

## Decision Registrada

El usuario aprobo explicitamente:

1. los cinco paquetes institucionales y sus responsables;
2. el orden tecnico posterior por dependencias;
3. los cuatro checkpoints de control; y
4. la regla de que esta aprobacion no autoriza implementar ni activar reglas.

Los paquetes pueden recopilar insumos documentales en paralelo, pero ninguna
tarea tecnica comienza sin autorizacion SDD posterior y sin que su dependencia
institucional tenga evidencia suficiente.
