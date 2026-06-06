# Handoff - S&G Super App I5 Gate 0 cerrado, retake Task 1

**Fecha:** 2026-06-05  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Incremento activo:** I5 - Cursos y acreditaciones  
**Siguiente tarea autorizada:** I5 Task 1 - persistencia I5 y permisos base  

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
- I4 cerrado tecnicamente con suite completa, build backend y build frontend correctos.
- SPEC I5 creada y aprobada.
- Plan I5 creado y aprobado.
- I5 Gate 0 cerrado.
- Retake autorizado: Task 1 del plan I5.

## Retake Exacto - I5

Objetivo: iniciar Task 1 del plan I5 con TDD para persistencia y permisos base.

Primer ciclo recomendado:

1. Crear `Verify-SgSuperAppI5PersistenceClean.ps1` y `Verify-SgSuperAppI5Persistence.ps1`.
2. Crear migracion para `training_requirement_types` y `employee_training_records`.
3. Crear seed de permisos I5 para ADMIN, TH, GERENCIA y OPERACIONES.
4. Crear contrato SQL de persistencia.
5. Validar scripts de persistencia y `dotnet build`.

No implementar API/UI I5 antes de cerrar Task 1.

## Decisiones I5 Cerradas

- Estados calculados: `VENCIDO`, `CRITICO`, `PREVENTIVO`, `INFORMATIVO`, `AL_DIA`.
- `NO_HABILITADO` es indicador calculado, no bloqueo automatico de turnos.
- Alertas automaticas, correo y notificaciones quedan para I6.
- Soporte documental es referencia opcional en I5.
- Operaciones y Gerencia consultan cumplimiento, pero no editan.

## Riesgos Y Observaciones

- `graphify update .` sigue bloqueado porque `graphify` no esta disponible en PATH.
- `graphify-out/GRAPH_REPORT.md` existe pero esta obsoleto y cubre un alcance mas amplio que el modulo actual.
- Hay cambios acumulados sin commit de I2/I3/I4/I5; no revertir trabajo externo.
- `AGENTS.md` puede tener cambios externos; no incluirlo ni revertirlo por accidente.

## Git

- Rama actual esperada: `main`.
- No se realizo commit ni push en Gate 0 I5.
- Antes de cerrar sesion con Git, revisar `git status --short` y excluir artefactos locales (`.codex`, `.claude`, `.superpowers`, `graphify-out`) salvo instruccion contraria.
