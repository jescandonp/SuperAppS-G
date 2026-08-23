# I9 WP-E - Formato De Requisitos Del Puesto R06

> Estado: **LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_TH_OPERACIONES_NO_EJECUTABLE**
> Fecha de preparacion: 2026-08-14
> Responsables: Talento Humano valida; Director de Operaciones aprueba la excepcion operativa.
> Efecto: este formato no constituye catalogo institucional aprobado ni autoriza implementacion, excepciones o activacion de I9-R06.

## Proposito Y Regla De Diligenciamiento

Este formato permite recopilar los catalogos reales de requisitos de I3/I5 y
su contrato de integracion sin inventar codigos, estados, evidencias,
vigencias, responsables nominales ni fechas limite. Los valores
institucionales permanecen `PENDIENTE` hasta contar con fuente verificable y
decision de los roles competentes.

La ausencia de informacion nunca acredita cumplimiento. Todo codigo o estado
desconocido permanece `UNVERIFIED`; no se aproxima por nombre, texto, prefijo,
categoria o semejanza. Talento Humano valida los datos, la evidencia y la
subsanabilidad. El Director de Operaciones aprueba la excepcion operativa, sin
sustituir la validacion de Talento Humano.

## Estado Y Decision De Control

Estos marcadores son controles documentales, no valores institucionales ni
configuracion ejecutable. Cualquier cambio requiere evidencia completa y una
decision SDD posterior.

| Campo canonico | Valor obligatorio mientras WP-I9-E permanezca pendiente |
|---|---|
| TECHNICAL_IMPLEMENTATION_AUTHORIZED | NO |
| I9_R06_ACTIVE | NO |
| TASK_13_STATUS | OPEN |
| GATE_2_STATUS | BLOCKED |

## Identificacion Y Gobierno Del Catalogo

| Campo | Valor a diligenciar | Evidencia requerida |
|---|---|---|
| Identificador institucional del catalogo | PENDIENTE | Codigo institucional unico |
| Sistemas fuente I3/I5 | PENDIENTE | Nombre real, propietario y frontera de cada sistema |
| Version activa | PENDIENTE | Numero o identificador de version |
| Estado de la version | PENDIENTE | Borrador, aprobada, retirada u otro estado definido |
| Alcance | PENDIENTE | Proyecto o contrato, puesto y poblacion aplicable |
| Vigente desde | PENDIENTE | Fecha y hora reales de inicio |
| Vigente hasta | PENDIENTE | Fecha y hora real o criterio de vigencia abierta |
| Fuente institucional | PENDIENTE | Catalogo, procedimiento, contrato o evidencia verificable |
| Responsable de mantenimiento | PENDIENTE | Persona o rol autorizado |
| Evidencia de aprobacion de la version | PENDIENTE | Acta, ticket, documento o referencia verificable |

## Contrato De Integracion I3/I5

Se debe diligenciar una fila por sistema y version de contrato. Una interfaz,
ruta o campo no documentado se considera `PENDIENTE` y no puede usarse para
decidir cumplimiento. El contrato debe exponer los campos que permitan crear
el registro individual descrito en la seccion siguiente.
`sourceEmployeeKeyField` identifica el nombre del campo fuente usado para
obtener o resolver el `employeeId` no nominal de I2. Su valor permanece
`PENDIENTE`; no puede reemplazarse por nombre, numero de documento, correo,
telefono ni otro dato personal.

| Sistema fuente | Version del contrato | Interfaz o ruta | sourceEmployeeKeyField | Identificador de puesto | Codigo de requisito | Estado | Evidencia | Vigencia | Responsable tecnico | Evidencia del contrato |
|---|---|---|---|---|---|---|---|---|---|---|
| PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Evaluaciones Individuales I3/I5

Cada acreditacion o evaluacion recibida desde I3/I5 se registra con una clave
propia `evaluationId`. `employeeId` es la referencia no nominal de I2 que
correlaciona el requisito con el guarda evaluado; no contiene nombre, documento
de identidad ni otro dato personal. El registro vincula empleado, requisito,
puesto o alcance, evidencia, vigencia y snapshot sin modificar el mapeo
canonico.

| evaluationId | employeeId | sourceSystem | sourceRequirementCode | sourceStatus | positionOrScopeId | evidenceType | evidenceReference | effectiveFrom | effectiveTo | snapshotVersion | evaluatedAt |
|---|---|---|---|---|---|---|---|---|---|---|---|
| PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Categorias Canonicas Y Cobertura

Las categorias siguientes son el contrato funcional aprobado de I9-R06. No
son codigos oficiales de I3/I5 y no permiten inferir un mapeo institucional.

| Categoria canonica | Codigo real I3/I5 | Estado fuente real | Tipo de evidencia real | Vigencia real | Decision TH |
|---|---|---|---|---|---|
| COURSE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| ACCREDITATION | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| CERTIFICATION | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| LICENSE_OR_PERMIT | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| OTHER_REQUIREMENT | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Tabla De Mapeo Institucional

Se agrega una fila por combinacion real de sistema, codigo, estado, alcance y
periodo. Cada fila conserva su trazabilidad completa y un identificador unico,
sin depender de un empleado. `mappingId`, `sourceSystem`,
`sourceRequirementCode`, `sourceStatus`, `canonicalCategory`, `mappingVersion`,
`effectiveFrom`, `effectiveTo`, `evidenceType`, `verifiedBy`, `validationDate`,
`approvedBy`, `approvalDate` y `mappingEvidence` son obligatorios antes de
proponer un mapeo como vigente.

| mappingId | sourceSystem | sourceRequirementCode | sourceStatus | canonicalCategory | requirementName | positionOrScopeId | evidenceType | evidenceStatus | effectiveFrom | effectiveTo | mappingVersion | subsanable | remediationOwner | remediationDeadline | verifiedBy | validationDate | approvedBy | approvalDate | mappingEvidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Configuracion De Subsanabilidad

`subsanable` requiere configuracion explicita y versionada. Solo el valor
institucional que se diligencie con fuente puede habilitar el tratamiento
`INFORMATIVE_REMEDIABLE`. El responsable de subsanacion y la fecha limite son
obligatorios para ese tratamiento; su ausencia invalida la configuracion y no
equivale a cumplimiento.

| Codigo real | Estado real | Subsanable | Tratamiento autorizado | Responsable de subsanacion | Fecha limite | Fuente | Version | Validacion TH |
|---|---|---|---|---|---|---|---|---|---|
| PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Dataset Anonimo De Validacion

Los casos deben usar un `employeeId` anonimo y no incluir datos personales ni
evidencia sensible. Esta clave correlaciona requisito y guarda sin registrar su
nombre o documento. Los resultados esperados reflejan el contrato funcional;
los valores de entrada institucionales permanecen pendientes.

| Caso requerido | employeeId anonimo | Codigo/estado anonimo | Evidencia/vigencia anonima | Configuracion de subsanabilidad | Resultado esperado | Evidencia |
|---|---|---|---|---|---|---|
| Requisito vigente | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | COMPLIANT solo con evidencia verificable y vigencia durante todo el turno | PENDIENTE |
| Requisito faltante | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | MISSING; excepcion PENDIENTE | PENDIENTE |
| Requisito vencido | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | EXPIRED; excepcion PENDIENTE | PENDIENTE |
| Codigo o estado desconocido | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | UNVERIFIED; nunca presume cumplimiento | PENDIENTE |
| Subsanable informativo | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | INFORMATIVE_REMEDIABLE solo con configuracion completa | PENDIENTE |

## Reglas De Integridad Y Seguridad

1. `REQ-I9-E-01`: cada evaluacion exige `evaluationId`, `employeeId`, sistema
   fuente, codigo, estado, alcance, snapshot y vigencia identificados.
2. `REQ-I9-E-02`: un codigo o estado sin mapeo exacto produce `UNVERIFIED`; no
   se aproxima por nombre, texto, prefijo o semejanza.
3. `REQ-I9-E-03`: la ausencia de requisito, evidencia, estado o vigencia nunca
   produce `COMPLIANT`.
4. `REQ-I9-E-04`: la evidencia y la acreditacion deben permanecer vigentes
   durante todo el turno evaluado.
5. `REQ-I9-E-05`: no puede existir mas de un mapeo activo para el mismo
   sistema fuente, codigo, estado, alcance y periodo.
6. `REQ-I9-E-06`: `subsanable` solo tiene efecto con configuracion explicita,
   versionada y validada por Talento Humano.
7. `REQ-I9-E-07`: todo tratamiento subsanable informativo exige responsable
   de subsanacion y fecha limite; si falta alguno, la configuracion es invalida.
8. `REQ-I9-E-08`: la validacion de Talento Humano no sustituye la aprobacion
   de la excepcion por el Director de Operaciones.
9. `REQ-I9-E-09`: una excepcion cubre solo guarda, requisito, puesto, turno y
   version evaluados; nunca se reutiliza.
10. `REQ-I9-E-10`: cada evaluacion conserva snapshot de `employeeId`, codigos,
    estados, evidencia, vigencias, subsanabilidad, decisiones y version
    utilizadas.
11. `REQ-I9-E-11`: una nueva version no modifica evaluaciones historicas ni
    elude bloqueos absolutos de otras reglas.
12. `REQ-I9-E-12`: completar este formato no activa I9-R06 ni cierra Gate 2.

## Versionamiento Y Mantenimiento

| Decision | Valor a diligenciar | Evidencia |
|---|---|---|
| Convencion de version | PENDIENTE | Norma o acuerdo institucional |
| Criterio de nueva version | PENDIENTE | Cambio de codigo, estado, evidencia, vigencia, alcance o subsanabilidad |
| Responsable de mantenimiento | PENDIENTE | Persona o rol autorizado |
| Responsable de publicar | PENDIENTE | Persona o rol autorizado |
| Tratamiento de requisitos retirados | PENDIENTE | Fecha, motivo y reemplazo cuando corresponda |
| Tratamiento de evaluaciones historicas | Snapshot inmutable | Evidencia funcional aprobada; falta implementacion y prueba |

## Decision Institucional

| Rol | Nombre | Decision | Fecha | Evidencia | Observaciones |
|---|---|---|---|---|---|
| Talento Humano | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |
| Director de Operaciones | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Checklist De Cierre WP-I9-E

- [ ] Los catalogos reales I3/I5 y sus propietarios estan identificados.
- [ ] El contrato de integracion esta versionado y respaldado por evidencia.
- [ ] Cada codigo y estado real tiene mapeo exacto o resultado `UNVERIFIED`.
- [ ] Las categorias, evidencias y vigencias estan diligenciadas por alcance.
- [ ] No existen mapeos activos solapados para la misma clave y periodo.
- [ ] La subsanabilidad esta configurada explicitamente para cada caso aplicable.
- [ ] Todo subsanable informativo tiene responsable y fecha limite.
- [ ] La version, alcance y responsable de mantenimiento estan diligenciados.
- [ ] Evaluaciones y dataset correlacionan mediante `employeeId` no nominal; el mapeo canonico permanece independiente y el dataset cubre vigente, faltante, vencido, desconocido y subsanable.
- [ ] Talento Humano registro validacion y evidencia.
- [ ] El Director de Operaciones registro aprobacion de la excepcion y evidencia.
- [ ] Existe decision SDD posterior antes de implementar o activar I9-R06.

## Criterio De Salida

WP-I9-E solo puede proponerse como completo cuando los catalogos reales I3/I5
y su contrato de integracion estan identificados, versionados y vigentes; todos
los codigos reales estan mapeados o producen `UNVERIFIED`; la subsanabilidad,
los responsables y las fechas limite estan respaldados; Talento Humano registro
su validacion y el Director de Operaciones registro su aprobacion con evidencia.
Hasta entonces, I9-R06 permanece no ejecutable y Gate 2 sigue bloqueado.
