# Plan I7 - Auditoria, Dashboard y Cierre Piloto

**Fecha:** 2026-06-11  
**Producto:** S&G Super App  
**Incremento:** I7 - Auditoria, Dashboard y Cierre Piloto  
**SPEC:** `docs/specs/2026-06-11-sg-superapp-spec-i7-auditoria-dashboard-cierre-piloto.md`  
**Estado del plan:** Revisado y aprobado  
**Fecha de aprobacion:** 2026-06-11  
**Gate actual:** Task 7 cerrada; implementacion autorizada desde Task 8  

## 1. Objetivo

Cerrar el piloto Talento Humano con dashboard por perfil, consulta de auditoria, demo verificable, reporte de cierre y backlog priorizado para la siguiente fase.

I7 debe consolidar I1-I6 sin reabrir su alcance funcional.

## 2. Premisas

- I6 esta cerrado tecnicamente.
- La autoridad documental sigue siendo `README.md` -> Constitucion -> Arquitectura -> Tecnologia -> Design -> PRD -> SPEC I7 -> Plan I7.
- No se cambia stack.
- No se implementa WhatsApp, HELIZA, nomina, IA avanzada ni modulo completo de novedades.
- Dashboard y auditoria deben respetar roles y permisos.
- Gerencia y Operaciones consultan sin editar datos TH.
- `graphify update .` debe intentarse despues de modificar codigo cuando la herramienta este disponible.

## 3. Gate De Cierre I7

- [ ] Criterios de aceptacion 1-20 cubiertos.
- [ ] Suite funcional I7 ejecutada.
- [ ] Suite de regresion relevante I6 ejecutada o justificada.
- [ ] Backend build limpio.
- [ ] Frontend build limpio.
- [x] Demo checklist documentado.
- [x] Reporte de cierre piloto creado.
- [x] Backlog priorizado documentado.
- [x] Riesgos residuales documentados.
- [ ] Retake final definido.

## 4. Alcance

### Incluido

- Contratos backend de dashboard por rol.
- Contratos backend de auditoria y filtros.
- Persistencia o vista consultable de auditoria si falta cobertura transversal.
- UI dashboard por perfil.
- UI consulta de auditoria.
- Documentos de demo, cierre y backlog.
- Verificacion integral y cierre.

### Excluido

- Reabrir reglas I1-I6.
- Novedades funcional.
- WhatsApp.
- HELIZA.
- Nomina.
- IA avanzada.
- Bloqueo automatico operativo.
- Cambios de stack.

## 5. Tareas

### Task 1 - Contratos backend de dashboard por rol

**Objetivo:** exponer indicadores de dashboard filtrados por usuario/rol autenticado.

**Criterios:** 1, 2, 3, 4, 5, 6, 7, 8, 9, 10.

**Aceptacion:**

- [x] Endpoint autenticado de dashboard disponible.
- [x] Widgets se filtran por rol/permisos.
- [x] Indicadores cubren certificaciones, cursos, importaciones, notificaciones, puestos y plataforma segun rol.
- [x] Widgets no exponen acciones no autorizadas.

**Verificacion:**

- [x] Crear y ejecutar `scripts/dev/Verify-SgSuperAppI7Dashboard.ps1`.
- [x] Ejecutar `C:\tmp\dotnet6\dotnet.exe build apps/sg-superapp-api/sg-superapp-api.csproj`.

### Task 2 - Contratos backend de auditoria y filtros

**Objetivo:** exponer consulta de auditoria transversal con filtros y restricciones por rol.

**Criterios:** 11, 12, 13, 14, 15, 16.

**Aceptacion:**

- [x] Endpoint autenticado de auditoria disponible.
- [x] Eventos incluyen fecha, actor, modulo, accion, entidad y resumen.
- [x] Filtros por modulo, actor y rango de fechas funcionan.
- [x] Restricciones por rol impiden lectura excesiva.

**Verificacion:**

- [x] Crear y ejecutar `scripts/dev/Verify-SgSuperAppI7Audit.ps1`.
- [x] Crear o ampliar verificacion de seguridad I7.
- [x] Ejecutar backend build.

### Task 3 - Seguridad I7 por rol

**Objetivo:** asegurar que dashboard y auditoria respeten permisos de ADMIN, TH, GERENCIA y OPERACIONES.

**Criterios:** 1, 6, 15.

**Aceptacion:**

- [x] ADMIN ve dashboard y auditoria amplia.
- [x] TH ve indicadores y auditoria funcional TH.
- [x] GERENCIA ve indicadores ejecutivos y auditoria limitada.
- [x] OPERACIONES ve indicadores operativos y auditoria limitada.
- [x] Ningun rol de consulta puede editar auditoria ni acceder a acciones no autorizadas.

**Verificacion:**

- [x] Crear y ejecutar `scripts/dev/Verify-SgSuperAppI7Security.ps1`.
- [x] Ejecutar backend build.

### Task 4 - Cliente API y tipos frontend I7

**Objetivo:** agregar tipos y cliente frontend para dashboard y auditoria.

**Criterios:** 1-16.

**Aceptacion:**

- [x] Tipos TypeScript de widgets, metricas y eventos de auditoria definidos.
- [x] Cliente API cubre dashboard y auditoria.
- [x] Mocks frontend quedan alineados con contratos I7.
- [x] Build frontend pasa.

**Verificacion:**

- [x] Crear y ejecutar `scripts/dev/Verify-SgSuperAppI7FrontendApi.ps1`.
- [x] Ejecutar `npm run build` en `apps/sg-superapp-web`.

### Task 5 - UI dashboard por perfil

**Objetivo:** implementar dashboard operativo/ejecutivo segun perfil.

**Criterios:** 1, 2, 3, 4, 5, 6, 7, 8, 9, 10.

**Aceptacion:**

- [x] Dashboard muestra widgets autorizados.
- [x] Gerencia ve lectura ejecutiva.
- [x] TH ve prioridades operativas.
- [x] Operaciones ve habilitacion y puestos/asignaciones.
- [x] Administrador ve salud de plataforma.
- [x] UI respeta `docs/DESIGN.md`.

**Verificacion:**

- [x] Crear y ejecutar `scripts/dev/Verify-SgSuperAppI7DashboardUi.ps1`.
- [x] Ejecutar frontend build.

### Task 6 - UI consulta de auditoria

**Objetivo:** implementar pantalla de auditoria con filtros y detalle.

**Criterios:** 11, 12, 13, 14, 15, 16.

**Aceptacion:**

- [x] Tabla compacta de eventos disponible.
- [x] Filtros por modulo, actor y fecha visibles.
- [x] Detalle estructurado disponible.
- [x] Roles de consulta no ven acciones de edicion.
- [x] UI respeta `docs/DESIGN.md`.

**Verificacion:**

- [x] Crear y ejecutar `scripts/dev/Verify-SgSuperAppI7AuditUi.ps1`.
- [x] Ejecutar frontend build.

### Task 7 - Demo checklist y reporte de cierre piloto

**Objetivo:** documentar evidencia ejecutiva del piloto y guion de demo.

**Criterios:** 17, 18, 19, 20.

**Aceptacion:**

- [x] Demo checklist I1-I7 creado.
- [x] Reporte de cierre piloto creado.
- [x] Backlog priorizado creado.
- [x] Riesgos residuales documentados.
- [x] Recomendacion de escalamiento documentada.

**Verificacion:**

- [x] Crear `docs/demo/2026-06-11-sg-superapp-demo-checklist.md`.
- [x] Crear `docs/reports/2026-06-11-sg-superapp-cierre-piloto.md`.
- [x] Crear `docs/backlog/2026-06-11-sg-superapp-backlog-siguiente-fase.md`.
- [x] Verificacion documental con `Select-String`.

### Task 8 - Verificacion integral y cierre I7

**Objetivo:** demostrar cumplimiento completo de SPEC I7 y dejar cierre del piloto listo.

**Criterios:** 1-20.

**Aceptacion:**

- [ ] Suite `Verify-SgSuperAppI7*.ps1` completa pasa.
- [ ] Regresion relevante I6 pasa o queda justificada.
- [ ] Backend build pasa.
- [ ] Frontend build pasa.
- [ ] Matriz final 1-20 queda registrada.
- [ ] Riesgos residuales quedan documentados.
- [ ] Handoff final queda creado.

**Verificacion:**

- [ ] `C:\tmp\dotnet6\dotnet.exe build apps/sg-superapp-api/sg-superapp-api.csproj`
- [ ] `npm run build` en `apps/sg-superapp-web`
- [ ] `scripts/dev/Verify-SgSuperAppI7*.ps1`
- [ ] regresion I6 seleccionada: seguridad, notificaciones UI y alerts fallback
- [ ] `graphify update .` cuando la herramienta este disponible.

## 6. Checkpoints

### Checkpoint A - Backend I7

Despues de Tasks 1-3:

- [x] dashboard backend por rol disponible;
- [x] auditoria backend filtrable disponible;
- [x] seguridad I7 verificada;
- [x] backend build limpio.

### Checkpoint B - Frontend I7

Despues de Tasks 4-6:

- [x] cliente API y tipos I7 disponibles;
- [x] dashboard UI operativo;
- [x] auditoria UI operativa;
- [x] frontend build limpio.

### Checkpoint C - Cierre Piloto

Despues de Tasks 7-8:

- [x] demo checklist creado;
- [x] reporte de cierre piloto creado;
- [x] backlog priorizado creado;
- [ ] suite integral I7 pasa;
- [ ] cierre piloto documentado.

## 7. Matriz De Trazabilidad

| Criterio SPEC I7 | Tareas |
|------------------|--------|
| 1. Dashboard por rol/permisos | 1, 3, 5, 8 |
| 2. ADMIN ve salud de plataforma | 1, 3, 5, 8 |
| 3. TH ve certificaciones/cursos/importaciones/alertas | 1, 5, 8 |
| 4. Operaciones ve habilitacion y puestos | 1, 5, 8 |
| 5. Gerencia ve indicadores ejecutivos | 1, 5, 8 |
| 6. Widgets sin acciones no autorizadas | 1, 3, 5, 8 |
| 7. Indicadores de certificaciones | 1, 5, 8 |
| 8. Indicadores de cursos/acreditaciones | 1, 5, 8 |
| 9. Indicadores de importacion | 1, 5, 8 |
| 10. Indicadores de notificaciones | 1, 5, 8 |
| 11. Auditoria lista eventos completos | 2, 6, 8 |
| 12. Auditoria filtra por modulo | 2, 6, 8 |
| 13. Auditoria filtra por actor | 2, 6, 8 |
| 14. Auditoria filtra por fechas | 2, 6, 8 |
| 15. Auditoria respeta rol | 2, 3, 6, 8 |
| 16. Eventos existentes consultables | 2, 6, 8 |
| 17. Demo checklist I1-I7 | 7, 8 |
| 18. Reporte de cierre con evidencia | 7, 8 |
| 19. Backlog priorizado | 7, 8 |
| 20. Riesgos y recomendacion | 7, 8 |

## 8. Riesgos Y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Datos demo insuficientes | Medio | Seeds/mocks controlados y supuestos documentados |
| Auditoria historica parcial | Medio | Consolidar eventos existentes y documentar limites |
| Dashboard decorativo | Medio | Trazar cada widget a criterio y decision |
| Reapertura de alcance I1-I6 | Alto | Tratar solo bugs bloqueantes; cambios de alcance por nueva SPEC |
| Consultas pesadas | Medio | Filtros e indices justificados si aplica |
| `graphify` no disponible | Bajo | Intentar y documentar fallo |

## 9. Open Questions

No hay preguntas funcionales bloqueantes para iniciar I7 Task 1.

Decisiones de Gate 0:

- [x] I7 consolida dashboard, auditoria y cierre piloto.
- [x] I7 no reabre I1-I6.
- [x] Novedades permanece como futuro/diseno.
- [x] Demo y reporte son parte del cierre.
- [x] Backlog priorizado es salida obligatoria.

## 10. Execution Log

### 2026-06-11 - Gate 0 SPEC/plan I7 creado y aprobado

- Se leyeron `README.md`, handoff de cierre I6, documentos rectores, SPEC 00, PRD y cierre I6.
- Se creo SPEC I7 con alcance, actores, reglas, permisos, criterios 1-20 y riesgos.
- Se creo plan I7 con 8 tareas, checkpoints, matriz 1-20 y verificaciones.
- Gate 0 cerrado.
- Retake point: Task 1, contratos backend de dashboard por rol.

### 2026-06-11 - Task 1 contratos backend de dashboard por rol cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI7Dashboard.ps1` para validar endpoint autenticado, widgets por ADMIN/TH/GERENCIA/OPERACIONES, metricas obligatorias y bloqueo sin autenticacion.
- RED: `Verify-SgSuperAppI7Dashboard.ps1` fallo con HTTP 404 en `GET /api/portal/dashboard`.
- Se agregaron contratos `DashboardResponse` y `DashboardWidgetResponse`.
- Se agrego `GET /api/portal/dashboard` protegido por `DASHBOARD/VIEW`.
- Se implemento `GetDashboardAsync` con widgets filtrados por rol para plataforma, TH, gerencia, operaciones y notificaciones del usuario/rol.
- GREEN: `scripts/dev/Verify-SgSuperAppI7Dashboard.ps1` correcto contra API local.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 2, contratos backend de auditoria y filtros.

### 2026-06-11 - Task 2 contratos backend de auditoria y filtros cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI7Audit.ps1` para validar endpoint autenticado, forma de eventos, filtros por modulo/actor/rango de fechas, visibilidad por ADMIN/TH/GERENCIA/OPERACIONES y bloqueo sin autenticacion.
- RED: `Verify-SgSuperAppI7Audit.ps1` fallo con HTTP 404 en `GET /api/portal/audit`.
- Se agregaron contratos `AuditEventResponse` y `AuditEventsResponse`.
- Se agrego `GET /api/portal/audit` protegido por `DASHBOARD/VIEW`.
- Se implemento `GetAuditEventsAsync` sobre `audit_log` con clasificacion de modulo, filtros transversales y restricciones por rol.
- GREEN: `scripts/dev/Verify-SgSuperAppI7Audit.ps1` correcto contra API local.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 3, seguridad I7 por rol.

### 2026-06-12 - Task 3 seguridad I7 por rol cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI7Security.ps1` para validar seguridad transversal de dashboard y auditoria.
- La verificacion cubre bloqueo sin autenticacion para `GET /api/portal/dashboard` y `GET /api/portal/audit`.
- La verificacion confirma visibilidad por rol: ADMIN con alcance amplio, TH con indicadores/auditoria TH, GERENCIA con resumen ejecutivo/auditoria limitada y OPERACIONES con indicadores/auditoria operativa.
- La verificacion confirma que roles de consulta no tienen endpoint de mutacion para auditoria.
- GREEN: `scripts/dev/Verify-SgSuperAppI7Security.ps1` correcto contra API local.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 4, cliente API y tipos frontend I7.

### 2026-06-12 - Task 4 cliente API y tipos frontend I7 cerrada

- Se agregaron tipos TypeScript para dashboard, widgets, severidades, scopes, eventos de auditoria y filtros.
- Se agregaron funciones de cliente API `fetchDashboard` y `fetchAuditEvents`, con query string para modulo, actor y rango de fechas.
- Se alinearon mocks frontend con `DashboardResponse`, `DashboardWidget` y `AuditEvent` para preparar las pantallas de Task 5 y Task 6.
- Se creo `scripts/dev/Verify-SgSuperAppI7FrontendApi.ps1` con fixture temporal de contrato TypeScript.
- GREEN: `scripts/dev/Verify-SgSuperAppI7FrontendApi.ps1` correcto con `tsc --noEmit`.
- Frontend build: `npm.cmd run build` en `apps/sg-superapp-web` fallo dentro del sandbox por `esbuild`/`Access is denied` al leer directorios superiores; rerun con permisos elevados correcto, 47 modulos transformados.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 5, UI dashboard por perfil.

### 2026-06-12 - Task 5 UI dashboard por perfil cerrada

- RED: `scripts/dev/Verify-SgSuperAppI7DashboardUi.ps1` fallo porque `DashboardPage` no existia.
- Se creo `apps/sg-superapp-web/src/features/dashboard/DashboardPage.tsx` con carga `fetchDashboard`, fallback local, estado de carga, error y vacio.
- Se conecto `/dashboard` en `App.tsx` para renderizar `DashboardPage` con el usuario actual.
- Se agregaron widgets agrupados por scope `EXECUTIVE`, `TH`, `OPERATIONS`, `ADMIN` y `SYSTEM`, con accion interna cuando el contrato expone `actionUrl`.
- Se agregaron estilos compactos dark/gold para `dashboard-workspace`, resumen, secciones y tarjetas de widget.
- GREEN: `scripts/dev/Verify-SgSuperAppI7DashboardUi.ps1` correcto.
- Frontend build: `npm.cmd run build` fallo dentro del sandbox por `esbuild`/`Access is denied`; rerun con permisos elevados correcto, 48 modulos transformados.
- Preview local: `npm.cmd run preview` fallo dentro del sandbox por la misma limitacion de `esbuild`; rerun con permisos elevados dejo `http://127.0.0.1:3000/` activo y `Invoke-WebRequest http://127.0.0.1:3000/dashboard` respondio HTTP 200.
- Verificacion browser automatizada no ejecutada: Playwright no esta instalado en el runtime Node (`Module not found: playwright`).
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 6, UI consulta de auditoria.

### 2026-06-12 - Task 6 UI consulta de auditoria cerrada

- RED: `scripts/dev/Verify-SgSuperAppI7AuditUi.ps1` fallo porque `AuditPage` no existia.
- Se creo `apps/sg-superapp-web/src/features/audit/AuditPage.tsx` con carga `fetchAuditEvents`, fallback local, estados de carga, error y vacio.
- Se agregaron filtros por modulo, actor, fecha desde y fecha hasta.
- Se agrego tabla compacta de eventos con fecha, modulo, actor, accion y entidad.
- Se agrego panel de detalle estructurado con resumen, rol, metadatos y JSON de detalle.
- Se agrego modulo `audit` a mocks/navegacion y ruta en `ModuleWorkspace`.
- Se agregaron estilos compactos dark/gold para `audit-workspace`, filtros, tabla y detalle.
- GREEN: `scripts/dev/Verify-SgSuperAppI7AuditUi.ps1` correcto.
- Frontend build: `npm.cmd run build` fallo dentro del sandbox por `esbuild`/`Access is denied`; rerun con permisos elevados correcto, 49 modulos transformados.
- Preview local: `Invoke-WebRequest http://127.0.0.1:3000/module/audit` respondio HTTP 200.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 7, demo checklist y reporte de cierre piloto.

### 2026-06-12 - Task 7 demo checklist y reporte de cierre piloto cerrada

- Se creo `docs/demo/2026-06-11-sg-superapp-demo-checklist.md` con recorrido I1-I7, perfiles ADMIN/TH/GERENCIA/OPERACIONES, preparacion, criterios de exito y limites de alcance.
- Se creo `docs/reports/2026-06-11-sg-superapp-cierre-piloto.md` con resumen ejecutivo, alcance construido, evidencia de verificacion, lectura por perfil, riesgos residuales y recomendacion de escalamiento.
- Se creo `docs/backlog/2026-06-11-sg-superapp-backlog-siguiente-fase.md` con backlog P0-P4, secuencia recomendada e items no autorizados sin nueva SPEC.
- Verificacion documental: `Select-String` confirmo cobertura de I1-I7, demo, reporte, backlog, riesgos, recomendacion, escalamiento y prioridades P0/P1.
- No se modifico codigo en Task 7; `graphify update .` no aplica a esta tarea documental.
- Retake point: Task 8, verificacion integral y cierre I7.
