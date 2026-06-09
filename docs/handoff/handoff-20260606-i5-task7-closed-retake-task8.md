# Handoff - S&G Super App I5 Task 7 cerrada, retake Task 8

**Fecha:** 2026-06-06  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Incremento activo:** I5 - Cursos y acreditaciones  
**Siguiente tarea autorizada:** I5 Task 8 - UI de cumplimiento  

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
- I5 Tasks 1-7 cerradas.
- Retake autorizado: Task 8 del plan I5.

## Cambios Cerrados En Task 7

- `apps/sg-superapp-web/src/types/portal.ts`
  - tipos de requisito;
  - renovaciones;
  - estados calculados;
  - habilitacion;
  - listado de cumplimiento;
  - detalle de cumplimiento.
- `apps/sg-superapp-web/src/services/portalApi.ts`
  - `fetchTrainingRequirementTypes`;
  - `fetchTrainingRequirementTypeDetail`;
  - `createTrainingRequirementType`;
  - `updateTrainingRequirementType`;
  - `inactivateTrainingRequirementType`;
  - `createTrainingRecord`;
  - `inactivateTrainingRecord`;
  - `fetchTrainingServiceEnablement`;
  - `fetchTrainingCompliance`;
  - `fetchTrainingComplianceDetail`.

## Evidencia

- RED: `npm run build` fallo inicialmente por exports I5 faltantes desde `src/i5-api-contract.red.ts`.
- GREEN: `npm run build` correcto fuera del sandbox.
- Nota: dentro del sandbox Vite/esbuild falla con `Access is denied` al resolver `vite.config.ts`; el build escalado fue correcto.

## Retake Exacto - I5 Task 8

Objetivo: implementar listado y detalle de cumplimiento por empleado en UI.

Primer ciclo recomendado:

1. Leer `apps/sg-superapp-web/src/features/*` para replicar patrones de pages existentes.
2. Crear o cablear pagina I5 para el modulo `COURSES`.
3. Implementar:
   - listado filtrable por empleado, tipo, estado y habilitacion;
   - detalle de empleado con puesto actual, habilitacion, actuales e historico;
   - vista de solo consulta para OPERACIONES/GERENCIA.
4. Validar `npm run build`.
5. Ejecutar `scripts/dev/Verify-SgSuperAppI5Security.ps1`.

## Riesgos Y Observaciones

- Hay cambios acumulados sin commit de I2/I3/I4/I5; no revertir trabajo externo.
- `AGENTS.md` tiene cambios externos; no incluirlo ni revertirlo por accidente.
- `graphify update .` debe intentarse despues de modificar codigo; en esta maquina no esta disponible en PATH.
