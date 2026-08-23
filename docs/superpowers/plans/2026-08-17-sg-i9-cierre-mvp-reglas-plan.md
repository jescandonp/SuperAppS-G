# Plan De Implementacion - Cierre Tecnico MVP I9 R01 A R07

> Estado: **PROPUESTO_PARA_REVISION**
> Fecha: 2026-08-17
> SPEC: `docs/specs/2026-08-17-sg-superapp-spec-i9-cierre-mvp-reglas.md`
> Base tecnica: rama `codex/i9-scheduling-gate0`, Tasks 2 a 12 completadas.
> Regla de avance: no iniciar implementacion hasta aprobacion explicita.

## 1. Objetivo

Cerrar el MVP I9 mediante perfiles versionados y siete reglas ejecutables en
`MVP_TEST`, usando datos simulados identificables, TDD por corte vertical y una
suite hermetica integral. La activacion productiva permanece fuera de alcance.

## 2. Decisiones De Arquitectura

1. **Motor interno deterministico:** evaluadores C# puros; sin dependencia de un
   motor externo.
2. **Perfil versionado:** parametros JSONB por regla, checksum e inmutabilidad
   despues de activar.
3. **Separacion configuracion/evaluacion:** el repositorio persiste; los
   evaluadores deciden.
4. **Origen explicito:** `SIMULATED` y `INSTITUTIONAL` nunca se mezclan en la
   misma version.
5. **Gate de ambiente:** `SIMULATED` funciona en `MVP_TEST` y falla en
   `PRODUCTION`.
6. **Excepcion por snapshot:** toda decision se liga a `scopeHash`; cualquier
   cambio obliga a revalidar.
7. **Compatibilidad incremental:** las rutas actuales se amplian sin romper los
   contratos ya verificados de Tasks 8 a 12.

## 3. Dependencias

```text
Perfil versionado y migracion
    |
    +-- Contratos y repositorio de configuracion
    |       |
    |       +-- Orquestador y resultados comunes
    |               |
    |               +-- R01/R02
    |               +-- R03/R05
    |               +-- R04/R06
    |               +-- R07
    |                       |
    +-----------------------+-- Workflow y excepciones
                                    |
                                    +-- API/Frontend
                                    +-- Suite hermetica/cierre
```

Las tareas de reglas se ejecutan secuencialmente porque comparten contratos y
precedencia. Cada tarea deja el sistema verificable y no toca mas de cinco
archivos previstos.

## 4. Tareas

### Task 14 - Contrato RED Del Cierre MVP

**Descripcion:** crear un verificador que exija perfiles, resultados, siete
reglas, gate de ambiente, `scopeHash`, marca simulada y nuevos endpoints.

**Archivos:**

- Create: `scripts/dev/Verify-SgSuperAppI9MvpRules.ps1`

**Aceptacion:**

- [ ] Enumera controles estructurales para R01 a R07.
- [ ] Exige resultados, precedencia, snapshots y rechazo productivo.
- [ ] Falla antes de existir la implementacion.

**Verificacion:**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9MvpRules.ps1
# Esperado: I9 MVP RULES FAIL
```

**Dependencias:** SPEC y plan aprobados.
**Alcance:** XS, 1 archivo.

### Task 15 - Persistencia Versionada Y Seed Simulado

**Descripcion:** crear tablas convergentes para perfiles, entradas,
evaluaciones y ampliacion de excepciones/versiones; sembrar un perfil MVP
simulado completo.

**Archivos:**

- Create: `db/migrations/012_i9_mvp_rule_profiles.sql`
- Create: `db/seeds/011_i9_mvp_simulated_rule_profile.sql`
- Create: `db/tests/008_i9_mvp_rule_profiles_contract.sql`
- Modify: `scripts/dev/Verify-SgSuperAppI9MvpRules.ps1`

**Aceptacion:**

- [ ] Una sola version activa por alcance/ambiente/vigencia.
- [ ] Perfil activo y evaluaciones historicas son inmutables.
- [ ] Seed idempotente, `SIMULATED`, `MVP_TEST` y sin PII.

**Verificacion:**

```powershell
psql -v ON_ERROR_STOP=1 -f db/migrations/012_i9_mvp_rule_profiles.sql
psql -v ON_ERROR_STOP=1 -f db/seeds/011_i9_mvp_simulated_rule_profile.sql
psql -v ON_ERROR_STOP=1 -f db/tests/008_i9_mvp_rule_profiles_contract.sql
# Repetir migracion y seed: ambos deben pasar
```

**Dependencias:** Task 14.
**Alcance:** M, 4 archivos.

### Checkpoint A - Fundacion

- [ ] RED observado y registrado.
- [ ] Contrato SQL, migracion y seed pasan dos veces.
- [ ] Revision humana del modelo antes del backend.

### Task 16 - Contratos Y Repositorio De Perfiles

**Descripcion:** exponer modelos tipados, validacion fail-closed y persistencia
de perfiles sin mezclarla con decisiones de reglas.

**Archivos:**

- Create: `apps/sg-superapp-api/Domain/SchedulingRuleModels.cs`
- Create: `apps/sg-superapp-api/Services/SchedulingRuleProfileRepository.cs`
- Create: `apps/sg-superapp-api/Services/SchedulingRuleProfileValidator.cs`
- Modify: `apps/sg-superapp-api/Program.cs`
- Modify: `scripts/dev/Verify-SgSuperAppI9MvpRules.ps1`

**Aceptacion:**

- [ ] Perfil incompleto, superpuesto o simulado/productivo se rechaza.
- [ ] Checksum es estable para contenido equivalente.
- [ ] Repositorio carga una version exacta por proyecto/periodo/ambiente.

**Verificacion:** verificador Task 14 y build .NET.
**Dependencias:** Task 15.
**Alcance:** M, 5 archivos.

### Task 17 - Orquestador Y Frontera HTTP De Reglas

**Descripcion:** crear evaluacion comun, resumen y endpoints de consulta,
activacion MVP y evaluacion previa protegidos por permisos.

**Archivos:**

- Create: `apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs`
- Create: `apps/sg-superapp-api/Endpoints/SchedulingRuleEndpoints.cs`
- Create: `apps/sg-superapp-api/Contracts/Portal/SchedulingRuleContracts.cs`
- Modify: `apps/sg-superapp-api/Program.cs`
- Modify: `scripts/dev/Verify-SgSuperAppI9MvpRules.ps1`

**Aceptacion:**

- [ ] Resultados ordenados por regla y `scopeHash` deterministico.
- [ ] Endpoints aplican `VIEW`, `CONFIGURE` y `GENERATE`.
- [ ] Activacion productiva de `SIMULATED` devuelve conflicto seguro.

**Verificacion:** verificador, pruebas HTTP negativas y build .NET.
**Dependencias:** Task 16.
**Alcance:** M, 5 archivos.

### Task 18 - Corte Vertical R01 Y R02

**Descripcion:** implementar jornada y descanso con fronteras exactas, acuerdo
escrito y excepcion no bloqueante de generacion.

**Archivos:**

- Create: `apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9R01R02.ps1`
- Modify: `apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs`
- Modify: `scripts/dev/Verify-SgSuperAppI9MvpRules.ps1`

**Aceptacion:**

- [ ] R01 cubre 8/10/12 h y 42/60 h, acuerdo y maximos absolutos.
- [ ] R02 menor a 12 h exige excepcion; igual a 12 cumple.
- [ ] R01 bloqueante prevalece sobre R02 aprobada.

**Verificacion:** `Verify-SgSuperAppI9R01R02.ps1` y build .NET.
**Dependencias:** Task 17.
**Alcance:** M, 4 archivos.

### Task 19 - Corte Vertical R03 Y R05

**Descripcion:** implementar solapamientos semiabiertos y traslado direccional
con prioridad absoluta de R03.

**Archivos:**

- Create: `apps/sg-superapp-api/Services/SchedulingOverlapTravelRules.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9R03R05.ps1`
- Modify: `apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs`
- Modify: `scripts/dev/Verify-SgSuperAppI9MvpRules.ps1`

**Aceptacion:**

- [ ] Intervalos adyacentes cumplen y solapamientos reales bloquean.
- [ ] Matriz es direccional; ausente nunca equivale a cero.
- [ ] Traslado prohibido bloquea; insuficiente exige excepcion.

**Verificacion:** casos R03-T01..T15, R05-T01..T20 y build.
**Dependencias:** Task 18.
**Alcance:** M, 4 archivos.

### Checkpoint B - Bloqueos Y Tiempo

- [ ] R01/R03/R05 bloqueantes no admiten excepcion.
- [ ] R02/R05 aprobables conservan `scopeHash`.
- [ ] Resultados son deterministas en doble ejecucion.

### Task 20 - Corte Vertical R04 Y R06

**Descripcion:** implementar adaptadores seguros para novedades y requisitos,
manteniendo catalogo canonico separado de evaluacion por empleado.

**Archivos:**

- Create: `apps/sg-superapp-api/Services/SchedulingNoveltyRequirementRules.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9R04R06.ps1`
- Modify: `apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs`
- Modify: `scripts/dev/Verify-SgSuperAppI9MvpRules.ps1`

**Aceptacion:**

- [ ] INC/V/A/TA y D/N/X siguen el mapeo simulado aprobado.
- [ ] Desconocido no presume disponibilidad ni cumplimiento.
- [ ] R06 liga `employeeId`, puesto, requisito, evidencia y vigencia sin PII.

**Verificacion:** casos R04-T01..T24, R06-T01..T23 y build.
**Dependencias:** Task 19.
**Alcance:** M, 4 archivos.

### Task 21 - Corte Vertical R07

**Descripcion:** comparar plantilla/version/anclaje/celdas, producir desviaciones
exactas e invalidarlas ante cualquier cambio.

**Archivos:**

- Create: `apps/sg-superapp-api/Services/SchedulingTemplateDeviationRule.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9R07.ps1`
- Modify: `apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs`
- Modify: `scripts/dev/Verify-SgSuperAppI9MvpRules.ps1`

**Aceptacion:**

- [ ] Coincidencia no crea excepcion.
- [ ] Desviacion identifica valores esperado/propuesto y celdas.
- [ ] Agrupacion nunca mezcla guardas o snapshots.

**Verificacion:** casos R07-T01..T23 y build.
**Dependencias:** Task 20.
**Alcance:** M, 4 archivos.

### Task 22 - Integrar Generacion Y Edicion Manual

**Descripcion:** reemplazar hechos booleanos aislados por la evaluacion
versionada en generacion y revalidar despues de cada ajuste.

**Archivos:**

- Modify: `apps/sg-superapp-api/Domain/SchedulingModels.cs`
- Modify: `apps/sg-superapp-api/Services/SchedulingEligibilityService.cs`
- Modify: `apps/sg-superapp-api/Services/SchedulingRecommendationEngine.cs`
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9MvpGeneration.ps1`

**Aceptacion:**

- [ ] Candidato bloqueado nunca se asigna.
- [ ] Excepcion requerida penaliza score y queda visible.
- [ ] Edicion cambia `scopeHash`, invalida decision y recalcula resumen.

**Verificacion:** nuevo verificador, regresiones de elegibilidad/recomendacion y
build .NET.
**Dependencias:** Tasks 18 a 21.
**Alcance:** M, 5 archivos.

### Task 23 - Endurecer Excepciones, Aprobacion Y Publicacion

**Descripcion:** ligar decisiones a regla/evaluacion/snapshot y volver a
comprobar bloqueos antes de transiciones.

**Archivos:**

- Modify: `apps/sg-superapp-api/Contracts/Portal/SchedulingContracts.cs`
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
- Modify: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9MvpWorkflow.ps1`
- Modify: `scripts/dev/Verify-SgSuperAppI9MvpRules.ps1`

**Aceptacion:**

- [ ] Excepcion exige motivo catalogado, permiso y `scopeHash` vigente.
- [ ] Aprobar/publicar falla con bloqueos o pendientes.
- [ ] Perfil, resultados y marca simulada quedan en snapshot/auditoria.

**Verificacion:** nuevo verificador, workflow/security existentes y build.
**Dependencias:** Task 22.
**Alcance:** M, 5 archivos.

### Checkpoint C - Backend Integral

- [ ] Todas las reglas y precedencias pasan.
- [ ] Workflow rechaza decisiones obsoletas y acciones sin permiso.
- [ ] Persistencia, elegibilidad, recomendaciones, workflow y seguridad no
  presentan regresiones.

### Task 24 - Contratos Y Cliente Frontend

**Descripcion:** añadir perfiles, resumen de reglas y marca simulada al cliente
tipado sin romper rutas existentes.

**Archivos:**

- Modify: `apps/sg-superapp-web/src/types/portal.ts`
- Modify: `apps/sg-superapp-web/src/services/portalApi.ts`
- Modify: `apps/sg-superapp-web/src/hooks/usePortalShell.ts`
- Create: `scripts/dev/Verify-SgSuperAppI9MvpFrontendApi.ps1`

**Aceptacion:**

- [ ] No se infieren permisos ni resultados en frontend.
- [ ] Errores, carga y configuracion incompleta estan tipados.
- [ ] Contratos preservan compatibilidad con la UI I9 existente.

**Verificacion:** verificador, `tsc` mediante build Vite.
**Dependencias:** Task 23.
**Alcance:** M, 4 archivos.

### Task 25 - UI De Resultados Y Datos Simulados

**Descripcion:** mostrar perfil, badge, resumen por regla y bloqueos/pendientes,
incluida revalidacion tras edicion.

**Archivos:**

- Create: `apps/sg-superapp-web/src/features/scheduling/RuleEvaluationPanel.tsx`
- Modify: `apps/sg-superapp-web/src/features/scheduling/SchedulingPage.tsx`
- Modify: `apps/sg-superapp-web/src/features/scheduling/ExceptionPanel.tsx`
- Modify: `apps/sg-superapp-web/src/styles.css`
- Create: `scripts/dev/Verify-SgSuperAppI9MvpUi.ps1`

**Aceptacion:**

- [ ] Badge simulado permanece visible en todos los estados.
- [ ] Bloqueo, excepcion y advertencia tienen texto y accion pertinente.
- [ ] Aprobar/publicar deshabilitado explica la causa.

**Verificacion:** verificador UI, build Vite y navegacion por teclado.
**Dependencias:** Task 24.
**Alcance:** M, 5 archivos.

### Task 26 - Suite Hermetica Y Regresion

**Descripcion:** ampliar la suite aislada con perfiles/fixtures anonimos, siete
reglas, workflow, auditoria y exportaciones marcadas.

**Archivos:**

- Modify: `scripts/dev/Verify-SgSuperAppI9Integration.ps1`
- Create: `scripts/dev/Verify-SgSuperAppI9MvpIntegration.ps1`
- Modify: `db/tests/008_i9_mvp_rule_profiles_contract.sql`
- Modify: `scripts/dev/Verify-SgSuperAppI9MvpRules.ps1`

**Aceptacion:**

- [ ] Esquema temporal siempre se elimina.
- [ ] R01 a R07, precedencia, invalidacion y doble ejecucion pasan.
- [ ] Exportaciones/auditoria incluyen perfil y marca simulada.

**Verificacion:** suite nueva, suite I9 previa completa y builds .NET/Vite.
**Dependencias:** Tasks 23 y 25.
**Alcance:** M, 4 archivos.

### Task 27 - Recorrido Visual Y Funcional

**Descripcion:** validar estados cargando/error/vacio, reglas, excepciones,
edicion y publicacion de prueba en cuatro viewports.

**Archivos:**

- Modify: `scripts/dev/Verify-SgSuperAppI9MvpUi.ps1`
- Create: `docs/reports/2026-08-17-sg-superapp-i9-mvp-visual-checklist.md`

**Aceptacion:**

- [ ] 320/768 usan lista accesible; 1024/1440 usan matriz sin overflow de pagina.
- [ ] Acciones y estados son navegables y explicables.
- [ ] Evidencia no contiene datos personales reales.

**Verificacion:** recorrido real y checklist con resultado por viewport/estado.
**Dependencias:** Task 26.
**Alcance:** S, 2 archivos.

### Task 28 - Evidencia Y Propuesta De Cierre MVP

**Descripcion:** actualizar SPEC viva, execution log y baseline con resultados
reales; proponer cierre solo si todos los criterios pasan.

**Archivos:**

- Modify: `docs/specs/2026-08-17-sg-superapp-spec-i9-cierre-mvp-reglas.md`
- Modify: `docs/plans/2026-07-29-sg-superapp-i9-programacion-turnos-plan.md`
- Modify: `docs/reports/2026-07-29-sg-superapp-i9-pilot-baseline.md`
- Modify: `scripts/dev/Verify-SgSuperAppI9Docs.ps1`
- Create: `docs/reports/2026-08-17-sg-superapp-i9-mvp-closure.md`

**Aceptacion:**

- [ ] Solo se registran comandos y resultados observados.
- [ ] Datos simulados y limites productivos permanecen explicitos.
- [ ] Cierre del MVP queda sujeto a revision final del usuario.

**Verificacion:** docs verifier, diff-check, suite integral y revision humana.
**Dependencias:** Task 27.
**Alcance:** M, 5 archivos.

## 5. Gate Final

El MVP puede proponerse como cerrado solamente cuando:

- [ ] Tasks 14 a 28 estan completadas y revisadas.
- [ ] Verificadores R01 a R07 y suite hermetica pasan.
- [ ] Builds .NET y Vite pasan.
- [ ] No quedan hallazgos Critical/Important de revision.
- [ ] Recorrido responsive y workflow de prueba estan aprobados.
- [ ] Perfil simulado se rechaza en produccion.
- [ ] El usuario autoriza explicitamente el cierre.

## 6. Riesgos Y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|---|---|---|
| Confundir datos simulados con institucionales | Alto | Origen, ambiente y badge obligatorios; rechazo productivo |
| Excepcion elude bloqueo | Alto | Precedencia central y pruebas cruzadas |
| Decision se reutiliza | Alto | `scopeHash`, snapshot e invalidacion |
| Migracion no converge instalaciones parciales | Alto | Prueba en esquema parcial y doble ejecucion |
| Monolito de repositorio crece | Medio | Servicio/repositorio de perfiles separado; cambios puntuales al workflow existente |
| Casos R01-R07 demasiado amplios | Medio | Un corte vertical por grupo y checkpoint cada 2-3 tareas |
| UI oculta una restriccion | Medio | Resumen backend como fuente, texto junto al color y pruebas responsive |
| Evidencia contiene PII | Alto | Fixtures anonimos, contratos minimizados y revision negativa |

## 7. Comandos De Regresion Final

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9MvpRules.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9MvpIntegration.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Integration.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Docs.ps1
& 'C:\tmp\dotnet6\dotnet.exe' build apps/sg-superapp-api/sg-superapp-api.csproj
& 'C:\Program Files\nodejs\npm.cmd' --prefix apps/sg-superapp-web run build
git diff --check
```

## 8. Decision Pendiente

La implementacion esta detenida en este punto. Se requiere aprobacion explicita
del usuario sobre esta SPEC y este plan antes de comenzar Task 14.
