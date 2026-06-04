# Handoff - S&G Super App I1

Fecha: 2026-06-03  
Workspace: `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`

## Foco para la siguiente sesion

Continuar I1 desde este punto: backend conectado a PostgreSQL real, frontend con build verificado y siguiente objetivo en integracion UI contra backend vivo, verificacion integral y cierre documental de I1.

## Artefactos canonicos a leer primero

- `README.md`
- `docs/CONSTITUTION.md`
- `docs/TECNOLOGIA.md`
- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`
- `docs/plans/2026-06-03-sg-superapp-i1-portal-base-plan.md`

## Estado real alcanzado

- I0 ya quedo cerrado documentalmente.
- I1 tiene estructura creada en:
  - `apps/sg-superapp-web`
  - `apps/sg-superapp-api`
  - `db/`
  - `config/environments`
  - `scripts/dev`
- PostgreSQL local:
  - base `sg_superapp_dev` creada
  - esquema I1 aplicado
  - seeds aplicados
  - usuario funcional sembrado: `admin.sg`
  - password inicial sembrada: `Admin123`
- Backend:
  - proyecto `net6.0`
  - package `Npgsql 6.0.10`
  - repositorio real PostgreSQL agregado en `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
  - endpoints reales validados contra DB:
    - `GET /api/health`
    - `GET /api/auth/me`
    - `POST /api/auth/login`
    - `GET /api/portal/modules/ADMIN`
    - `GET /api/portal/notifications/admin.sg`
- Frontend:
  - build pasa
  - shell React ya consume API con fallback a mock via `src/hooks/usePortalShell.ts`

## Validaciones ya confirmadas

- `modules/ADMIN` ya devuelve el menu base esperado desde `role_permissions` persistido:
  - `alerts`
  - `certifications`
  - `courses`
  - `dashboard`
  - `employees`
  - `imports`
  - `notifications`
  - `positions`
  - `settings`
- El bug del bootstrap de DB (`CREATE DATABASE` dentro de `DO`) ya fue corregido.
- El mismatch de roles `Admin` vs `ADMIN` ya fue corregido.
- La brecha seed/backend para modulos admin ya fue corregida y revalidada.

## Bloqueos o fricciones vigentes

- El frontend `vite dev` sigue inestable por la ruta del workspace con `&` en `ProyectoS&G`.
- `graphify update .` no esta disponible en PATH.
- El repo Git esta inicializado y con `origin`, pero todo sigue sin commit inicial.
- El backend puede requerir reinicio manual si se sigue iterando:
  - SDK local instalado en `C:\tmp\dotnet6`
  - usar `DOTNET_CLI_HOME=C:\tmp\dotnet-home`

## Comandos utiles

Inicializar/reaplicar DB:

```powershell
Set-Location "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G"
Set-ExecutionPolicy -Scope Process Bypass
& ".\scripts\dev\Init-SgSuperAppDb.ps1" -PostgresPassword "<password-postgres>"
```

Levantar backend:

```powershell
$env:DOTNET_CLI_HOME='C:\tmp\dotnet-home'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1'
$env:DOTNET_NOLOGO='1'
& "C:\tmp\dotnet6\dotnet.exe" run --urls "http://localhost:5080" --project "C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\apps\sg-superapp-api\sg-superapp-api.csproj"
```

Prueba backend:

```powershell
Invoke-RestMethod -Uri "http://localhost:5080/api/health"
Invoke-RestMethod -Uri "http://localhost:5080/api/auth/me"
Invoke-RestMethod -Uri "http://localhost:5080/api/portal/modules/ADMIN"
Invoke-RestMethod -Uri "http://localhost:5080/api/portal/notifications/admin.sg"
$body = @{ username = 'admin.sg'; password = 'Admin123' } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:5080/api/auth/login" -Method Post -ContentType "application/json" -Body $body
```

## Siguiente paso recomendado

1. Resolver un arranque usable del frontend fuera de la friccion de la ruta con `&`.
2. Verificar que el shell React realmente consume `http://localhost:5080/api` y ya no cae a mock.
3. Cerrar `Task 5` y `Task 6` del plan I1 con evidencia de UI + backend real.
4. Actualizar el plan I1 y preparar cierre de incremento o retake claro hacia endurecimiento/autenticacion real.

## Skills sugeridas para la siguiente sesion

- `superpowers:executing-plans`
- `agent-skills:frontend-ui-engineering`
- `agent-skills:debugging-and-error-recovery`
- `handoff`
