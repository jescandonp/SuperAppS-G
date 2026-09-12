# Plan - Corregir Estado Y Orden De Modulos En El Menu Lateral

**Fecha:** 2026-09-12
**Producto:** S&G Super App
**Origen:** feedback directo del usuario sobre experiencia de navegacion, tras el cierre tecnico de I7 e I8
**Estado:** Aprobado por el usuario (proceso brainstorming, path arquitectonico degradado a alcance acotado tras aclarar requisitos)

## 1. Problema

El usuario reporto dos sintomas al usar el portal:

1. El menu lateral se ve desorganizado.
2. Modulos como "Cursos y Acreditaciones" aparecen marcados `Pendiente` pero
   tienen funcionalidad real dentro; "Configuracion" no deja claro que esta
   construido y que no.

## 2. Causa raiz (verificada en codigo, no solo observada)

- **Orden alfabetico no intencional:** `PostgresPortalRepository.GetModulesAsync`
  ordena los modulos con `order by rp.module_code` (linea 293) - alfabetico
  por codigo, sin ninguna agrupacion por flujo de trabajo.
- **Catalogo de estado desactualizado:** `PostgresPortalRepository.ModuleCatalog`
  (lineas 81-95) es un diccionario estatico escrito en la epoca de I2/I3 y
  nunca actualizado al cerrar I4, I5 e I6:
  - `COURSES` (Cursos y Acreditaciones) reporta `Pendiente` pese a que I5 esta
    cerrado tecnicamente y el modulo funciona completo.
  - `ALERTS` reporta `Pendiente` pese a que I6 esta cerrado tecnicamente y
    funciona completo.
  - `SETTINGS` (Configuracion) reporta `Disponible` pese a ser un placeholder
    vacio identico al de Novedades (que si dice `Pendiente` correctamente).
- El mismo patron de descripciones stale ("Pendiente implementacion en I2/I3")
  existe en el fallback mock `apps/sg-superapp-web/src/mock/session.ts`
  (usado solo si la API no responde), agravado ahi (tambien marca Empleados,
  Puestos y Cargas de datos como `Pendiente` pese a estar cerrados).
- Hallazgo adicional durante la implementacion: existe una **tercera copia**
  del mismo problema en `MockPortalQueryService.GetModules` (backend), usado
  como fallback de `GET /api/portal/modules/{role}` cuando
  `repository.CanConnectAsync()` es `false` (Postgres inalcanzable). Marca
  `positions`, `courses`, `certifications` y `alerts` como `Pendiente` pese a
  estar cerrados, y ademas no incluye `scheduling` ni `novedades` en su
  lista. Se corrige junto con lo anterior por ser la misma causa raiz, no
  alcance nuevo.

## 3. Decisiones tomadas con el usuario

- Configuracion: **no se construye funcionalidad nueva en esta iteracion**;
  solo se corrige la etiqueta a `Pendiente`, igual que Novedades.
- Orden del menu: por flujo de trabajo, sin encabezados de seccion visibles
  (lista reordenada, no agrupada visualmente).
- Alcance cerrado explicitamente a esto - no se agrega Auditoria al menu
  (hallazgo aparte: el endpoint I7 de auditoria existe y funciona pero nunca
  se registro en `ModuleCatalog`, por lo que no aparece en el sidebar; el
  usuario decidio no ampliar el alcance para incluirlo ahora).

## 4. Diseno

### 4.1 Backend - `PostgresPortalRepository.cs`

- Corregir `ModuleCatalog`:
  - `COURSES`: `Status` -> `"Disponible"`, `Description` -> reflejar I5 real
    (tipos de curso, cumplimiento, registros).
  - `ALERTS`: `Status` -> `"Disponible"`, `Description` -> reflejar I6 real
    (generadores, exportacion, fallback de correo).
  - `SETTINGS`: `Status` -> `"Pendiente"`, `Description` -> mismo patron que
    Novedades ("Proximamente / en diseno").
  - Revisar el resto de descripciones (`DASHBOARD`, `EMPLOYEES`, `POSITIONS`,
    `CERTIFICATES`, `NOTIFICATIONS`, `IMPORTS`, `NOVEDADES`, `SCHEDULING`) y
    corregir cualquier texto stale encontrado.
- Cambiar `GetModulesAsync`: reemplazar el `order by rp.module_code` de SQL
  por un orden fijo por flujo de trabajo, aplicado en memoria despues de leer
  el `reader` (sin cambiar el contrato `PortalModuleResponse`):

  `DASHBOARD, EMPLOYEES, POSITIONS, SCHEDULING, CERTIFICATES, COURSES, ALERTS, IMPORTS, NOTIFICATIONS, SETTINGS, NOVEDADES`

### 4.2 Frontend - `mock/session.ts`

- Corregir `baseModules` con el mismo criterio: estados/descripciones
  honestos y mismo orden de despliegue, para que el fallback offline no
  contradiga al backend real.

### 4.3 Verificacion

- Crear `scripts/dev/Verify-SgSuperAppModulesCatalog.ps1`: login por rol,
  `GET /api/portal/modules/{rol}`, y asserts de:
  - `courses`, `alerts`, `certificates`, `employees`, `positions`,
    `scheduling` reportan `Disponible`.
  - `settings`, `novedades` reportan `Pendiente`.
  - El orden devuelto coincide con el orden de flujo de trabajo definido
    arriba (para el subconjunto visible por rol).
- Ejecutar backend build y frontend build.
- Recorrido visual manual del sidebar con sesion ADMIN.

## 5. Fuera de alcance (explicito)

- Agregar Auditoria (I7) como modulo de navegacion.
- Construir funcionalidad real para Configuracion.
- Encabezados de seccion visibles en el sidebar.
- Cualquier cambio a permisos (`role_permissions`) o a que modulos ve cada rol.

## 6. Execution Log

### 2026-09-12 - Correccion de estado y orden de modulos cerrada

- `PostgresPortalRepository.cs`: corregido `ModuleCatalog` (Cursos, Alertas ->
  `Disponible`; Configuracion -> `Pendiente`; descripciones actualizadas para
  todos los modulos) y `GetModulesAsync` (orden fijo por flujo de trabajo en
  memoria, ya no `order by rp.module_code`).
- `MockPortalQueryService.cs` (fallback backend si Postgres no responde):
  mismo criterio de estados corregido.
- `apps/sg-superapp-web/src/mock/session.ts` (fallback frontend): mismo
  criterio de estados/descripciones y mismo orden de despliegue.
- Creado `scripts/dev/Verify-SgSuperAppModulesCatalog.ps1`: confirma estado
  `Disponible` en empleados/puestos/certificaciones/cursos/alertas/
  programacion, `Pendiente` en configuracion/novedades, y el orden de
  despliegue completo.
- GREEN: `Verify-SgSuperAppModulesCatalog.ps1`, mas regresion
  `Verify-SgSuperAppI7Dashboard.ps1`, `Verify-SgSuperAppI7Security.ps1`,
  `Verify-SgSuperAppI6Security.ps1`.
- Backend build: `dotnet build` correcto, 0 advertencias, 0 errores.
- Frontend build: `tsc -b` + `vite build` correcto, 56 modulos transformados.
- Recorrido visual manual (sesion ADMIN): orden confirmado
  `Dashboard, Empleados/Guardas, Puestos de Servicio, Programacion de
  Turnos, Certificaciones, Cursos y Acreditaciones, Alertas, Cargas de
  Datos, Notificaciones, Configuracion, Novedades`; etiquetas confirmadas
  correctas.
- `graphify update .` intentado; no disponible en PATH.

### Hallazgos fuera de alcance (documentados, no corregidos en esta sesion)

Encontrados durante la implementacion; el usuario confirmo no ampliar el
alcance de esta iteracion para incluirlos:

1. **Auditoria (I7) no esta registrada como modulo de navegacion** - el
   endpoint funciona (`/module/audit` es alcanzable por URL directa y desde
   un widget del dashboard) pero no aparece en `ModuleCatalog` ni en el
   sidebar.
2. **Codigo de modulo inconsistente para Certificaciones**: la ruta real
   registrada en `ModuleWorkspace.tsx` es `certificates`, pero
   `DashboardPage.tsx` (link del widget "Certificaciones generadas") y el
   mock frontend (antes de esta correccion, y el mock backend
   `MockPortalQueryService`) usan `certifications` (con "i" extra). Un click
   en ese widget cae al placeholder generico en vez de abrir Certificaciones.
3. **Links de widgets del dashboard rotos**: se observaron
   `href="/portal/configuracion"` y `href="/portal/cursos"` en widgets del
   dashboard - no coinciden con el esquema de rutas real (`/module/<code>`).
4. **`GET /api/portal/modules/{role}` no exige autenticacion** - a diferencia
   de `/api/portal/dashboard` y `/api/portal/audit`, este endpoint responde
   200 sin token. Bajo impacto (solo expone metadatos de modulos, no datos de
   negocio) pero es inconsistente con el resto de la API.

### 2026-09-12 - Correccion de los 4 hallazgos cerrada

El usuario confirmo abordar los 4 hallazgos en una iteracion aparte, en la
misma sesion:

- **Auditoria en el menu:** agregada a `ModuleCatalog` y `ModuleDisplayOrder`
  (backend). Se investigo si requeria una migracion nueva de
  `role_permissions` y **no la requiere**: `GET /api/portal/audit` ya
  reutiliza el permiso `DASHBOARD/VIEW` (concedido a los 4 roles desde
  `db/seeds/001_roles_and_permissions.sql`), asi que `GetModulesAsync` deriva
  la visibilidad de Auditoria del mismo permiso en memoria, sin tabla nueva.
  Se agrego tambien a `MockPortalQueryService` (backend fallback) por
  consistencia; ya existia en `mock/session.ts` (frontend fallback).
- **`certifications` -> `certificates`:** corregido en
  `DashboardPage.tsx` (`resolveActionUrl`).
- **Links de widgets rotos:** en `PostgresPortalRepository.cs`,
  "Usuarios activos" (ADMIN) y "Notificaciones sin leer" (SYSTEM) quedan sin
  `actionUrl` (sin boton "Abrir": no existe una pantalla real de destino
  hoy); "Cursos criticos o vencidos" (TH/ADMIN) y "Guardas no habilitados"
  (OPERACIONES) pasan de `/portal/cursos` a `/portal/courses` (la forma que
  ya se traduce correctamente en el frontend). Se encontro un quinto link
  roto durante la implementacion, no reportado originalmente: el widget
  "Notificaciones sin leer" apuntaba a `/portal/notificaciones` (con "es"),
  que tampoco coincidia con ningun prefijo conocido por el frontend.
- **Autenticacion en `/api/portal/modules/{role}`:** protegido con el mismo
  `authorization.RequireAsync("DASHBOARD", "VIEW", ...)` que ya usan
  dashboard y auditoria - sin permiso nuevo, sin migracion.
- Verificacion ampliada: `Verify-SgSuperAppModulesCatalog.ps1` ahora exige
  `audit` en `Disponible`, valida el orden completo incluyendolo, y confirma
  401 sin autenticacion. `Verify-SgSuperAppI7Dashboard.ps1` ahora valida que
  ningun widget de ningun rol tenga un `actionUrl` que el frontend no sepa
  traducir.
- GREEN: `Verify-SgSuperAppModulesCatalog.ps1`,
  `Verify-SgSuperAppI7Dashboard.ps1`, `Verify-SgSuperAppI7Audit.ps1`,
  `Verify-SgSuperAppI7Security.ps1`, `Verify-SgSuperAppI6Security.ps1`.
- Backend build: `dotnet build` correcto, 0 advertencias, 0 errores.
- Frontend build: `tsc -b` + `vite build` correcto, 56 modulos transformados.
- Recorrido visual manual (sesion ADMIN): Auditoria visible y funcional desde
  el menu con datos reales; widget "Usuarios activos" sin boton "Abrir".
- `graphify update .` intentado; no disponible en PATH.
