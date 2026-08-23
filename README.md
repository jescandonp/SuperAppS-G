# ProyectoS&G - S&G Super App

S&G Super App es el ecosistema digital propuesto para Seguridad & Gestion Ltda. El piloto inicial se enfoca en Talento Humano, con certificaciones laborales y alertas de cursos/acreditaciones como quick wins, pero se estructura desde el inicio como plataforma interna con datos maestros, perfiles, trazabilidad y capacidad de evolucionar hacia novedades, operaciones, inventario, armamento, nomina e integraciones.

El proyecto se organiza bajo **Spec-Driven Development (SDD), nivel Spec-Anchored**: las especificaciones gobiernan el desarrollo y el codigo no es la fuente primaria de verdad.

## Entrada Canonica

Este `README.md` es el punto de entrada obligatorio para iniciar o retomar trabajo en el repositorio.

Antes de editar codigo:

1. Leer este `README.md`.
2. Confirmar el incremento activo y su gate.
3. Leer los documentos rectores en el orden definido por la Constitucion.
4. Leer la SPEC activa completa.
5. Leer el plan activo completo.
6. Verificar que SPEC y plan esten aprobados.

Si la SPEC o el plan activo estan en revision, la implementacion permanece pausada. En ese estado solo se permite trabajar sobre artefactos documentales y decisiones pendientes.

## Orden De Autoridad

| Documento | Proposito |
|-----------|-----------|
| `docs/CONSTITUTION.md` | Reglas SDD, autoridad de artefactos, gates, alcance y limites por incremento |
| `docs/ARCHITECTURE.md` | Arquitectura rectora de la S&G Super App y modelo de ecosistema |
| `docs/TECNOLOGIA.md` | Restricciones, decisiones y criterios de seleccion tecnologica |
| `docs/DESIGN.md` | Identidad visual, UX/UI y reglas de diseño para la Super App |
| `docs/prd/` | PRD del piloto y documentos de producto |
| `docs/specs/` | SPECs por incremento |
| `docs/plans/` | Planes ejecutables, execution logs y tareas por incremento |
| `Referencias/` | Insumos reales compartidos por S&G para levantamiento funcional |
| `Prototipos/` | Prototipos visuales, pantallas, mockups y capturas de referencia |

Cuando exista contradiccion, prevalece el orden definido en `docs/CONSTITUTION.md`. El codigo fuente no reemplaza una decision documental.

## Incrementos Del Piloto

| Incremento | Descripcion | Estado |
|-----------|-------------|--------|
| I0 | Descubrimiento tecnico e infraestructura | Cerrado |
| I1 | Portal base | Cerrado tecnicamente |
| I2 | Datos maestros e importacion | Cerrado tecnicamente: pendiente solo recorrido visual manual desktop/movil |
| I3 | Puestos de servicio y asignaciones | Cerrado tecnicamente |
| I4 | Certificaciones laborales | Cerrado tecnicamente |
| I5 | Cursos y acreditaciones | Cerrado tecnicamente |
| I6 | Alertas y notificaciones | Cerrado tecnicamente |
| I7 | Auditoria, dashboard y cierre piloto | Activo: Task 7 cerrada; retake Task 8 |
| I8 | UX/UI Sentinel Enterprise | Activo: Task 2 cerrada; siguiente retake Task 3 |

El incremento activo, sus decisiones y validaciones obligatorias deben consultarse siempre en `docs/specs/` y `docs/plans/`.

## Gate Actual

**Incremento activo:** I7 - Auditoria, dashboard y cierre piloto
**Estado:** I6 cerrado tecnicamente; SPEC I7 y plan I7 aprobados; Task 7 cerrada. Iteracion UX/UI I8 abierta con SPEC/plan aprobados y Task 2 cerrada.
**Implementacion:** cierre funcional autorizado desde Task 8 del plan I7; refinamiento visual autorizado desde Task 3 del plan I8.

Documentos obligatorios para la revision:

- SPEC I3 cerrada: `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`
- Plan I3 cerrado: `docs/plans/2026-06-04-sg-superapp-i3-puestos-servicio-asignaciones-plan.md`
- SPEC I4 cerrada: `docs/specs/2026-05-21-sg-superapp-spec-i4-certificaciones-laborales.md`
- Plan I4 cerrado: `docs/plans/2026-06-05-sg-superapp-i4-certificaciones-laborales-plan.md`
- SPEC I5 cerrada: `docs/specs/2026-05-21-sg-superapp-spec-i5-cursos-acreditaciones.md`
- Plan I5 cerrado: `docs/plans/2026-06-05-sg-superapp-i5-cursos-acreditaciones-plan.md`
- SPEC I6: `docs/specs/2026-06-09-sg-superapp-spec-i6-alertas-notificaciones.md`
- Plan I6: `docs/plans/2026-06-09-sg-superapp-i6-alertas-notificaciones-plan.md`
- Handoff cierre I6: `docs/handoff/handoff-20260611-i6-closed-retake-i7-gate0.md`
- SPEC I7: `docs/specs/2026-06-11-sg-superapp-spec-i7-auditoria-dashboard-cierre-piloto.md`
- Plan I7: `docs/plans/2026-06-11-sg-superapp-i7-auditoria-dashboard-cierre-piloto-plan.md`
- SPEC I8 UX/UI: `docs/specs/2026-06-16-sg-superapp-spec-i8-uxui-sentinel-enterprise.md`
- Plan I8 UX/UI: `docs/plans/2026-06-16-sg-superapp-i8-uxui-sentinel-enterprise-plan.md`

La SPEC I3 y el plan I3 fueron aprobados el 2026-06-04. I3 queda cerrado tecnicamente el 2026-06-05.

I2 queda cerrado tecnicamente. Sus riesgos residuales y la matriz de aceptacion estan registrados en el execution log del plan I2.

## Estructura Base

```text
ProyectoS&G/
├── docs/
│   ├── CONSTITUTION.md
│   ├── ARCHITECTURE.md
│   ├── TECNOLOGIA.md
│   ├── DESIGN.md
│   ├── prd/
│   ├── specs/
│   ├── plans/
│   ├── handoff/
│   └── superpowers/
├── apps/
│   ├── sg-superapp-api/
│   └── sg-superapp-web/
├── db/
├── config/
├── scripts/
├── Prototipos/
├── graphify-out/
└── README.md
```

## Estado Actual

- PRD refinado del piloto: `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`.
- SPEC marco de incrementos: `docs/specs/2026-05-21-sg-superapp-spec-00-arquitectura-incrementos.md`.
- SPEC I0: `docs/specs/2026-05-21-sg-superapp-spec-i0-descubrimiento-tecnico-infraestructura.md`.
- SPEC I1: `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`.
- SPEC I2: `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`.
- SPEC I3: `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`.
- SPEC I4: `docs/specs/2026-05-21-sg-superapp-spec-i4-certificaciones-laborales.md`.
- Plan I0: `docs/plans/2026-05-21-sg-superapp-i0-descubrimiento-tecnico-plan.md`.
- Plan I1: `docs/plans/2026-06-03-sg-superapp-i1-portal-base-plan.md`.
- Plan I3: `docs/plans/2026-06-04-sg-superapp-i3-puestos-servicio-asignaciones-plan.md`.
- Plan I2 aprobado: `docs/plans/2026-06-03-sg-superapp-i2-datos-maestros-importacion-plan.md`.
- Servidor de aplicaciones confirmado: Windows Server 2012.
- I0 cerrado documentalmente con decision de stack: React SPA + backend .NET compatible + PostgreSQL.
- I1 cerrado tecnicamente como portal base.
- I2 cerrado tecnicamente.
- I3 cerrado tecnicamente con suite completa `Verify-SgSuperAppI3*.ps1`, build backend y build frontend correctos.
- I4 cerrado tecnicamente con suite completa `Verify-SgSuperAppI4*.ps1`, build backend y build frontend correctos.
- I5 cerrado tecnicamente con suite completa `Verify-SgSuperAppI5*.ps1`, backend build y frontend build correctos.
- I6 Task 1 cerrada con persistencia de notificaciones/eventos, permisos base y backend build correctos.
- I6 Task 2 cerrada con bandeja autenticada, contador de no leidas, filtros por estado/severidad/modulo, seguridad backend por rol y backend build correctos.
- I6 Task 3 cerrada con acciones de marcar como leida y archivar, eventos `READ`/`ARCHIVED`, proteccion por usuario/rol autenticado y backend build correctos.
- I6 Task 4 cerrada con generador de alertas I5 por vencimiento, severidades `CRITICAL`/`WARNING`/`INFO`, exclusion de `AL_DIA`, dedupe activo, restriccion `NOTIFICATIONS/GENERATE_ALERTS` y backend build correctos; siguiente retake autorizado en Task 5, generadores de alertas I2/I4.
- I6 Task 5 cerrada con generadores de alertas I2/I4 para importaciones `CON_ERRORES` y certificaciones `GENERADA`/`APROBADA`/`ANULADA`, resumen de errores `INCOMPLETO`/`DUPLICADO`/`ERRONEO`, dedupe activo, eventos `CREATED`, restriccion `NOTIFICATIONS/GENERATE_ALERTS` y backend build correctos; siguiente retake autorizado en Task 6, exportacion fallback y correo opcional.
- I6 Task 6 cerrada con exportacion CSV filtrable de notificaciones, evento `EXPORTED`, email summary no bloqueante con `EMAIL_ATTEMPTED`/`EMAIL_FAILED`, fallback disponible sin SMTP, restricciones `NOTIFICATIONS/EXPORT` y `NOTIFICATIONS/CONFIGURE_EMAIL`, y backend build correctos; siguiente retake autorizado en Task 7, cliente API y tipos frontend.
- I6 Task 7 cerrada con tipos TypeScript I6 para notificaciones, filtros, contador, generadores, exportacion y email fallback; cliente API cubre bandeja, contador, acciones, generadores, exportacion y correo opcional; verificacion de contrato frontend y build frontend correctos; siguiente retake autorizado en Task 8, UI de bandeja, contador y acciones.
- I6 Task 8 cerrada con bandeja operativa en el shell, contador accesible junto al perfil, filtros por estado/severidad/modulo, acciones leer/archivar conectadas al cliente I6, consulta para roles sin configuracion, verificacion UI, seguridad backend y build frontend correctos; siguiente retake autorizado en Task 9, UI TH de alertas y fallback.
- I6 Task 9 cerrada con panel TH/ADMIN para generar alertas I5/I2/I4, exportar resumen y mostrar estado de correo/fallback sin depender de SMTP; GERENCIA/OPERACIONES quedan en consulta sin generacion/configuracion; build frontend y verificaciones backend correctas; siguiente retake autorizado en Task 10, verificacion integral y cierre I6.
- I6 cerrado tecnicamente con suite completa `Verify-SgSuperAppI6*.ps1`, backend build, frontend build, matriz 1-20 y riesgos residuales registrados; siguiente retake autorizado en I7 Gate 0.
- I7 Gate 0 cerrado con SPEC y plan aprobados para auditoria, dashboard y cierre piloto; siguiente retake autorizado en Task 1, contratos backend de dashboard por rol.
- I7 Task 1 cerrada con endpoint autenticado `GET /api/portal/dashboard`, widgets por ADMIN/TH/GERENCIA/OPERACIONES, contrato `DashboardResponse`, verificacion `Verify-SgSuperAppI7Dashboard.ps1` y backend build correctos; siguiente retake autorizado en Task 2, contratos backend de auditoria y filtros.
- I7 Task 2 cerrada con endpoint autenticado `GET /api/portal/audit`, contratos `AuditEventResponse`/`AuditEventsResponse`, filtros por modulo/actor/rango de fechas, restricciones por rol ADMIN/TH/GERENCIA/OPERACIONES, verificacion `Verify-SgSuperAppI7Audit.ps1` y backend build correctos; siguiente retake autorizado en Task 3, seguridad I7 por rol.
- I7 Task 3 cerrada con verificacion `Verify-SgSuperAppI7Security.ps1` para dashboard, auditoria, bloqueo sin autenticacion, ausencia de mutaciones de auditoria y visibilidad ADMIN/TH/GERENCIA/OPERACIONES; backend build correcto; siguiente retake autorizado en Task 4, cliente API y tipos frontend I7.
- I7 Task 4 cerrada con tipos TypeScript de dashboard, widgets, auditoria y filtros; cliente API `fetchDashboard`/`fetchAuditEvents`; mocks frontend alineados; verificacion `Verify-SgSuperAppI7FrontendApi.ps1` y build frontend correctos; siguiente retake autorizado en Task 5, UI dashboard por perfil.
- I7 Task 5 cerrada con `DashboardPage`, carga `fetchDashboard`, fallback local, widgets agrupados por perfil/scope, estados de carga/error/vacio, estilos dark/gold compactos, verificacion `Verify-SgSuperAppI7DashboardUi.ps1` y build frontend correctos; siguiente retake autorizado en Task 6, UI consulta de auditoria.
- I7 Task 6 cerrada con `AuditPage`, filtros por modulo/actor/fechas, tabla compacta de eventos, detalle estructurado, lectura sin acciones de edicion, modulo `audit` en navegacion, verificacion `Verify-SgSuperAppI7AuditUi.ps1` y build frontend correctos; siguiente retake autorizado en Task 7, demo checklist y reporte de cierre piloto.
- I7 Task 7 cerrada con demo checklist I1-I7, reporte de cierre piloto, backlog priorizado, riesgos residuales y recomendacion de escalamiento documentados; siguiente retake autorizado en Task 8, verificacion integral y cierre I7.
- I8 Task 1 cerrada con variante Sentinel Enterprise registrada en `docs/DESIGN.md`, SPEC/plan I8 creados, shell React ajustado a consola enterprise, tokens CSS claros `#003366`/`#FFC700`, dashboard/auditoria refinados visualmente, verificacion `Verify-SgSuperAppI8SentinelUx.ps1` y build frontend correctos; `graphify update .` intentado sin disponibilidad en PATH; siguiente retake autorizado en Task 2, refinamiento responsive/accesibilidad y recorrido visual.
- I8 Task 2 cerrada con refinamiento de espacio en sidebar, topbar, panel lateral de notificaciones y workspace central; se elimino la fila de cards genericos del shell, se agrego `shell-body` con rail de notificaciones de 340px y fallback responsive; verificacion `Verify-SgSuperAppI8SentinelUx.ps1`, build frontend y HTTP 200 en preview local correctos; `graphify update .` intentado sin disponibilidad en PATH; siguiente retake autorizado en Task 3, recorrido visual manual fino y ajuste de pantallas funcionales internas.
- `graphify update .` es obligatorio despues de modificar codigo cuando la herramienta este disponible.

## Siguiente Paso Metodologico

Continuar con una de estas dos rutas autorizadas:

- cierre funcional: ejecutar Task 8 del plan I7, verificacion integral y cierre I7;
- UX/UI: ejecutar Task 3 del plan I8, recorrido visual manual fino y ajuste de pantallas funcionales internas.

Condicion de entrada:

- suite `Verify-SgSuperAppI7*.ps1` completa;
- regresion relevante I6: seguridad, notificaciones UI y alerts fallback;
- backend build limpio;
- frontend build limpio;
- matriz final 1-20 registrada;
- riesgos residuales documentados;
- handoff final creado.
