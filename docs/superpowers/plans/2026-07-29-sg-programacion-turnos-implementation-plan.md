# S&G Programación Asistida de Turnos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir un MVP integrado que configure proyectos, cobertura y plantillas cíclicas; genere propuestas explicables; gestione excepciones, aprobación y publicación; y exporte la programación a PDF y Excel.

**Architecture:** El módulo se implementará dentro de la SPA React y la API .NET 6 existentes, reutilizando PostgreSQL, permisos, notificaciones y auditoría. El primer motor será heurístico, determinístico y aislado de la persistencia mediante modelos de entrada/salida; sus restricciones se ejecutan antes de la puntuación y nunca ocultan vacantes. Las versiones publicadas serán snapshots inmutables y toda desviación de plantilla exigirá excepción auditada.

**Tech Stack:** React 18, TypeScript 5.6, Vite 5, ASP.NET Core minimal APIs sobre .NET 6, Npgsql 6.0.10, PostgreSQL, DocumentFormat.OpenXml 3.0.2, scripts de verificación PowerShell 4-compatible.

---

## Alcance de este plan

Este plan entrega el MVP descrito en el diseño aprobado. La optimización matemática avanzada queda fuera: solo se habilitará después de medir el piloto. Antes de implementar se debe trabajar en un worktree dedicado y preservar los cambios no relacionados que ya existen en el checkout principal.

## Mapa de archivos

### Documentos

- Modificar: `docs/CONSTITUTION.md` — autorizar programación asistida.
- Modificar: `docs/ARCHITECTURE.md` — registrar módulo, entidades y flujo.
- Modificar: `docs/TECNOLOGIA.md` — fijar motor heurístico .NET 6 sin dependencia externa.
- Modificar: `docs/DESIGN.md` — registrar patrón de matriz mensual y comparación.
- Crear: `docs/specs/2026-07-29-sg-superapp-spec-i9-programacion-turnos.md` — contrato funcional/técnico.
- Crear: `docs/plans/2026-07-29-sg-superapp-i9-programacion-turnos-plan.md` — execution log y gates I9.
- Crear: `docs/operations/2026-07-29-i9-catalogo-reglas-programacion.md` — catálogo jurídico-operativo firmado.

### Base de datos

- Crear: `db/migrations/009_i9_scheduling.sql` — clientes, proyectos, plantillas, cobertura, reglas y disponibilidad.
- Crear: `db/migrations/010_i9_schedule_versions.sql` — propuestas, versiones, turnos, asignaciones y excepciones.
- Crear: `db/seeds/009_i9_scheduling_permissions.sql` — permisos y módulo.
- Crear: `db/seeds/010_i9_shift_templates.sql` — 2x2, 4x2 y 6x1.
- Crear: `db/tests/007_i9_scheduling_contract.sql` — invariantes estructurales.

### Backend

- Crear: `apps/sg-superapp-api/Domain/SchedulingModels.cs` — modelos puros del motor.
- Crear: `apps/sg-superapp-api/Services/ShiftCycleProjector.cs` — proyección de plantillas.
- Crear: `apps/sg-superapp-api/Services/SchedulingEligibilityService.cs` — restricciones y razones.
- Crear: `apps/sg-superapp-api/Services/SchedulingRecommendationEngine.cs` — heurística determinística.
- Crear: `apps/sg-superapp-api/Services/SchedulingExportService.cs` — PDF/XLSX.
- Crear: `apps/sg-superapp-api/Contracts/Portal/SchedulingContracts.cs` — requests/responses.
- Modificar: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs` — persistencia I9.
- Modificar: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs` — endpoints I9.
- Modificar: `apps/sg-superapp-api/Program.cs` — registro de servicios.

### Frontend

- Crear: `apps/sg-superapp-web/src/features/scheduling/SchedulingPage.tsx` — panel y flujo principal.
- Crear: `apps/sg-superapp-web/src/features/scheduling/ShiftTemplatesPanel.tsx` — plantillas.
- Crear: `apps/sg-superapp-web/src/features/scheduling/ScheduleMatrix.tsx` — calendario mensual.
- Crear: `apps/sg-superapp-web/src/features/scheduling/ProposalComparison.tsx` — comparación.
- Crear: `apps/sg-superapp-web/src/features/scheduling/ExceptionPanel.tsx` — vacantes/excepciones.
- Modificar: `apps/sg-superapp-web/src/types/portal.ts` — contratos TypeScript.
- Modificar: `apps/sg-superapp-web/src/services/portalApi.ts` — cliente I9.
- Modificar: `apps/sg-superapp-web/src/features/shell/ModuleWorkspace.tsx` — ruta del módulo.
- Modificar: `apps/sg-superapp-web/src/styles.css` — estilos Sentinel Enterprise.

### Verificación

- Crear: `scripts/dev/Verify-SgSuperAppI9Persistence.ps1`.
- Crear: `scripts/dev/Verify-SgSuperAppI9ShiftCycles.ps1`.
- Crear: `scripts/dev/Verify-SgSuperAppI9Eligibility.ps1`.
- Crear: `scripts/dev/Verify-SgSuperAppI9Recommendations.ps1`.
- Crear: `scripts/dev/Verify-SgSuperAppI9Workflow.ps1`.
- Crear: `scripts/dev/Verify-SgSuperAppI9Security.ps1`.
- Crear: `scripts/dev/Verify-SgSuperAppI9Exports.ps1`.
- Crear: `scripts/dev/Verify-SgSuperAppI9FrontendApi.ps1`.
- Crear: `scripts/dev/Verify-SgSuperAppI9Ui.ps1`.

---

### Task 1: Cerrar Gate 0 documental y jurídico-operativo

**Files:**
- Modify: `docs/CONSTITUTION.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/TECNOLOGIA.md`
- Modify: `docs/DESIGN.md`
- Create: `docs/specs/2026-07-29-sg-superapp-spec-i9-programacion-turnos.md`
- Create: `docs/plans/2026-07-29-sg-superapp-i9-programacion-turnos-plan.md`
- Create: `docs/operations/2026-07-29-i9-catalogo-reglas-programacion.md`

- [ ] **Step 1: Escribir el chequeo RED de autoridad documental**

Crear `scripts/dev/Verify-SgSuperAppI9Docs.ps1` con comprobaciones literales:

```powershell
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$required = @(
    @{ Path = "docs\CONSTITUTION.md"; Pattern = "programacion asistida de turnos" },
    @{ Path = "docs\ARCHITECTURE.md"; Pattern = "Modulo De Programacion De Turnos" },
    @{ Path = "docs\TECNOLOGIA.md"; Pattern = "motor heuristico deterministico" },
    @{ Path = "docs\DESIGN.md"; Pattern = "matriz mensual de turnos" },
    @{ Path = "docs\specs\2026-07-29-sg-superapp-spec-i9-programacion-turnos.md"; Pattern = "Estado: Aprobada" },
    @{ Path = "docs\operations\2026-07-29-i9-catalogo-reglas-programacion.md"; Pattern = "Aprobacion Operaciones" }
)
foreach ($item in $required) {
    $path = Join-Path $root $item.Path
    if (-not (Test-Path $path)) { throw "Falta $($item.Path)" }
    if (-not (Select-String -Path $path -Pattern $item.Pattern -Quiet)) { throw "Falta patron $($item.Pattern)" }
}
Write-Host "I9 DOCS PASS"
```

- [ ] **Step 2: Ejecutar RED**

Run: `powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Docs.ps1`

Expected: FAIL indicando que I9 aún no está autorizado en Constitución/Arquitectura.

- [ ] **Step 3: Actualizar documentos rectores y crear SPEC/plan operativo**

La SPEC debe convertir las secciones 5–17 del diseño en criterios normativos y declarar como gate de implementación:

```markdown
## Gate 0 - Reglas versionadas

No se genera programación hasta que exista un catálogo con: código, fuente, alcance,
vigencia desde/hasta, prioridad, severidad BLOQUEANTE/SUBSANABLE/INFORMATIVA,
parámetros y evidencia de aprobación por Operaciones, TH y responsable jurídico-laboral.
```

El catálogo debe incluir filas explícitas para jornada máxima, descanso mínimo, cruce de turnos, novedades bloqueantes, ubicación, requisitos del puesto y desviación de plantilla. Las filas ingresan como `BORRADOR_NO_EJECUTABLE`; el Gate 0 solo cierra cuando todas las filas ejecutables pasan a `APROBADA` con parámetros concretos y evidencia firmada.

- [ ] **Step 4: Ejecutar GREEN y revisar contradicciones**

Run: `powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Docs.ps1`

Expected: `I9 DOCS PASS`.

- [ ] **Step 5: Commit**

```powershell
git add docs/CONSTITUTION.md docs/ARCHITECTURE.md docs/TECNOLOGIA.md docs/DESIGN.md docs/specs/2026-07-29-sg-superapp-spec-i9-programacion-turnos.md docs/plans/2026-07-29-sg-superapp-i9-programacion-turnos-plan.md docs/operations/2026-07-29-i9-catalogo-reglas-programacion.md scripts/dev/Verify-SgSuperAppI9Docs.ps1
git commit -m "docs: authorize S&G I9 shift scheduling"
```

### Task 2: Crear persistencia de maestros, plantillas y reglas

**Files:**
- Create: `db/migrations/009_i9_scheduling.sql`
- Create: `db/seeds/009_i9_scheduling_permissions.sql`
- Create: `db/seeds/010_i9_shift_templates.sql`
- Create: `db/tests/007_i9_scheduling_contract.sql`
- Create: `scripts/dev/Verify-SgSuperAppI9Persistence.ps1`

- [ ] **Step 1: Escribir contrato SQL RED**

El test debe abortar si faltan tablas o secuencias oficiales:

```sql
DO $$
BEGIN
  IF to_regclass('public.clients') IS NULL OR
     to_regclass('public.service_projects') IS NULL OR
     to_regclass('public.shift_templates') IS NULL OR
     to_regclass('public.shift_template_steps') IS NULL OR
     to_regclass('public.position_coverage_rules') IS NULL OR
     to_regclass('public.scheduling_rules') IS NULL OR
     to_regclass('public.employee_availability_exceptions') IS NULL THEN
    RAISE EXCEPTION 'I9 scheduling master tables missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM shift_templates t
    JOIN shift_template_steps s ON s.template_id = t.id
    WHERE t.code = '4X2'
    GROUP BY t.id HAVING string_agg(s.shift_code, ',' ORDER BY s.step_order) = 'D,D,D,D,N,N,X,X'
  ) THEN
    RAISE EXCEPTION 'Official 4X2 sequence missing';
  END IF;
END $$;
```

- [ ] **Step 2: Ejecutar RED contra base limpia**

Run: `powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Persistence.ps1`

Expected: FAIL con `I9 scheduling master tables missing`.

- [ ] **Step 3: Implementar migración 009**

Crear las tablas con claves foráneas y checks. La relación entre puesto y proyecto se agrega como `project_id BIGINT REFERENCES service_projects(id)` en `service_positions`. El núcleo de plantillas debe seguir esta forma:

```sql
CREATE TABLE shift_templates (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(30) NOT NULL,
  name VARCHAR(120) NOT NULL,
  version INTEGER NOT NULL,
  effective_from DATE NOT NULL,
  effective_to DATE,
  mandatory_by_default BOOLEAN NOT NULL DEFAULT TRUE,
  status VARCHAR(20) NOT NULL CHECK (status IN ('ACTIVO','INACTIVO')),
  UNIQUE (code, version),
  CHECK (effective_to IS NULL OR effective_to >= effective_from)
);
CREATE TABLE shift_template_steps (
  id BIGSERIAL PRIMARY KEY,
  template_id BIGINT NOT NULL REFERENCES shift_templates(id) ON DELETE RESTRICT,
  step_order INTEGER NOT NULL CHECK (step_order > 0),
  shift_code VARCHAR(10) NOT NULL CHECK (shift_code IN ('D','N','X')),
  UNIQUE (template_id, step_order)
);
```

`scheduling_rules` almacena `source_level`, `scope_type`, `scope_id`, `severity`, `effective_from`, `effective_to` y `parameters JSONB`; no guardar límites legales como constantes C#.

- [ ] **Step 4: Sembrar permisos y plantillas**

Permisos: `SCHEDULING/VIEW`, `CONFIGURE`, `GENERATE`, `APPROVE_EXCEPTION`, `APPROVE`, `PUBLISH`, `EXPORT`, `AUDIT`. ADMIN recibe todos; OPERACIONES recibe todos salvo configuración global de reglas; TH puede ver y mantener disponibilidad; GERENCIA solo `VIEW` y `EXPORT`.

- [ ] **Step 5: Ejecutar GREEN y regresión I3/I5/I6**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Persistence.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI3Persistence.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI5Persistence.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI6Persistence.ps1
```

Expected: cuatro scripts PASS.

- [ ] **Step 6: Commit**

```powershell
git add db/migrations/009_i9_scheduling.sql db/seeds/009_i9_scheduling_permissions.sql db/seeds/010_i9_shift_templates.sql db/tests/007_i9_scheduling_contract.sql scripts/dev/Verify-SgSuperAppI9Persistence.ps1
git commit -m "feat: add I9 scheduling masters and templates"
```

### Task 3: Implementar proyección determinística de ciclos

**Files:**
- Create: `apps/sg-superapp-api/Domain/SchedulingModels.cs`
- Create: `apps/sg-superapp-api/Services/ShiftCycleProjector.cs`
- Modify: `apps/sg-superapp-api/Program.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9ShiftCycles.ps1`

- [ ] **Step 1: Escribir verificación RED de ciclos**

El script arranca la API, llama `POST /api/portal/scheduling/cycles/project` con secuencia y anclaje, y valida:

```powershell
$body = @{ sequence = @('D','D','D','D','N','N','X','X'); anchorDate = '2026-07-01'; from = '2026-07-01'; to = '2026-07-10'; phaseOffset = 0 } | ConvertTo-Json
$result = Invoke-RestMethod "$base/api/portal/scheduling/cycles/project" -Method Post -Headers $headers -ContentType 'application/json' -Body $body
$actual = ($result.days | ForEach-Object { $_.shiftCode }) -join ','
if ($actual -ne 'D,D,D,D,N,N,X,X,D,D') { throw "4X2 incorrecto: $actual" }
```

- [ ] **Step 2: Ejecutar RED**

Run: `powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9ShiftCycles.ps1`

Expected: HTTP 404.

- [ ] **Step 3: Crear modelos y proyector mínimo**

```csharp
public sealed record ShiftCycleRequest(
    IReadOnlyList<string> Sequence,
    DateOnly AnchorDate,
    DateOnly From,
    DateOnly To,
    int PhaseOffset);

public sealed record ProjectedShiftDay(DateOnly Date, string ShiftCode, int StepIndex);

public sealed class ShiftCycleProjector
{
    public IReadOnlyList<ProjectedShiftDay> Project(ShiftCycleRequest request)
    {
        if (request.Sequence.Count == 0 || request.To < request.From)
            throw new ArgumentException("Secuencia o rango invalido.");
        return Enumerable.Range(0, request.To.DayNumber - request.From.DayNumber + 1)
            .Select(offset => request.From.AddDays(offset))
            .Select(date => {
                var elapsed = date.DayNumber - request.AnchorDate.DayNumber + request.PhaseOffset;
                var index = ((elapsed % request.Sequence.Count) + request.Sequence.Count) % request.Sequence.Count;
                return new ProjectedShiftDay(date, request.Sequence[index], index);
            }).ToArray();
    }
}
```

Registrar `builder.Services.AddSingleton<ShiftCycleProjector>();` y exponer el endpoint solo para ADMIN/OPERACIONES con `SCHEDULING/CONFIGURE`.

- [ ] **Step 4: Ejecutar GREEN y casos de borde**

El script debe validar 2x2, 4x2, 6x1, cambio de mes, offset negativo y rechazo de secuencia vacía.

Expected: `I9 SHIFT CYCLES PASS`.

- [ ] **Step 5: Build y commit**

```powershell
C:\tmp\dotnet6\dotnet.exe build apps/sg-superapp-api/sg-superapp-api.csproj --no-restore
git add apps/sg-superapp-api/Domain/SchedulingModels.cs apps/sg-superapp-api/Services/ShiftCycleProjector.cs apps/sg-superapp-api/Program.cs apps/sg-superapp-api/Endpoints/PortalEndpoints.cs scripts/dev/Verify-SgSuperAppI9ShiftCycles.ps1
git commit -m "feat: add deterministic I9 shift cycle projection"
```

### Task 4: Persistir proyectos, cobertura, reglas y disponibilidad

> Enmienda aprobada por el usuario el 2026-08-11: antes de implementar la API,
> el modelo persistente debe incorporar franja/ambito semanal de cobertura,
> tipo/carácter bloqueante de disponibilidad y requisitos propios del puesto.
> Esta correccion no autoriza reglas normativas ejecutables.

**Files:**
- Modify: `db/migrations/009_i9_scheduling.sql`
- Modify: `db/tests/007_i9_scheduling_contract.sql`
- Modify: `scripts/dev/Verify-SgSuperAppI9Persistence.ps1`
- Create: `apps/sg-superapp-api/Contracts/Portal/SchedulingContracts.cs`
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
- Modify: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9Configuration.ps1`

- [x] **Step 1: Escribir pruebas RED del modelo persistente corregido**

El contrato SQL debe exigir `weekday_scope`, `starts_at` y `ends_at` en
`position_coverage_rules`; `kind` y `blocking` en
`employee_availability_exceptions`; y una tabla `position_requirements` que
relacione puesto y tipo de requisito con severidad y fecha opcional de
subsanacion. La migracion debe converger instalaciones parciales con las mismas
garantias de tipos, secuencias, claves y checks ya aprobadas para Task 2.

- [x] **Step 2: Ejecutar RED persistente y luego GREEN**

Expected RED: faltan columnas y tabla del modelo corregido. Expected GREEN:
verificador hermetico I9, doble ejecucion y regresiones I3/I5 pasan.

- [x] **Step 3: Escribir pruebas RED de configuración**

Validar CRUD de cliente/proyecto, asociación de puesto, cobertura por franja, clasificación de requisito y disponibilidad excepcional; debe rechazarse cobertura fuera de vigencia y requisito sin severidad válida.

- [x] **Step 4: Ejecutar RED de API**

Expected: endpoints `/api/portal/scheduling/projects` retornan 404.

- [x] **Step 5: Implementar contratos explícitos**

```csharp
public sealed record UpsertSchedulingProjectRequest(long ClientId, string Code, string Name, string EffectiveFrom, string? EffectiveTo, string Status);
public sealed record UpsertCoverageRuleRequest(long PositionId, long TemplateId, string WeekdayScope, string StartsAt, string EndsAt, int RequiredGuards);
public sealed record UpsertAvailabilityExceptionRequest(long EmployeeId, string From, string To, string Kind, bool Blocking, string Reason);
public sealed record UpsertPositionRequirementRequest(long PositionId, long RequirementTypeId, string Severity, string? ResolutionDueDate);
```

Los endpoints usan `DateOnly.TryParse`, `TimeOnly.TryParse`, checks de `ACTIVO/INACTIVO` y severidades `BLOQUEANTE/SUBSANABLE/INFORMATIVA` antes de llamar al repositorio.

- [x] **Step 6: Implementar transacciones y auditoría**

Cada escritura llama `InsertAuditLogAsync` dentro de la misma transacción con eventos `SCHEDULING_PROJECT_*`, `COVERAGE_RULE_*`, `AVAILABILITY_*` o `POSITION_REQUIREMENT_*`.

- [x] **Step 7: Ejecutar GREEN, seguridad y build**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Configuration.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI3Security.ps1
C:\tmp\dotnet6\dotnet.exe build apps/sg-superapp-api/sg-superapp-api.csproj --no-restore
```

Expected: PASS y build sin errores.

- [x] **Step 8: Commit**

```powershell
git add apps/sg-superapp-api/Contracts/Portal/SchedulingContracts.cs apps/sg-superapp-api/Services/PostgresPortalRepository.cs apps/sg-superapp-api/Endpoints/PortalEndpoints.cs scripts/dev/Verify-SgSuperAppI9Configuration.ps1
git commit -m "feat: add I9 project coverage configuration"
```

### Task 5: Implementar elegibilidad y explicación de restricciones

**Files:**
- Modify: `apps/sg-superapp-api/Domain/SchedulingModels.cs`
- Create: `apps/sg-superapp-api/Services/SchedulingEligibilityService.cs`
- Modify: `apps/sg-superapp-api/Program.cs`
- Modify: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9Eligibility.ps1`

- [x] **Step 1: Escribir matriz RED**

El script envía candidatos con: activo, retirado, incapacidad, cruce, descanso insuficiente, requisito vencido bloqueante, subsanable e informativo. Debe comprobar `Eligible`, `RequiresException` y códigos de razón estables.

- [x] **Step 2: Ejecutar RED**

Expected: servicio/endpoint ausente.

- [x] **Step 3: Implementar evaluación pura y ordenada**

```csharp
public sealed record EligibilityReason(string Code, string Severity, string Message);
public sealed record EligibilityResult(bool Eligible, bool RequiresException, IReadOnlyList<EligibilityReason> Reasons);

public EligibilityResult Evaluate(GuardSchedulingFacts facts)
{
    var reasons = new List<EligibilityReason>();
    if (!facts.Active) reasons.Add(new("EMPLOYEE_INACTIVE", "BLOCKING", "Guarda inactivo."));
    if (facts.HasBlockingAbsence) reasons.Add(new("BLOCKING_ABSENCE", "BLOCKING", "Novedad bloqueante vigente."));
    if (facts.HasOverlap) reasons.Add(new("SHIFT_OVERLAP", "BLOCKING", "Cruce con otro turno."));
    if (!facts.RestRuleSatisfied) reasons.Add(new("MINIMUM_REST", "BLOCKING", "Descanso minimo incumplido."));
    reasons.AddRange(facts.RequirementReasons);
    var blocked = reasons.Any(x => x.Severity == "BLOCKING");
    var exception = reasons.Any(x => x.Severity == "SUBSANABLE");
    return new EligibilityResult(!blocked, exception, reasons);
}
```

La ubicación produce razón bloqueante solo cuando la regla versionada lo determine; no codificar distancias fijas.

- [x] **Step 4: Ejecutar GREEN y determinismo**

Ejecutar dos veces el mismo payload y comparar JSON normalizado.

Expected: `I9 ELIGIBILITY PASS`.

- [x] **Step 5: Build y commit**

```powershell
C:\tmp\dotnet6\dotnet.exe build apps/sg-superapp-api/sg-superapp-api.csproj --no-restore
git add apps/sg-superapp-api/Domain/SchedulingModels.cs apps/sg-superapp-api/Services/SchedulingEligibilityService.cs apps/sg-superapp-api/Program.cs scripts/dev/Verify-SgSuperAppI9Eligibility.ps1
git commit -m "feat: add explainable I9 eligibility rules"
```

### Task 6: Crear persistencia de propuestas, versiones y excepciones

**Files:**
- Create: `db/migrations/010_i9_schedule_versions.sql`
- Modify: `db/tests/007_i9_scheduling_contract.sql`
- Modify: `scripts/dev/Verify-SgSuperAppI9Persistence.ps1`

- [ ] **Step 1: Extender RED con invariantes de versión**

Verificar tablas `schedules`, `schedule_versions`, `required_shifts`, `schedule_assignments`, `schedule_exceptions`, `schedule_generation_runs`; índice único para una sola versión `PUBLICADA` por proyecto/periodo; trigger que impida UPDATE/DELETE de versión publicada y sus asignaciones.

- [ ] **Step 2: Ejecutar RED**

Expected: FAIL `I9 schedule version tables missing`.

- [ ] **Step 3: Implementar migración**

Estados:

```sql
CHECK (status IN ('BORRADOR','PROPUESTA','APROBADA','PUBLICADA','REEMPLAZADA','CANCELADA'))
```

`schedule_versions` almacena `source_snapshot JSONB`, `rules_snapshot JSONB`, `parameters_snapshot JSONB`, `coverage_percent`, `vacancy_count`, `exception_count`, `created_by`, `approved_by`, `published_by` y timestamps. `schedule_assignments` permite `employee_id NULL` únicamente cuando `status = 'VACANTE'`.

- [ ] **Step 4: Ejecutar GREEN y prueba de inmutabilidad**

El script publica una versión e intenta modificar una asignación; espera SQLSTATE `55000` o mensaje `published schedule version is immutable`.

- [ ] **Step 5: Commit**

```powershell
git add db/migrations/010_i9_schedule_versions.sql db/tests/007_i9_scheduling_contract.sql scripts/dev/Verify-SgSuperAppI9Persistence.ps1
git commit -m "feat: add immutable I9 schedule versions"
```

### Task 7: Implementar motor heurístico determinístico

**Files:**
- Create: `apps/sg-superapp-api/Services/SchedulingRecommendationEngine.cs`
- Modify: `apps/sg-superapp-api/Domain/SchedulingModels.cs`
- Modify: `apps/sg-superapp-api/Program.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9Recommendations.ps1`

- [ ] **Step 1: Escribir RED con dataset fijo**

Dataset: dos puestos, seis turnos, cuatro guardas; uno bloqueado, uno subsanable, uno habitual y uno relevo. Esperar seis resultados, cinco cubiertos, una vacante visible y explicación del ranking.

- [ ] **Step 2: Ejecutar RED**

Expected: HTTP 404 o servicio ausente.

- [ ] **Step 3: Implementar score y desempate estable**

```csharp
private static decimal Score(EligibleCandidate c, SchedulingWeights w) =>
    c.Continuity * w.Continuity +
    c.Equity * w.Equity -
    c.AdditionalHours * w.AdditionalHoursPenalty -
    c.DistancePenalty * w.DistancePenalty -
    (c.RequiresException ? w.ExceptionPenalty : 0m) -
    c.PublishedScheduleChange * w.StabilityPenalty;

var selected = candidates
    .Where(x => x.Eligibility.Eligible)
    .OrderByDescending(x => Score(x, weights))
    .ThenBy(x => x.EmployeeId)
    .FirstOrDefault();
```

Procesar turnos por fecha, inicio, puesto e id. Actualizar hechos acumulados después de cada asignación. Si no hay candidato elegible, crear `VACANTE` con todas las razones agregadas; nunca elegir un bloqueado.

- [ ] **Step 4: Persistir corrida y snapshots**

El repositorio crea `schedule_generation_runs` en `EN_COLA`, pasa a `PROCESANDO` y termina `COMPLETADO`, `COMPLETADO_CON_VACANTES` o `FALLIDO`. El reintento con la misma `idempotency_key` retorna la corrida existente.

- [ ] **Step 5: Ejecutar GREEN, repetibilidad y build**

Run el script dos veces; comparar orden, scores y asignaciones.

Expected: `I9 RECOMMENDATIONS PASS`; build limpio.

- [ ] **Step 6: Commit**

```powershell
git add apps/sg-superapp-api/Services/SchedulingRecommendationEngine.cs apps/sg-superapp-api/Domain/SchedulingModels.cs apps/sg-superapp-api/Services/PostgresPortalRepository.cs apps/sg-superapp-api/Program.cs scripts/dev/Verify-SgSuperAppI9Recommendations.ps1
git commit -m "feat: add deterministic I9 recommendation engine"
```

### Task 8: Exponer workflow, permisos y auditoría

**Files:**
- Modify: `apps/sg-superapp-api/Contracts/Portal/SchedulingContracts.cs`
- Modify: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9Workflow.ps1`
- Create: `scripts/dev/Verify-SgSuperAppI9Security.ps1`

- [ ] **Step 1: Escribir RED de transición de estados**

Validar: generar `PROPUESTA`; ajuste manual revalida; excepción subsanable exige motivo/responsable/fecha; aprobar; publicar; publicación reemplaza versión anterior; una vacante aceptada queda en snapshot.

- [ ] **Step 2: Escribir RED de permisos**

ADMIN ejecuta todo; OPERACIONES según permisos; TH no aprueba/publica; GERENCIA no muta; sesión ausente recibe 401. Intentar llamar endpoints directamente, no solo ocultar botones.

- [ ] **Step 3: Ejecutar RED**

Expected: 404 en workflow I9.

- [ ] **Step 4: Implementar endpoints**

```text
POST /api/portal/scheduling/projects/{projectId}/proposals
GET  /api/portal/scheduling/projects/{projectId}/schedules/{period}
GET  /api/portal/scheduling/proposals/{versionId}
PUT  /api/portal/scheduling/proposals/{versionId}/assignments/{assignmentId}
POST /api/portal/scheduling/proposals/{versionId}/exceptions
POST /api/portal/scheduling/proposals/{versionId}/approve
POST /api/portal/scheduling/proposals/{versionId}/publish
GET  /api/portal/scheduling/versions/{versionId}/audit
```

Cada mutación usa transacción, valida versión esperada y escribe `audit_log`. Si `created_by = approved_by = published_by`, agregar `selfManaged: true` al detalle de publicación.

- [ ] **Step 5: Ejecutar GREEN, regresión I6/I7 y build**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Workflow.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Security.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI7Audit.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI6Security.ps1
C:\tmp\dotnet6\dotnet.exe build apps/sg-superapp-api/sg-superapp-api.csproj --no-restore
```

- [ ] **Step 6: Commit**

```powershell
git add apps/sg-superapp-api/Contracts/Portal/SchedulingContracts.cs apps/sg-superapp-api/Endpoints/PortalEndpoints.cs apps/sg-superapp-api/Services/PostgresPortalRepository.cs scripts/dev/Verify-SgSuperAppI9Workflow.ps1 scripts/dev/Verify-SgSuperAppI9Security.ps1
git commit -m "feat: add I9 approval and publication workflow"
```

### Task 9: Integrar novedades, alternativas y notificaciones

**Files:**
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
- Modify: `apps/sg-superapp-api/Services/SchedulingRecommendationEngine.cs`
- Modify: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- Modify: `db/migrations/008_i6_notifications.sql` via new migration `db/migrations/011_i9_scheduling_notifications.sql`
- Create: `scripts/dev/Verify-SgSuperAppI9Replanning.ps1`

- [ ] **Step 1: Escribir RED de reprogramación**

Publicar calendario, insertar incapacidad y pedir dos escenarios. `MINIMUM_IMPACT` solo cambia turnos afectados; `GLOBAL` puede cambiar más turnos y debe informar `changedAssignments`, `additionalHours`, `vacancies`, `exceptions`.

- [ ] **Step 2: Ejecutar RED**

Expected: endpoint ausente.

- [ ] **Step 3: Implementar escenarios y avisos**

Agregar endpoint:

```text
POST /api/portal/scheduling/versions/{versionId}/replan
```

Request: `{ "triggerType":"ABSENCE", "triggerId":"...", "modes":["MINIMUM_IMPACT","GLOBAL"] }`.

Ampliar `notification_items.source_module` con `SCHEDULING` mediante migración nueva. Crear notificaciones deduplicadas para vacante crítica, excepción próxima a vencer, propuesta pendiente y novedad sobre programación publicada.

- [ ] **Step 4: Ejecutar GREEN y regresión de notificaciones**

Run I9 Replanning + I6 Inbox + I6 NotificationActions.

Expected: todos PASS.

- [ ] **Step 5: Commit**

```powershell
git add db/migrations/011_i9_scheduling_notifications.sql apps/sg-superapp-api/Services/PostgresPortalRepository.cs apps/sg-superapp-api/Services/SchedulingRecommendationEngine.cs apps/sg-superapp-api/Endpoints/PortalEndpoints.cs scripts/dev/Verify-SgSuperAppI9Replanning.ps1
git commit -m "feat: add I9 replanning and notifications"
```

### Task 10: Exportar versiones a PDF y Excel

**Files:**
- Create: `apps/sg-superapp-api/Services/SchedulingExportService.cs`
- Modify: `apps/sg-superapp-api/Program.cs`
- Modify: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- Create: `scripts/dev/Verify-SgSuperAppI9Exports.ps1`

- [ ] **Step 1: Escribir RED por formato y alcance**

Solicitar exportación por proyecto, puesto y guarda. Validar magic bytes `%PDF-` y `PK`, nombres de archivo, periodo, estado, versión y actor. TH/GERENCIA solo exportan proyectos visibles.

- [ ] **Step 2: Ejecutar RED**

Expected: 404.

- [ ] **Step 3: Implementar exportador desacoplado**

```csharp
public interface ISchedulingExportService
{
    byte[] BuildPdf(ScheduleExportModel model);
    byte[] BuildXlsx(ScheduleExportModel model);
}
```

Reutilizar la técnica PDF interna de certificados, moviendo la construcción genérica a un helper privado del nuevo servicio; usar `SpreadsheetDocument.Create` para XLSX. Encabezado obligatorio: cliente, proyecto, periodo, versión, estado, fecha de generación y responsable. Ningún export lee datos fuera del snapshot publicado.

- [ ] **Step 4: Exponer endpoints y auditar**

```text
GET /api/portal/scheduling/versions/{versionId}/export.pdf?positionId=&employeeId=
GET /api/portal/scheduling/versions/{versionId}/export.xlsx?positionId=&employeeId=
```

Registrar `SCHEDULE_EXPORTED` con formato y filtros.

- [ ] **Step 5: Ejecutar GREEN y abrir archivos**

El script guarda en `.codex-tmp/i9-exports`, abre XLSX con Open XML y valida PDF con encabezado/trailer.

Expected: `I9 EXPORTS PASS`.

- [ ] **Step 6: Commit**

```powershell
git add apps/sg-superapp-api/Services/SchedulingExportService.cs apps/sg-superapp-api/Program.cs apps/sg-superapp-api/Endpoints/PortalEndpoints.cs scripts/dev/Verify-SgSuperAppI9Exports.ps1
git commit -m "feat: export I9 schedules to PDF and Excel"
```

### Task 11: Añadir contratos y cliente frontend

**Files:**
- Modify: `apps/sg-superapp-web/src/types/portal.ts`
- Modify: `apps/sg-superapp-web/src/services/portalApi.ts`
- Modify: `apps/sg-superapp-web/src/mock/session.ts`
- Create: `scripts/dev/Verify-SgSuperAppI9FrontendApi.ps1`

- [ ] **Step 1: Escribir RED estático/compilación**

Exigir tipos `ShiftTemplate`, `SchedulingProject`, `ScheduleProposal`, `ScheduleAssignment`, `ScheduleException`, `ScheduleComparison`, `SchedulingCapabilities` y funciones API para capacidades, configuración, generación, consulta, ajuste, excepción, aprobación, publicación, replan y exportación.

- [ ] **Step 2: Ejecutar RED**

Expected: FAIL por símbolos ausentes.

- [ ] **Step 3: Añadir tipos discriminados**

```typescript
export type ScheduleStatus = "BORRADOR" | "PROPUESTA" | "APROBADA" | "PUBLICADA" | "REEMPLAZADA" | "CANCELADA";
export type ShiftCode = "D" | "N" | "X";
export type RequirementSeverity = "BLOQUEANTE" | "SUBSANABLE" | "INFORMATIVA";
export interface ScheduleAssignment {
  id: number; date: string; startsAt: string; endsAt: string;
  positionId: number; employeeId?: number; shiftCode: ShiftCode;
  status: "ASIGNADA" | "VACANTE"; score?: number;
  reasons: Array<{ code: string; severity: string; message: string }>;
}
export interface SchedulingCapabilities {
  view: boolean; configure: boolean; generate: boolean;
  approveException: boolean; approve: boolean; publish: boolean; export: boolean;
}
```

- [ ] **Step 4: Añadir cliente API con manejo uniforme de errores**

Funciones `fetchSchedulingCapabilities`, `fetchSchedulingProjects`, `fetchShiftTemplates`, `generateScheduleProposal`, `fetchScheduleProposal`, `updateScheduleAssignment`, `approveScheduleException`, `approveSchedule`, `publishSchedule`, `replanSchedule`, `downloadSchedulePdf`, `downloadScheduleXlsx` deben usar `getSessionHeaders()` y propagar `data.message`. El backend expone `GET /api/portal/scheduling/capabilities` calculando cada acción con `HasPermissionAsync`; la UI no infiere permisos únicamente desde el rol.

- [ ] **Step 5: Ejecutar GREEN y build**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9FrontendApi.ps1
node "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build --prefix apps/sg-superapp-web
```

Expected: PASS y build Vite correcto.

- [ ] **Step 6: Commit**

```powershell
git add apps/sg-superapp-web/src/types/portal.ts apps/sg-superapp-web/src/services/portalApi.ts apps/sg-superapp-web/src/mock/session.ts scripts/dev/Verify-SgSuperAppI9FrontendApi.ps1
git commit -m "feat: add I9 frontend scheduling contracts"
```

### Task 12: Construir UI de configuración, matriz y comparación

**Files:**
- Create: `apps/sg-superapp-web/src/features/scheduling/SchedulingPage.tsx`
- Create: `apps/sg-superapp-web/src/features/scheduling/ShiftTemplatesPanel.tsx`
- Create: `apps/sg-superapp-web/src/features/scheduling/ScheduleMatrix.tsx`
- Create: `apps/sg-superapp-web/src/features/scheduling/ProposalComparison.tsx`
- Create: `apps/sg-superapp-web/src/features/scheduling/ExceptionPanel.tsx`
- Modify: `apps/sg-superapp-web/src/features/shell/ModuleWorkspace.tsx`
- Modify: `apps/sg-superapp-web/src/styles.css`
- Create: `scripts/dev/Verify-SgSuperAppI9Ui.ps1`

- [ ] **Step 1: Escribir RED de estructura UI**

Verificar ruta `scheduling`, estados loading/error/empty, selector proyecto/periodo, pantalla de plantillas, matriz con D/N/X/VACANTE, detalle explicable, comparación, excepciones, aprobación y exportación. Exigir `aria-label` en matriz, filtros y acciones.

- [ ] **Step 2: Ejecutar RED**

Expected: FAIL por directorio/ruta ausente.

- [ ] **Step 3: Implementar página coordinadora**

`SchedulingPage` mantiene solo estado de navegación y datos; cada componente recibe props tipadas. La matriz usa tabla semántica, encabezado sticky, botón por celda y panel lateral; no agregar librería de grid.

```tsx
if (loading) return <div className="panel-empty">Cargando programación...</div>;
if (error) return <div className="panel-empty error-state">{error}</div>;
if (!proposal) return <div className="panel-empty">Selecciona proyecto y periodo para generar una propuesta.</div>;
return <ScheduleMatrix proposal={proposal} selectedAssignmentId={selectedId} onSelect={setSelectedId} />;
```

- [ ] **Step 4: Implementar permisos y acciones**

Mostrar acciones solo cuando `SchedulingCapabilities` las permita, pero mantener la seguridad real en API. Al ajustar una celda, abrir alternativas con razones; una desviación de plantilla exige formulario con motivo. Después de publicar, deshabilitar edición y ofrecer crear nueva versión.

- [ ] **Step 5: Aplicar diseño Sentinel Enterprise y responsive**

Reutilizar tokens `#003366` y `#FFC700`; matriz con scroll horizontal, contraste accesible y leyenda textual además del color. En viewport menor a 900px, priorizar filtros, lista diaria y detalle; no intentar comprimir 31 columnas.

- [ ] **Step 6: Ejecutar GREEN, build y recorrido manual**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Ui.ps1
node "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build --prefix apps/sg-superapp-web
```

Expected: PASS. Recorrer panel, configuración, matriz, comparación y publicación contra API y mock fallback.

- [ ] **Step 7: Commit**

```powershell
git add apps/sg-superapp-web/src/features/scheduling apps/sg-superapp-web/src/features/shell/ModuleWorkspace.tsx apps/sg-superapp-web/src/styles.css scripts/dev/Verify-SgSuperAppI9Ui.ps1
git commit -m "feat: add I9 scheduling workspace"
```

### Task 13: Cierre integral, piloto y documentación de retake

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/2026-07-29-sg-superapp-i9-programacion-turnos-plan.md`
- Create: `docs/demo/2026-07-29-sg-superapp-i9-demo-checklist.md`
- Create: `docs/reports/2026-07-29-sg-superapp-i9-pilot-baseline.md`
- Create: `docs/handoff/handoff-20260729-i9-mvp-closed.md`

- [ ] **Step 1: Ejecutar suite I9 completa**

```powershell
Get-ChildItem scripts/dev/Verify-SgSuperAppI9*.ps1 | Sort-Object Name | ForEach-Object { & $_.FullName }
```

Expected: todos los scripts muestran PASS.

- [ ] **Step 2: Ejecutar regresión crítica y builds**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI3Security.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI5ServiceEnablement.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI6Inbox.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI7Audit.ps1
C:\tmp\dotnet6\dotnet.exe build apps/sg-superapp-api/sg-superapp-api.csproj --no-restore
node "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build --prefix apps/sg-superapp-web
```

Expected: regresión y builds correctos.

- [ ] **Step 3: Ejecutar piloto histórico anonimizado**

Registrar en el baseline: cobertura, tiempo de generación, cambios manuales, vacantes, excepciones, horas adicionales estimadas, distribución de noches/domingos/festivos y desviaciones de plantilla. Comparar propuesta A con programación histórica sin publicar datos personales.

- [ ] **Step 4: Actualizar docs y handoff**

Marcar tareas cerradas con evidencia exacta, riesgos residuales y retake. La optimización avanzada solo se autoriza si el baseline demuestra que la heurística no alcanza cobertura/calidad acordada.

- [ ] **Step 5: Actualizar grafo**

Run: `graphify update .`

Expected: actualización AST completa; si la herramienta no está disponible, registrar la limitación exacta en el execution log sin declarar éxito.

- [ ] **Step 6: Commit final de cierre**

```powershell
git add README.md docs/plans/2026-07-29-sg-superapp-i9-programacion-turnos-plan.md docs/demo/2026-07-29-sg-superapp-i9-demo-checklist.md docs/reports/2026-07-29-sg-superapp-i9-pilot-baseline.md docs/handoff/handoff-20260729-i9-mvp-closed.md graphify-out
git commit -m "docs: close S&G I9 scheduling MVP"
```

---

## Gates de ejecución

| Gate | Condición de salida |
|---|---|
| Gate 0 | Autoridad documental y catálogo jurídico-operativo aprobados |
| Gate 1 | Persistencia, plantillas y configuración validadas |
| Gate 2 | Ciclos, elegibilidad y motor determinístico validados |
| Gate 3 | Workflow, seguridad, auditoría y reprogramación validados |
| Gate 4 | Exportaciones y UI integradas |
| Gate 5 | Suite integral, piloto anonimizado y handoff cerrados |

## Orden obligatorio

No iniciar Task 2 antes de cerrar Task 1. No iniciar generación heurística antes de tener reglas ejecutables aprobadas. No exponer publicación en UI antes de verificar inmutabilidad, permisos y auditoría en backend. No iniciar optimización avanzada dentro de este plan.
