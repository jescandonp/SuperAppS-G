# S&G Super App I3 - Puestos De Servicio Y Asignaciones - Plan De Implementacion

**Fecha base:** 2026-06-04  
**Ultima revision:** 2026-06-04  
**Incremento:** I3 - Puestos de Servicio y Asignaciones  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Estado del plan:** Cerrado tecnicamente  
**Fecha de aprobacion:** 2026-06-04  
**Gate actual:** I3 cerrado tecnicamente; retake I4 Gate 0  

## 1. Objetivo

Implementar el maestro de puestos de servicio y el historico de asignaciones entre empleados/guardas y puestos, conectando la base de datos maestros I2 con la estructura operativa inicial de S&G.

I3 termina cuando puestos, asignaciones, historicos, permisos, auditoria y UI administrativa cumplan los 18 criterios de aceptacion de la SPEC I3.

## 2. Documentos Rectores

Orden de autoridad aplicable:

1. `docs/CONSTITUTION.md`
2. `docs/ARCHITECTURE.md`
3. `docs/TECNOLOGIA.md`
4. `docs/DESIGN.md`
5. `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`
6. `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`
7. Este plan
8. Codigo fuente

## 3. Gates SDD

### Gate 0 - Revision documental

- [x] SPEC I3 leida.
- [x] Documentos rectores revisados.
- [x] Dependencia I0 resuelta por `docs/TECNOLOGIA.md`.
- [x] Plan I3 revisado y aprobado.
- [x] Alcance fuera de I3 confirmado.

La SPEC I3 mantiene texto historico de bloqueo por I0. Para este plan, esa restriccion queda satisfecha por el cierre tecnico I0 ya registrado en `docs/TECNOLOGIA.md`.

### Gate por tarea

Cada tarea requiere:

- trazabilidad a criterios de aceptacion;
- verificacion ejecutable definida antes de editar codigo;
- resultado y riesgos registrados en el execution log;
- no invadir turnos, cuadrantes, contratos/clientes formales, facturacion, inventario, armamento o novedades operativas completas.

### Gate de cierre I3

- [x] Criterios de aceptacion 1-18 cubiertos.
- [x] Pruebas funcionales y de permisos ejecutadas.
- [x] Riesgos residuales documentados.
- [x] SPEC, plan y documentos operativos actualizados si hubo decisiones nuevas.
- [x] Retake point hacia I4 definido.

## 4. Alcance

### Incluido

- maestro de puestos de servicio;
- creacion, edicion e inactivacion controlada de puestos;
- cliente como texto libre;
- ubicacion y observaciones;
- asignacion de empleado/guarda o personal administrativo a puesto activo;
- finalizacion de asignaciones;
- regla de una sola asignacion vigente por empleado;
- historico de asignaciones por empleado y por puesto;
- puesto actual visible desde empleado;
- empleados asignados visibles desde puesto;
- auditoria de puestos y asignaciones;
- permisos diferenciados para ADMIN, TH, GERENCIA y OPERACIONES;
- UI administrativa dark/gold consistente con `docs/DESIGN.md`.

### Fuera de alcance

- programacion automatica de turnos;
- cuadrantes;
- relevos;
- validacion contra contratos o clientes formales;
- facturacion por puesto;
- novedades operativas completas;
- inventario/dotacion por puesto;
- armamento por puesto;
- solicitudes de cambio por Operaciones;
- maestro formal de clientes.

## 5. Estado De Entrada

I2 queda cerrado tecnicamente y provee:

- empleados/guardas persistidos;
- campo textual `current_service_position_text` como insumo de normalizacion;
- roles y permisos reales;
- auditoria transversal;
- backend .NET 6 + PostgreSQL + React SPA;
- scripts de verificacion funcional bajo `scripts/dev`.

I3 debe reutilizar esos patrones en lugar de crear una arquitectura paralela.

## 6. Decisiones Tecnicas Propuestas Para Aprobacion

| Area | Decision propuesta |
|------|--------------------|
| Modelo de puesto | Tabla `service_positions` con nombre obligatorio, codigo opcional unico cuando exista, cliente texto libre, ubicacion, estado y observaciones |
| Modelo de asignacion | Tabla `employee_position_assignments` con empleado, puesto, fecha inicio, fecha fin, estado, motivo y observaciones |
| Vigencia | Una sola asignacion `VIGENTE` por empleado garantizada en persistencia |
| Puestos inactivos | No se pueden usar para nuevas asignaciones; conservan historico |
| Finalizacion | Exige `fecha_fin`; motivo opcional |
| Cambio de puesto | Cerrar asignacion vigente previa antes de crear la nueva, en una sola transaccion cuando aplique |
| Cliente | Texto libre MVP; sin tabla `clients` en I3 |
| Normalizacion I2 | `current_service_position_text` puede alimentar revision manual, no crea puestos automaticamente sin decision explicita |
| Auditoria | Eventos `SERVICE_POSITION_CREATED`, `SERVICE_POSITION_UPDATED`, `SERVICE_POSITION_INACTIVATED`, `POSITION_ASSIGNMENT_CREATED`, `POSITION_ASSIGNMENT_FINALIZED` |
| Seguridad | ADMIN y TH editan; GERENCIA y OPERACIONES consultan; servidor valida permisos siempre |
| UI | Modulo `positions` dentro del shell existente |
| Pruebas | Scripts PowerShell `Verify-SgSuperAppI3*.ps1` siguiendo patron I2 |

## 7. Modelo De Datos Objetivo

### `service_positions`

- `id`
- `code`
- `name`
- `client_text`
- `location_text`
- `status`: `ACTIVO`, `INACTIVO`
- `notes`
- `created_at`
- `updated_at`

### `employee_position_assignments`

- `id`
- `employee_id`
- `position_id`
- `start_date`
- `end_date`
- `status`: `VIGENTE`, `FINALIZADA`
- `change_reason`
- `notes`
- `created_by`
- `created_at`
- `updated_at`

### Reglas de integridad

- `service_positions.name` obligatorio.
- `service_positions.code` unico si no es nulo.
- una sola asignacion vigente por empleado.
- asignacion nueva solo contra puesto activo.
- `end_date >= start_date`.
- no eliminar fisicamente puestos con historico.

## 8. Contratos API Objetivo

Rutas propuestas:

- `GET /api/portal/positions`
- `GET /api/portal/positions/{positionId}`
- `POST /api/portal/positions`
- `PUT /api/portal/positions/{positionId}`
- `POST /api/portal/positions/{positionId}/inactivate`
- `GET /api/portal/positions/{positionId}/assignments`
- `GET /api/portal/employees/{employeeId}/position-assignments`
- `POST /api/portal/employees/{employeeId}/position-assignments`
- `POST /api/portal/position-assignments/{assignmentId}/finalize`

Permisos propuestos:

| Permiso | ADMIN | TH | GERENCIA | OPERACIONES |
|---------|-------|----|----------|-------------|
| `POSITIONS/VIEW` | Si | Si | Si | Si |
| `POSITIONS/MANAGE` | Si | Si | No | No |
| `POSITION_ASSIGNMENTS/VIEW` | Si | Si | Si | Si |
| `POSITION_ASSIGNMENTS/MANAGE` | Si | Si | No | No |

## 9. Plan De Tareas

### Task 1 - Persistencia I3

**Objetivo:** crear migracion incremental para puestos, asignaciones, permisos y restricciones.

**Criterios:** 1, 2, 3, 4, 7, 8, 15, 17.

**Aceptacion:**

- [x] Existen tablas `service_positions` y `employee_position_assignments`.
- [x] Se bloquea doble asignacion vigente por empleado.
- [x] Se bloquea asignacion a puesto inactivo.
- [x] Permisos I3 quedan registrados para los cuatro roles.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI3Persistence.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI3PersistenceClean.ps1`
- [x] `dotnet build`

**Archivos probables:**

- `db/migrations/005_i3_service_positions_assignments.sql`
- `db/seeds/005_i3_positions_permissions.sql`
- `scripts/dev/Verify-SgSuperAppI3Persistence.ps1`
- `scripts/dev/Verify-SgSuperAppI3PersistenceClean.ps1`

### Task 2 - Contratos backend de puestos

**Objetivo:** exponer DTOs y repositorio para listado, detalle, creacion, edicion e inactivacion de puestos.

**Criterios:** 1, 2, 3, 14, 15.

**Aceptacion:**

- [x] Listado permite busqueda por nombre y filtro por estado.
- [x] Crear puesto exige nombre.
- [x] Editar conserva cliente texto, ubicacion y observaciones.
- [x] Inactivar conserva historico y no elimina registros.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI3Positions.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI3Security.ps1`
- [x] `dotnet build`

**Archivos probables:**

- `apps/sg-superapp-api/Contracts/Portal/*Position*.cs`
- `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
- `scripts/dev/Verify-SgSuperAppI3Positions.ps1`

### Task 3 - Contratos backend de asignaciones

**Objetivo:** crear, consultar y finalizar asignaciones con reglas de vigencia.

**Criterios:** 4, 5, 6, 7, 8, 9, 16, 17.

**Aceptacion:**

- [x] Se asigna empleado a puesto activo.
- [x] El empleado expone puesto actual.
- [x] Doble vigente responde conflicto.
- [x] Finalizacion exige fecha fin y permite motivo vacio.
- [x] Historial se conserva.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI3Assignments.ps1`
- [ ] `scripts/dev/Verify-SgSuperAppI3AssignmentHistory.ps1`
- [x] `dotnet build`

**Archivos probables:**

- `apps/sg-superapp-api/Contracts/Portal/*Assignment*.cs`
- `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
- `scripts/dev/Verify-SgSuperAppI3Assignments.ps1`
- `scripts/dev/Verify-SgSuperAppI3AssignmentHistory.ps1`

### Task 4 - Auditoria y permisos I3

**Objetivo:** cerrar autorizacion servidor y auditoria de cambios de puestos/asignaciones.

**Criterios:** 10, 11, 12, 18.

**Aceptacion:**

- [x] ADMIN y TH editan puestos/asignaciones.
- [x] GERENCIA y OPERACIONES consultan sin editar.
- [x] Operaciones no puede crear solicitudes de cambio.
- [x] Cambios generan eventos de auditoria.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI3Security.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI3Audit.ps1`
- [x] `dotnet build`

**Archivos probables:**

- `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
- `scripts/dev/Verify-SgSuperAppI3Security.ps1`
- `scripts/dev/Verify-SgSuperAppI3Audit.ps1`

### Task 5 - Cliente API y tipos frontend

**Objetivo:** incorporar tipos y cliente React para puestos y asignaciones.

**Criterios:** 1, 5, 6, 8, 9.

**Aceptacion:**

- [x] Existen tipos TypeScript para puesto, detalle y asignacion.
- [x] Cliente API cubre listado, detalle, crear/editar/inactivar, asignar/finalizar.
- [x] Errores HTTP se propagan de forma consistente con I2.

**Verificacion:**

- [x] `npm run build`

**Archivos probables:**

- `apps/sg-superapp-web/src/types/portal.ts`
- `apps/sg-superapp-web/src/services/portalApi.ts`

### Task 6 - UI de listado y detalle de puestos

**Objetivo:** crear modulo visual `positions` para listar, filtrar y consultar puestos.

**Criterios:** 1, 10, 11, 13, 15.

**Aceptacion:**

- [x] Listado muestra nombre, estado, cliente, ubicacion y asignados vigentes.
- [x] Detalle muestra datos, asignados actuales e historico basico.
- [x] GERENCIA/OPERACIONES consultan sin acciones de edicion.
- [x] UI conserva dark/gold administrativa.

**Verificacion:**

- [x] `npm run build`
- [x] Matriz HTTP por rol para `POSITIONS/VIEW`.

**Archivos probables:**

- `apps/sg-superapp-web/src/features/positions/PositionsPage.tsx`
- `apps/sg-superapp-web/src/features/shell/ModuleWorkspace.tsx`
- `apps/sg-superapp-web/src/styles.css`

### Task 7 - UI de gestion de puestos

**Objetivo:** habilitar creacion, edicion e inactivacion para ADMIN/TH.

**Criterios:** 2, 3, 13, 14, 15.

**Aceptacion:**

- [x] ADMIN/TH ven formulario de puesto.
- [x] Nombre obligatorio se valida antes de enviar.
- [x] Inactivar requiere confirmacion visual.
- [x] GERENCIA/OPERACIONES no ven acciones de gestion.

**Verificacion:**

- [x] `npm run build`
- [x] `Verify-SgSuperAppI3Positions.ps1`
- [x] `Verify-SgSuperAppI3Security.ps1`

**Archivos probables:**

- `apps/sg-superapp-web/src/features/positions/PositionsPage.tsx`
- `apps/sg-superapp-web/src/styles.css`

### Task 8 - UI de asignacion desde empleado

**Objetivo:** mostrar puesto actual e historico en empleado y permitir asignar/finalizar segun rol.

**Criterios:** 5, 6, 7, 8, 9, 13, 16, 17.

**Aceptacion:**

- [x] Detalle de empleado muestra puesto actual normalizado.
- [x] Historial de puestos visible.
- [x] ADMIN/TH pueden asignar a puesto activo.
- [x] Finalizar asignacion permite motivo vacio y exige fecha fin.
- [x] La UI no permite doble vigente.

**Verificacion:**

- [x] `npm run build`
- [x] `Verify-SgSuperAppI3Assignments.ps1`
- [x] `Verify-SgSuperAppI3AssignmentHistory.ps1`

**Archivos probables:**

- `apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx`
- `apps/sg-superapp-web/src/features/positions/PositionsPage.tsx`
- `apps/sg-superapp-web/src/services/portalApi.ts`
- `apps/sg-superapp-web/src/types/portal.ts`

### Task 9 - Normalizacion asistida de texto I2

**Objetivo:** exponer como referencia el `current_service_position_text` importado en I2 para apoyar normalizacion manual, sin crear puestos automaticamente.

**Criterios:** 12, 15.

**Aceptacion:**

- [x] Empleado conserva texto de puesto importado.
- [x] UI muestra diferencia entre texto importado y puesto normalizado.
- [x] No se crean puestos automaticamente desde texto I2.

**Verificacion:**

- [x] `npm run build`
- [x] `Verify-SgSuperAppI3Assignments.ps1`

**Archivos probables:**

- `apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx`
- `apps/sg-superapp-api/Contracts/Portal/EmployeeDetailResponse.cs`
- `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`

### Task 10 - Verificacion integral y cierre I3

**Objetivo:** demostrar cumplimiento completo de SPEC I3.

**Criterios:** 1-18.

**Aceptacion:**

- [x] Suite `Verify-SgSuperAppI3*.ps1` completa pasa.
- [x] Backend build pasa.
- [x] Frontend build pasa.
- [x] Matriz final 1-18 queda registrada.
- [x] Riesgos residuales quedan documentados.
- [x] Retake point I4 queda definido.

**Verificacion:**

- [x] `dotnet build apps/sg-superapp-api/sg-superapp-api.csproj`
- [x] `npm run build` en `apps/sg-superapp-web`
- [x] `scripts/dev/Verify-SgSuperAppI3*.ps1`
- [ ] `graphify update .` cuando la herramienta este disponible.

**Archivos probables:**

- `docs/plans/2026-06-04-sg-superapp-i3-puestos-servicio-asignaciones-plan.md`
- `docs/handoff/*`
- `README.md`

## 10. Checkpoints

### Checkpoint A - Persistencia y contratos

Despues de Tasks 1-4:

- [x] scripts backend I3 pasan;
- [x] seguridad servidor validada;
- [x] auditoria validada;
- [x] `dotnet build` limpio.

### Checkpoint B - UI operativa

Despues de Tasks 5-9:

- [x] `npm run build` limpio;
- [x] acciones visibles respetan permisos;
- [x] puestos y asignaciones consultables por rol;
- [x] riesgo responsive documentado o verificado.

### Checkpoint C - Cierre I3

Despues de Task 10:

- [x] criterios 1-18 trazados;
- [x] riesgos residuales registrados;
- [x] retake point I4 definido.

## 11. Matriz De Trazabilidad

| Criterio SPEC I3 | Tareas |
|------------------|--------|
| 1. Existe listado de puestos | 1, 2, 6, 10 |
| 2. Se puede crear puesto activo con nombre | 1, 2, 7, 10 |
| 3. Se puede inactivar puesto | 1, 2, 7, 10 |
| 4. No se puede asignar empleado a puesto inactivo | 1, 3, 10 |
| 5. Se puede asignar empleado a puesto activo | 3, 8, 10 |
| 6. El empleado muestra puesto actual | 3, 8, 10 |
| 7. Un empleado no puede tener dos asignaciones vigentes | 1, 3, 8, 10 |
| 8. Se puede finalizar asignacion con fecha fin | 3, 8, 10 |
| 9. El historial de asignaciones se conserva | 3, 8, 10 |
| 10. Operaciones consulta sin editar | 4, 6, 10 |
| 11. Gerencia consulta puesto actual e historial | 4, 6, 10 |
| 12. Cambios auditados | 4, 10 |
| 13. UI respeta `docs/DESIGN.md` | 6, 7, 8, 10 |
| 14. TH puede crear puestos | 2, 7, 10 |
| 15. Cliente texto libre | 1, 2, 6, 7, 10 |
| 16. Asignar personal administrativo si existe como empleado | 3, 8, 10 |
| 17. Finalizar no exige motivo | 1, 3, 8, 10 |
| 18. Operaciones no crea solicitudes de cambio | 4, 10 |

### Matriz Final De Cierre I3

| Criterio | Estado | Evidencia |
|----------|--------|-----------|
| 1 | Cubierto | `Verify-SgSuperAppI3Persistence.ps1`, `Verify-SgSuperAppI3Positions.ps1`, UI `PositionsPage` |
| 2 | Cubierto | `Verify-SgSuperAppI3Positions.ps1`, UI gestion ADMIN/TH |
| 3 | Cubierto | `Verify-SgSuperAppI3Positions.ps1`, inactivacion logica |
| 4 | Cubierto | `Verify-SgSuperAppI3Assignments.ps1`, trigger/servicio bloquean puesto inactivo |
| 5 | Cubierto | `Verify-SgSuperAppI3Assignments.ps1`, UI asignacion desde empleado |
| 6 | Cubierto | `Verify-SgSuperAppI3Assignments.ps1`, `EmployeeDetailResponse.currentServicePositionName` |
| 7 | Cubierto | `Verify-SgSuperAppI3Assignments.ps1`, indice unico parcial |
| 8 | Cubierto | `Verify-SgSuperAppI3Assignments.ps1`, finalizacion con fecha fin |
| 9 | Cubierto | `Verify-SgSuperAppI3AssignmentHistory.ps1` |
| 10 | Cubierto | `Verify-SgSuperAppI3Security.ps1`, roles de solo consulta |
| 11 | Cubierto | `Verify-SgSuperAppI3Security.ps1`, `Verify-SgSuperAppI3AssignmentHistory.ps1` |
| 12 | Cubierto | `Verify-SgSuperAppI3Audit.ps1` |
| 13 | Cubierto | `npm run build`, UI dark/gold administrativa en puestos/empleados |
| 14 | Cubierto | `Verify-SgSuperAppI3Positions.ps1` |
| 15 | Cubierto | `Verify-SgSuperAppI3Assignments.ps1`, texto I2 conservado sin maestro cliente |
| 16 | Cubierto | asignacion por `employee_id` sin restringir cargo |
| 17 | Cubierto | `Verify-SgSuperAppI3Assignments.ps1`, motivo de finalizacion opcional |
| 18 | Cubierto | `Verify-SgSuperAppI3Security.ps1` |

## 12. Riesgos Y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Duplicados de puestos por variaciones de nombre | Medio | Busqueda, codigo opcional unico y normalizacion manual |
| Texto I2 confundido con puesto normalizado | Medio | Mostrarlo como referencia, no como entidad automatica |
| Doble asignacion vigente por condiciones de carrera | Alto | Restriccion en persistencia y transaccion de cambio |
| Alcance deriva hacia turnos/cuadrantes | Alto | Mantener programacion operativa fuera de I3 |
| Operaciones solicita cambios | Medio | Bloqueo por permisos y registro como fuera de MVP |
| Sin browser automatizado local | Medio | Build frontend, matriz HTTP y documentar recorrido manual si Playwright sigue ausente |
| `graphify` no disponible | Bajo | Intentar `graphify update .` y documentar fallo hasta instalar herramienta |

### Riesgos Residuales De Cierre

- Recorrido visual desktop/movil queda pendiente de validacion manual o Playwright cuando el entorno lo permita.
- `graphify update .` no se puede completar porque `graphify` no esta instalado/disponible en PATH.
- I3 no incluye maestro formal de clientes, turnos, cuadrantes ni solicitudes operativas; quedan explicitamente para incrementos futuros.

## 13. Open Questions

No hay preguntas funcionales abiertas en la SPEC I3. Preguntas tecnicas a confirmar durante Gate 0:

- [x] Aprobar tabla `service_positions` y `employee_position_assignments` con los nombres propuestos.
- [x] Aprobar permisos `POSITIONS/*` y `POSITION_ASSIGNMENTS/*`.
- [x] Aprobar no crear puestos automaticamente desde `current_service_position_text`.
- [x] Aprobar que ADMIN gestione asignaciones igual que TH, conforme matriz SPEC I3.

## 14. Execution Log

### 2026-06-04 - Gate 0 plan I3 creado

- Se leyo SPEC I3 y documentos rectores.
- Se confirmo que el bloqueo historico por I0 queda resuelto por `docs/TECNOLOGIA.md`.
- Se creo plan I3 con 10 tareas, checkpoints, matriz 1-18, riesgos y preguntas tecnicas de Gate 0.
- Implementacion permanece bloqueada hasta aprobacion del plan.

### 2026-06-04 - Gate 0 aprobado y Task 1 persistencia cerrada

- Se aprobo Gate 0 como continuidad operativa solicitada.
- Se inicio Task 1 con TDD:
  - RED: `Verify-SgSuperAppI3Persistence.ps1` fallo por ausencia de `service_positions`;
  - GREEN: se creo migracion `005_i3_service_positions_assignments.sql`, seed `005_i3_positions_permissions.sql` y contrato `003_i3_persistence_contract.sql`.
- Persistencia I3 implementada:
  - tabla `service_positions`;
  - tabla `employee_position_assignments`;
  - codigo opcional unico;
  - nombre obligatorio/no vacio;
  - una sola asignacion vigente por empleado;
  - bloqueo de asignacion vigente a puesto inactivo;
  - rango de fechas valido;
  - permisos `POSITIONS/*` y `POSITION_ASSIGNMENTS/*`.
- Verificaciones:
  - `Verify-SgSuperAppI3Persistence.ps1`: correcto;
  - `Verify-SgSuperAppI3PersistenceClean.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 1 cerrada.
- Retake point: Task 2, contratos backend de puestos.

### 2026-06-04 - Task 2 contratos backend de puestos cerrada

- Se inicio Task 2 con TDD:
  - RED: `Verify-SgSuperAppI3Positions.ps1` fallo con `404` porque `/api/portal/positions` no existia;
  - GREEN: se implementaron contratos, repositorio y endpoints de puestos.
- Contratos backend implementados:
  - `GET /api/portal/positions` con busqueda y filtro por estado;
  - `GET /api/portal/positions/{positionId}`;
  - `POST /api/portal/positions`;
  - `PUT /api/portal/positions/{positionId}`;
  - `POST /api/portal/positions/{positionId}/inactivate`.
- Permisos aplicados:
  - `POSITIONS/VIEW` para ADMIN, TH, GERENCIA y OPERACIONES;
  - `POSITIONS/MANAGE` para ADMIN y TH;
  - GERENCIA y OPERACIONES bloqueados para creacion.
- El contrato retorna conteo de asignaciones vigentes sin implementar todavia la gestion de asignaciones.
- Verificaciones:
  - `Verify-SgSuperAppI3Positions.ps1`: correcto;
  - `Verify-SgSuperAppI3Persistence.ps1`: correcto;
  - `Verify-SgSuperAppI3PersistenceClean.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 2 cerrada.
- Retake point: Task 3, contratos backend de asignaciones.

### 2026-06-04 - Task 3 contratos backend de asignaciones cerrada

- Se inicio Task 3 con TDD:
  - RED: `Verify-SgSuperAppI3Assignments.ps1` fallo con `404` porque los endpoints de asignacion no existian;
  - GREEN: se implementaron contratos, repositorio y endpoints de asignaciones.
- Contratos backend implementados:
  - `GET /api/portal/employees/{employeeId}/position-assignments`;
  - `POST /api/portal/employees/{employeeId}/position-assignments`;
  - `POST /api/portal/position-assignments/{assignmentId}/finalize`.
- Se amplio detalle de empleado con:
  - `currentServicePositionId`;
  - `currentServicePositionName`.
- Reglas validadas:
  - no asignar a puesto inactivo;
  - no permitir doble asignacion vigente;
  - GERENCIA/OPERACIONES consultan sin crear;
  - finalizacion exige fecha fin valida y no exige motivo;
  - historial de asignaciones se conserva.
- Verificaciones:
  - `Verify-SgSuperAppI3Assignments.ps1`: correcto;
  - `Verify-SgSuperAppI3Positions.ps1`: correcto;
  - `Verify-SgSuperAppI3Persistence.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 3 cerrada.
- Retake point: Task 4, auditoria y permisos I3.

### 2026-06-05 - Task 4 auditoria y permisos I3 cerrada

- Se inicio Task 4 con TDD:
  - RED: `Verify-SgSuperAppI3Audit.ps1` fallo porque no existian eventos `audit_log` para puestos ni asignaciones;
  - GREEN: se agregaron scripts `Verify-SgSuperAppI3Security.ps1` y `Verify-SgSuperAppI3Audit.ps1`, se conectaron endpoints I3 al `RequestUserContext` y se implemento auditoria transaccional en `audit_log`.
- Cobertura cerrada en backend:
  - `SERVICE_POSITION_CREATED`;
  - `SERVICE_POSITION_UPDATED`;
  - `SERVICE_POSITION_INACTIVATED`;
  - `POSITION_ASSIGNMENT_CREATED`;
  - `POSITION_ASSIGNMENT_FINALIZED`.
- Permisos validados:
  - ADMIN y TH gestionan puestos/asignaciones;
  - GERENCIA y OPERACIONES consultan historial y detalle sin editar;
  - OPERACIONES no crea cambios dentro del MVP.
- Verificaciones:
  - `Verify-SgSuperAppI3Audit.ps1`: correcto;
  - `Verify-SgSuperAppI3Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- `graphify update .` intentado segun politica del repo cuando la herramienta este disponible.
- Task 4 cerrada.
- Retake point: Task 5, cliente API y tipos frontend.

### 2026-06-05 - Task 5 cliente API y tipos frontend cerrada

- Se inicio Task 5 desde el retake autorizado:
  - baseline: `npm run build` paso antes de editar;
  - GREEN: se agregaron tipos TypeScript y cliente API para puestos/asignaciones.
- Tipos agregados:
  - `ServicePosition`, `ServicePositionRequest`, `ServicePositionStatus`;
  - `PositionAssignment`, `CreatePositionAssignmentRequest`, `FinalizePositionAssignmentRequest`;
  - `EmployeeDetail.currentServicePositionId` y `EmployeeDetail.currentServicePositionName`.
- Cliente API agregado:
  - listado y detalle de puestos;
  - crear, editar e inactivar puesto;
  - consultar, crear y finalizar asignaciones;
  - propagacion de errores HTTP con mensaje de backend cuando existe.
- Verificaciones:
  - frontend `npm run build`: correcto.
- Task 5 cerrada.
- Retake point: Task 6, UI de listado y detalle de puestos.

### 2026-06-05 - Task 6 UI de listado y detalle de puestos cerrada

- Se implemento el modulo React `positions` dentro del shell existente.
- UI cerrada:
  - listado con busqueda por nombre/codigo/cliente y filtro por estado;
  - filas con nombre, codigo, cliente, ubicacion, estado y asignados vigentes;
  - detalle de puesto con estado, ubicacion, observaciones y conteo vigente;
  - asignaciones vigentes e historial basico en panel de detalle;
  - mensaje por rol sin exponer acciones de gestion en Task 6.
- Se completo contrato de consulta faltante:
  - `GET /api/portal/positions/{positionId}/assignments`;
  - cliente `fetchServicePositionAssignments`;
  - matriz de lectura validada para ADMIN, TH, GERENCIA y OPERACIONES.
- Navegacion:
  - modulo `POSITIONS` actualizado como `Disponible` en catalogo backend.
- Verificaciones:
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - frontend `npm run build`: correcto;
  - `Verify-SgSuperAppI3Security.ps1`: correcto.
- Task 6 cerrada.
- Retake point: Task 7, UI de gestion de puestos.

### 2026-06-05 - Task 7 UI de gestion de puestos cerrada

- Se habilito gestion de puestos en la vista `positions` para ADMIN y TH.
- UI cerrada:
  - boton `Nuevo puesto` solo para roles gestores;
  - formulario de creacion/edicion con codigo opcional, nombre obligatorio, cliente texto libre, ubicacion y observaciones;
  - validacion client-side de nombre obligatorio antes de enviar;
  - accion de inactivacion con confirmacion visual;
  - GERENCIA y OPERACIONES conservan consulta sin acciones de gestion.
- Contratos reutilizados:
  - `createServicePosition`;
  - `updateServicePosition`;
  - `inactivateServicePosition`.
- Verificaciones:
  - frontend `npm run build`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - `Verify-SgSuperAppI3Positions.ps1`: correcto;
  - `Verify-SgSuperAppI3Security.ps1`: correcto.
- Task 7 cerrada.
- Retake point: Task 8, UI de asignacion desde empleado.

### 2026-06-05 - Task 8 UI de asignacion desde empleado cerrada

- Se implemento gestion de asignaciones desde `EmployeesPage`:
  - detalle muestra puesto actual normalizado y texto importado I2;
  - historial de puestos visible con asignacion vigente y finalizadas;
  - ADMIN/TH pueden asignar puesto activo cuando no existe vigente;
  - finalizacion exige fecha fin y acepta motivo vacio;
  - UI bloquea doble vigente ocultando nueva asignacion hasta cerrar la vigente.
- Se agrego verificacion ejecutable `Verify-SgSuperAppI3AssignmentHistory.ps1`.
- Verificaciones:
  - frontend `npm run build`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - `Verify-SgSuperAppI3Assignments.ps1`: correcto;
  - `Verify-SgSuperAppI3AssignmentHistory.ps1`: correcto.
- Task 8 cerrada.
- Retake point: Task 9, normalizacion asistida de texto I2.

### 2026-06-05 - Task 9 normalizacion asistida de texto I2 cerrada

- Se reforzo el detalle de empleado con bloque de normalizacion asistida:
  - texto importado I2 visible;
  - puesto normalizado visible;
  - indicador de consistencia/revision cuando ambos difieren.
- Se amplio `Verify-SgSuperAppI3Assignments.ps1` para validar:
  - `currentServicePositionText` se conserva al asignar puesto normalizado;
  - asignar puesto no crea registros adicionales en `service_positions` desde texto importado I2.
- Verificaciones:
  - frontend `npm run build`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - `Verify-SgSuperAppI3Assignments.ps1`: correcto.
- Task 9 cerrada.
- Retake point: Task 10, verificacion integral y cierre I3.

### 2026-06-05 - Task 10 verificacion integral y cierre I3 cerrada

- Se ejecuto cierre tecnico completo de I3.
- Verificaciones:
  - backend `dotnet build apps/sg-superapp-api/sg-superapp-api.csproj`: correcto, 0 advertencias y 0 errores;
  - frontend `npm run build` en `apps/sg-superapp-web`: correcto;
  - suite completa `Verify-SgSuperAppI3*.ps1`: correcta.
- Scripts I3 ejecutados:
  - `Verify-SgSuperAppI3AssignmentHistory.ps1`;
  - `Verify-SgSuperAppI3Assignments.ps1`;
  - `Verify-SgSuperAppI3Audit.ps1`;
  - `Verify-SgSuperAppI3Persistence.ps1`;
  - `Verify-SgSuperAppI3PersistenceClean.ps1`;
  - `Verify-SgSuperAppI3Positions.ps1`;
  - `Verify-SgSuperAppI3Security.ps1`.
- Matriz final 1-18 registrada en este plan.
- Riesgos residuales registrados.
- `graphify update .` queda pendiente por herramienta no disponible.
- I3 cerrado tecnicamente.
- Retake point: I4 Gate 0, preparar plan de Certificaciones Laborales desde SPEC I4.
