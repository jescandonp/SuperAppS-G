# Handoff - S&G Super App I5 Task 2 cerrada, retake Task 3

**Fecha:** 2026-06-06  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Incremento activo:** I5 - Cursos y acreditaciones  
**Siguiente tarea autorizada:** I5 Task 3 - renovaciones y reglas de fecha  

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
- I5 Task 1 cerrada.
- I5 Task 2 cerrada con contratos backend de tipos.
- Retake autorizado: Task 3 del plan I5.

## Cambios Cerrados En Task 2

- Contratos:
  - `apps/sg-superapp-api/Contracts/Portal/TrainingRequirementTypeResponse.cs`
  - `apps/sg-superapp-api/Contracts/Portal/UpsertTrainingRequirementTypeRequest.cs`
- Endpoints:
  - `GET /api/portal/training-types`
  - `GET /api/portal/training-types/{typeId}`
  - `POST /api/portal/training-types`
  - `PUT /api/portal/training-types/{typeId}`
  - `POST /api/portal/training-types/{typeId}/inactivate`
- Repositorio:
  - listar/consultar tipos;
  - crear/actualizar/inactivar tipos;
  - auditoria `TRAINING_TYPE_CREATED`, `TRAINING_TYPE_UPDATED`, `TRAINING_TYPE_INACTIVATED`.
- Validaciones:
  - nombre obligatorio;
  - categoria `CURSO` o `ACREDITACION`;
  - `validityDays` opcional, pero positivo si viene;
  - codigo unico si se define.
- Seguridad:
  - ADMIN/TH gestionan;
  - GERENCIA/OPERACIONES consultan y no editan.

## Evidencia

- RED: `scripts/dev/Verify-SgSuperAppI5Types.ps1` fallo inicialmente con HTTP 404 por endpoint inexistente.
- GREEN: `scripts/dev/Verify-SgSuperAppI5Types.ps1` correcto.
- GREEN: `scripts/dev/Verify-SgSuperAppI5Security.ps1` correcto.
- `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj`: correcto, 0 advertencias y 0 errores.

Nota: durante la verificacion, un proceso `sg-superapp-api` vivo bloqueo temporalmente el binario y el primer build final fallo por archivo en uso. Se cerro el proceso y el build final paso limpio.

## Retake Exacto - I5 Task 3

Objetivo: implementar registro de renovaciones por empleado y reglas de fecha.

Primer ciclo recomendado:

1. Crear `Verify-SgSuperAppI5Renewals.ps1` con casos RED para registro de renovacion.
2. Crear `Verify-SgSuperAppI5Audit.ps1` para auditoria de creacion/inactivacion.
3. Crear DTOs de renovacion en `Contracts/Portal`.
4. Agregar endpoint `POST /api/portal/employees/{employeeId}/training`.
5. Validar empleado existente.
6. Validar tipo activo.
7. Calcular `expires_at` desde `validity_days` cuando exista.
8. Exigir `expiresAt` manual cuando el tipo no tenga vigencia.
9. Rechazar vencimiento anterior a realizacion.
10. Ejecutar backend build.

No implementar estados calculados, habilitacion, consultas de cumplimiento ni UI antes de cerrar Task 3.

## Riesgos Y Observaciones

- Hay cambios acumulados sin commit de I2/I3/I4/I5; no revertir trabajo externo.
- `AGENTS.md` tiene cambios externos; no incluirlo ni revertirlo por accidente.
- `graphify update .` debe intentarse despues de modificar codigo cuando la herramienta este disponible; en esta maquina suele no estar en PATH.
