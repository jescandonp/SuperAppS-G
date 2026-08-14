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
| I9-R02 | Umbral preventivo global de 12 h; excepcion por turno antes de aprobar/publicar | Mensajes, pruebas y evidencia institucional | Director de Operaciones | PENDIENTE_DE_PARAMETROS |
| I9-R03 | Solapamiento real bloqueante; traslado se remite a I9-R05 | Mensajes, fronteras temporales y enlace validado con R05 | Operaciones | PENDIENTE_DE_PARAMETROS |
| I9-R04 | Novedades clasificadas como bloqueo, excepcion o informacion | Mapeo de codigos y estados reales de novedades | Talento Humano y Operaciones | PENDIENTE_DE_PARAMETROS |
| I9-R05 | Matriz de traslados por proyecto/contrato; sin valor universal | Matriz real origen-destino y combinaciones prohibidas | Operaciones | PENDIENTE_DE_PARAMETROS |
| I9-R06 | No bloquea propuesta; excepcion antes de aprobar/publicar | Catalogos reales I3/I5, vigencias y responsables de subsanacion | Talento Humano y Operaciones | PENDIENTE_DE_PARAMETROS |
| I9-R07 | Plantilla obligatoria; desviacion con aprobacion auditada | Motivos autorizados y responsables de excepcion | Operaciones | PENDIENTE_DE_PARAMETROS |

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
| Mensajes y pruebas | PENDIENTE | Casos menor, igual y mayor a 12 h |

### I9-R03 - Cruces

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Solapamiento real | Bloqueo absoluto | Pruebas con fecha y hora completas |
| Turnos exactamente adyacentes | No son solapamiento | Prueba de frontera exacta |
| Puestos distintos | Evaluar traslado mediante I9-R05 | Integracion con matriz vigente |
| Mensajes y pruebas temporales | PENDIENTE | Nocturnos, cambio de mes/ano y zonas horarias aplicables |

### I9-R04 - Novedades

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Codigos que bloquean | PENDIENTE | Mapeo a incapacidad, vacaciones, licencia/calamidad, suspension/retiro y ausencia confirmada |
| Codigos con excepcion | PENDIENTE | Mapeo a ausencia por confirmar, capacitacion/induccion y turno adicional |
| Codigos informativos | PENDIENTE | Mapeo a disponible y novedad administrativa |
| Estados sin efecto | Vencida o anulada | Estados reales equivalentes |
| Fuente y version | PENDIENTE | Catalogo institucional de novedades |
| Mensajes y pruebas de prioridad | PENDIENTE | Coincidencia bloqueo/excepcion/informacion |

### I9-R05 - Ubicacion Y Traslado

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Proyecto/contrato | PENDIENTE | Identificador y vigencia |
| Origen, destino y tiempo requerido | PENDIENTE | Matriz versionada; unidad en minutos |
| Combinaciones prohibidas | PENDIENTE | Fuente contractual u operativa |
| Valor ausente | Advertencia y excepcion PENDIENTE; nunca cero | Prueba de ausencia de fila |
| Tiempo insuficiente | Excepcion PENDIENTE | Pruebas menor, igual y mayor al requerido |
| Trafico/rutas dinamicas | Fuera del MVP | Confirmacion de alcance |

### I9-R06 - Requisitos Del Puesto

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Catalogo de requisitos por puesto | PENDIENTE | Integracion y version de I3/I5 |
| Tipos y vigencias de acreditacion | PENDIENTE | Campos y estados reales |
| Faltante, vencido o no verificado | Excepcion PENDIENTE; no bloquea propuesta | Prueba de bloqueo de aprobacion/publicacion |
| Requisito subsanable informativo | Solo configuracion explicita | Responsable, plazo y evidencia |
| Responsable de subsanacion | PENDIENTE | Rol autorizado |
| Mensajes y pruebas | PENDIENTE | Cumplido, faltante, vencido, no verificado e informativo |

### I9-R07 - Desviacion De Plantilla

| Campo | Valor actual | Evidencia requerida |
|---|---|---|
| Plantillas base | 2X2, 4X2 y 6X1; otras solo si estan aprobadas | Version vigente por proyecto |
| Obligatoriedad | Obligatoria por defecto | Prueba de desviacion automatica y manual |
| Motivos autorizados | PENDIENTE | Catalogo versionado |
| Rol aprobador | PENDIENTE | Permiso y responsable institucional |
| Efecto de desviacion | Excepcion PENDIENTE; impide aprobar/publicar | Prueba de workflow |
| Cambio de version | Solo borradores futuros | Prueba de inmutabilidad de programacion aprobada |

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
