# Handoff - S&G Super App I3 cerrado, retake I4

**Fecha:** 2026-06-05  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Incremento cerrado:** I3 - Puestos de Servicio y Asignaciones  
**Siguiente tarea autorizada:** I4 Task 8 - UI de certificaciones  

## Entrada Canonica Obligatoria

Toda nueva sesion debe iniciar leyendo:

1. `README.md`
2. `docs/CONSTITUTION.md`
3. `docs/ARCHITECTURE.md`
4. `docs/TECNOLOGIA.md`
5. `docs/DESIGN.md`
6. `docs/specs/2026-05-21-sg-superapp-spec-i4-certificaciones-laborales.md`
7. `docs/plans/2026-06-05-sg-superapp-i4-certificaciones-laborales-plan.md`
8. `docs/plans/2026-06-04-sg-superapp-i3-puestos-servicio-asignaciones-plan.md`
9. Este handoff

## Estado SDD Canonico

- I0 cerrado.
- I1 cerrado tecnicamente.
- I2 cerrado tecnicamente; queda solo riesgo residual de recorrido visual manual desktop/movil.
- I3 cerrado tecnicamente el 2026-06-05.
- I3 cubre maestro de puestos, asignaciones historicas, permisos, auditoria, UI administrativa y normalizacion asistida de texto I2.
- I4 Gate 0 cerrado el 2026-06-05 con plan aprobado.
- I4 Task 1 cerrada: persistencia de firmantes/certificaciones, snapshot/consecutivo y permisos base.
- I4 Task 2 cerrada: contratos backend de firmantes, permisos y seguridad.
- I4 Task 3 cerrada: preview backend para certificacion activa, salario vigente, firmante vigente y variables manuales.
- I4 Task 4 cerrada: preview backend para certificacion retirada, fecha/motivo de retiro y variantes `CESANTIAS`/`INTERESADO`.
- I4 Task 5 cerrada: aprobacion/generacion backend, PDF descargable y snapshot inmutable.
- I4 Task 6 cerrada: anulacion con motivo, PDF/snapshot preservados, historial y auditoria.
- I4 Task 7 cerrada: tipos TypeScript y cliente API frontend I4.

## Evidencia De Cierre I3

Build backend:

```powershell
$env:DOTNET_CLI_HOME = "C:\tmp\dotnet-home"
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
& "C:\tmp\dotnet6\dotnet.exe" build "apps\sg-superapp-api\sg-superapp-api.csproj"
```

Resultado: correcto, 0 advertencias y 0 errores.

Build frontend:

```powershell
Set-Location "apps\sg-superapp-web"
node "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build
```

Resultado: correcto.

Suite I3 completa con API activa en `http://localhost:5080`:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& ".\scripts\dev\Verify-SgSuperAppI3AssignmentHistory.ps1"
& ".\scripts\dev\Verify-SgSuperAppI3Assignments.ps1"
& ".\scripts\dev\Verify-SgSuperAppI3Audit.ps1"
& ".\scripts\dev\Verify-SgSuperAppI3Persistence.ps1"
& ".\scripts\dev\Verify-SgSuperAppI3PersistenceClean.ps1"
& ".\scripts\dev\Verify-SgSuperAppI3Positions.ps1"
& ".\scripts\dev\Verify-SgSuperAppI3Security.ps1"
```

Resultado: todos correctos.

## Alcance Cerrado En I3

- `service_positions` y `employee_position_assignments` con restricciones de persistencia.
- CRUD logico de puestos: listar, crear, editar e inactivar.
- Asignacion y finalizacion de puestos desde empleado.
- Historial por empleado y por puesto.
- Bloqueo de doble asignacion vigente.
- Bloqueo de asignacion a puesto inactivo.
- Permisos ADMIN/TH de gestion y GERENCIA/OPERACIONES de consulta.
- Auditoria de creacion/edicion/inactivacion/asignacion/finalizacion.
- UI React para puestos y asignacion desde empleado.
- Texto importado I2 visible como referencia, sin crear puestos automaticamente.

## Retake Exacto - I4

Objetivo: iniciar Task 8 del plan I4 con TDD para UI de certificaciones.

Primer ciclo recomendado:

1. Implementar listado de certificados y configuracion operativa basica de firmantes si aplica.
2. Implementar flujo nueva certificacion: empleado, proposito, variables, preview, generar y descargar.
3. Implementar detalle/historial/anulacion segun permisos.
4. Validar `npm run build` y recorrido visual cuando el entorno lo permita.

No cerrar I4 sin build frontend y matriz final.

## Riesgos Residuales

- Recorrido visual desktop/movil queda pendiente de validacion manual o Playwright cuando el entorno lo permita.
- `graphify update .` no corre porque `graphify` no esta instalado/disponible en PATH.
- I3 no incluye maestro formal de clientes, turnos, cuadrantes ni solicitudes operativas; quedan fuera del MVP I3.

## Git Y Procesos

- Rama actual esperada: `main`.
- Hay cambios amplios I2/I3 sin commit de cierre.
- `AGENTS.md` tiene cambios externos/no realizados durante esta ejecucion: no revertir ni incluir por accidente.
- No asumir que existe API activa; verificar `http://localhost:5080/api/health` o levantar proceso temporal.
- No se hizo commit ni push durante este cierre.
