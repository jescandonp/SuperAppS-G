# Handoff - S&G Super App I2 Tasks 1-3 cerradas, retake Task 4

**Fecha:** 2026-06-04  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Incremento activo:** I2 - Datos Maestros e Importacion  
**Siguiente tarea autorizada:** Task 4 - Completar Consulta Y Edicion De Empleados  

## Entrada Canonica Obligatoria

Toda nueva sesion debe iniciar leyendo, en este orden:

1. `README.md`
2. `docs/CONSTITUTION.md`
3. `docs/ARCHITECTURE.md`
4. `docs/TECNOLOGIA.md`
5. `docs/DESIGN.md`
6. `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`
7. `docs/plans/2026-06-03-sg-superapp-i2-datos-maestros-importacion-plan.md`
8. Este handoff

`README.md` es la base canonica para retomar. Si contradice este handoff, se debe resolver siguiendo el orden de autoridad de `docs/CONSTITUTION.md`.

## Estado SDD Canonico

- SPEC I2 validada y aprobada el 2026-06-04.
- Plan I2 revisado y aprobado el 2026-06-04.
- Gate 0 cerrado.
- Task 1 cerrada: auditoria de implementacion adelantada registrada en el execution log del plan.
- Task 2 cerrada: persistencia I2 completada y verificada con TDD.
- Task 3 cerrada: seguridad y permisos I2 completados y verificados con TDD.
- Implementacion autorizada exclusivamente desde Task 4, siguiendo el plan en orden.

No modificar alcance directamente en codigo. Cualquier cambio entra primero por SPEC y luego por plan.

## Decisiones Canonicas Vigentes

Las decisiones completas estan en la seccion 6 del plan I2. Para continuar Task 4, respetar especialmente:

- TH es el unico rol operativo de edicion de empleados y salario.
- ADMIN consulta empleados, salario, historial y errores, pero no opera cargas por defecto.
- GERENCIA consulta empleados y salario sin editar.
- OPERACIONES consulta empleados sin salario y sin editar.
- La autorizacion se valida en backend; ocultar acciones en UI no es suficiente.
- La llave funcional de empleado es `tipo_identificacion + numero_identificacion`.
- Solo puede existir una vigencia salarial abierta por empleado.
- Toda edicion manual debe registrar usuario, fecha, campo, valor anterior y valor nuevo.
- Los cambios de comportamiento se implementan con TDD: prueba RED valida, cambio minimo GREEN y refactor manteniendo verde.

## Estado Tecnico Real

### Persistencia

- Migraciones I2:
  - `db/migrations/002_employee_master.sql`
  - `db/migrations/003_i2_persistence_completion.sql`
  - `db/migrations/004_i2_security_sessions.sql`
- Existen mapeos y staging:
  - `import_column_mappings`
  - `import_batch_rows`
- Existen restricciones verificadas para llave funcional y salario abierto unico.
- `scripts/dev/Init-SgSuperAppDb.ps1` aplica migraciones y seeds actuales.

### Seguridad

- Login PostgreSQL crea tokens opacos; en DB solo se guarda hash SHA-256.
- Las solicitudes autenticadas usan `Authorization: Bearer <token>`.
- `RequestUserContext`, `SessionAuthenticationMiddleware` y `PortalAuthorizationService` aplican contexto y permisos.
- El frontend persiste y envia el Bearer token.
- El backend usa el usuario autenticado para cargas; no confia en `uploadedBy` enviado por cliente.
- Usuarios locales de verificacion:
  - `admin.sg / Admin123`
  - `th.sg / Th123456`
  - `gerencia.sg / Gerencia123`
  - `operaciones.sg / Operaciones123`

### Git Y Procesos

- Rama actual: `main`.
- El repositorio no tiene commits; todos los archivos aparecen untracked.
- No hay proceso `sg-superapp-api` activo al crear este handoff.
- Existen varios procesos `node`; no asumir que pertenecen todos a este proyecto.
- `graphify update .` sigue sin ejecutarse porque `graphify` no esta instalado.

## Verificaciones Que Pasan

Persistencia sobre DB existente:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& ".\scripts\dev\Verify-SgSuperAppI2Persistence.ps1"
```

Persistencia desde esquema limpio aislado:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& ".\scripts\dev\Verify-SgSuperAppI2PersistenceClean.ps1"
```

Seguridad I2, requiere API activa en `http://localhost:5080`:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& ".\scripts\dev\Verify-SgSuperAppI2Security.ps1"
```

Build backend:

```powershell
$env:DOTNET_CLI_HOME = "C:\tmp\dotnet-home"
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
& "C:\tmp\dotnet6\dotnet.exe" build "apps\sg-superapp-api\sg-superapp-api.csproj"
```

Build frontend:

```powershell
Set-Location "apps\sg-superapp-web"
node "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build
```

## Retake Exacto - Task 4

Seguir la Task 4 del plan aprobado. No avanzar a Task 5 antes de cerrarla.

Primer ciclo TDD recomendado:

1. Crear prueba RED para filtro de completitud en listado de empleados.
2. Implementar el filtro minimo en repositorio, contrato y UI.
3. Confirmar GREEN y registrar evidencia.

Siguientes ciclos TDD de Task 4:

- detalle con historial basico de cambios;
- edicion manual valida exclusiva de TH;
- rechazo de edicion por ADMIN, GERENCIA y OPERACIONES;
- auditoria por campo con valor anterior y nuevo;
- versionado salarial sin solapamiento.

No ampliar importaciones, `.xlsx`, cancelacion o confirmacion de cargas durante Task 4; pertenecen a Tasks 5-8.

## Riesgos Y Observaciones

- No existe suite de pruebas de framework dedicada; las verificaciones actuales son scripts reproducibles PowerShell/SQL. Mantener TDD creando primero una verificacion RED valida.
- El backend usa sesiones opacas propias, no middleware estándar ASP.NET Authentication.
- La UI de empleados actual siempre renderiza espacios salariales; OPERACIONES recibe `null`, pero Task 4 debe revisar presentación por rol.
- La implementacion previa fue auditada como prototipo parcial; consultar la matriz de Task 1 en el execution log antes de asumir cumplimiento.
- La ruta contiene `&` en `ProyectoS&G`; el flujo frontend estable puede requerir staging mediante scripts existentes.

## Skills Sugeridas

- `superpowers:using-superpowers`
- `superpowers:executing-plans`
- `superpowers:test-driven-development`
- `superpowers:systematic-debugging` si una prueba falla por causa no esperada
- `handoff` al cerrar la siguiente sesion
