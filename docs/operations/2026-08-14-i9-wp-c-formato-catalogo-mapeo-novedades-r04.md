# I9 WP-C - Formato De Catalogo Y Mapeo De Novedades R04

> Estado: **LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_TH_OPERACIONES_NO_EJECUTABLE**
> Fecha de preparacion: 2026-08-14
> Responsables de validacion: Talento Humano y Operaciones.
> Efecto: este formato no constituye catalogo institucional aprobado ni autoriza implementacion, excepciones o activacion de I9-R04.

## Proposito Y Regla De Diligenciamiento

Este formato permite documentar, sin inventar codigos institucionales, como
los valores reales de cada sistema fuente se traducen a las doce categorias
canonicas ya aprobadas para I9-R04. Cada mapeo debe conservar evidencia,
version, vigencia y aprobacion conjunta de Talento Humano y Operaciones.

Un valor desconocido permanece `UNKNOWN`: no se aproxima por texto, prefijo,
semejanza ni significado supuesto. `D`, `N` y `X` son codigos de programacion,
no codigos de novedades, y deben rechazarse en este contrato.

## Identificacion Y Gobierno Del Catalogo

| Campo | Valor a diligenciar | Evidencia requerida |
|---|---|---|
| Identificador del catalogo | PENDIENTE | Codigo institucional unico |
| Nombre institucional | PENDIENTE | Denominacion aprobada |
| Version activa | PENDIENTE | Numero o identificador de version |
| Estado de la version | PENDIENTE | Borrador, aprobada, retirada u otro estado definido |
| Vigente desde | PENDIENTE | Fecha real de inicio |
| Vigente hasta | PENDIENTE | Fecha real o criterio de vigencia abierta |
| Sistemas fuente incluidos | PENDIENTE | Nombre y responsable de cada sistema |
| Propietario funcional | PENDIENTE | Persona o rol de Talento Humano |
| Validador operativo | PENDIENTE | Persona o rol de Operaciones |
| Evidencia de aprobacion conjunta | PENDIENTE | Acta, ticket, documento o referencia verificable |

## Cobertura De Categorias Canonicas

La columna `Tratamiento funcional base` proviene del contrato funcional
aprobado y no equivale a un codigo institucional. Las columnas de fuente y
codigo permanecen pendientes hasta recibir evidencia real.

| Categoria canonica | Tratamiento funcional base | Sistema fuente real | Codigo real | Estado real | Evidencia | Confirmacion TH | Confirmacion Operaciones |
|---|---|---|---|---|---|---|---|
| INCAPACITY_ACTIVE | Bloqueo absoluto | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| VACATION_APPROVED_ACTIVE | Bloqueo absoluto | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| LEAVE_OR_CALAMITY_ACTIVE | Bloqueo absoluto | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| SUSPENSION_OR_TERMINATION_ACTIVE | Bloqueo absoluto | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| ABSENCE_CONFIRMED | Bloqueo absoluto | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| ABSENCE_PENDING_CONFIRMATION | Excepcion aprobable | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| TRAINING_OR_INDUCTION_OVERLAP | Excepcion aprobable | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| AVAILABLE | Informativa | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| ADDITIONAL_SHIFT | Excepcion aprobable sujeta a I9-R01 e I9-R02 | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| ADMINISTRATIVE_EVENT | Informativa salvo indisponibilidad formal | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| EXPIRED_OR_CANCELLED | Sin efecto sobre disponibilidad | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| UNKNOWN | Advertencia segura; no infiere disponibilidad ni aprobacion | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Registro Detallado De Mapeos

Se agrega una fila por cada combinacion real. Ningun campo obligatorio puede
quedar `PENDIENTE` al aprobar una version.

| sourceSystem | sourceCode | sourceStatus | semanticCategory | mappingVersion | effectiveFrom | effectiveTo | mappedBy | approvedBy | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Referencia Simulada Que Requiere Confirmacion Institucional

Estos cinco mapeos proceden del historico simulado aprobado como referencia
funcional. No son codigos oficiales, no prueban la existencia de un sistema
fuente y deben permanecer pendientes de confirmacion institucional.

| Referencia simulada | Estado simulado | Categoria propuesta | Confirmacion institucional | Evidencia real |
|---|---|---|---|---|
| INC | Vigente | INCAPACITY_ACTIVE | PENDIENTE | PENDIENTE |
| V | Aprobada y vigente | VACATION_APPROVED_ACTIVE | PENDIENTE | PENDIENTE |
| A | Confirmada | ABSENCE_CONFIRMED | PENDIENTE | PENDIENTE |
| A | Pendiente de confirmar | ABSENCE_PENDING_CONFIRMATION | PENDIENTE | PENDIENTE |
| TA | Vigente | ADDITIONAL_SHIFT | PENDIENTE | PENDIENTE |

## Reglas De Integridad Del Catalogo

1. `CAT-I9-C-01`: `sourceSystem`, `sourceCode`, `sourceStatus`,
   `semanticCategory`, `mappingVersion`, `effectiveFrom`, `mappedBy` y
   `approvedBy` son obligatorios para un mapeo aprobado.
2. `CAT-I9-C-02`: no puede existir mas de un mapeo activo para la misma terna
   `sourceSystem + sourceCode + sourceStatus`.
3. `CAT-I9-C-03`: una version activa debe ser unica dentro del alcance definido.
4. `CAT-I9-C-04`: todo codigo o estado no mapeado produce `UNKNOWN`.
5. `CAT-I9-C-05`: se prohibe el mapeo aproximado por texto, prefijo o semejanza.
6. `CAT-I9-C-06`: `D`, `N` y `X` se rechazan como novedades.
7. `CAT-I9-C-07`: cada evaluacion conserva snapshot del codigo, estado,
   categoria y version utilizados.
8. `CAT-I9-C-08`: retirar o deprecar un mapeo exige fecha, motivo y reemplazo
   cuando corresponda.
9. `CAT-I9-C-09`: una nueva version no modifica evaluaciones historicas.
10. `CAT-I9-C-10`: Talento Humano y Operaciones validan conjuntamente cada
    version antes de proponer su activacion.
11. `CAT-I9-C-11`: todo mapeo aprobado conserva una referencia de evidencia
    verificable del sistema fuente.
12. `CAT-I9-C-12`: completar este formato no activa I9-R04 ni cierra Gate 2.

## Versionamiento Y Deprecacion

| Decision | Valor a diligenciar | Evidencia |
|---|---|---|
| Convencion de version | PENDIENTE | Norma o acuerdo institucional |
| Criterio de nueva version | PENDIENTE | Cambio de codigo, estado, semantica o fuente |
| Responsable de publicar | PENDIENTE | Persona o rol autorizado |
| Procedimiento de deprecacion | PENDIENTE | Pasos, motivo, fecha y reemplazo |
| Tratamiento de historicos | Snapshot inmutable | Prueba de no alteracion retroactiva |
| Frontera con I3 | PENDIENTE | Contrato, version y prueba de adaptador |
| Frontera con I5 | PENDIENTE | Contrato, version y prueba de adaptador |

## Decisiones Institucionales

| Rol | Nombre | Decision | Fecha | Evidencia | Observaciones |
|---|---|---|---|---|---|
| Talento Humano | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Operaciones | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Checklist De Cierre WP-I9-C

- [ ] Las doce categorias canonicas tienen cobertura institucional explicita.
- [ ] Cada combinacion real identifica sistema, codigo y estado de origen.
- [ ] Los cinco mapeos simulados fueron confirmados o reemplazados con evidencia.
- [ ] Los valores no reconocidos permanecen `UNKNOWN`.
- [ ] No existen mapeos activos solapados para la misma terna de origen.
- [ ] La version, vigencia y alcance estan diligenciados.
- [ ] El propietario funcional y el responsable operativo estan identificados.
- [ ] La deprecacion y el tratamiento historico estan definidos.
- [ ] Las fronteras con I3 e I5 tienen contrato y evidencia de validacion.
- [ ] Talento Humano registro su decision y evidencia.
- [ ] Operaciones registro su decision y evidencia.
- [ ] Existe decision SDD posterior antes de implementar o activar I9-R04.

## Criterio De Salida

WP-I9-C solo puede proponerse como completo cuando las doce categorias estan
mapeadas con datos reales o tratadas explicitamente como no reconocidas hacia
`UNKNOWN`, existe una sola version activa sin solapamientos, las fronteras con
I3/I5 estan validadas y Talento Humano y Operaciones registraron su aprobacion
con evidencia. Hasta entonces, I9-R04 permanece no ejecutable y Gate 2 sigue
bloqueado.
