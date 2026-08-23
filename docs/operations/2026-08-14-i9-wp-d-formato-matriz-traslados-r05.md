# I9 WP-D - Formato De Matriz De Traslados R05

> Estado: **LISTO_PARA_DILIGENCIAMIENTO_PENDIENTE_OPERACIONES_NO_EJECUTABLE**
> Fecha de preparacion: 2026-08-14
> Responsable de validacion: Director de Operaciones.
> Efecto: este formato no constituye matriz institucional aprobada ni autoriza implementacion, excepciones o activacion de I9-R05.

## Proposito Y Regla De Diligenciamiento

Este formato permite registrar, sin inventar proyectos, contratos, puestos,
tiempos ni restricciones, las relaciones reales de traslado que requiere
I9-R05. Cada fila representa un solo sentido: `A -> B` y `B -> A` son
relaciones independientes y pueden tener tiempos o restricciones diferentes.

Los tiempos se expresan en minutos enteros no negativos. Una relacion ausente
nunca se interpreta como cero. El unico caso que requiere cero minutos por
identidad es el mismo puesto exacto; puestos diferentes de la misma sede o zona
requieren una fila explicita.

## Identificacion Y Gobierno De La Matriz

| Campo | Valor a diligenciar | Evidencia requerida |
|---|---|---|
| Identificador de la matriz | PENDIENTE | Codigo institucional unico |
| Proyecto o contrato | PENDIENTE | Identificador real y alcance |
| Version activa | PENDIENTE | Numero o identificador de version |
| Estado de la version | PENDIENTE | Borrador, aprobada, retirada u otro estado definido |
| Vigente desde | PENDIENTE | Fecha y hora reales de inicio |
| Vigente hasta | PENDIENTE | Fecha y hora real o criterio de vigencia abierta |
| Fuente operativa | PENDIENTE | Estudio, contrato, procedimiento o evidencia verificable |
| Responsable de mantenimiento | PENDIENTE | Persona o rol autorizado |
| Responsable de aprobacion | Director de Operaciones | Confirmacion funcional aprobada; falta decision sobre esta version |
| Evidencia de aprobacion | PENDIENTE | Acta, ticket, documento o referencia verificable |

## Catalogo De Puestos Del Alcance

Cada identificador debe corresponder a un puesto real del proyecto o contrato.

| projectOrContractId | positionId | Nombre del puesto | Sede o zona | Vigente desde | Vigente hasta | Fuente | Estado |
|---|---|---|---|---|---|---|---|
| PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Relaciones Direccionales De Traslado

Se agrega una fila por sentido. `requiredMinutes` solo admite enteros no
negativos y `prohibited` debe ser `SI` o `NO`. Si `prohibited = SI`, la fuente
de prohibicion es obligatoria y la combinacion no admite excepcion.

| projectOrContractId | originPositionId | destinationPositionId | requiredMinutes | prohibited | restrictionSource | matrixVersion | effectiveFrom | effectiveTo | recordedBy | Evidencia |
|---|---|---|---:|---|---|---|---|---|---|---|
| PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Combinaciones Expresamente Prohibidas

Esta tabla facilita la revision de bloqueos absolutos. No reemplaza la fila
correspondiente de la matriz ni permite deducir prohibiciones por cercania,
zona, nombre o ausencia de relacion.

| Proyecto o contrato | Origen | Destino | Motivo de prohibicion | Fuente verificable | Version | Vigencia | Confirmacion Operaciones |
|---|---|---|---|---|---|---|---|
| PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Dataset Anonimo De Validacion

Los identificadores de prueba deben ser anonimos y no representar personas ni
datos sensibles. Los valores permanecen pendientes hasta que Operaciones
entregue un conjunto controlado.

| Caso requerido | Proyecto/contrato anonimo | Origen anonimo | Destino anonimo | Minutos o restriccion | Resultado esperado | Evidencia |
|---|---|---|---|---|---|---|
| Fila existente | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | Evalua la frontera configurada | PENDIENTE |
| Fila ausente | PENDIENTE | PENDIENTE | PENDIENTE | Sin fila | Excepcion PENDIENTE; nunca usa cero | PENDIENTE |
| Combinacion prohibida | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | Bloqueo absoluto sin excepcion | PENDIENTE |

## Reglas De Integridad De La Matriz

1. `MAT-I9-D-01`: proyecto o contrato, origen, destino, version y vigencia son
   obligatorios para cada relacion aprobada.
2. `MAT-I9-D-02`: `requiredMinutes` admite solamente minutos enteros no
   negativos.
3. `MAT-I9-D-03`: cada fila es direccional; una fila `A -> B` no crea `B -> A`.
4. `MAT-I9-D-04`: no puede existir mas de una relacion activa para la misma
   combinacion de proyecto o contrato, origen y destino.
5. `MAT-I9-D-05`: una relacion ausente produce excepcion `PENDIENTE` y nunca
   se interpreta como cero.
6. `MAT-I9-D-06`: el mismo puesto exacto requiere cero minutos por identidad;
   puestos distintos siempre requieren relacion explicita.
7. `MAT-I9-D-07`: una combinacion prohibida es bloqueo absoluto y no admite
   excepcion.
8. `MAT-I9-D-08`: una prohibicion exige motivo y fuente verificable.
9. `MAT-I9-D-09`: cada evaluacion conserva snapshot de relacion, version,
   vigencia, minutos y restriccion utilizados.
10. `MAT-I9-D-10`: una nueva version no modifica evaluaciones historicas.
11. `MAT-I9-D-11`: I9-R03 y las combinaciones prohibidas prevalecen sobre
    cualquier excepcion de traslado.
12. `MAT-I9-D-12`: completar este formato no activa I9-R05 ni cierra Gate 2.

## Versionamiento Y Cambio

| Decision | Valor a diligenciar | Evidencia |
|---|---|---|
| Convencion de version | PENDIENTE | Norma o acuerdo institucional |
| Criterio de nueva version | PENDIENTE | Cambio de puestos, tiempos, restriccion o alcance |
| Responsable de publicar | PENDIENTE | Persona o rol autorizado |
| Tratamiento de relaciones retiradas | PENDIENTE | Fecha, motivo y reemplazo cuando corresponda |
| Tratamiento de borradores existentes | Snapshot inmutable; regenerar usa version vigente | Prueba funcional aprobada; falta evidencia ejecutada |
| Integracion con I9-R03 | PENDIENTE | Contrato y prueba de precedencia |

## Decision Institucional

| Rol | Nombre | Decision | Fecha | Evidencia | Observaciones |
|---|---|---|---|---|---|
| Director de Operaciones | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE | PENDIENTE |

## Checklist De Cierre WP-I9-D

- [ ] El proyecto o contrato y todos los puestos del alcance estan identificados.
- [ ] Cada relacion real registra origen, destino y sentido.
- [ ] Todos los tiempos son minutos enteros no negativos.
- [ ] Las relaciones inversas requeridas tienen filas independientes.
- [ ] No existen relaciones activas solapadas para el mismo alcance y sentido.
- [ ] Toda combinacion prohibida tiene motivo y fuente verificable.
- [ ] La version, vigencia y responsable de mantenimiento estan diligenciados.
- [ ] El dataset anonimo contiene fila existente, ausente y prohibida.
- [ ] La ausencia de fila se valida como excepcion pendiente y nunca como cero.
- [ ] La precedencia de I9-R03 y de los bloqueos absolutos esta validada.
- [ ] El Director de Operaciones registro decision y evidencia.
- [ ] Existe decision SDD posterior antes de implementar o activar I9-R05.

## Criterio De Salida

WP-I9-D solo puede proponerse como completo cuando existe una matriz real,
versionada y vigente para el alcance, sin solapamientos activos, con tiempos
direccionales y prohibiciones respaldadas; el dataset anonimo demuestra fila
existente, ausente y prohibida; y el Director de Operaciones registro su
aprobacion con evidencia. Hasta entonces, I9-R05 permanece no ejecutable y
Gate 2 sigue bloqueado.
