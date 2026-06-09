# Handoff - S&G Super App I5 Task 8 cerrada, retake Task 9

**Fecha:** 2026-06-06  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Incremento activo:** I5 - Cursos y acreditaciones  
**Siguiente tarea autorizada:** I5 Task 9 - UI de gestion TH/ADMIN  

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
- I5 Tasks 1-8 cerradas.
- Retake autorizado: Task 9 del plan I5.

## Cambios Cerrados En Task 8

- `apps/sg-superapp-web/src/features/courses/CoursesPage.tsx`
  - listado filtrable por empleado/identificacion, tipo, estado calculado y habilitacion;
  - detalle con empleado, puesto actual, habilitacion, KPIs, requisitos actuales e historico;
  - nota de rol para consulta sin acciones en OPERACIONES/GERENCIA.
- `apps/sg-superapp-web/src/features/shell/ModuleWorkspace.tsx`
  - cablea `module/courses` hacia `CoursesPage`.
- `apps/sg-superapp-web/src/styles.css`
  - estilos responsive para filtros, detalle, KPIs y tarjetas I5.

## Evidencia

- RED: `npm run build` fallo inicialmente por `CoursesPage` inexistente desde `src/i5-courses-ui.red.ts`.
- GREEN: `npm run build` correcto fuera del sandbox.
- GREEN: `scripts/dev/Verify-SgSuperAppI5Security.ps1` correcto.
- Nota: dentro del sandbox Vite/esbuild falla con `Access is denied` al resolver `vite.config.ts`; el build escalado fue correcto.

## Retake Exacto - I5 Task 9

Objetivo: implementar gestion visual de tipos y renovaciones para ADMIN/TH.

Primer ciclo recomendado:

1. Extender `CoursesPage` sin separar un sistema visual nuevo.
2. Agregar gestion de tipos para ADMIN/TH:
   - crear/editar;
   - inactivar;
   - validaciones y errores backend.
3. Agregar registro e inactivacion de renovaciones para ADMIN/TH.
4. Mantener GERENCIA/OPERACIONES sin acciones de edicion visibles.
5. Validar:
   - `npm run build`;
   - `scripts/dev/Verify-SgSuperAppI5Types.ps1`;
   - `scripts/dev/Verify-SgSuperAppI5Renewals.ps1`.

## Riesgos Y Observaciones

- Hay cambios acumulados sin commit de I2/I3/I4/I5; no revertir trabajo externo.
- `AGENTS.md` tiene cambios externos; no incluirlo ni revertirlo por accidente.
- `graphify update .` debe intentarse despues de modificar codigo; en esta maquina no esta disponible en PATH.
