# Handoff - S&G Super App I5 Task 1 cerrada, retake Task 2

**Fecha:** 2026-06-06  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Incremento activo:** I5 - Cursos y acreditaciones  
**Siguiente tarea autorizada:** I5 Task 2 - contratos backend de tipos  

## Entrada Canonica Obligatoria

Toda nueva sesion debe iniciar leyendo:

1. `README.md`
2. `docs/CONSTITUTION.md`
3. `docs/ARCHITECTURE.md`
4. `docs/TECNOLOGIA.md`
5. `docs/DESIGN.md`
6. `docs/specs/2026-05-21-sg-superapp-spec-i5-cursos-acreditaciones.md`
7. `docs/plans/2026-06-05-sg-superapp-i5-cursos-acreditaciones-plan.md`
8. Este handoff

## Estado SDD Canonico

- I2 cerrado tecnicamente.
- I3 cerrado tecnicamente.
- I4 cerrado tecnicamente.
- SPEC I5 aprobada.
- Plan I5 aprobado.
- I5 Gate 0 cerrado.
- I5 Task 1 cerrada con persistencia, permisos base, contrato SQL y build backend correctos.
- Retake autorizado: Task 2 del plan I5.

## Cambios Cerrados En Task 1

- `db/migrations/007_i5_training_accreditations.sql`
  - crea `training_requirement_types`;
  - crea `employee_training_records`;
  - valida categoria, estado, vigencia positiva, fechas y referencias obligatorias;
  - modela `support_path` como referencia opcional.
- `db/seeds/007_i5_training_permissions.sql`
  - registra permisos I5 para ADMIN, TH, GERENCIA y OPERACIONES;
  - ADMIN/TH gestionan tipos y renovaciones;
  - GERENCIA/OPERACIONES consultan sin permisos `MANAGE`.
- `db/tests/005_i5_persistence_contract.sql`
  - cubre tablas, unicidad, foreign keys, fechas invalidas, soporte opcional y permisos.
- `scripts/dev/Verify-SgSuperAppI5Persistence.ps1`
- `scripts/dev/Verify-SgSuperAppI5PersistenceClean.ps1`

## Evidencia

- `scripts/dev/Verify-SgSuperAppI5PersistenceClean.ps1`: correcto sobre esquema temporal `i5_verify_clean`.
- Migracion 007 + seed 007 aplicados sobre `sg_superapp_dev`: correctos.
- `scripts/dev/Verify-SgSuperAppI5Persistence.ps1`: correcto.
- `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj`: correcto, 0 advertencias y 0 errores.

## Retake Exacto - I5 Task 2

Objetivo: implementar contratos backend para administrar tipos de curso/acreditacion.

Primer ciclo recomendado:

1. Crear `Verify-SgSuperAppI5Types.ps1` con casos RED para listar, crear, editar e inactivar tipos.
2. Crear/usar DTOs en `apps/sg-superapp-api/Contracts/Portal/` para tipos I5.
3. Agregar metodos de repositorio para tipos I5 en `PostgresPortalRepository`.
4. Exponer endpoints:
   - `GET /api/portal/training-types`
   - `GET /api/portal/training-types/{typeId}`
   - `POST /api/portal/training-types`
   - `PUT /api/portal/training-types/{typeId}`
   - `POST /api/portal/training-types/{typeId}/inactivate`
5. Validar seguridad con `Verify-SgSuperAppI5Security.ps1`.
6. Ejecutar backend build.

No implementar renovaciones, consultas de cumplimiento ni UI antes de cerrar Task 2.

## Riesgos Y Observaciones

- Hay cambios acumulados sin commit de I2/I3/I4/I5; no revertir trabajo externo.
- `AGENTS.md` tiene cambios externos; no incluirlo ni revertirlo por accidente.
- `graphify update .` debe intentarse despues de modificar codigo cuando la herramienta este disponible; en handoffs previos constaba no disponible en PATH.
