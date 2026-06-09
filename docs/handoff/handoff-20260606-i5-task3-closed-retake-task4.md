# Handoff - S&G Super App I5 Task 3 cerrada, retake Task 4

**Fecha:** 2026-06-06  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Incremento activo:** I5 - Cursos y acreditaciones  
**Siguiente tarea autorizada:** I5 Task 4 - estados calculados  

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
- I5 Task 2 cerrada.
- I5 Task 3 cerrada con renovaciones, reglas de fecha y auditoria.
- Retake autorizado: Task 4 del plan I5.

## Cambios Cerrados En Task 3

- Contratos:
  - `apps/sg-superapp-api/Contracts/Portal/CreateTrainingRecordRequest.cs`
  - `apps/sg-superapp-api/Contracts/Portal/TrainingRecordResponse.cs`
- Endpoints:
  - `POST /api/portal/employees/{employeeId}/training`
  - `POST /api/portal/training/{recordId}/inactivate`
- Repositorio:
  - crea renovaciones por empleado;
  - calcula `expires_at` desde `validity_days` si aplica;
  - exige `expiresAt` manual si el tipo no tiene vigencia;
  - inactiva renovaciones sin borrar historico;
  - registra auditoria.
- Validaciones:
  - empleado existente;
  - tipo existente y activo;
  - fecha de realizacion valida;
  - vencimiento no anterior a realizacion;
  - soporte opcional.

## Evidencia

- RED: `scripts/dev/Verify-SgSuperAppI5Renewals.ps1` fallo inicialmente con HTTP 404 por endpoint inexistente.
- GREEN: `scripts/dev/Verify-SgSuperAppI5Renewals.ps1` correcto.
- GREEN: `scripts/dev/Verify-SgSuperAppI5Audit.ps1` correcto.
- `C:\tmp\dotnet6\dotnet.exe build apps\sg-superapp-api\sg-superapp-api.csproj`: correcto, 0 advertencias y 0 errores.

## Retake Exacto - I5 Task 4

Objetivo: calcular estados de vencimiento por umbral y dejar reglas reutilizables para I6.

Primer ciclo recomendado:

1. Crear `Verify-SgSuperAppI5StatusRules.ps1` con casos RED para:
   - `VENCIDO`
   - `CRITICO`
   - `PREVENTIVO`
   - `INFORMATIVO`
   - `AL_DIA`
2. Centralizar la regla de estado en backend para reutilizarla en consultas y luego en I6.
3. Exponer estado calculado donde corresponda sin implementar habilitacion de servicio todavia.
4. Ejecutar backend build.

No implementar habilitado/no habilitado, consultas completas de cumplimiento ni UI antes de cerrar Task 4.

## Riesgos Y Observaciones

- Hay cambios acumulados sin commit de I2/I3/I4/I5; no revertir trabajo externo.
- `AGENTS.md` tiene cambios externos; no incluirlo ni revertirlo por accidente.
- `graphify update .` debe intentarse despues de modificar codigo cuando la herramienta este disponible; en esta maquina suele no estar en PATH.
