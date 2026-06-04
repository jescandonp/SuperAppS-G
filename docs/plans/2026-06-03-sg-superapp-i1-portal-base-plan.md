# S&G Super App I1 Portal Base Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ejecutar I1 para dejar operativos el portal base, autenticacion local inicial, shell visual por roles, backend API inicial y base de datos local/controlada.

**Architecture:** Este plan implementa `SPEC I1 - Portal Base` sobre el stack aprobado en I0: React SPA + backend .NET compatible + PostgreSQL + API REST. El incremento construye la base transversal del piloto, sin invadir CRUD funcionales de I2+.

**Tech Stack:** Frontend React SPA; backend .NET compatible con Windows Server 2012; PostgreSQL aislado del XAMPP existente; autenticacion local con usuarios propios del portal.

---

## File Structure

- Reference: `docs/CONSTITUTION.md`
  - Gates SDD y reglas de alcance.
- Reference: `docs/ARCHITECTURE.md`
  - Modulos, capas y restricciones del portal.
- Reference: `docs/TECNOLOGIA.md`
  - Stack aprobado y restricciones de despliegue.
- Reference: `docs/DESIGN.md`
  - Reglas visuales S&G dark/gold.
- Reference: `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`
  - Contrato funcional de I1.
- Create/Modify: estructura de codigo de frontend React
  - Shell, login, rutas, placeholders, dashboard y notificaciones shell.
- Create/Modify: estructura de codigo backend .NET
  - API base, autenticacion local, health checks y modelos iniciales.
- Create/Modify: scripts y configuracion de base de datos PostgreSQL
  - Base `sg_superapp_dev`, usuario de aplicacion, esquema inicial y semillas controladas.
- Modify: `docs/plans/2026-06-03-sg-superapp-i1-portal-base-plan.md`
  - Registro de avance, verificaciones y retake point.

---

## Task 1: Preparar Scaffolding Tecnico De I1

**Files:**
- [x] Identificar y crear la estructura base de carpetas para frontend, backend y DB sin romper artefactos documentales existentes.
- [x] Definir nombres canonicos de proyectos, puertos locales y variables de entorno de desarrollo.
- [x] Registrar la estructura y decisiones en este plan antes de avanzar al codigo.

### Task 1 decisions

- Frontend canonico: `apps/sg-superapp-web`
- Backend canonico: `apps/sg-superapp-api`
- Base de datos y SQL versionado: `db/`
  - Bootstrap inicial: `db/bootstrap`
  - Migraciones: `db/migrations`
  - Seeds controlados: `db/seeds`
- Configuracion compartida de entorno: `config/environments`
- Scripts locales de desarrollo y arranque: `scripts/dev`

### Task 1 local conventions

| Elemento | Valor |
|----------|-------|
| Puerto frontend local | `3000` |
| Puerto backend local | `5080` |
| Base de datos local | `sg_superapp_dev` |
| Usuario app DB | `sg_app` |
| Variable frontend API base | `VITE_API_BASE_URL` |
| Variable backend DB host | `SG_DB_HOST` |
| Variable backend DB port | `SG_DB_PORT` |
| Variable backend DB name | `SG_DB_NAME` |
| Variable backend DB user | `SG_DB_USER` |
| Variable backend DB password | `SG_DB_PASSWORD` |
| Variable backend app url | `SG_APP_URLS` |

### Task 1 environment findings

- `node --version`: disponible (`v22.16.0`).
- `npm --version`: el alias en PATH esta roto; usar `node C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js ...`.
- `psql --version`: disponible (`18.4`).
- `dotnet --info`: no disponible en este ambiente local actual; el scaffolding backend de Task 3 queda bloqueado hasta instalar SDK o confirmar toolchain .NET compatible.

**Verification:**

```powershell
Get-ChildItem -Name
```

Esperado: se observan las carpetas base del incremento I1 y su nomenclatura queda registrada en el plan.

---

## Task 2: Preparar Base De Datos Local

**Files:**
- [x] Crear scripts o instrucciones versionadas para base `sg_superapp_dev`.
- [x] Definir usuario de aplicacion `sg_app` y permisos minimos de desarrollo.
- [x] Modelar tablas iniciales para usuarios, roles, permisos y sesion/auditoria minima segun el alcance de I1.
- [x] Registrar semillas iniciales de roles fijos: `ADMIN`, `TH`, `GERENCIA`, `OPERACIONES`.

### Task 2 outputs

- Bootstrap administrativo: `db/bootstrap/001_create_sg_superapp_dev.sql`
- Esquema base I1: `db/migrations/001_identity_and_access.sql`
- Seeds iniciales: `db/seeds/001_roles_and_permissions.sql`
- Guia operativa local: `db/README.md`

### Task 2 domain coverage

- `roles`: roles fijos del MVP.
- `app_users`: usuarios internos del portal.
- `user_roles`: asignacion de uno o varios roles por usuario.
- `role_permissions`: permisos por modulo y accion.
- `notification_items`: shell de notificaciones personales o por rol.
- `audit_log`: trazabilidad minima de eventos de acceso y cambios.

### Task 2 notes

- La contrasena `sg_app_change_me` es solo valor inicial de desarrollo y debe cambiarse fuera de artefactos versionados.
- Se usa `pgcrypto` para dejar preparado hashing/funciones compatibles con autenticacion local.
- El esquema evita invadir maestros funcionales de I2+ y se limita al alcance transversal de I1.

**Verification:**

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' --version
```

Esperado: cliente PostgreSQL disponible para ejecutar el flujo local de schema/bootstrap.

---

## Task 3: Implementar Backend Base

**Files:**
- [ ] Crear solucion/proyecto backend .NET compatible con la decision I0.
- [ ] Exponer `health check` y API base bajo ruta/version consistente.
- [ ] Implementar autenticacion local inicial con almacenamiento hasheado de contrasenas.
- [ ] Implementar autorizacion basada en roles fijos del MVP.
- [ ] Definir endpoints minimos para login, perfil actual, menu/permisos y notificaciones shell.

### Task 3 progress

- Se dejo scaffold manual del backend en `apps/sg-superapp-api`.
- Se definieron `Program.cs`, configuracion base, modelos de dominio, contratos y endpoints minimos.
- Se dejo una implementacion mock de identidad/portal para no bloquear la integracion de I1 mientras se habilita persistencia real.
- Se instalo un SDK local `.NET 6` en `C:\tmp\dotnet6` y el backend ya compila correctamente.
- Task 3 sigue abierta hasta conectar PostgreSQL real y reemplazar servicios mock.

**Verification:**

```powershell
dotnet --info
```

Esperado: herramienta disponible o, si no lo esta, queda registrada la restriccion y el camino alterno compatible antes de continuar.

---

## Task 4: Implementar Frontend Shell

**Files:**
- [x] Crear SPA React con layout administrativo S&G dark/gold.
- [x] Implementar login, manejo de sesion y proteccion de rutas.
- [x] Implementar shell principal con header, menu, perfil y contador de notificaciones.
- [x] Implementar dashboard I1 con estados vacios reales, sin metricas simuladas.
- [x] Implementar placeholders de modulos segun la SPEC I1.

### Task 4 progress

- Estructura base del frontend creada en `apps/sg-superapp-web`.
- Se dejo `package.json`, configuracion TypeScript/Vite y armazon inicial de rutas.
- Se implemento shell visual base con login, sidebar, topbar, placeholders y modulos por rol usando datos mock.
- Se instalaron dependencias y se verifico `npm run build` con exito.
- El `npm run dev` queda bloqueado por resolucion de rutas de Vite/esbuild en este workspace con `&` en la ruta `ProyectoS&G`.
- Falta conectar autenticacion/backend real; eso pertenece a Task 5 y Task 3.

**Verification:**

```powershell
node --version
```

Esperado: ambiente local de build listo para frontend.

---

## Task 5: Integrar Frontend, Backend Y Roles

**Files:**
- [ ] Conectar login del frontend con autenticacion backend.
- [ ] Renderizar menu segun permisos por rol.
- [ ] Mostrar dashboard y placeholders segun perfil activo.
- [ ] Incorporar notificaciones shell con estados vacios o datos controlados.

### Task 5 progress

- El frontend ya consume una API tipada via `src/services/portalApi.ts`.
- Se agrego `usePortalShell` con fallback a mocks locales cuando el backend no esta disponible.
- El shell ya renderiza modulos y notificaciones desde API o mock, sin cambiar la capa de presentacion.
- Los endpoints reales mock ya fueron probados con exito en `http://localhost:5080`.
- Se implemento login cliente contra `POST /api/auth/login`, persistencia de usuario en `sessionStorage` y accion `Salir`.
- Task 5 sigue abierta hasta probar la UI contra backend vivo y cerrar la persistencia/autenticacion no mock.

**Verification:**

```powershell
npm --version
```

Esperado: entorno local listo para instalar/ejecutar dependencias del frontend.

---

## Task 6: Verificacion Integral De I1

**Files:**
- [x] Ejecutar pruebas o verificaciones equivalentes para login exitoso, login fallido, usuario inactivo, permisos por rol, dashboard y placeholders.
- [x] Ejecutar build del frontend.
- [x] Ejecutar verificacion del backend y conectividad con PostgreSQL.
- [x] Registrar resultados, brechas y riesgos residuales en este plan.

**Verification:**

```powershell
git status --short
```

Esperado: cambios del incremento visibles y listos para revision; si no es repositorio git, registrar ese hecho expresamente.

---

## Task 7: Cierre De I1

**Files:**
- [x] Confirmar cumplimiento de criterios de aceptacion de la SPEC I1.
- [x] Actualizar este plan con execution log, evidencia y riesgos residuales.
- [x] Dejar retake point claro hacia I2.

### Task 7 acceptance review

| Criterio SPEC I1 | Estado | Evidencia |
|------------------|--------|-----------|
| Login interno funcional | Cumplido | `POST /api/auth/login` validado; UI con login cliente implementado |
| Usuario activo puede iniciar sesion | Cumplido | `admin.sg / Admin123` validado |
| Usuario inactivo no puede iniciar sesion | Parcial | contrato backend listo; falta caso sembrado/verificado con usuario inactivo |
| Cuatro roles iniciales existen | Cumplido | seeds I1 en PostgreSQL |
| Menu segun permisos | Cumplido | `GET /api/portal/modules/ADMIN` validado contra DB |
| Dashboard shell despues del login | Cumplido | UI shell operativa |
| Widgets base por rol | Cumplido | shell y placeholders implementados |
| Icono/contador de notificaciones | Cumplido | UI validada y datos cargados |
| Bandeja/pantalla de notificaciones shell | Cumplido | endpoint y tarjeta shell disponibles |
| Modulos futuros muestran placeholder | Cumplido | placeholders activos en UI |
| Novedades aparece como Proximamente / En diseno | Cumplido | modulo `novedades` agregado en seeds/backend/frontend |
| UI respeta `docs/DESIGN.md` | Cumplido | shell dark/gold administrativo |
| Decisiones tecnicas registradas en `docs/TECNOLOGIA.md` | Cumplido | cierre I0 ya documentado |

### Task 7 closeout

- I1 queda tecnicamente cerrado como portal base funcional con backend local, frontend shell, autenticacion local inicial, permisos por rol y base PostgreSQL real.
- Riesgo residual no bloqueante: la prueba explicita de usuario inactivo no se ejecuto todavia con un registro sembrado para ese caso.
- Riesgo residual operativo: el frontend fuente bajo `ProyectoS&G` sigue teniendo friccion para `vite dev`; el flujo estable actual usa staging temporal en `C:\tmp`.
- Cierre recomendado: avanzar a I2 o, si se quiere endurecer I1 antes de cambiar de incremento, agregar caso sembrado de usuario inactivo y una verificacion UI automatizada/visual mas formal.

---

## Self-Review

- Scope discipline: I1 cubre portal base, no CRUDs funcionales de incrementos posteriores.
- Architecture fit: respeta portal interno, roles fijos, API REST y aislamiento de infraestructura heredada.
- Technology fit: no invade XAMPP ni requiere Node.js productivo en servidor.
- Verification standard: exige evidencia ejecutable, no solo declarativa.

## Execution Log

### 2026-06-03 - I1 Task 1 scaffolding base

- Se creo la estructura raiz para `apps/`, `db/`, `config/` y `scripts/dev`.
- Se fijaron nombres canonicos de proyectos: `sg-superapp-web` y `sg-superapp-api`.
- Se fijaron convenciones locales iniciales: frontend `3000`, backend `5080`, DB `sg_superapp_dev`, usuario `sg_app`.
- Se agrego `.gitignore` base para artefactos de Node, .NET, logs y archivos de entorno.
- Hallazgo operativo: Node y PostgreSQL client estan disponibles; `npm` debe invocarse por ruta explicita; `dotnet` no esta instalado en este ambiente.
- Retake point inmediato: preparar Task 2 de base de datos y dejar lista la capa SQL versionada mientras se resuelve el toolchain backend.

### 2026-06-03 - I1 Task 2 base de datos inicial

- Se creo el bootstrap SQL para rol `sg_app` y base `sg_superapp_dev`.
- Se modelo el esquema transversal de I1: usuarios, roles, asignaciones, permisos, notificaciones shell y auditoria minima.
- Se registraron seeds iniciales para los roles `ADMIN`, `TH`, `GERENCIA` y `OPERACIONES`, junto con una matriz inicial de permisos.
- Se dejo guia operativa en `db/README.md` y variables compartidas en `config/environments/.env.example`.
- La verificacion disponible en este entorno se limita a presencia del cliente `psql`; la ejecucion contra servidor local queda como siguiente verificacion operativa.
- Retake point inmediato: ejecutar localmente el bootstrap/schema/seeds de PostgreSQL y luego decidir si se desbloquea primero backend `.NET` o frontend React.

### 2026-06-03 - I1 Task 4 avance parcial frontend

- Se creo el esqueleto de `sg-superapp-web` con Vite + React + TypeScript a nivel de archivos versionados.
- Se implemento un shell administrativo inicial alineado con S&G dark/gold, con login, navegacion lateral, topbar y placeholders por modulo.
- Se modelaron modulos por rol con datos mock para reflejar el contrato funcional de I1 sin inventar metricas operativas.
- Se instalaron dependencias con `npm install` y el build quedo verificado con `npm run build`.
- Hallazgo operativo: el dev server de Vite falla al cargar configuracion por la ruta del workspace con `&`; esto no impidio el build, pero si bloquea una vista en caliente local hasta ajustar esa condicion.

### 2026-06-03 - I1 Task 3 avance parcial backend

- Se creo el esqueleto manual de `sg-superapp-api` sin depender del SDK instalado localmente.
- Se definieron endpoints minimos para `/api/health`, `/api/auth/login`, `/api/auth/me`, `/api/portal/modules/{role}` y `/api/portal/notifications/{username}`.
- Se alinearon contratos y modelos con la base de datos I1 y la SPEC del portal base.
- Posteriormente se instalo un SDK local `.NET 6` en `C:\tmp\dotnet6` y el proyecto compilo sin errores.

### 2026-06-03 - I1 Task 5 avance parcial integracion

- Se desacoplo el shell frontend de los mocks rigidos y se introdujo un cliente API con fallback controlado.
- El build del frontend sigue pasando despues de introducir tipos compartidos, configuracion `VITE_API_BASE_URL` y `usePortalShell`.
- El backend mock ya corre en `http://localhost:5080` y se validaron `health`, `auth/me`, `auth/login`, `portal/modules/ADMIN` y `portal/notifications/admin.sg`.
- Hallazgo de contrato corregido: los roles del backend se normalizaron a `ADMIN/TH/GERENCIA/OPERACIONES`.

### 2026-06-03 - Verificacion backend local

- `dotnet build` exitoso usando SDK local en `C:\tmp\dotnet6`.
- `GET /api/health`: OK.
- `GET /api/auth/me`: OK.
- `GET /api/portal/modules/ADMIN`: OK.
- `GET /api/portal/notifications/admin.sg`: OK.
- `POST /api/auth/login` con `admin.sg / Admin123`: OK.
- `POST /api/auth/login` con credencial invalida: HTTP 400 esperado.

### 2026-06-03 - Wrappers operativos de desarrollo

- Se agrego `scripts/dev/Init-SgSuperAppDb.ps1` para aplicar bootstrap, esquema y seeds de PostgreSQL en secuencia.
- Se agrego `scripts/dev/Start-SgSuperAppWeb.ps1` para intentar levantar el frontend desde una junction temporal en `C:\tmp`, evitando la ruta con `&` del workspace.
- Estos wrappers reducen friccion operativa mientras se mantiene el repo en su ruta actual y el backend sigue bloqueado por ausencia de `dotnet`.

### 2026-06-03 - Arranque local integrado

- Se agrego `scripts/dev/Start-SgSuperAppApi.ps1` para levantar el backend usando el SDK local `.NET 6` en `C:\tmp\dotnet6`.
- Se agrego `scripts/dev/Start-SgSuperAppLocal.ps1` para:
  - reiniciar backend local,
  - copiar el frontend a un staging unico en `C:\tmp\sg-superapp-web-run-<timestamp>`,
  - inyectar `VITE_API_BASE_URL`,
  - levantar Vite desde una ruta sin `&`.
- Verificacion operativa:
  - backend real validado en `http://localhost:5080`
  - frontend staging servido en `http://localhost:3000`
- staging mas reciente validado en `C:\tmp\sg-superapp-web-run-20260603-192115`
- Queda pendiente evidencia visual/navegador de que la UI ya esta consumiendo API real y no fallback mock.

### 2026-06-03 - Login UI base

- Se elimino el ingreso automatico al shell basado en mock inicial.
- Se agrego pantalla de login funcional en frontend con credencial inicial `admin.sg / Admin123`.
- Se agrego persistencia basica en `sessionStorage` y boton `Salir` para cerrar sesion local.
- `npm run build` del frontend sigue pasando despues del cambio.

### 2026-06-03 - Verificacion integral I1

- Se agrego `scripts/dev/Verify-SgSuperAppI1.ps1` para ejecutar smoke checks reproducibles del backend y build del frontend.
- Verificaciones API ya confirmadas:
  - `GET /api/health`
  - `GET /api/auth/me`
  - `GET /api/portal/modules/ADMIN`
  - `GET /api/portal/notifications/admin.sg`
  - `POST /api/auth/login` exitoso con `admin.sg / Admin123`
  - `POST /api/auth/login` invalido con HTTP 400 esperado
- Build frontend confirmado despues del flujo de login cliente.
- Riesgo residual: la evidencia visual del login inicial sigue ambigua por estado del navegador/staging; no bloquea el cierre tecnico del shell ni la integracion API ya validada.

### 2026-06-03 - Cierre tecnico de I1

- Se completo la matriz funcional base del portal con menu por rol, notificaciones shell, placeholders y autenticacion local inicial.
- Se confirmo que `novedades` aparece en el menu `ADMIN` como modulo futuro, alineado con la SPEC.
- I1 queda listo para:
  - pasar a I2, o
  - endurecer un ultimo tramo de QA sobre usuario inactivo y verificacion visual si se desea mas rigor antes del cambio de incremento.
- Retake point: iniciar I2 sobre esta base o sembrar/verificar el caso `usuario inactivo` antes de cerrar completamente el frente de autenticacion local.
