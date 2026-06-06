# Plan I5 - Cursos y Acreditaciones

**Fecha:** 2026-06-05  
**Producto:** S&G Super App  
**Incremento:** I5 - Cursos y Acreditaciones  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Estado del plan:** Revisado y aprobado  
**Fecha de aprobacion:** 2026-06-05  
**Gate actual:** Task 1 cerrada; implementacion autorizada desde Task 2  

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

- [ ] Criterios de aceptacion 1-20 cubiertos.
- [ ] Suite funcional I5 ejecutada.
- [ ] Backend build limpio.
- [ ] Frontend build limpio.
- [ ] Riesgos residuales documentados.
- [ ] Retake point I6 definido.

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

- [ ] ADMIN/TH crean, editan e inactivan tipos.
- [ ] GERENCIA/OPERACIONES consultan sin editar.
- [ ] Codigo unico se valida si se define.
- [ ] Vigencia en dias es opcional y no negativa.

**Verificacion:**

- [ ] `scripts/dev/Verify-SgSuperAppI5Types.ps1`
- [ ] `scripts/dev/Verify-SgSuperAppI5Security.ps1`
- [ ] `dotnet build`

### Task 3 - Renovaciones y reglas de fecha

**Objetivo:** implementar registro de renovaciones por empleado.

**Criterios:** 4, 5, 6, 7, 8, 16, 17.

**Aceptacion:**

- [ ] TH registra renovacion para empleado existente.
- [ ] Tipo activo es obligatorio.
- [ ] Vencimiento se calcula desde vigencia cuando aplica.
- [ ] Vencimiento manual se exige cuando no hay vigencia.
- [ ] Vencimiento anterior a realizacion se rechaza.
- [ ] Historico no se borra.
- [ ] Auditoria registra cambios.

**Verificacion:**

- [ ] `scripts/dev/Verify-SgSuperAppI5Renewals.ps1`
- [ ] `scripts/dev/Verify-SgSuperAppI5Audit.ps1`
- [ ] `dotnet build`

### Task 4 - Estados calculados

**Objetivo:** calcular estados de vencimiento por umbral.

**Criterios:** 9, 20.

**Aceptacion:**

- [ ] `VENCIDO` se calcula correctamente.
- [ ] `CRITICO` se calcula correctamente.
- [ ] `PREVENTIVO` se calcula correctamente.
- [ ] `INFORMATIVO` se calcula correctamente.
- [ ] `AL_DIA` se calcula correctamente.
- [ ] Reglas quedan reutilizables por I6.

**Verificacion:**

- [ ] `scripts/dev/Verify-SgSuperAppI5StatusRules.ps1`
- [ ] `dotnet build`

### Task 5 - Habilitacion de servicio

**Objetivo:** calcular habilitado/no habilitado segun requisitos obligatorios vencidos.

**Criterios:** 10, 11, 12, 13.

**Aceptacion:**

- [ ] Obligatorio vencido marca `NO_HABILITADO`.
- [ ] Obligatorio no vencido mantiene `HABILITADO`.
- [ ] No obligatorio vencido no bloquea habilitacion.
- [ ] Operaciones consulta habilitacion sin editar.
- [ ] Gerencia consulta cumplimiento sin editar.

**Verificacion:**

- [ ] `scripts/dev/Verify-SgSuperAppI5ServiceEnablement.ps1`
- [ ] `scripts/dev/Verify-SgSuperAppI5Security.ps1`
- [ ] `dotnet build`

### Task 6 - Listado y detalle backend

**Objetivo:** exponer consultas de cumplimiento y detalle por empleado.

**Criterios:** 12, 13, 14, 15.

**Aceptacion:**

- [ ] Listado filtra por empleado, tipo, estado y habilitacion.
- [ ] Detalle muestra requisitos actuales.
- [ ] Detalle muestra historico de renovaciones.
- [ ] Puesto actual se expone si existe.

**Verificacion:**

- [ ] `scripts/dev/Verify-SgSuperAppI5Queries.ps1`
- [ ] `dotnet build`

### Task 7 - Cliente API y tipos frontend

**Objetivo:** agregar tipos TypeScript y cliente API I5.

**Criterios:** 1-20.

**Aceptacion:**

- [ ] Tipos cubren tipo, renovacion, estado y habilitacion.
- [ ] Cliente API cubre tipos, cumplimiento, detalle y renovaciones.
- [ ] Errores HTTP propagan mensajes backend.

**Verificacion:**

- [ ] `npm run build`

### Task 8 - UI de cumplimiento

**Objetivo:** implementar listado y detalle de cumplimiento por empleado.

**Criterios:** 12, 13, 14, 15, 19.

**Aceptacion:**

- [ ] Listado filtra por empleado, tipo, estado y habilitacion.
- [ ] Detalle muestra actuales e historico.
- [ ] Operaciones/Gerencia consultan sin acciones.
- [ ] UI respeta estilo dark/gold administrativo.

**Verificacion:**

- [ ] `npm run build`
- [ ] `scripts/dev/Verify-SgSuperAppI5Security.ps1`

### Task 9 - UI de gestion TH/ADMIN

**Objetivo:** implementar gestion visual de tipos y renovaciones.

**Criterios:** 2, 3, 4, 5, 6, 7, 8, 17, 19.

**Aceptacion:**

- [ ] ADMIN/TH gestionan tipos.
- [ ] ADMIN/TH registran renovaciones.
- [ ] GERENCIA/OPERACIONES no ven acciones de edicion.
- [ ] Errores de fechas y permisos se muestran desde backend.

**Verificacion:**

- [ ] `npm run build`
- [ ] `scripts/dev/Verify-SgSuperAppI5Types.ps1`
- [ ] `scripts/dev/Verify-SgSuperAppI5Renewals.ps1`

### Task 10 - Verificacion integral y cierre I5

**Objetivo:** demostrar cumplimiento completo de SPEC I5.

**Criterios:** 1-20.

**Aceptacion:**

- [ ] Suite `Verify-SgSuperAppI5*.ps1` completa pasa.
- [ ] Backend build pasa.
- [ ] Frontend build pasa.
- [ ] Matriz final 1-20 queda registrada.
- [ ] Riesgos residuales quedan documentados.
- [ ] Retake point I6 queda definido.

**Verificacion:**

- [ ] `dotnet build apps/sg-superapp-api/sg-superapp-api.csproj`
- [ ] `npm run build` en `apps/sg-superapp-web`
- [ ] `scripts/dev/Verify-SgSuperAppI5*.ps1`
- [ ] `graphify update .` cuando la herramienta este disponible.

## 7. Checkpoints

### Checkpoint A - Base documental y contratos

Despues de Tasks 1-2:

- [x] persistencia I5 creada;
- [ ] permisos I5 registrados;
- [ ] tipos configurables;
- [ ] backend build limpio.

### Checkpoint B - Reglas backend completas

Despues de Tasks 3-6:

- [ ] renovaciones funcionan;
- [ ] estados calculados;
- [ ] habilitacion calculada;
- [ ] consultas por rol disponibles.

### Checkpoint C - UI y cierre

Despues de Tasks 7-10:

- [ ] UI operativa por rol;
- [ ] suite completa I5 pasa;
- [ ] matriz 1-20 registrada;
- [ ] retake I6 definido.

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

## 9. Riesgos Y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Tipos reales no estandarizados | Alto | Catalogo configurable y codigo opcional unico |
| Datos fuente incompletos | Alto | Validaciones de fecha y estado antes de persistir |
| Confusion entre no habilitado y bloqueo operativo | Alto | UI debe mostrar indicador y no bloquear programacion |
| Expectativa de alertas automaticas | Medio | Documentar que I6 implementa alertas/notificaciones |
| Soportes sin ruta aprobada | Medio | Guardar referencia opcional y diferir binarios |
| `graphify` no disponible | Bajo | Intentar `graphify update .` y documentar fallo hasta instalar herramienta |

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
