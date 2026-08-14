# Matriz De Parametrizacion De Reglas I9

> Estado: **BORRADOR_PARA_DILIGENCIAMIENTO_NO_EJECUTABLE**
> Fecha: 2026-08-13
> Alcance: preparar el cierre del Gate 2 sin inventar parametros ni activar reglas.

## Regla De Uso

Esta matriz traduce las decisiones funcionales aprobadas para I9-R01 a I9-R07
en insumos verificables. No reemplaza el catalogo rector, no constituye una
politica institucional y no autoriza ejecucion en el motor.

Una regla solo puede proponerse para estado ejecutable cuando todos sus campos
obligatorios tengan valor, unidad, fuente, version o fecha de vigencia, alcance,
responsable, mensajes, pruebas y aprobacion institucional. `PENDIENTE` nunca se
interpreta como cero, falso, vacio permitido o valor por defecto.

## Resumen De Preparacion

| Regla | Decision funcional aprobada | Insumo pendiente principal | Ruta de validacion | Estado |
|---|---|---|---|---|
| I9-R01 | Limites ordinarios y sectoriales con aprobacion obligatoria entre 10 y 12 h | Revision juridica de la armonizacion Ley 1920/2018 y articulo 167A CST; vigencia | Juridica y Operaciones | PROPUESTA_JURIDICA_EN_REVISION_NO_EJECUTABLE |
| I9-R02 | Umbral preventivo global de 12 h; excepcion por turno antes de aprobar/publicar | Implementacion TDD, ejecucion de pruebas y evidencia institucional | Director de Operaciones | PARAMETROS_FUNCIONALES_APROBADOS_NO_EJECUTABLE |
| I9-R03 | Solapamiento global bloqueante sobre intervalo [inicio, fin); traslado se remite a I9-R05 | Implementacion TDD, ejecucion de pruebas, enlace validado con R05 y evidencia | Operaciones | PARAMETROS_FUNCIONALES_APROBADOS_NO_EJECUTABLE |
| I9-R04 | Novedades clasificadas; mapeo inicial, contrato, mensajes y pruebas aprobados | Codigos institucionales restantes, fuente/version, implementacion TDD y evidencia | Talento Humano y Operaciones | PARAMETROS_FUNCIONALES_PARCIALES_APROBADOS_NO_EJECUTABLE |
| I9-R05 | Matriz de traslados por proyecto/contrato; parametros, mensajes y pruebas aprobados | Matriz real, fuente/version, TDD y evidencia | Director de Operaciones | PARAMETROS_FUNCIONALES_APROBADOS_NO_EJECUTABLE |
| I9-R06 | No bloquea propuesta; parametros, mensajes y pruebas aprobados | Catalogos reales I3/I5, fuente/version, TDD y evidencia | Talento Humano valida; Director de Operaciones aprueba | PARAMETROS_FUNCIONALES_APROBADOS_NO_EJECUTABLE |
| I9-R07 | Plantilla obligatoria; propuesta detallada de motivos, parametros, mensajes y pruebas | Aprobacion de parametros; catalogo institucional de motivos, fuente/version, TDD y evidencia | Operaciones | PROPUESTA_DE_PARAMETROS_PARA_VALIDACION_NO_EJECUTABLE |

## Datos A Diligenciar

### I9-R01 - Jornada Maxima

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Jornada ordinaria diaria | 8 horas | Fuente juridica validada |
| Jornada ordinaria semanal | 42 horas | Fuente juridica y vigencia validadas |
| Maximo vigilancia diario | 12 horas | Fuente sectorial validada |
| Maximo vigilancia semanal | 60 horas | Fuente sectorial validada |
| Existencia de acuerdo escrito | Marca obligatoria para programar mas de 8 h; conserva responsable y fecha | Confirmacion explicita del usuario |
| Referencia, documento u otro soporte del acuerdo | Opcional; su ausencia no bloquea por si sola | Campo disponible para trazabilidad |
| Conservacion legal del acuerdo | La marca I9 no reemplaza escrito ni firmas; medio institucional PENDIENTE | Revision de Juridica sobre Ley 1920 de 2018, articulo 7 |
| Tratamiento mayor a 10 y hasta 12 h/dia | Excepcion PENDIENTE con aprobacion obligatoria; no bloquea propuesta | Decision del usuario; falta fuente/vigencia juridica |
| Rol aprobador de 10 a 12 h/dia | Director de Operaciones | Confirmacion explicita del usuario; permiso SCHEDULING/APPROVE_EXCEPTION |
| Tratamiento mayor a 12 h/dia | Bloqueo absoluto | Prueba de rechazo sin excepcion |
| Alcance | Todos los proyectos de vigilancia gestionados por I9; sin valor distinto por proyecto/contrato | Confirmacion explicita del usuario |
| Mensajes y pruebas de borde | PENDIENTE | Casos 8/10/12 h y 42/60 h |

Propuesta de referencia para revision:
`docs/operations/2026-08-13-i9-propuesta-juridica-jornada.md`. Su revision no
bloquea el desarrollo, pero I9-R01 permanece no ejecutable en produccion.

### I9-R02 - Descanso Minimo

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Umbral preventivo | 12 horas | Politica S&G aprobada y vigente |
| Efecto bajo el umbral | Excepcion PENDIENTE; no bloquea propuesta | Prueba de generacion y bloqueo de aprobacion/publicacion |
| Permiso aprobador | SCHEDULING/APPROVE_EXCEPTION | Matriz de permisos vigente |
| Rol aprobador | Director de Operaciones | Confirmacion explicita del usuario |
| Alcance | Todos los proyectos de vigilancia gestionados por I9; umbral unico | Confirmacion explicita del usuario |
| Vigencia de la autorizacion | Solo el turno y excepcion evaluados; no reutilizable | Auditoria por asignacion |
| Motivos autorizados | Reemplazo urgente; continuidad temporal; contingencia operativa; emergencia/fuerza mayor; solicitud excepcional del cliente; otro | Catalogo inicial aprobado por el usuario; requiere version y vigencia |
| Motivo Otro | Descripcion obligatoria | Prueba de rechazo sin descripcion |
| Efecto del motivo | No sustituye la aprobacion del Director de Operaciones | Prueba de workflow pendiente/aprobado |
| Modo durante desarrollo | Desactivada o advertencia; no ejecutable en produccion | Prueba de configuration gate |
| Mensajes y pruebas | APROBADO_FUNCIONALMENTE_NO_EJECUTABLE | `docs/operations/2026-08-13-i9-r02-mensajes-pruebas.md`; casos R02-T01 a R02-T16 |

### I9-R03 - Cruces

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Solapamiento real | Bloqueo absoluto | Pruebas con fecha y hora completas |
| Alcance | Todos los proyectos/puestos; borradores vigentes y programaciones aprobadas del guarda | Confirmacion explicita del usuario |
| Semantica del intervalo | Semiabierto [inicio, fin) | Prueba de frontera compartida |
| Turnos exactamente adyacentes | No son solapamiento | Prueba de frontera exacta |
| Puestos distintos | Evaluar traslado mediante I9-R05 | Integracion con matriz vigente |
| Cambios manuales | Revalidacion obligatoria antes de guardar/aprobar/publicar | Prueba de edicion |
| Prioridad frente a R05 | Excepcion de traslado nunca elude solapamiento | Prueba de precedencia absoluta |
| Modo durante desarrollo | Desactivada o validacion simulada; no ejecutable | Prueba de configuration gate |
| Mensajes y pruebas temporales | APROBADO_FUNCIONALMENTE_NO_EJECUTABLE | `docs/operations/2026-08-13-i9-r03-mensajes-pruebas.md`; casos R03-T01 a R03-T15 |

### I9-R04 - Novedades

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Codigos que bloquean | INC: incapacidad vigente; V: vacaciones aprobadas/vigentes; A confirmada: ausencia | Licencia/calamidad y suspension/retiro permanecen PENDIENTES |
| Codigos con excepcion | A pendiente de confirmar; TA sujeto a I9-R01/I9-R02 | Capacitacion/induccion permanece PENDIENTE |
| Codigos informativos | PENDIENTE | Mapeo a disponible y novedad administrativa |
| Codigos de programacion | D dia; N noche; X descanso; no son novedades | Historico simulado aprobado como fuente de mapeo inicial |
| Codigo desconocido | Advertencia; no infiere bloqueo, excepcion aprobada ni disponibilidad | Prueba de codigo no mapeado |
| Rol aprobador | Director de Operaciones | SCHEDULING/APPROVE_EXCEPTION |
| Alcance | Todos los proyectos de vigilancia gestionados por I9 | Confirmacion explicita del usuario |
| Estados sin efecto | Vencida o anulada | Estados reales equivalentes |
| Fuente y version | Historico simulado para mapeo inicial; catalogo institucional PENDIENTE | Validacion de Talento Humano y Operaciones |
| Contrato interno desacoplado | APROBADO_FUNCIONALMENTE_NO_EJECUTABLE | `docs/operations/2026-08-13-i9-r04-contrato-categorias-novedad.md`; 12 categorias canonicas |
| Mensajes y pruebas de prioridad | APROBADO_FUNCIONALMENTE_NO_EJECUTABLE | `docs/operations/2026-08-13-i9-r04-mensajes-pruebas.md`; casos R04-T01 a R04-T24 |

### I9-R05 - Ubicacion Y Traslado

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Proyecto/contrato | PENDIENTE | Identificador y vigencia |
| Origen, destino y tiempo requerido | PENDIENTE | Matriz versionada; unidad en minutos |
| Combinaciones prohibidas | PENDIENTE | Fuente contractual u operativa |
| Valor ausente | Advertencia y excepcion PENDIENTE; nunca cero | Prueba de ausencia de fila |
| Tiempo insuficiente | Excepcion PENDIENTE | Pruebas menor, igual y mayor al requerido |
| Trafico/rutas dinamicas | Fuera del MVP | Confirmacion de alcance |
| Parametros, mensajes y pruebas | APROBADO_FUNCIONALMENTE_NO_EJECUTABLE | `docs/operations/2026-08-13-i9-r05-parametros-mensajes-pruebas.md`; casos R05-T01 a R05-T20; aprobacion explicita del usuario |

### I9-R06 - Requisitos Del Puesto

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Catalogo de requisitos por puesto | PENDIENTE | Integracion y version de I3/I5 |
| Tipos y vigencias de acreditacion | PENDIENTE | Campos y estados reales |
| Faltante, vencido o no verificado | Excepcion PENDIENTE; no bloquea propuesta | Prueba de bloqueo de aprobacion/publicacion |
| Requisito subsanable informativo | Solo configuracion explicita | Responsable, plazo y evidencia |
| Responsable de subsanacion | PENDIENTE | Rol autorizado |
| Mensajes y pruebas | PENDIENTE | Cumplido, faltante, vencido, no verificado e informativo |
| Parametros, mensajes y pruebas | APROBADO_FUNCIONALMENTE_NO_EJECUTABLE | `docs/operations/2026-08-14-i9-r06-parametros-mensajes-pruebas.md`; casos R06-T01 a R06-T23; aprobacion explicita del usuario |

### I9-R07 - Desviacion De Plantilla

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Plantillas base | 2X2, 4X2 y 6X1; otras solo si estan aprobadas | Version vigente por proyecto |
| Obligatoriedad | Obligatoria por defecto | Prueba de desviacion automatica y manual |
| Motivos autorizados | PENDIENTE | Catalogo versionado |
| Rol aprobador | PENDIENTE | Permiso y responsable institucional |
| Efecto de desviacion | Excepcion PENDIENTE; impide aprobar/publicar | Prueba de workflow |
| Cambio de version | Solo borradores futuros | Prueba de inmutabilidad de programacion aprobada |
| Propuesta detallada | PROPUESTA_PARA_VALIDACION_NO_EJECUTABLE | `docs/operations/2026-08-14-i9-r07-parametros-mensajes-pruebas.md`; casos R07-T01 a R07-T23 |

## Criterio De Salida Del Subgate 2A

El Subgate 2A solo puede cerrarse cuando:

1. no exista ningun `PENDIENTE` en los campos requeridos para activar una regla;
2. cada dato tenga fuente, version/vigencia, alcance y responsable identificados;
3. Operaciones, Talento Humano y Juridica hayan validado las reglas que les correspondan;
4. esten aprobados los mensajes y los casos de prueba de borde;
5. exista una decision explicita por regla para cambiar su estado; y
6. el verificador documental y las pruebas negativas rechacen reglas incompletas.

Hasta ese cierre, las siete reglas permanecen no ejecutables y Gate 2 continua
bloqueado.
