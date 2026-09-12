# Plan I6 - Alertas y Notificaciones

**Fecha:** 2026-06-09  
**Producto:** S&G Super App  
**Incremento:** I6 - Alertas y Notificaciones  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Estado del plan:** Revisado y aprobado  
**Fecha de aprobacion:** 2026-06-09  
**Gate actual:** Task 10 cerrada; I6 cerrado tecnicamente; retake I7 Gate 0  

## 1. Objetivo

Implementar el centro de alertas y notificaciones del piloto Talento Humano con bandeja por usuario/rol, contador, gestion de lectura/archivo, trazabilidad, alertas generadas desde I2/I4/I5 y fallback exportable cuando SMTP no este disponible.

I6 termina cuando el flujo cumpla los 20 criterios de aceptacion de la SPEC I6 sin invadir WhatsApp, integraciones HELIZA/nomina, bloqueo operativo automatico, app movil ni IA avanzada.

## 2. Documentos Rectores

Orden de autoridad aplicable:

1. `docs/CONSTITUTION.md`
2. `docs/ARCHITECTURE.md`
3. `docs/TECNOLOGIA.md`
4. `docs/DESIGN.md`
5. `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`
6. `docs/specs/2026-06-09-sg-superapp-spec-i6-alertas-notificaciones.md`
7. Este plan

SPECs relacionadas:

- `docs/specs/2026-05-21-sg-superapp-spec-00-arquitectura-incrementos.md`
- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`
- `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`
- `docs/specs/2026-05-21-sg-superapp-spec-i4-certificaciones-laborales.md`
- `docs/specs/2026-05-21-sg-superapp-spec-i5-cursos-acreditaciones.md`

## 3. Gate 0

### Decisiones Confirmadas

- I5 queda cerrado tecnicamente y sus reglas de vencimiento se reutilizan en I6.
- I6 implementa notificaciones internas operables por rol.
- SMTP/correo es opcional; no bloquea operacion.
- Fallback exportable es obligatorio.
- WhatsApp queda fuera de alcance.
- `NO_HABILITADO` sigue siendo indicador, no bloqueo automatico de turnos.
- Operaciones/Gerencia consultan sin editar datos TH ni configurar reglas.

### Restricciones

- No implementar WhatsApp.
- No implementar integraciones HELIZA/nomina.
- No bloquear turnos o asignaciones automaticamente.
- No agregar dependencias externas sin actualizar `docs/TECNOLOGIA.md`.
- No depender de SMTP para cerrar I6.
- Mantener compatibilidad con Windows Server 2012.

### Gate De Cierre I6

- [x] Criterios de aceptacion 1-20 cubiertos.
- [x] Suite funcional I6 ejecutada.
- [x] Backend build limpio.
- [x] Frontend build limpio.
- [x] Riesgos residuales documentados.
- [x] Retake point I7 definido.

## 4. Alcance

### Incluido

- Persistencia de notificaciones y eventos.
- Permisos I6 por rol.
- Bandeja por usuario/rol.
- Contador de no leidas.
- Filtros por estado, severidad y modulo.
- Marcar como leida.
- Archivar.
- Alertas por vencimiento I5.
- Alertas por importaciones con error.
- Alertas por certificaciones.
- Exportacion de resumen.
- Intento SMTP opcional con trazabilidad.
- UI administrativa dark/gold.

### Excluido

- WhatsApp.
- Push movil.
- Notificaciones a guardas como usuarios.
- HELIZA/nomina.
- Bloqueo operativo automatico.
- Motor completo de novedades.
- IA avanzada.

## 5. Diseño Tecnico Propuesto

### Persistencia

Tablas nuevas o evolucionadas:

- `notification_items`
- `notification_events`

Campos esperados de `notification_items`:

- `id`
- `target_type`
- `target_key`
- `title`
- `body`
- `severity`
- `source_module`
- `source_type`
- `source_id`
- `dedupe_key`
- `status`
- `action_url`
- `created_at`
- `read_at`
- `managed_at`
- `managed_by`

Campos esperados de `notification_events`:

- `id`
- `notification_id`
- `actor_username`
- `event_type`
- `detail`
- `created_at`

### Contratos API

Endpoints esperados:

- `GET /api/portal/notifications`
- `GET /api/portal/notifications/unread-count`
- `POST /api/portal/notifications/{notificationId}/read`
- `POST /api/portal/notifications/{notificationId}/archive`
- `GET /api/portal/notifications/export`
- `POST /api/portal/alerts/training/generate`
- `POST /api/portal/alerts/imports/generate`
- `POST /api/portal/alerts/certificates/generate`
- `POST /api/portal/notifications/email-summary`

### Reglas De Dedupe

- La clave debe combinar modulo, tipo de fuente, id origen, target y estado relevante.
- Si existe una notificacion activa con la misma clave, se actualiza o se conserva sin duplicar.
- Si la causa desaparece, no se borra automaticamente; se puede archivar o resolver en tarea futura si se aprueba.

### Severidad

- `CRITICAL`: vencido, critico, errores bloqueantes.
- `WARNING`: preventivo, duplicados/incompletos que requieren accion.
- `INFO`: informativo, certificaciones generadas/aprobadas.

## 6. Tareas

### Task 1 - Persistencia I6 y permisos base

**Objetivo:** crear/evolucionar tablas de notificaciones, eventos, permisos y contrato SQL base.

**Criterios:** 1, 2, 5, 6, 18, 20.

**Aceptacion:**

- [x] `notification_items` soporta target, severidad, modulo, dedupe, estado y rutas.
- [x] `notification_events` registra trazabilidad de gestion.
- [x] Estados validan `UNREAD`, `READ`, `ARCHIVED`, `DISMISSED`.
- [x] Severidad valida `INFO`, `WARNING`, `CRITICAL`.
- [x] Permisos I6 quedan registrados para cuatro roles.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI6Persistence.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI6PersistenceClean.ps1`
- [x] `dotnet build`

### Task 2 - Contratos backend de bandeja y contador

**Objetivo:** exponer bandeja de notificaciones y contador de no leidas por usuario/rol.

**Criterios:** 1, 2, 3, 4, 16, 17, 18.

**Aceptacion:**

- [x] Usuario ve notificaciones personales y de su rol.
- [x] Contador considera personales y rol.
- [x] Filtros por estado, severidad y modulo funcionan.
- [x] Operaciones/Gerencia consultan sin endpoints de configuracion.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI6Inbox.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI6Security.ps1`
- [x] `dotnet build`

### Task 3 - Gestion de lectura, archivo y trazabilidad

**Objetivo:** implementar acciones de lectura y archivo con eventos trazables.

**Criterios:** 5, 6, 14, 18, 20.

**Aceptacion:**

- [x] Marcar como leida actualiza `status` y `read_at`.
- [x] Archivar actualiza `status`, `managed_at` y `managed_by`.
- [x] Cada accion registra evento.
- [x] Usuarios no gestionan notificaciones fuera de su usuario/rol.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI6NotificationActions.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI6Security.ps1`
- [x] `dotnet build`

### Task 4 - Generador de alertas I5 por vencimiento

**Objetivo:** generar alertas desde cursos/acreditaciones reutilizando reglas I5.

**Criterios:** 7, 8, 9, 10, 16, 17, 20.

**Aceptacion:**

- [x] VENCIDO y CRITICO generan `CRITICAL`.
- [x] PREVENTIVO genera `WARNING`.
- [x] INFORMATIVO genera `INFO`.
- [x] AL_DIA no genera alerta.
- [x] No se duplican alertas activas por empleado/tipo/estado.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI6TrainingAlerts.ps1`
- [x] `dotnet build`

### Task 5 - Generadores de alertas I2/I4

**Objetivo:** generar alertas desde importaciones con errores y certificaciones.

**Criterios:** 11, 12, 18, 20.

**Aceptacion:**

- [x] Importaciones `CON_ERRORES` generan alerta para TH.
- [x] Errores `ERRONEO`, `DUPLICADO` e `INCOMPLETO` quedan resumidos.
- [x] Certificaciones generadas/aprobadas/anuladas generan notificacion.
- [x] No se duplican alertas activas del mismo origen.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI6ImportAlerts.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI6CertificateAlerts.ps1`
- [x] `dotnet build`

### Task 6 - Exportacion fallback y correo opcional

**Objetivo:** agregar exportacion de resumen y registrar intento SMTP sin bloquear operacion.

**Criterios:** 13, 14, 15, 18, 20.

**Aceptacion:**

- [x] Exportacion genera resumen filtrable.
- [x] Exportacion registra evento `EXPORTED`.
- [x] Email summary registra `EMAIL_ATTEMPTED`.
- [x] Sin SMTP disponible, el endpoint responde con resultado controlado y mantiene fallback.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI6Export.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI6EmailFallback.ps1`
- [x] `dotnet build`

### Task 7 - Cliente API y tipos frontend

**Objetivo:** agregar tipos TypeScript y cliente API I6.

**Criterios:** 1-20.

**Aceptacion:**

- [x] Tipos cubren notificacion, evento, filtros, contador y exportacion.
- [x] Cliente API cubre bandeja, contador, acciones, generadores, exportacion y correo opcional.
- [x] Errores HTTP propagan mensajes backend.

**Verificacion:**

- [x] `npm run build`

### Task 8 - UI de bandeja, contador y acciones

**Objetivo:** implementar bandeja operativa de notificaciones en el shell.

**Criterios:** 2, 3, 4, 5, 6, 16, 17, 19.

**Aceptacion:**

- [x] Contador se muestra junto al perfil.
- [x] Bandeja lista personales y rol.
- [x] Filtros por estado, severidad y modulo.
- [x] Acciones leer/archivar disponibles segun permisos.
- [x] Operaciones/Gerencia consultan sin configuracion.
- [x] UI respeta dark/gold administrativo.

**Verificacion:**

- [x] `npm run build`
- [x] `scripts/dev/Verify-SgSuperAppI6Security.ps1`

### Task 9 - UI TH de alertas y fallback

**Objetivo:** implementar panel de generacion/gestion TH para alertas y exportacion.

**Criterios:** 7, 8, 9, 10, 11, 12, 13, 15, 19.

**Aceptacion:**

- [x] ADMIN/TH pueden disparar generacion manual de alertas.
- [x] ADMIN/TH pueden exportar resumen.
- [x] Estado de correo/fallback es visible sin depender de SMTP.
- [x] GERENCIA/OPERACIONES no ven acciones de generacion/configuracion.

**Verificacion:**

- [x] `npm run build`
- [x] `scripts/dev/Verify-SgSuperAppI6TrainingAlerts.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI6Export.ps1`

### Task 10 - Verificacion integral y cierre I6

**Objetivo:** demostrar cumplimiento completo de SPEC I6.

**Criterios:** 1-20.

**Aceptacion:**

- [x] Suite `Verify-SgSuperAppI6*.ps1` completa pasa.
- [x] Backend build pasa.
- [x] Frontend build pasa.
- [x] Matriz final 1-20 queda registrada.
- [x] Riesgos residuales quedan documentados.
- [x] Retake point I7 queda definido.

**Verificacion:**

- [x] `C:\tmp\dotnet6\dotnet.exe build apps/sg-superapp-api/sg-superapp-api.csproj`
- [x] `npm run build` en `apps/sg-superapp-web`
- [x] `scripts/dev/Verify-SgSuperAppI6*.ps1`
- [x] `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.

## 7. Checkpoints

### Checkpoint A - Base documental y persistencia

Despues de Tasks 1-3:

- [x] persistencia I6 creada;
- [x] permisos I6 registrados;
- [x] bandeja y contador disponibles;
- [x] acciones con trazabilidad;
- [x] backend build limpio.

### Checkpoint B - Generadores y fallback

Despues de Tasks 4-6:

- [x] alertas I5 funcionan;
- [x] alertas I2/I4 funcionan;
- [x] exportacion fallback funciona;
- [x] correo opcional no bloquea.

### Checkpoint C - UI y cierre

Despues de Tasks 7-10:

- [x] UI operativa por rol;
- [x] panel TH de alertas disponible;
- [x] suite completa I6 pasa;
- [x] matriz 1-20 registrada;
- [x] retake I7 definido.

## 8. Matriz De Trazabilidad

| Criterio SPEC I6 | Tareas |
|------------------|--------|
| 1. Notificaciones personales y por rol | 1, 2, 10 |
| 2. Contador de no leidas | 2, 7, 8, 10 |
| 3. Bandeja por usuario autenticado | 2, 7, 8, 10 |
| 4. Filtros por estado/severidad/modulo | 2, 7, 8, 10 |
| 5. Marcar como leida | 3, 7, 8, 10 |
| 6. Archivar | 3, 7, 8, 10 |
| 7. ADMIN/TH generan alertas I5 | 4, 9, 10 |
| 8. Severidad correcta por vencimiento | 4, 10 |
| 9. AL_DIA no genera alerta | 4, 10 |
| 10. Dedupe de alertas | 4, 5, 10 |
| 11. Importaciones con error alertan TH | 5, 10 |
| 12. Certificaciones generan notificacion | 5, 10 |
| 13. Exportar resumen | 6, 9, 10 |
| 14. SMTP registra intento/resultado | 6, 10 |
| 15. Sin SMTP hay fallback | 6, 9, 10 |
| 16. Operaciones consulta sin editar | 2, 8, 10 |
| 17. Gerencia consulta sin editar | 2, 8, 10 |
| 18. Seguridad backend | 1, 2, 3, 6, 10 |
| 19. UI respeta DESIGN | 8, 9, 10 |
| 20. Eventos listos para I7 | 1, 3, 4, 5, 6, 10 |

### Matriz Final De Aceptacion I6

| # | Criterio | Estado | Evidencia |
|---|----------|--------|-----------|
| 1 | Notificaciones personales y por rol | Cumplido | `Verify-SgSuperAppI6Inbox.ps1`, `Verify-SgSuperAppI6NotificationsUi.ps1` |
| 2 | Contador de no leidas | Cumplido | `Verify-SgSuperAppI6Inbox.ps1`, `Verify-SgSuperAppI6FrontendApi.ps1` |
| 3 | Bandeja por usuario autenticado | Cumplido | `Verify-SgSuperAppI6Inbox.ps1`, `Verify-SgSuperAppI6Security.ps1` |
| 4 | Filtros por estado/severidad/modulo | Cumplido | `Verify-SgSuperAppI6Inbox.ps1`, `Verify-SgSuperAppI6NotificationsUi.ps1` |
| 5 | Marcar como leida | Cumplido | `Verify-SgSuperAppI6NotificationActions.ps1` |
| 6 | Archivar | Cumplido | `Verify-SgSuperAppI6NotificationActions.ps1` |
| 7 | ADMIN/TH generan alertas I5 | Cumplido | `Verify-SgSuperAppI6TrainingAlerts.ps1`, `Verify-SgSuperAppI6AlertsFallbackUi.ps1` |
| 8 | Severidad correcta por vencimiento | Cumplido | `Verify-SgSuperAppI6TrainingAlerts.ps1` |
| 9 | `AL_DIA` no genera alerta | Cumplido | `Verify-SgSuperAppI6TrainingAlerts.ps1` |
| 10 | Dedupe de alertas | Cumplido | `Verify-SgSuperAppI6TrainingAlerts.ps1`, `Verify-SgSuperAppI6ImportAlerts.ps1`, `Verify-SgSuperAppI6CertificateAlerts.ps1` |
| 11 | Importaciones con error alertan TH | Cumplido | `Verify-SgSuperAppI6ImportAlerts.ps1` |
| 12 | Certificaciones generan notificacion | Cumplido | `Verify-SgSuperAppI6CertificateAlerts.ps1` |
| 13 | Exportar resumen | Cumplido | `Verify-SgSuperAppI6Export.ps1`, `Verify-SgSuperAppI6AlertsFallbackUi.ps1` |
| 14 | SMTP registra intento/resultado | Cumplido | `Verify-SgSuperAppI6EmailFallback.ps1` |
| 15 | Sin SMTP hay fallback | Cumplido | `Verify-SgSuperAppI6EmailFallback.ps1`, `Verify-SgSuperAppI6Export.ps1` |
| 16 | Operaciones consulta sin editar | Cumplido | `Verify-SgSuperAppI6Security.ps1`, `Verify-SgSuperAppI6NotificationsUi.ps1` |
| 17 | Gerencia consulta sin editar | Cumplido | `Verify-SgSuperAppI6Security.ps1`, `Verify-SgSuperAppI6AlertsFallbackUi.ps1` |
| 18 | Seguridad backend | Cumplido | `Verify-SgSuperAppI6Security.ps1` |
| 19 | UI respeta DESIGN | Cumplido | `Verify-SgSuperAppI6NotificationsUi.ps1`, `Verify-SgSuperAppI6AlertsFallbackUi.ps1`, `npm run build` |
| 20 | Eventos listos para I7 | Cumplido | `Verify-SgSuperAppI6Persistence.ps1`, `Verify-SgSuperAppI6NotificationActions.ps1`, generadores y export/email |

## 9. Riesgos Y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| SMTP no disponible | Medio | Fallback exportable obligatorio y correo opcional |
| Duplicacion de alertas | Alto | Dedupe key por origen/target/estado |
| Ruido operativo por demasiadas alertas | Medio | Filtros por severidad/modulo/estado |
| Jobs no definidos en Windows Server 2012 | Medio | Generacion manual primero; tarea programada compatible si se aprueba |
| Operaciones/Gerencia editan por error | Medio | Permisos backend y UI sin configuracion |
| `graphify` no disponible | Bajo | Intentar `graphify update .` y documentar fallo |

### Riesgos Residuales Al Cierre I6

| Riesgo residual | Estado | Tratamiento |
|-----------------|--------|-------------|
| SMTP real no configurado en ambiente local | Aceptado | I6 no depende de SMTP; queda fallback exportable y trazabilidad de intento/error. |
| `graphify` no disponible en PATH | Aceptado | `graphify update .` fue intentado y documentado; actualizar grafo cuando la herramienta este disponible. |
| Jobs automaticos en Windows Server 2012 no definidos | Diferido | I6 cierra con generacion manual protegida por permisos; automatizacion queda sujeta a aprobacion posterior. |
| Recorrido visual manual desktop/movil puede complementar la evidencia UI | Bajo | Builds y verificaciones estructurales pasaron; recorrido visual puede incorporarse en Gate 0/I7 si se requiere para cierre piloto. |
| Integraciones WhatsApp, HELIZA/nomina y bloqueo operativo automatico | Fuera de alcance | Se mantienen excluidas por SPEC I6 y no bloquean el cierre tecnico. |

## 10. Open Questions

No hay preguntas funcionales bloqueantes para iniciar I6 Task 1.

Decisiones tecnicas de Gate 0:

- [x] I6 inicia con notificaciones internas.
- [x] SMTP no bloquea.
- [x] Fallback exportable es obligatorio.
- [x] WhatsApp queda fuera.
- [x] Reglas I5 se reutilizan para vencimientos.
- [x] Operaciones/Gerencia consultan, no configuran.

## 11. Execution Log

### 2026-06-09 - Gate 0 SPEC/plan I6 creado y aprobado

- Se leyeron documentos rectores, SPEC 00 e handoff de cierre I5.
- Se creo SPEC I6 con alcance, actores, reglas, permisos, criterios 1-20 y riesgos.
- Se creo plan I6 con 10 tareas, checkpoints, matriz 1-20 y verificaciones.
- Gate 0 cerrado.
- Retake point: Task 1, persistencia I6 y permisos base.

### 2026-06-09 - Task 1 persistencia I6 y permisos base cerrada

- Se creo `db/tests/006_i6_notifications_contract.sql` con contrato de persistencia para notificaciones, eventos, constraints, dedupe y permisos I6.
- Se creo `scripts/dev/Verify-SgSuperAppI6Persistence.ps1` para validar el contrato sobre `sg_superapp_dev`.
- Se creo `scripts/dev/Verify-SgSuperAppI6PersistenceClean.ps1` para validar desde migraciones/seeds en esquema temporal `i6_verify_clean`.
- Se creo `db/migrations/008_i6_notifications.sql` para evolucionar `notification_items`, crear `notification_events`, constraints e indices.
- Se creo `db/seeds/008_i6_notification_permissions.sql` con permisos I6 para ADMIN, TH, GERENCIA y OPERACIONES.
- TDD RED: `Verify-SgSuperAppI6Persistence.ps1` fallo inicialmente por tabla `notification_events` ausente.
- TDD RED: `Verify-SgSuperAppI6PersistenceClean.ps1` fallo inicialmente por migracion `008_i6_notifications.sql` inexistente.
- GREEN: migracion 008 + seed 008 aplicados sobre `sg_superapp_dev`.
- GREEN: `scripts/dev/Verify-SgSuperAppI6Persistence.ps1` correcto.
- GREEN: `scripts/dev/Verify-SgSuperAppI6PersistenceClean.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- Retake point: Task 2, contratos backend de bandeja y contador.

### 2026-06-09 - Task 2 contratos backend de bandeja y contador cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI6Inbox.ps1` para validar bandeja autenticada, notificaciones personales/rol, filtros por estado/severidad/modulo y contador de no leidas.
- Se creo `scripts/dev/Verify-SgSuperAppI6Security.ps1` para validar acceso de lectura por ADMIN/TH/GERENCIA/OPERACIONES y ausencia de permisos de generacion/configuracion para GERENCIA/OPERACIONES.
- TDD RED: `Verify-SgSuperAppI6Inbox.ps1` fallo inicialmente por HTTP 404 en `GET /api/portal/notifications`.
- TDD RED: `Verify-SgSuperAppI6Security.ps1` fallo inicialmente por HTTP 404 en `GET /api/portal/notifications`.
- GREEN: se agregaron contratos backend I6 de notificacion con severidad, modulo, origen, accion, fechas de gestion y contador.
- GREEN: se implementaron `GET /api/portal/notifications` y `GET /api/portal/notifications/unread-count` por usuario autenticado y rol.
- GREEN: `scripts/dev/Verify-SgSuperAppI6Inbox.ps1` correcto.
- GREEN: `scripts/dev/Verify-SgSuperAppI6Security.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- Retake point: Task 3, gestion de lectura, archivo y trazabilidad.

### 2026-06-11 - Task 3 gestion de lectura, archivo y trazabilidad cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI6NotificationActions.ps1` para validar marcar como leida, archivar, campos de gestion, eventos `READ`/`ARCHIVED` y bloqueo de gestion fuera de usuario/rol.
- Se amplio `scripts/dev/Verify-SgSuperAppI6Security.ps1` para cubrir intentos de gestion sobre notificaciones fuera del alcance autenticado.
- TDD RED: `Verify-SgSuperAppI6NotificationActions.ps1` fallo inicialmente por HTTP 404 en `POST /api/portal/notifications/{notificationId}/read`.
- GREEN: se implementaron `POST /api/portal/notifications/{notificationId}/read` y `POST /api/portal/notifications/{notificationId}/archive`.
- GREEN: las acciones actualizan `status`, `read_at`, `archived_at`, `managed_at` y `managed_by` segun corresponda.
- GREEN: cada accion registra evento trazable en `notification_events`.
- GREEN: la gestion queda limitada a notificaciones visibles por usuario o rol autenticado.
- GREEN: `scripts/dev/Verify-SgSuperAppI6NotificationActions.ps1` correcto.
- GREEN: `scripts/dev/Verify-SgSuperAppI6Security.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- Retake point: Task 4, generador de alertas I5 por vencimiento.

### 2026-06-11 - Task 4 generador de alertas I5 por vencimiento cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI6TrainingAlerts.ps1` para validar estados I5 `VENCIDO`, `CRITICO`, `PREVENTIVO`, `INFORMATIVO` y `AL_DIA`, severidad esperada, evento `CREATED`, restriccion de generacion y dedupe activo.
- RED: `scripts/dev/Verify-SgSuperAppI6TrainingAlerts.ps1` fallo por HTTP 404 en `POST /api/portal/alerts/training/generate`.
- Se agrego `POST /api/portal/alerts/training/generate` protegido por `NOTIFICATIONS/GENERATE_ALERTS`.
- Se implemento `GenerateTrainingExpiryAlertsAsync` reutilizando `TrainingComplianceStatusCalculator` de I5 y generando notificaciones `TRAINING`/`TRAINING_EXPIRY` para rol `TH`.
- GREEN: `scripts/dev/Verify-SgSuperAppI6TrainingAlerts.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 5, generadores de alertas I2/I4.

### 2026-06-11 - Task 5 generadores de alertas I2/I4 cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI6ImportAlerts.ps1` para validar alertas desde importaciones `CON_ERRORES`, resumen de `INCOMPLETO`, `DUPLICADO` y `ERRONEO`, evento `CREATED`, dedupe activo y bloqueo para `GERENCIA`.
- Se creo `scripts/dev/Verify-SgSuperAppI6CertificateAlerts.ps1` para validar notificaciones desde certificaciones `GENERADA`, `APROBADA` y `ANULADA`, evento `CREATED`, dedupe activo y bloqueo para `GERENCIA`.
- RED: ambos scripts fallaron inicialmente por HTTP 404 en `POST /api/portal/alerts/imports/generate` y `POST /api/portal/alerts/certificates/generate`.
- Se agregaron `POST /api/portal/alerts/imports/generate` y `POST /api/portal/alerts/certificates/generate`, protegidos por `NOTIFICATIONS/GENERATE_ALERTS`.
- Se implementaron `GenerateImportErrorAlertsAsync` y `GenerateCertificateAlertsAsync` con notificaciones para rol `TH`, fuentes `IMPORTS`/`IMPORT_BATCH` y `CERTIFICATES`/`LABOR_CERTIFICATE`, dedupe por origen y trazabilidad `CREATED`.
- GREEN: `scripts/dev/Verify-SgSuperAppI6ImportAlerts.ps1` correcto.
- GREEN: `scripts/dev/Verify-SgSuperAppI6CertificateAlerts.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 6, exportacion fallback y correo opcional.

### 2026-06-11 - Task 6 exportacion fallback y correo opcional cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI6Export.ps1` para validar exportacion CSV filtrable por estado, severidad y modulo, visibilidad por rol y evento `EXPORTED`.
- Se creo `scripts/dev/Verify-SgSuperAppI6EmailFallback.ps1` para validar email summary con SMTP no disponible, respuesta controlada, `EMAIL_ATTEMPTED`, `EMAIL_FAILED`, fallback disponible y bloqueo para `GERENCIA`.
- RED: `Verify-SgSuperAppI6Export.ps1` fallo por HTTP 404 en `GET /api/portal/notifications-summary/export`.
- RED: `Verify-SgSuperAppI6EmailFallback.ps1` fallo por HTTP 404 en `POST /api/portal/notifications-summary/email`.
- Se agregaron `GET /api/portal/notifications-summary/export` protegido por `NOTIFICATIONS/EXPORT` y `POST /api/portal/notifications-summary/email` protegido por `NOTIFICATIONS/CONFIGURE_EMAIL`.
- Se implementaron `ExportNotificationsAsync` y `AttemptNotificationEmailSummaryAsync`, reutilizando visibilidad de usuario/rol y registrando eventos `EXPORTED`, `EMAIL_ATTEMPTED` y `EMAIL_FAILED`.
- GREEN: `scripts/dev/Verify-SgSuperAppI6Export.ps1` correcto.
- GREEN: `scripts/dev/Verify-SgSuperAppI6EmailFallback.ps1` correcto.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 7, cliente API y tipos frontend.

### 2026-06-11 - Task 7 cliente API y tipos frontend cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI6FrontendApi.ps1` para validar contrato TypeScript de tipos I6 y cliente API.
- RED: `Verify-SgSuperAppI6FrontendApi.ps1` fallo por tipos faltantes `NotificationFilters`, `NotificationSeverity`, `NotificationStatus`, `NotificationUnreadCountResponse`, `NotificationGenerationResponse`, `NotificationEmailSummaryRequest`, `NotificationEmailSummaryResponse` y funciones faltantes del cliente API I6.
- Se ampliaron `apps/sg-superapp-web/src/types/portal.ts` y `apps/sg-superapp-web/src/services/portalApi.ts`.
- El cliente API cubre bandeja autenticada, contador, leer, archivar, generadores I5/I2/I4, exportacion CSV y email summary.
- Se actualizaron mocks frontend al contrato enriquecido de `NotificationItem`.
- GREEN: `scripts/dev/Verify-SgSuperAppI6FrontendApi.ps1` correcto.
- GREEN: `npm run build` en `apps/sg-superapp-web` correcto fuera del sandbox; 46 modulos transformados, bundle JS 232.51 kB.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 8, UI de bandeja, contador y acciones.

### 2026-06-11 - Task 8 UI de bandeja, contador y acciones cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI6NotificationsUi.ps1` para validar contrato estructural de bandeja, contador accesible, filtros, acciones y estilos.
- RED: `Verify-SgSuperAppI6NotificationsUi.ps1` fallo porque el shell aun no cargaba bandeja autenticada ni contador API.
- Se amplio `usePortalShell` para cargar `fetchNotificationsInbox`, `fetchNotificationUnreadCount`, refrescar bandeja y ejecutar acciones `markNotificationAsRead`/`archiveNotification`.
- Se implemento bandeja operativa en `ShellLayout` con contador accesible junto al perfil, filtros por estado/severidad/modulo, listado personal/rol y acciones leer/archivar.
- Se agregaron estilos dark/gold para `notification-tray`, `notification-filters` y `notification-row`, con layout estable desktop/movil.
- GREEN: `scripts/dev/Verify-SgSuperAppI6NotificationsUi.ps1` correcto.
- GREEN: `scripts/dev/Verify-SgSuperAppI6Security.ps1` correcto contra API local.
- GREEN: `npm run build` en `apps/sg-superapp-web` correcto fuera del sandbox; 46 modulos transformados, bundle JS 236.87 kB.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 9, UI TH de alertas y fallback.

### 2026-06-11 - Task 9 UI TH de alertas y fallback cerrada

- Se creo `scripts/dev/Verify-SgSuperAppI6AlertsFallbackUi.ps1` para validar contrato estructural del panel TH de alertas/fallback.
- RED: `Verify-SgSuperAppI6AlertsFallbackUi.ps1` fallo porque `AlertsPage` no existia.
- Se creo `apps/sg-superapp-web/src/features/alerts/AlertsPage.tsx`.
- Se conecto modulo `alerts` en `ModuleWorkspace`.
- El panel permite a ADMIN/TH disparar generadores I5/I2/I4, exportar resumen y consultar estado de email/fallback.
- GERENCIA/OPERACIONES ven estado de consulta sin acciones de generacion/configuracion.
- Se agregaron estilos `alerts-workspace`, `alert-action-grid`, `alert-action-card` y `alert-fallback-panel`.
- GREEN: `scripts/dev/Verify-SgSuperAppI6AlertsFallbackUi.ps1` correcto.
- GREEN: `npm run build` en `apps/sg-superapp-web` correcto fuera del sandbox; 47 modulos transformados, bundle JS 240.88 kB.
- GREEN: `scripts/dev/Verify-SgSuperAppI6TrainingAlerts.ps1` correcto contra API local.
- GREEN: `scripts/dev/Verify-SgSuperAppI6Export.ps1` correcto contra API local.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 10, verificacion integral y cierre I6.

### 2026-06-11 - Task 10 verificacion integral y cierre I6 cerrada

- Suite integral I6 ejecutada contra API local en `http://localhost:5080`; 13 scripts `Verify-SgSuperAppI6*.ps1` pasaron en verde.
- Scripts GREEN: `Verify-SgSuperAppI6Persistence.ps1`, `Verify-SgSuperAppI6PersistenceClean.ps1`, `Verify-SgSuperAppI6Inbox.ps1`, `Verify-SgSuperAppI6Security.ps1`, `Verify-SgSuperAppI6NotificationActions.ps1`, `Verify-SgSuperAppI6TrainingAlerts.ps1`, `Verify-SgSuperAppI6ImportAlerts.ps1`, `Verify-SgSuperAppI6CertificateAlerts.ps1`, `Verify-SgSuperAppI6Export.ps1`, `Verify-SgSuperAppI6EmailFallback.ps1`, `Verify-SgSuperAppI6FrontendApi.ps1`, `Verify-SgSuperAppI6NotificationsUi.ps1`, `Verify-SgSuperAppI6AlertsFallbackUi.ps1`.
- Backend build: `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj` correcto, 0 advertencias y 0 errores.
- Frontend build: `npm run build` en `apps/sg-superapp-web` correcto fuera del sandbox; Vite transformo 47 modulos y genero bundle JS `240.88 kB`.
- Matriz final de aceptacion 1-20 registrada como cumplida.
- Riesgos residuales registrados y no bloqueantes para cierre tecnico.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- I6 queda cerrado tecnicamente.
- Retake point: I7 Gate 0, crear/aprobar SPEC y plan de auditoria, dashboard y cierre piloto antes de implementar codigo.
