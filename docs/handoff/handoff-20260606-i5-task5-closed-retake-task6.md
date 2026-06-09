# Handoff - S&G Super App I5 Task 5 cerrada, retake Task 6

**Fecha:** 2026-06-06  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Incremento activo:** I5 - Cursos y acreditaciones  
**Siguiente tarea autorizada:** I5 Task 6 - listado y detalle backend  

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
- I5 Tasks 1-5 cerradas.
- Retake autorizado: Task 6 del plan I5.

## Cambios Cerrados En Task 5

- `TrainingServiceEnablementResponse`
  - expone `employeeId`;
  - expone `serviceEnablementStatus`;
  - expone `blockingExpiredRequirementsCount`;
  - expone `calculatedAt`.
- `GET /api/portal/employees/{employeeId}/training/enablement`
  - protegido por `TRAINING_SERVICE_ENABLEMENT/VIEW`;
  - disponible para TH, GERENCIA y OPERACIONES segun seed I5;
  - retorna 404 si el empleado no existe.
- `PostgresPortalRepository.GetTrainingServiceEnablementAsync`
  - calcula `NO_HABILITADO` si hay requisitos obligatorios de servicio vencidos;
  - mantiene `HABILITADO` si los requisitos obligatorios estan vigentes;
  - ignora requisitos no obligatorios para bloqueo;
  - reutiliza `TrainingComplianceStatusCalculator`.

## Evidencia

- RED: `scripts/dev/Verify-SgSuperAppI5ServiceEnablement.ps1` fallo inicialmente con HTTP 404 por endpoint inexistente.
- GREEN: `scripts/dev/Verify-SgSuperAppI5ServiceEnablement.ps1` correcto.
- GREEN: `scripts/dev/Verify-SgSuperAppI5Security.ps1` correcto.
- `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj`: correcto, 0 advertencias y 0 errores.

## Retake Exacto - I5 Task 6

Objetivo: exponer consultas de cumplimiento y detalle por empleado.

Primer ciclo recomendado:

1. Crear `scripts/dev/Verify-SgSuperAppI5Queries.ps1`.
2. Cubrir:
   - listado backend de empleados con cumplimiento por rol autorizado;
   - detalle por empleado con renovaciones activas e historicas;
   - filtros por estado de cumplimiento;
   - puesto actual si existe.
3. No implementar UI antes de cerrar Task 6.
4. Ejecutar backend build.

## Riesgos Y Observaciones

- Hay cambios acumulados sin commit de I2/I3/I4/I5; no revertir trabajo externo.
- `AGENTS.md` tiene cambios externos; no incluirlo ni revertirlo por accidente.
- `graphify update .` debe intentarse despues de modificar codigo; en esta maquina no esta disponible en PATH.
