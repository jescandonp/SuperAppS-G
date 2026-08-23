# Plan I5 - Cursos y Acreditaciones

**Fecha:** 2026-06-05  
**Producto:** S&G Super App  
**Incremento:** I5 - Cursos y Acreditaciones  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Estado del plan:** Revisado y aprobado  
**Fecha de aprobacion:** 2026-06-05  
**Gate actual:** I5 cerrado tecnicamente; retake autorizado en I6 Gate 0  

## 1. Objetivo

Implementar el modulo de cursos y acreditaciones para controlar requisitos obligatorios por empleado/guarda, historico de renovaciones, vencimientos calculados, estado de cumplimiento y habilitado/no habilitado para servicio.

I5 termina cuando el flujo cumpla los 20 criterios de aceptacion de la SPEC I5 sin invadir alertas automaticas, correo, WhatsApp, bloqueo de programacion, HELIZA, nomina ni carga documental binaria obligatoria.

## 2. Documentos Rectores

Orden de autoridad aplicable:

1. `docs/CONSTITUTION.md`
2. `docs/ARCHITECTURE.md`
3. `docs/TECNOLOGIA.md`
4. `docs/DESIGN.md`
5. `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`
6. `docs/specs/2026-05-21-sg-superapp-spec-i5-cursos-acreditaciones.md`
7. Este plan

SPECs relacionadas:

- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`
- `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`
- `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`

## 3. Gate 0

### Decisiones Confirmadas

- I0 ya cerro stack: React SPA + backend .NET compatible + PostgreSQL.
- I1 provee login, roles, permisos y auditoria base.
- I2 provee maestro de empleados.
- I3 provee puesto actual/asignaciones para enriquecer consulta operativa.
- Estados de vencimiento se calculan por reglas: `VENCIDO`, `CRITICO`, `PREVENTIVO`, `INFORMATIVO`, `AL_DIA`.
- `NO_HABILITADO` es indicador visible para servicio, no bloqueo automatico de programacion.
- Alertas automaticas, correo y centro de notificaciones quedan para I6.
- Soporte documental queda como referencia opcional; carga binaria no bloquea I5.

### Restricciones

- No implementar notificaciones automaticas.
- No implementar correo/SMTP.
- No implementar WhatsApp.
- No bloquear turnos o asignaciones automaticamente.
- No integrar HELIZA ni nomina.
- No cambiar stack ni dependencias sin actualizar `docs/TECNOLOGIA.md`.

### Gate De Cierre I5

- [x] Criterios de aceptacion 1-20 cubiertos.
- [x] Suite funcional I5 ejecutada.
- [x] Backend build limpio.
- [x] Frontend build limpio.
- [x] Riesgos residuales documentados.
- [x] Retake point I6 definido.

## 4. Alcance

### Incluido

- Tipos de curso/acreditacion.
- Renovaciones historicas por empleado.
- Fecha de realizacion y vencimiento.
- Calculo de estado.
- Habilitado/no habilitado para servicio.
- Consulta por TH, Operaciones y Gerencia.
- Gestion por ADMIN/TH.
- Auditoria.
- UI administrativa dark/gold.

### Excluido

- Alertas automaticas.
- Correo automatico.
- WhatsApp.
- Bloqueo operativo automatico.
- Integraciones HELIZA/nomina.
- Carga binaria obligatoria de soportes.

## 5. Diseño Tecnico Propuesto

### Persistencia

Tablas nuevas:

- `training_requirement_types`
- `employee_training_records`

Campos minimos de `training_requirement_types`:

- `id`
- `code`
- `name`
- `category`
- `validity_days`
- `is_service_required`
- `status`
- `notes`
- `created_at`
- `updated_at`

Campos minimos de `employee_training_records`:

- `id`
- `employee_id`
- `requirement_type_id`
- `completed_at`
- `expires_at`
- `support_path`
- `notes`
- `status`
- `created_by`
- `created_at`
- `updated_at`

### Contratos API

Endpoints esperados:

- `GET /api/portal/training-types`
- `GET /api/portal/training-types/{typeId}`
- `POST /api/portal/training-types`
- `PUT /api/portal/training-types/{typeId}`
- `POST /api/portal/training-types/{typeId}/inactivate`
- `GET /api/portal/training-compliance`
- `GET /api/portal/employees/{employeeId}/training`
- `POST /api/portal/employees/{employeeId}/training`
- `POST /api/portal/training/{recordId}/inactivate`

### Reglas De Calculo

- `VENCIDO`: vencimiento menor a hoy.
- `CRITICO`: 0 a 15 dias restantes.
- `PREVENTIVO`: 16 a 30 dias restantes.
- `INFORMATIVO`: 31 a 60 dias restantes.
- `AL_DIA`: mas de 60 dias restantes.
- `NO_HABILITADO`: al menos un requisito obligatorio vencido.
- `HABILITADO`: ningun requisito obligatorio vencido.

### UI

Modulo `TRAINING`:

- listado de cumplimiento;
- filtros por empleado, tipo, estado y habilitacion;
- detalle por empleado;
- registro de renovacion para TH/ADMIN;
- gestion de tipos para TH/ADMIN;
- consulta operativa para Operaciones/Gerencia.

## 6. Tareas

### Task 1 - Persistencia I5 y permisos base

**Objetivo:** crear tablas, restricciones, permisos y contrato SQL para tipos y renovaciones.

**Criterios:** 1, 2, 3, 4, 5, 16, 18.

**Aceptacion:**

- [x] Existen tablas de tipos y renovaciones.
- [x] Tipos validan categoria y estado.
- [x] Renovaciones validan empleado, tipo, fechas y estado.
- [x] Soporte documental queda como referencia opcional.
- [x] Permisos I5 quedan registrados para cuatro roles.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI5Persistence.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI5PersistenceClean.ps1`
- [x] `dotnet build`

### Task 2 - Contratos backend de tipos

**Objetivo:** implementar API para administrar tipos de curso/acreditacion.

**Criterios:** 1, 2, 3, 18.

**Aceptacion:**

- [x] ADMIN/TH crean, editan e inactivan tipos.
- [x] GERENCIA/OPERACIONES consultan sin editar.
- [x] Codigo unico se valida si se define.
- [x] Vigencia en dias es opcional y no negativa.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI5Types.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI5Security.ps1`
- [x] `dotnet build`

### Task 3 - Renovaciones y reglas de fecha

**Objetivo:** implementar registro de renovaciones por empleado.

**Criterios:** 4, 5, 6, 7, 8, 16, 17.

**Aceptacion:**

- [x] TH registra renovacion para empleado existente.
- [x] Tipo activo es obligatorio.
- [x] Vencimiento se calcula desde vigencia cuando aplica.
- [x] Vencimiento manual se exige cuando no hay vigencia.
- [x] Vencimiento anterior a realizacion se rechaza.
- [x] Historico no se borra.
- [x] Auditoria registra cambios.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI5Renewals.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI5Audit.ps1`
- [x] `dotnet build`

### Task 4 - Estados calculados

**Objetivo:** calcular estados de vencimiento por umbral.

**Criterios:** 9, 20.

**Aceptacion:**

- [x] `VENCIDO` se calcula correctamente.
- [x] `CRITICO` se calcula correctamente.
- [x] `PREVENTIVO` se calcula correctamente.
- [x] `INFORMATIVO` se calcula correctamente.
- [x] `AL_DIA` se calcula correctamente.
- [x] Reglas quedan reutilizables por I6.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI5StatusRules.ps1`
- [x] `dotnet build`

### Task 5 - Habilitacion de servicio

**Objetivo:** calcular habilitado/no habilitado segun requisitos obligatorios vencidos.

**Criterios:** 10, 11, 12, 13.

**Aceptacion:**

- [x] Obligatorio vencido marca `NO_HABILITADO`.
- [x] Obligatorio no vencido mantiene `HABILITADO`.
- [x] No obligatorio vencido no bloquea habilitacion.
- [x] Operaciones consulta habilitacion sin editar.
- [x] Gerencia consulta cumplimiento sin editar.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI5ServiceEnablement.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI5Security.ps1`
- [x] `dotnet build`

### Task 6 - Listado y detalle backend

**Objetivo:** exponer consultas de cumplimiento y detalle por empleado.

**Criterios:** 12, 13, 14, 15.

**Aceptacion:**

- [x] Listado filtra por empleado, tipo, estado y habilitacion.
- [x] Detalle muestra requisitos actuales.
- [x] Detalle muestra historico de renovaciones.
- [x] Puesto actual se expone si existe.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI5Queries.ps1`
- [x] `dotnet build`

### Task 7 - Cliente API y tipos frontend

**Objetivo:** agregar tipos TypeScript y cliente API I5.

**Criterios:** 1-20.

**Aceptacion:**

- [x] Tipos cubren tipo, renovacion, estado y habilitacion.
- [x] Cliente API cubre tipos, cumplimiento, detalle y renovaciones.
- [x] Errores HTTP propagan mensajes backend.

**Verificacion:**

- [x] `npm run build`

### Task 8 - UI de cumplimiento

**Objetivo:** implementar listado y detalle de cumplimiento por empleado.

**Criterios:** 12, 13, 14, 15, 19.

**Aceptacion:**

- [x] Listado filtra por empleado, tipo, estado y habilitacion.
- [x] Detalle muestra actuales e historico.
- [x] Operaciones/Gerencia consultan sin acciones.
- [x] UI respeta estilo dark/gold administrativo.

**Verificacion:**

- [x] `npm run build`
- [x] `scripts/dev/Verify-SgSuperAppI5Security.ps1`

### Task 9 - UI de gestion TH/ADMIN

**Objetivo:** implementar gestion visual de tipos y renovaciones.

**Criterios:** 2, 3, 4, 5, 6, 7, 8, 17, 19.

**Aceptacion:**

- [x] ADMIN/TH gestionan tipos.
- [x] ADMIN/TH registran renovaciones.
- [x] GERENCIA/OPERACIONES no ven acciones de edicion.
- [x] Errores de fechas y permisos se muestran desde backend.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI5ManagementUi.ps1`
- [x] `npm run build`
- [x] `scripts/dev/Verify-SgSuperAppI5Types.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI5Renewals.ps1`

### Task 10 - Verificacion integral y cierre I5

**Objetivo:** demostrar cumplimiento completo de SPEC I5.

**Criterios:** 1-20.

**Aceptacion:**

- [x] Suite `Verify-SgSuperAppI5*.ps1` completa pasa.
- [x] Backend build pasa.
- [x] Frontend build pasa.
- [x] Matriz final 1-20 queda registrada.
- [x] Riesgos residuales quedan documentados.
- [x] Retake point I6 queda definido.

**Verificacion:**

- [x] `dotnet build apps/sg-superapp-api/sg-superapp-api.csproj`
- [x] `npm run build` en `apps/sg-superapp-web`
- [x] `scripts/dev/Verify-SgSuperAppI5*.ps1`
- [x] `graphify update .` intentado; herramienta no disponible en PATH.

## 7. Checkpoints

### Checkpoint A - Base documental y contratos

Despues de Tasks 1-2:

- [x] persistencia I5 creada;
- [x] permisos I5 registrados;
- [x] tipos configurables;
- [x] backend build limpio.

### Checkpoint B - Reglas backend completas

Despues de Tasks 3-6:

- [x] renovaciones funcionan;
- [x] estados calculados;
- [x] habilitacion calculada;
- [x] consultas por rol disponibles.

### Checkpoint C - UI y cierre

Despues de Tasks 7-10:

- [x] UI operativa por rol;
- [x] UI de gestion TH/ADMIN;
- [x] suite completa I5 pasa;
- [x] matriz 1-20 registrada;
- [x] retake I6 definido.

## 8. Matriz De Trazabilidad

| Criterio SPEC I5 | Tareas |
|------------------|--------|
| 1. Tipos parametrizables | 1, 2, 7, 10 |
| 2. ADMIN/TH gestionan tipos | 2, 9, 10 |
| 3. GERENCIA/OPERACIONES no editan tipos | 2, 5, 8, 9, 10 |
| 4. TH registra renovaciones | 3, 9, 10 |
| 5. Historico de renovaciones | 3, 6, 8, 10 |
| 6. Calcula vencimiento por vigencia | 3, 10 |
| 7. Exige vencimiento manual si no calcula | 3, 10 |
| 8. Rechaza fechas invalidas | 3, 10 |
| 9. Estados calculados | 4, 10 |
| 10. Obligatorio vencido no habilita | 5, 10 |
| 11. Sin obligatorio vencido habilita | 5, 10 |
| 12. Operaciones consulta | 5, 6, 8, 10 |
| 13. Gerencia consulta | 5, 6, 8, 10 |
| 14. Listado filtra | 6, 8, 10 |
| 15. Detalle actuales e historico | 6, 8, 10 |
| 16. Soporte opcional modelado | 1, 3, 10 |
| 17. Auditoria | 3, 10 |
| 18. Seguridad backend | 1, 2, 5, 10 |
| 19. UI respeta DESIGN | 8, 9, 10 |
| 20. Reglas listas para I6 | 4, 10 |

### Matriz Final De Aceptacion I5 - 2026-06-09

| Criterio SPEC I5 | Estado | Evidencia |
|------------------|--------|-----------|
| 1. Tipos parametrizables | Cubierto | `Verify-SgSuperAppI5Types.ps1`, cliente API y UI |
| 2. ADMIN/TH gestionan tipos | Cubierto | `Verify-SgSuperAppI5Types.ps1`, `Verify-SgSuperAppI5ManagementUi.ps1` |
| 3. GERENCIA/OPERACIONES no editan tipos | Cubierto | `Verify-SgSuperAppI5Security.ps1`, UI por rol |
| 4. TH registra renovaciones | Cubierto | `Verify-SgSuperAppI5Renewals.ps1`, UI de renovaciones |
| 5. Historico de renovaciones | Cubierto | `Verify-SgSuperAppI5Renewals.ps1`, `Verify-SgSuperAppI5Queries.ps1` |
| 6. Calcula vencimiento por vigencia | Cubierto | `Verify-SgSuperAppI5Renewals.ps1` |
| 7. Exige vencimiento manual si no calcula | Cubierto | `Verify-SgSuperAppI5Renewals.ps1` |
| 8. Rechaza fechas invalidas | Cubierto | `Verify-SgSuperAppI5Renewals.ps1` |
| 9. Estados calculados | Cubierto | `Verify-SgSuperAppI5StatusRules.ps1` |
| 10. Obligatorio vencido no habilita | Cubierto | `Verify-SgSuperAppI5ServiceEnablement.ps1` |
| 11. Sin obligatorio vencido habilita | Cubierto | `Verify-SgSuperAppI5ServiceEnablement.ps1` |
| 12. Operaciones consulta | Cubierto | `Verify-SgSuperAppI5Security.ps1`, `Verify-SgSuperAppI5Queries.ps1` |
| 13. Gerencia consulta | Cubierto | `Verify-SgSuperAppI5Security.ps1`, `Verify-SgSuperAppI5Queries.ps1` |
| 14. Listado filtra | Cubierto | `Verify-SgSuperAppI5Queries.ps1`, UI de cumplimiento |
| 15. Detalle actuales e historico | Cubierto | `Verify-SgSuperAppI5Queries.ps1`, UI de detalle |
| 16. Soporte opcional modelado | Cubierto | `Verify-SgSuperAppI5Persistence*.ps1`, `Verify-SgSuperAppI5Renewals.ps1` |
| 17. Auditoria | Cubierto | `Verify-SgSuperAppI5Audit.ps1` |
| 18. Seguridad backend | Cubierto | `Verify-SgSuperAppI5Security.ps1` |
| 19. UI respeta DESIGN | Cubierto | `npm run build`, UI dark/gold administrativa |
| 20. Reglas listas para I6 | Cubierto | `TrainingComplianceStatusCalculator`, `Verify-SgSuperAppI5StatusRules.ps1` |

## 9. Riesgos Y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Tipos reales no estandarizados | Alto | Catalogo configurable y codigo opcional unico |
| Datos fuente incompletos | Alto | Validaciones de fecha y estado antes de persistir |
| Confusion entre no habilitado y bloqueo operativo | Alto | UI debe mostrar indicador y no bloquear programacion |
| Expectativa de alertas automaticas | Medio | Documentar que I6 implementa alertas/notificaciones |
| Soportes sin ruta aprobada | Medio | Guardar referencia opcional y diferir binarios |
| `graphify` no disponible | Bajo | Intentar `graphify update .` y documentar fallo hasta instalar herramienta |

### Riesgos Residuales De Cierre I5 - 2026-06-09

| Riesgo residual | Estado | Tratamiento |
|-----------------|--------|-------------|
| Alertas automaticas aun no existen | Esperado | Pasa a I6; I5 deja reglas centralizadas y datos consultables |
| SMTP/correo no validado | Esperado | I6 debe decidir SMTP o fallback exportable segun infraestructura |
| Soportes documentales solo son referencia textual | Aceptado | Carga binaria/ruta institucional queda fuera de I5 |
| `NO_HABILITADO` puede confundirse con bloqueo de turnos | Aceptado | UI y SPEC lo tratan como indicador, no bloqueo automatico |
| `graphify` no disponible en PATH | Operativo | Se intento actualizacion y se documenta limitacion |

## 10. Open Questions

No hay preguntas funcionales bloqueantes para iniciar I5 Task 1.

Decisiones tecnicas de Gate 0:

- [x] Stack I0 desbloquea implementacion I5.
- [x] Estados calculados usan umbrales PRD/SPEC 00.
- [x] Habilitacion es lectura calculada.
- [x] Alertas automaticas quedan para I6.
- [x] Soportes documentales son referencia opcional en I5.
- [x] Operaciones y Gerencia consultan, no editan.

## 11. Execution Log

### 2026-06-05 - Gate 0 plan I5 creado y aprobado

- Se leyeron documentos rectores y PRD.
- Se creo SPEC I5 con alcance, actores, reglas, permisos, criterios 1-20 y riesgos.
- Se creo plan I5 con 10 tareas, checkpoints, matriz 1-20 y verificaciones.
- Gate 0 cerrado.
- Retake point: Task 1, persistencia I5 y permisos base.

### 2026-06-06 - Task 1 persistencia I5 y permisos base cerrada

- Se creo `db/migrations/007_i5_training_accreditations.sql` con tablas `training_requirement_types` y `employee_training_records`, restricciones de categoria/estado/fechas, soporte opcional e indices operativos.
- Se creo `db/seeds/007_i5_training_permissions.sql` con permisos I5 para ADMIN, TH, GERENCIA y OPERACIONES, preservando gestion solo para ADMIN/TH y consulta para GERENCIA/OPERACIONES.
- Se creo `db/tests/005_i5_persistence_contract.sql` con contrato de persistencia para tablas, unicidad, foreign keys, fechas invalidas, soporte opcional y matriz de permisos.
- Verificacion limpia: `scripts/dev/Verify-SgSuperAppI5PersistenceClean.ps1` correcta sobre esquema temporal `i5_verify_clean`.
- Verificacion dev: migracion 007 + seed 007 aplicados sobre `sg_superapp_dev`; `scripts/dev/Verify-SgSuperAppI5Persistence.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- Retake point: Task 2, contratos backend de tipos.

### 2026-06-06 - Task 2 contratos backend de tipos cerrada

- Se crearon contratos `TrainingRequirementTypeResponse` y `UpsertTrainingRequirementTypeRequest`.
- Se agregaron endpoints:
  - `GET /api/portal/training-types`
  - `GET /api/portal/training-types/{typeId}`
  - `POST /api/portal/training-types`
  - `PUT /api/portal/training-types/{typeId}`
  - `POST /api/portal/training-types/{typeId}/inactivate`
- Se agregaron metodos de repositorio para listar, consultar, crear, actualizar e inactivar tipos I5 con auditoria.
- Se validan nombre obligatorio, categoria `CURSO`/`ACREDITACION`, vigencia positiva u opcional y codigo unico.
- Seguridad backend: ADMIN/TH gestionan; GERENCIA/OPERACIONES consultan sin editar.
- TDD RED: `scripts/dev/Verify-SgSuperAppI5Types.ps1` fallo inicialmente con HTTP 404 por endpoint inexistente.
- Verificacion GREEN: `scripts/dev/Verify-SgSuperAppI5Types.ps1` correcto.
- Verificacion GREEN: `scripts/dev/Verify-SgSuperAppI5Security.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- Retake point: Task 3, renovaciones y reglas de fecha.

### 2026-06-06 - Task 3 renovaciones y reglas de fecha cerrada

- Se crearon contratos `CreateTrainingRecordRequest` y `TrainingRecordResponse`.
- Se agrego `POST /api/portal/employees/{employeeId}/training` para registrar renovaciones por empleado.
- Se agrego `POST /api/portal/training/{recordId}/inactivate` para inactivar renovaciones sin borrar historico.
- Se validan empleado existente, tipo existente y activo, fecha de realizacion valida, vencimiento manual requerido si el tipo no tiene vigencia y vencimiento no anterior a realizacion.
- El vencimiento se calcula desde `validity_days` cuando el tipo lo define.
- Se registra auditoria `TRAINING_RECORD_CREATED` y `TRAINING_RECORD_INACTIVATED`.
- TDD RED: `scripts/dev/Verify-SgSuperAppI5Renewals.ps1` fallo inicialmente con HTTP 404 por endpoint inexistente.
- Verificacion GREEN: `scripts/dev/Verify-SgSuperAppI5Renewals.ps1` correcto.
- Verificacion GREEN: `scripts/dev/Verify-SgSuperAppI5Audit.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- Retake point: Task 4, estados calculados.

### 2026-06-06 - Task 4 estados calculados cerrada

- Se creo `TrainingComplianceStatusCalculator` para centralizar la regla de estados y reutilizarla en I6.
- `TrainingRecordResponse` expone `complianceStatus` y `daysUntilExpiry`.
- Los estados se calculan por dias restantes contra la fecha actual:
  - `VENCIDO`: menor a 0 dias.
  - `CRITICO`: 0 a 15 dias.
  - `PREVENTIVO`: 16 a 30 dias.
  - `INFORMATIVO`: 31 a 60 dias.
  - `AL_DIA`: 61 dias o mas.
- TDD RED: `scripts/dev/Verify-SgSuperAppI5StatusRules.ps1` fallo inicialmente porque `complianceStatus` no estaba expuesto.
- Verificacion GREEN: `scripts/dev/Verify-SgSuperAppI5StatusRules.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- Retake point: Task 5, habilitacion de servicio.

### 2026-06-06 - Task 5 habilitacion de servicio cerrada

- Se creo contrato `TrainingServiceEnablementResponse`.
- Se agrego endpoint `GET /api/portal/employees/{employeeId}/training/enablement` protegido por `TRAINING_SERVICE_ENABLEMENT/VIEW`.
- Se implemento `GetTrainingServiceEnablementAsync` con indicador calculado, no persistido manualmente.
- La regla bloquea servicio solo cuando existe requisito obligatorio, activo, de servicio, vencido y asociado al empleado.
- Se reutiliza `TrainingComplianceStatusCalculator` para determinar vencimiento.
- TDD RED: `scripts/dev/Verify-SgSuperAppI5ServiceEnablement.ps1` fallo inicialmente con HTTP 404 por endpoint inexistente.
- Verificacion GREEN: `scripts/dev/Verify-SgSuperAppI5ServiceEnablement.ps1` correcto.
- Verificacion GREEN: `scripts/dev/Verify-SgSuperAppI5Security.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- Retake point: Task 6, listado y detalle backend.

### 2026-06-06 - Task 6 listado y detalle backend cerrada

- Se crearon contratos `TrainingComplianceSummaryResponse`, `TrainingComplianceDetailResponse`, `TrainingComplianceEmployeeResponse` y `TrainingCurrentPositionResponse`.
- Se agrego `GET /api/portal/training-compliance` con filtros por empleado, tipo, estado calculado y habilitacion.
- Se agrego `GET /api/portal/employees/{employeeId}/training-compliance` con empleado, puesto actual, habilitacion, requisitos actuales e historico.
- Se implementaron consultas por rol bajo `TRAINING_RECORDS/VIEW`; GERENCIA y OPERACIONES consultan sin acciones de edicion.
- Se conserva la regla de estados mediante `TrainingComplianceStatusCalculator`.
- TDD RED: `scripts/dev/Verify-SgSuperAppI5Queries.ps1` fallo inicialmente con HTTP 404 por endpoint inexistente.
- Verificacion GREEN: `scripts/dev/Verify-SgSuperAppI5Queries.ps1` correcto.
- Verificacion GREEN: `scripts/dev/Verify-SgSuperAppI5Security.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- Retake point: Task 7, cliente API y tipos frontend.

### 2026-06-06 - Task 7 cliente API y tipos frontend cerrada

- Se agregaron tipos TypeScript I5 en `apps/sg-superapp-web/src/types/portal.ts`.
- Los tipos cubren tipos de requisito, renovaciones, estados calculados, habilitacion, listado de cumplimiento y detalle de cumplimiento.
- Se agregaron funciones cliente I5 en `apps/sg-superapp-web/src/services/portalApi.ts`.
- El cliente cubre tipos, creacion/inactivacion de renovaciones, habilitacion, listado de cumplimiento y detalle por empleado.
- Los errores HTTP siguen propagando `message` backend mediante `getJson`/`sendJson`.
- TDD RED: `npm run build` fallo inicialmente con exports faltantes desde un contrato temporal `src/i5-api-contract.red.ts`.
- GREEN: `npm run build` correcto fuera del sandbox; dentro del sandbox Vite/esbuild falla con `Access is denied` al resolver `vite.config.ts`.
- Retake point: Task 8, UI de cumplimiento.

### 2026-06-06 - Task 8 UI de cumplimiento cerrada

- Se agrego `CoursesPage` en `apps/sg-superapp-web/src/features/courses/CoursesPage.tsx`.
- Se cableo el modulo `courses` en `ModuleWorkspace`.
- La UI incluye filtros por empleado/identificacion, tipo, estado calculado y habilitacion.
- La vista de detalle muestra empleado, puesto actual, habilitacion, KPIs, requisitos actuales e historico.
- OPERACIONES/GERENCIA quedan como roles de consulta sin acciones de edicion.
- Se agregaron estilos responsive dark/gold para la vista I5 sin crear un sistema visual paralelo.
- TDD RED: `npm run build` fallo inicialmente por `CoursesPage` inexistente desde `src/i5-courses-ui.red.ts`.
- GREEN: `npm run build` correcto fuera del sandbox; dentro del sandbox Vite/esbuild falla con `Access is denied` al resolver `vite.config.ts`.
- Verificacion GREEN: `scripts/dev/Verify-SgSuperAppI5Security.ps1` correcto.
- Retake point: Task 9, UI de gestion TH/ADMIN.

### 2026-06-09 - Task 9 UI de gestion TH/ADMIN cerrada

- Se agrego verificacion TDD `scripts/dev/Verify-SgSuperAppI5ManagementUi.ps1` para exigir marcadores de gestion visual de tipos y renovaciones en `CoursesPage`.
- Se extendio `apps/sg-superapp-web/src/features/courses/CoursesPage.tsx` sin crear sistema visual nuevo:
  - ADMIN/TH pueden crear/editar/inactivar tipos de curso/acreditacion.
  - ADMIN/TH pueden registrar renovaciones por empleado.
  - ADMIN/TH pueden inactivar renovaciones activas desde requisitos actuales.
  - GERENCIA/OPERACIONES conservan vista de consulta sin acciones de edicion visibles.
  - Errores de validacion/permiso se muestran desde mensajes backend propagados por el cliente API.
- Se ajusto `CreateTrainingRecordRequest.expiresAt` en TypeScript a `string | null`, alineado con el backend para vencimiento calculado por vigencia.
- Se agregaron estilos responsive compactos para gestion I5 en `apps/sg-superapp-web/src/styles.css`.
- TDD RED: `scripts/dev/Verify-SgSuperAppI5ManagementUi.ps1` fallo inicialmente por marcador faltante `createTrainingRequirementType`.
- GREEN: `scripts/dev/Verify-SgSuperAppI5ManagementUi.ps1` correcto.
- GREEN: `npm run build` correcto en `apps/sg-superapp-web`.
- GREEN: con API temporal en `http://localhost:5080`, `scripts/dev/Verify-SgSuperAppI5Types.ps1` correcto.
- GREEN: con API temporal en `http://localhost:5080`, `scripts/dev/Verify-SgSuperAppI5Renewals.ps1` correcto.
- `graphify update .` intentado y fallido porque `graphify` no esta disponible en PATH.
- Retake point: Task 10, verificacion integral y cierre I5.

### 2026-06-09 - Task 10 verificacion integral y cierre I5

- Suite completa I5 ejecutada con API temporal en `http://localhost:5080`:
  - `Verify-SgSuperAppI5Audit.ps1`
  - `Verify-SgSuperAppI5ManagementUi.ps1`
  - `Verify-SgSuperAppI5Persistence.ps1`
  - `Verify-SgSuperAppI5PersistenceClean.ps1`
  - `Verify-SgSuperAppI5Queries.ps1`
  - `Verify-SgSuperAppI5Renewals.ps1`
  - `Verify-SgSuperAppI5Security.ps1`
  - `Verify-SgSuperAppI5ServiceEnablement.ps1`
  - `Verify-SgSuperAppI5StatusRules.ps1`
  - `Verify-SgSuperAppI5Types.ps1`
- Resultado: suite completa correcta.
- Frontend build: `npm run build` en `apps/sg-superapp-web` correcto.
- Backend build: primer intento fallo por binario bloqueado por proceso local `sg-superapp-api` PID 8876; se detuvo el proceso y se repitio `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` con 0 advertencias y 0 errores.
- Se registro matriz final de aceptacion 1-20.
- Se registraron riesgos residuales.
- `graphify update .` intentado y fallido porque `graphify` no esta disponible en PATH.
- I5 queda cerrado tecnicamente.
- Retake point: I6 Gate 0, crear SPEC I6 y plan I6 de Alertas y Notificaciones antes de codificar.
