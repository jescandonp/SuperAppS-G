# Puestos de Servicio — UX (paginación, modales, gestión de asignación) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Llevar el módulo de Puestos de Servicio (`PositionsPage.tsx`) al mismo estándar de UX ya aprobado para Empleados — listado paginado, formulario crear/editar movido a un `Modal`, y una capacidad nueva (gestionar asignaciones de empleados desde el lado de Puestos, hoy solo posible desde Empleados).

**Architecture:** Paginación aditiva en `GET /api/portal/positions` (mismo patrón ya usado por `GET /api/portal/employees`, sin romper al único otro consumidor). Dos modales nuevos en `PositionsPage.tsx` reutilizando el primitivo `Modal` y las funciones `createPositionAssignment`/`finalizePositionAssignment` de `portalApi.ts` que hoy solo usa `EmployeesPage.tsx` — sin componente compartido nuevo (ver spec sección 8, decisión YAGNI). `PositionAssignment` gana el nombre del empleado (join con `employees`), necesario para que el botón "Finalizar" sea usable.

**Tech Stack:** .NET 6 (backend existente), React 18 + TypeScript (frontend existente), PostgreSQL (sin migración de esquema).

**Spec:** `docs/superpowers/specs/2026-09-14-sg-puestos-ux-paginacion-modales-design.md`

## Global Constraints

- Ningún cambio a `role_permissions` ni a los campos editables del puesto (spec sección 9).
- No se extrae un componente de asignación compartido con Empleados — lógica local en `PositionsPage.tsx` (spec sección 8).
- `GET /api/portal/positions` sin `page`/`pageSize` debe seguir devolviendo el arreglo completo, sin límite — `EmployeesPage.tsx:182` lo consume así y no debe romperse.
- `dotnet` no está en el PATH: usar `C:\tmp\dotnet6\dotnet.exe` con `$env:DOTNET_CLI_HOME = "C:\tmp\dotnet-home"`.
- La ruta del repo tiene un `&` literal (`...\ProyectoS&G\...`): usar siempre rutas completas entre comillas.
- Credenciales de prueba: `admin.sg`/`Admin123` (ADMIN), `th.sg`/`Th123456` (TH, es quien tiene `POSITIONS/MANAGE` y `POSITION_ASSIGNMENTS/MANAGE`).

---

## Task 1: `PositionAssignment` gana el nombre del empleado (backend + tipos)

**Files:**
- Modify: `apps/sg-superapp-api/Contracts/Portal/PositionAssignmentResponse.cs`
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:2627-2648` (`GetEmployeePositionAssignmentsAsync`)
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:2665-2689` (`GetPositionAssignmentsAsync`)
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:2706-2727` (`GetPositionAssignmentByIdAsync`)
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:5328-5345` (`ReadPositionAssignment`)
- Modify: `apps/sg-superapp-web/src/types/portal.ts:366-381` (`PositionAssignment`)

**Interfaces:**
- Produces: `PositionAssignmentResponse` con `EmployeeFullName` (`string`) y `EmployeeIdentificationNumber` (`string`) insertados justo después de `EmployeeId` — usado por Task 7.
- Produces: `PositionAssignment` (TS) con `employeeFullName: string` y `employeeIdentificationNumber: string` en la misma posición — usado por Task 7.

- [ ] **Step 1: Contrato backend**

```csharp
// apps/sg-superapp-api/Contracts/Portal/PositionAssignmentResponse.cs
namespace Sg.SuperApp.Api.Contracts.Portal;

public sealed record PositionAssignmentResponse(
    long Id,
    long EmployeeId,
    string EmployeeFullName,
    string EmployeeIdentificationNumber,
    long PositionId,
    string PositionName,
    string? PositionCode,
    string? ClientText,
    string StartDate,
    string? EndDate,
    string Status,
    string? ChangeReason,
    string? Notes,
    string? CreatedBy,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
```

- [ ] **Step 2: Las 3 consultas SQL — agregar join y columnas**

En `PostgresPortalRepository.cs`, reemplazar el `sql` de `GetEmployeePositionAssignmentsAsync` (líneas 2629-2648) por:

```csharp
        const string sql = @"
            select
                epa.id,
                epa.employee_id,
                e.full_name as employee_full_name,
                e.identification_number as employee_identification_number,
                epa.position_id,
                sp.name as position_name,
                sp.code as position_code,
                sp.client_text,
                epa.start_date,
                epa.end_date,
                epa.status,
                epa.change_reason,
                epa.notes,
                epa.created_by,
                epa.created_at,
                epa.updated_at
            from employee_position_assignments epa
            join service_positions sp on sp.id = epa.position_id
            join employees e on e.id = epa.employee_id
            where epa.employee_id = @employeeId
            order by epa.start_date desc, epa.id desc;";
```

El `sql` de `GetPositionAssignmentsAsync` (líneas 2667-2689) queda:

```csharp
        const string sql = @"
            select
                epa.id,
                epa.employee_id,
                e.full_name as employee_full_name,
                e.identification_number as employee_identification_number,
                epa.position_id,
                sp.name as position_name,
                sp.code as position_code,
                sp.client_text,
                epa.start_date,
                epa.end_date,
                epa.status,
                epa.change_reason,
                epa.notes,
                epa.created_by,
                epa.created_at,
                epa.updated_at
            from employee_position_assignments epa
            join service_positions sp on sp.id = epa.position_id
            join employees e on e.id = epa.employee_id
            where epa.position_id = @positionId
            order by
                case when epa.status = 'VIGENTE' then 0 else 1 end,
                epa.start_date desc,
                epa.id desc;";
```

El `sql` de `GetPositionAssignmentByIdAsync` (líneas 2708-2727) queda:

```csharp
        const string sql = @"
            select
                epa.id,
                epa.employee_id,
                e.full_name as employee_full_name,
                e.identification_number as employee_identification_number,
                epa.position_id,
                sp.name as position_name,
                sp.code as position_code,
                sp.client_text,
                epa.start_date,
                epa.end_date,
                epa.status,
                epa.change_reason,
                epa.notes,
                epa.created_by,
                epa.created_at,
                epa.updated_at
            from employee_position_assignments epa
            join service_positions sp on sp.id = epa.position_id
            join employees e on e.id = epa.employee_id
            where epa.id = @assignmentId
            limit 1;";
```

Ninguna de las tres cambia sus parámetros (`@employeeId`, `@positionId`, `@assignmentId`) ni el resto del método — solo el texto del `sql`.

- [ ] **Step 3: `ReadPositionAssignment` — leer las 2 columnas nuevas**

Reemplazar el método completo (líneas 5328-5345) por:

```csharp
    private static PositionAssignmentResponse ReadPositionAssignment(NpgsqlDataReader reader)
    {
        return new PositionAssignmentResponse(
            reader.GetInt64(reader.GetOrdinal("id")),
            reader.GetInt64(reader.GetOrdinal("employee_id")),
            reader.GetString(reader.GetOrdinal("employee_full_name")),
            reader.GetString(reader.GetOrdinal("employee_identification_number")),
            reader.GetInt64(reader.GetOrdinal("position_id")),
            reader.GetString(reader.GetOrdinal("position_name")),
            reader.IsDBNull(reader.GetOrdinal("position_code")) ? null : reader.GetString(reader.GetOrdinal("position_code")),
            reader.IsDBNull(reader.GetOrdinal("client_text")) ? null : reader.GetString(reader.GetOrdinal("client_text")),
            reader.GetDateTime(reader.GetOrdinal("start_date")).ToString("yyyy-MM-dd"),
            reader.IsDBNull(reader.GetOrdinal("end_date")) ? null : reader.GetDateTime(reader.GetOrdinal("end_date")).ToString("yyyy-MM-dd"),
            reader.GetString(reader.GetOrdinal("status")),
            reader.IsDBNull(reader.GetOrdinal("change_reason")) ? null : reader.GetString(reader.GetOrdinal("change_reason")),
            reader.IsDBNull(reader.GetOrdinal("notes")) ? null : reader.GetString(reader.GetOrdinal("notes")),
            reader.IsDBNull(reader.GetOrdinal("created_by")) ? null : reader.GetString(reader.GetOrdinal("created_by")),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("created_at"))),
            new DateTimeOffset(reader.GetFieldValue<DateTime>(reader.GetOrdinal("updated_at"))));
    }
```

- [ ] **Step 4: Tipo TypeScript**

```typescript
// apps/sg-superapp-web/src/types/portal.ts:366-381
export interface PositionAssignment {
  id: number;
  employeeId: number;
  employeeFullName: string;
  employeeIdentificationNumber: string;
  positionId: number;
  positionName: string;
  positionCode: string | null;
  clientText: string | null;
  startDate: string;
  endDate: string | null;
  status: PositionAssignmentStatus;
  changeReason: string | null;
  notes: string | null;
  createdBy: string | null;
  createdAt: string;
  updatedAt: string;
}
```

- [ ] **Step 5: Compilar backend y frontend**

```bash
"C:\tmp\dotnet6\dotnet.exe" build apps/sg-superapp-api/sg-superapp-api.csproj
```

Expected: `Compilación correcta.` 0 errores.

```bash
cd apps/sg-superapp-web && node "./node_modules/typescript/bin/tsc" -b .
```

Expected: sin salida (compilación limpia). `EmployeesPage.tsx` no debería fallar — no lee esos campos hoy, pero `PositionAssignment` sigue siendo un supertipo compatible (agregar campos no rompe un consumidor que no los usa).

- [ ] **Step 6: Commit**

```bash
git add apps/sg-superapp-api/Contracts/Portal/PositionAssignmentResponse.cs apps/sg-superapp-api/Services/PostgresPortalRepository.cs apps/sg-superapp-web/src/types/portal.ts
git commit -m "feat(puestos): agregar nombre de empleado a PositionAssignment"
```

---

## Task 2: Backend — paginación aditiva en `GET /api/portal/positions`

**Files:**
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:1199-1237` (`GetServicePositionsAsync`)
- Modify: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs:714-735` (endpoint `GET /api/portal/positions`)

**Interfaces:**
- Consumes: ninguna de tareas anteriores.
- Produces: `GetServicePositionsAsync(string? search, string? status, int page, int pageSize, CancellationToken) : Task<(IReadOnlyList<ServicePositionResponse> Items, int TotalCount)>` — reemplaza la firma anterior (sin `page`/`pageSize`, retorno no-tupla). Usada por Task 3 indirectamente (vía el endpoint HTTP, no se llama desde el frontend directamente).

- [ ] **Step 1: Reescribir `GetServicePositionsAsync`**

Reemplazar el método completo (líneas 1199-1237) por:

```csharp
    public async Task<(IReadOnlyList<ServicePositionResponse> Items, int TotalCount)> GetServicePositionsAsync(string? search, string? status, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        const string countSql = @"
            select count(*)
            from service_positions sp
            where (@search is null
                or sp.name ilike '%' || @search || '%'
                or sp.code ilike '%' || @search || '%'
                or sp.client_text ilike '%' || @search || '%')
              and (@status is null or sp.status = @status);";

        const string sql = @"
            select
                sp.id,
                sp.code,
                sp.name,
                sp.client_text,
                sp.location_text,
                sp.status,
                sp.notes,
                sp.created_at,
                sp.updated_at,
                count(epa.id) filter (where epa.status = 'VIGENTE')::int as active_assignments_count
            from service_positions sp
            left join employee_position_assignments epa on epa.position_id = sp.id
            where (@search is null
                or sp.name ilike '%' || @search || '%'
                or sp.code ilike '%' || @search || '%'
                or sp.client_text ilike '%' || @search || '%')
              and (@status is null or sp.status = @status)
            group by sp.id
            order by sp.name
            limit @pageSize offset @offset;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var countCommand = new NpgsqlCommand(countSql, connection);
        countCommand.Parameters.Add("search", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        countCommand.Parameters.Add("status", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(status) ? DBNull.Value : status.Trim().ToUpperInvariant();
        var totalCount = Convert.ToInt32(await countCommand.ExecuteScalarAsync(cancellationToken));

        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add("search", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        command.Parameters.Add("status", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(status) ? DBNull.Value : status.Trim().ToUpperInvariant();
        command.Parameters.Add("pageSize", NpgsqlDbType.Integer).Value = pageSize;
        command.Parameters.Add("offset", NpgsqlDbType.Integer).Value = (page - 1) * pageSize;

        var positions = new List<ServicePositionResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            positions.Add(ReadServicePosition(reader));
        }

        return (positions, totalCount);
    }
```

- [ ] **Step 2: Compilar para confirmar el error esperado**

```bash
"C:\tmp\dotnet6\dotnet.exe" build apps/sg-superapp-api/sg-superapp-api.csproj
```

Expected: falla con `CS1503` o similar en `PortalEndpoints.cs` en la línea que llama `GetServicePositionsAsync(search, normalizedStatus, cancellationToken)` — es esperado, el Step 3 actualiza esa llamada.

- [ ] **Step 3: Actualizar el endpoint**

Reemplazar el bloque completo del endpoint (líneas 714-735 de `PortalEndpoints.cs`) por:

```csharp
        app.MapGet("/api/portal/positions", async (string? search, string? status, int? page, int? pageSize, HttpContext httpContext, PortalAuthorizationService authorization, PostgresPortalRepository repository, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("POSITIONS", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!await repository.CanConnectAsync(cancellationToken))
            {
                return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
            }

            var normalizedStatus = status?.Trim().ToUpperInvariant();
            if (normalizedStatus is not null && normalizedStatus is not ("ACTIVO" or "INACTIVO"))
            {
                return Results.BadRequest(new { message = "El estado de puesto no es valido." });
            }

            // 100_000 is not a real product limit, just an overflow guard: with resolvedPageSize
            // capped at 100, (100_000 - 1) * 100 stays well within int32 range, so the offset
            // computed in GetServicePositionsAsync can never overflow regardless of the requested page.
            const int maxPage = 100_000;
            var resolvedPageSize = pageSize.HasValue ? Math.Clamp(pageSize.Value, 1, 100) : int.MaxValue;
            // Paging only makes sense once pageSize is actually bounded. When pageSize is omitted,
            // resolvedPageSize is the "unbounded" sentinel (int.MaxValue) and any page > 1 would
            // overflow int32 in (page - 1) * pageSize (offset), so ignore the caller's page in that
            // case and force page 1 — this also preserves the "omit both -> identical to old
            // unpaginated behavior" guarantee even when only page is supplied without pageSize.
            var resolvedPage = !pageSize.HasValue ? 1 : (page.HasValue ? Math.Clamp(page.Value, 1, maxPage) : 1);

            var (positions, totalCount) = await repository.GetServicePositionsAsync(search, normalizedStatus, resolvedPage, resolvedPageSize, cancellationToken);
            httpContext.Response.Headers["X-Total-Count"] = totalCount.ToString();
            return Results.Ok(positions);
        });
```

- [ ] **Step 4: Compilar**

```bash
"C:\tmp\dotnet6\dotnet.exe" build apps/sg-superapp-api/sg-superapp-api.csproj
```

Expected: `Compilación correcta.` 0 errores.

- [ ] **Step 5: Commit**

```bash
git add apps/sg-superapp-api/Services/PostgresPortalRepository.cs apps/sg-superapp-api/Endpoints/PortalEndpoints.cs
git commit -m "feat(puestos): paginacion aditiva en GET /api/portal/positions"
```

---

## Task 3: Frontend — `fetchServicePositionsPage` en `portalApi.ts`

**Files:**
- Modify: `apps/sg-superapp-web/src/services/portalApi.ts` (agregar función nueva justo después de `fetchServicePositions`, línea 458)

**Interfaces:**
- Consumes: nada nuevo — usa `API_BASE_URL`, `getSessionHeaders`, `PortalApiError`, `readProblem` ya existentes en el mismo archivo.
- Produces: `ServicePositionsPageResult { items: ServicePosition[]; totalCount: number }` y `fetchServicePositionsPage(filters: { search?: string; status?: ServicePositionStatus; page: number; pageSize: number }): Promise<ServicePositionsPageResult>` — usada por Task 4.

- [ ] **Step 1: Agregar la función**

Insertar inmediatamente después del cierre de `fetchServicePositions` (después de la línea 458, antes de `fetchServicePositionDetail`):

```typescript
export interface ServicePositionsPageResult {
  items: ServicePosition[];
  totalCount: number;
}

export async function fetchServicePositionsPage(filters: {
  search?: string;
  status?: ServicePositionStatus;
  page: number;
  pageSize: number;
}): Promise<ServicePositionsPageResult> {
  const params = new URLSearchParams();

  if (filters.search) {
    params.set("search", filters.search);
  }

  if (filters.status) {
    params.set("status", filters.status);
  }

  params.set("page", String(filters.page));
  params.set("pageSize", String(filters.pageSize));

  const response = await fetch(`${API_BASE_URL}/portal/positions?${params.toString()}`, {
    headers: getSessionHeaders()
  });

  if (!response.ok) {
    throw new PortalApiError(await readProblem(response));
  }

  const items = (await response.json()) as ServicePosition[];
  const totalCountHeader = response.headers.get("X-Total-Count");
  if (totalCountHeader === null) {
    console.warn("fetchServicePositionsPage: falta el header X-Total-Count en la respuesta; usando la longitud de la pagina actual como total.");
  }
  const totalCount = Number(totalCountHeader ?? items.length);
  return { items, totalCount };
}
```

No se toca `fetchServicePositions` — sigue existiendo tal cual, la sigue usando `EmployeesPage.tsx:182`.

- [ ] **Step 2: Compilar**

```bash
cd apps/sg-superapp-web && node "./node_modules/typescript/bin/tsc" -b .
```

Expected: sin salida (compilación limpia). `ServicePositionStatus` ya está importado en este archivo (usado por `fetchServicePositions`), no hace falta agregar el import.

- [ ] **Step 3: Commit**

```bash
git add apps/sg-superapp-web/src/services/portalApi.ts
git commit -m "feat(puestos): fetchServicePositionsPage con soporte de paginacion"
```

---

## Task 4: Frontend — `PositionsPage` — paginación en el listado

**Files:**
- Modify: `apps/sg-superapp-web/src/features/positions/PositionsPage.tsx`

**Interfaces:**
- Consumes: `fetchServicePositionsPage` (Task 3).
- Produces: nada nuevo para otras tareas — este task es autocontenido dentro de `PositionsPage`.

- [ ] **Step 1: Actualizar el import**

Reemplazar la línea 2:

```typescript
import { createServicePosition, fetchServicePositionAssignments, fetchServicePositionDetail, fetchServicePositions, inactivateServicePosition, PortalApiError, updateServicePosition } from "../../services/portalApi";
```

por:

```typescript
import { createServicePosition, fetchServicePositionAssignments, fetchServicePositionDetail, fetchServicePositionsPage, inactivateServicePosition, PortalApiError, updateServicePosition } from "../../services/portalApi";
```

(`fetchServicePositions` ya no se usa en este archivo tras este task — se elimina del import; sigue existiendo en `portalApi.ts` para `EmployeesPage.tsx`.)

- [ ] **Step 2: Estado de paginación**

Insertar después de la línea `const [positions, setPositions] = useState<ServicePosition[]>([]);` (línea 36):

```typescript
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);
  const [totalCount, setTotalCount] = useState(0);
  const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
```

- [ ] **Step 3: Reiniciar página al cambiar filtros**

Insertar justo antes del `useEffect` de `loadPositions` (antes de la línea 54):

```typescript
  useEffect(() => {
    setPage(1);
  }, [search, status]);
```

- [ ] **Step 4: `loadPositions` usa la versión paginada**

Dentro del `useEffect` de `loadPositions` (líneas 54-99), reemplazar el cuerpo del `try`/`catch` (líneas 61-91) por:

```typescript
      try {
        const { items, totalCount: total } = await fetchServicePositionsPage({ search, status: status || undefined, page, pageSize });
        if (ignore) {
          return;
        }

        setPositions(items);
        setTotalCount(total);
        if (items.length === 0) {
          setSelectedId(null);
          setSelectedPosition(null);
          setAssignments([]);
          return;
        }

        const nextId = selectedId !== null && items.some((position) => position.id === selectedId)
          ? selectedId
          : items[0].id;
        setSelectedId(nextId);
      } catch (error) {
        if (!ignore) {
          setErrorMessage(error instanceof Error ? error.message : "No fue posible cargar puestos de servicio.");
          setPositions([]);
          setTotalCount(0);
          setSelectedId(null);
          setSelectedPosition(null);
          setAssignments([]);
        }
      }
```

Y actualizar el arreglo de dependencias del mismo efecto (línea 99) de:

```typescript
  }, [search, status, selectedId, refreshKey]);
```

a:

```typescript
  }, [search, status, selectedId, refreshKey, page, pageSize]);
```

- [ ] **Step 5: Encabezado del listado usa el total real**

Cambiar (línea 299):

```tsx
            <span>{loading ? "Cargando..." : `${positions.length} puestos`}</span>
```

por:

```tsx
            <span>{loading ? "Cargando..." : `${totalCount} puestos`}</span>
```

- [ ] **Step 6: Controles de paginación**

Insertar inmediatamente después del cierre de `.employee-table` (después de la línea 324, antes del cierre de `</section>` en la línea 325):

```tsx
          <div className="pagination-controls">
            <button type="button" className="ghost-button" disabled={page <= 1} onClick={() => setPage((current) => current - 1)}>
              Anterior
            </button>
            <span className="muted">{totalCount === 0 ? "Sin resultados" : `Página ${page} de ${totalPages}`}</span>
            <button type="button" className="ghost-button" disabled={page >= totalPages} onClick={() => setPage((current) => current + 1)}>
              Siguiente
            </button>
            <select value={pageSize} onChange={(event) => { setPageSize(Number(event.target.value)); setPage(1); }}>
              <option value={25}>25 por página</option>
              <option value={50}>50 por página</option>
              <option value={100}>100 por página</option>
            </select>
          </div>
```

- [ ] **Step 7: Compilar y construir**

```bash
cd apps/sg-superapp-web && node "./node_modules/typescript/bin/tsc" -b . && node "./node_modules/vite/bin/vite.js" build
```

Expected: ambos comandos terminan sin error; `vite build` reporta `✓ built in ...`.

- [ ] **Step 8: Commit**

```bash
git add apps/sg-superapp-web/src/features/positions/PositionsPage.tsx
git commit -m "feat(puestos): paginacion en el listado de PositionsPage"
```

---

## Task 5: Frontend — modal "Crear/Editar puesto"

**Files:**
- Modify: `apps/sg-superapp-web/src/features/positions/PositionsPage.tsx`

**Interfaces:**
- Consumes: `Modal` (`apps/sg-superapp-web/src/components/Modal.tsx`, ya existente — `Modal({ title, onClose, children })`).
- Produces: `openCreateModal()`, `openEditModal()` — no consumidas por otras tareas de este plan, pero establecen el patrón que Task 6/7 replican para sus propios modales.

- [ ] **Step 1: Importar `Modal`**

Agregar después de la línea 3 (después del `import type ...` de tipos):

```typescript
import { Modal } from "../../components/Modal";
```

- [ ] **Step 2: Nuevo estado del modal, eliminar el efecto de auto-poblado**

Agregar después de `const [refreshKey, setRefreshKey] = useState(0);` (línea 52):

```typescript
  const [isPositionModalOpen, setIsPositionModalOpen] = useState(false);
```

Eliminar por completo este efecto (líneas 143-153 del archivo original):

```typescript
  useEffect(() => {
    if (!selectedPosition || formMode !== "edit") {
      return;
    }

    setFormCode(selectedPosition.code || "");
    setFormName(selectedPosition.name);
    setFormClientText(selectedPosition.clientText || "");
    setFormLocationText(selectedPosition.locationText || "");
    setFormNotes(selectedPosition.notes || "");
  }, [selectedPosition, formMode]);
```

(Su trabajo lo hacen ahora `openCreateModal`/`openEditModal` de forma explícita, evitando que el formulario se repueble solo mientras el modal está cerrado.)

- [ ] **Step 3: Funciones para abrir el modal**

Agregar después de `clearForm()` (después de la línea 165 original):

```typescript
  function openCreateModal() {
    setFormMode("create");
    clearForm();
    setActionMessage(null);
    setIsPositionModalOpen(true);
  }

  function openEditModal() {
    if (!selectedPosition) {
      return;
    }

    setFormMode("edit");
    setFormCode(selectedPosition.code || "");
    setFormName(selectedPosition.name);
    setFormClientText(selectedPosition.clientText || "");
    setFormLocationText(selectedPosition.locationText || "");
    setFormNotes(selectedPosition.notes || "");
    setActionMessage(null);
    setIsPositionModalOpen(true);
  }
```

- [ ] **Step 4: `savePosition` cierra el modal al guardar con éxito**

Reemplazar el cuerpo del `try` en `savePosition()` (líneas 206-226 originales) por:

```typescript
      if (formMode === "create") {
        const created = await createServicePosition(request);
        setSelectedId(created.id);
        setSelectedPosition(created);
        setAssignments([]);
        setRefreshKey((current) => current + 1);
        setIsPositionModalOpen(false);
        return;
      }

      if (!selectedPosition) {
        setActionMessage("Seleccione un puesto para editar.");
        return;
      }

      const updated = await updateServicePosition(selectedPosition.id, request);
      setSelectedPosition(updated);
      setPositions((current) => current.map((item) => item.id === updated.id ? updated : item));
      setIsPositionModalOpen(false);
```

(El `catch`/`finally` que siguen no cambian.)

- [ ] **Step 5: Botón "Nuevo puesto" del toolbar llama a `openCreateModal`**

Reemplazar el botón completo (líneas 273-289 originales):

```tsx
          {canManagePositions ? (
            <button
              type="button"
              className="secondary-action"
              onClick={() => {
                setFormMode("create");
                setSelectedId(null);
                setSelectedPosition(null);
                setAssignments([]);
                setDetailErrorMessage(null);
                clearForm();
                setActionMessage(null);
              }}
            >
              Nuevo puesto
            </button>
          ) : null}
```

por:

```tsx
          {canManagePositions ? (
            <button type="button" className="secondary-action" onClick={openCreateModal}>
              Nuevo puesto
            </button>
          ) : null}
```

(Ya no limpia la selección — crear un puesto nuevo no debe afectar qué puesto sigue mostrando el panel de Detalle detrás del modal.)

- [ ] **Step 6: Reestructurar el panel de Detalle**

Reemplazar el bloque completo desde `{selectedPosition || formMode === "create" ? (` hasta el `) : (` que le corresponde, **solo la parte que va desde el inicio del bloque hasta el cierre del antiguo formulario inline** (líneas 335-404 originales) — es decir, todo lo que hoy va desde el header condicional (`selectedPosition ? <>...` con el título "Nuevo puesto de servicio") hasta el cierre del `</div>` de `.position-form` — por:

```tsx
          {selectedPosition ? (
            <div className="employee-detail">
              <h4>{selectedPosition.name}</h4>
              <p className="muted">
                {selectedPosition.code || "Sin codigo"} · {selectedPosition.clientText || "Sin cliente"}
              </p>

              {canManagePositions ? (
                <div className="position-form-actions">
                  <button type="button" onClick={openEditModal}>Editar puesto</button>
                </div>
              ) : null}

              <dl>
                <div>
                  <dt>Estado</dt>
                  <dd><span className={`status-chip ${getStatusClass(selectedPosition.status)}`}>{selectedPosition.status}</span></dd>
                </div>
                <div>
                  <dt>Ubicacion</dt>
                  <dd>{selectedPosition.locationText || "No definida"}</dd>
                </div>
                <div>
                  <dt>Asignados vigentes</dt>
                  <dd>{selectedPosition.activeAssignmentsCount}</dd>
                </div>
                <div>
                  <dt>Observaciones</dt>
                  <dd>{selectedPosition.notes || "Sin observaciones"}</dd>
                </div>
              </dl>

              {isPositionModalOpen ? (
                <Modal title={formMode === "create" ? "Crear puesto" : "Editar puesto"} onClose={() => setIsPositionModalOpen(false)}>
                  <div className="position-form">
                    {actionMessage ? <p className="muted">{actionMessage}</p> : null}
                    <input value={formCode} onChange={(event) => setFormCode(event.target.value)} placeholder="Codigo opcional" />
                    <input value={formName} onChange={(event) => setFormName(event.target.value)} placeholder="Nombre obligatorio" />
                    <input value={formClientText} onChange={(event) => setFormClientText(event.target.value)} placeholder="Cliente texto libre" />
                    <input value={formLocationText} onChange={(event) => setFormLocationText(event.target.value)} placeholder="Ubicacion" />
                    <textarea value={formNotes} onChange={(event) => setFormNotes(event.target.value)} placeholder="Observaciones" />
                    <div className="position-form-actions">
                      <button type="button" onClick={() => void savePosition()} disabled={actionPending}>
                        {actionPending ? "Guardando..." : formMode === "create" ? "Crear puesto" : "Guardar cambios"}
                      </button>
                      {selectedPosition.status === "ACTIVO" && formMode === "edit" ? (
                        <button type="button" className="danger-action" onClick={() => void deactivateSelectedPosition()} disabled={actionPending}>
                          Inactivar
                        </button>
                      ) : null}
                    </div>
                  </div>
                </Modal>
              ) : null}
```

Nota: el `) : (` que sigue en el original (con el `<div className="panel-empty">Seleccione un puesto para ver su detalle.</div>`) se mantiene tal cual como rama `else` de este `selectedPosition ?` — ya no hace falta la rama especial para `formMode === "create"` porque crear ya no depende de tener algo (o nada) seleccionado.

Las secciones "Asignaciones vigentes", "Historial basico" y el `<p className="muted role-note">` final (líneas 406-446 originales) **no cambian en este task** — Task 6 y 7 las tocan.

- [ ] **Step 7: Compilar y construir**

```bash
cd apps/sg-superapp-web && node "./node_modules/typescript/bin/tsc" -b . && node "./node_modules/vite/bin/vite.js" build
```

Expected: ambos sin error.

- [ ] **Step 8: Commit**

```bash
git add apps/sg-superapp-web/src/features/positions/PositionsPage.tsx
git commit -m "feat(puestos): mover formulario crear/editar a un Modal"
```

---

## Task 6: Frontend — modal "Asignar empleado"

**Files:**
- Modify: `apps/sg-superapp-web/src/features/positions/PositionsPage.tsx`

**Interfaces:**
- Consumes: `fetchEmployees`, `createPositionAssignment` (`portalApi.ts`, ya existentes — usadas hoy solo por `CertificatesPage.tsx`/`EmployeesPage.tsx` respectivamente); `EmployeeSummary` (`types/portal.ts`); `Modal` (Task 5).
- Produces: `openAssignEmployeeModal()`, `assignEmployee()` — no consumidas por otras tareas.

- [ ] **Step 1: Actualizar imports**

El import de `portalApi` (ya modificado en Task 4) gana `fetchEmployees` y `createPositionAssignment`:

```typescript
import { createPositionAssignment, createServicePosition, fetchEmployees, fetchServicePositionAssignments, fetchServicePositionDetail, fetchServicePositionsPage, inactivateServicePosition, PortalApiError, updateServicePosition } from "../../services/portalApi";
```

El import de tipos (línea 3 original) gana `EmployeeSummary`:

```typescript
import type { CurrentUser, EmployeeSummary, PositionAssignment, ServicePosition, ServicePositionRequest, ServicePositionStatus } from "../../types/portal";
```

- [ ] **Step 2: Nuevo estado**

Agregar después de `const [isPositionModalOpen, setIsPositionModalOpen] = useState(false);` (agregado en Task 5):

```typescript
  const [isAssignEmployeeModalOpen, setIsAssignEmployeeModalOpen] = useState(false);
  const [employeeSearch, setEmployeeSearch] = useState("");
  const [employeeOptions, setEmployeeOptions] = useState<EmployeeSummary[]>([]);
  const [assignEmployeeId, setAssignEmployeeId] = useState("");
  const [assignStartDate, setAssignStartDate] = useState("");
  const [assignReason, setAssignReason] = useState("");
  const [assignNotes, setAssignNotes] = useState("");
  const [assignPending, setAssignPending] = useState(false);
  const [assignMessage, setAssignMessage] = useState<string | null>(null);
```

- [ ] **Step 3: Efecto de búsqueda de empleados**

Agregar como nuevo `useEffect`, después del efecto de `loadPositions` (Task 4):

```typescript
  useEffect(() => {
    if (!isAssignEmployeeModalOpen) {
      return;
    }

    let ignore = false;
    async function loadEmployeeOptions() {
      try {
        const data = await fetchEmployees({ search: employeeSearch || undefined, status: "ACTIVO" });
        if (!ignore) {
          setEmployeeOptions(data.slice(0, 20));
        }
      } catch {
        if (!ignore) {
          setEmployeeOptions([]);
        }
      }
    }

    void loadEmployeeOptions();
    return () => {
      ignore = true;
    };
  }, [isAssignEmployeeModalOpen, employeeSearch]);
```

(Se filtra a `status: "ACTIVO"` porque asignar un empleado retirado a un puesto no tiene sentido de negocio — decisión tomada en esta tarea, análoga a como `EmployeesPage.tsx:182` ya filtra puestos a `status: "ACTIVO"` para su propio selector.)

- [ ] **Step 4: Abrir modal y crear asignación**

Agregar después de `openEditModal()` (Task 5):

```typescript
  function openAssignEmployeeModal() {
    setEmployeeSearch("");
    setEmployeeOptions([]);
    setAssignEmployeeId("");
    setAssignStartDate(new Date().toISOString().slice(0, 10));
    setAssignReason("");
    setAssignNotes("");
    setAssignMessage(null);
    setIsAssignEmployeeModalOpen(true);
  }

  async function assignEmployee() {
    if (!selectedPosition) {
      return;
    }

    if (!assignEmployeeId || !assignStartDate) {
      setAssignMessage("Seleccione un empleado y una fecha de inicio.");
      return;
    }

    setAssignPending(true);
    setAssignMessage(null);
    try {
      await createPositionAssignment(Number(assignEmployeeId), {
        positionId: selectedPosition.id,
        startDate: assignStartDate,
        changeReason: assignReason.trim() || null,
        notes: assignNotes.trim() || null
      });
      await reloadPosition(selectedPosition.id);
      setIsAssignEmployeeModalOpen(false);
    } catch (error) {
      setAssignMessage(error instanceof Error ? error.message : "No fue posible crear la asignacion.");
    } finally {
      setAssignPending(false);
    }
  }
```

(`reloadPosition` ya existe sin cambios, definida junto a `savePosition`.)

- [ ] **Step 5: Botón y modal en el JSX**

Agregar, inmediatamente después del bloque `{canManagePositions ? (<div className="position-form-actions"><button ... Editar puesto ...</div>) : null}` que Task 5 dejó dentro de `.employee-detail`:

```tsx
              {canManagePositions && selectedPosition.status === "ACTIVO" ? (
                <div className="position-form-actions">
                  <button type="button" onClick={openAssignEmployeeModal}>Asignar empleado</button>
                </div>
              ) : null}
```

Y agregar el modal, después del cierre del modal de crear/editar (`{isPositionModalOpen ? (...) : null}` de Task 5), todavía dentro de `.employee-detail`:

```tsx
              {isAssignEmployeeModalOpen ? (
                <Modal title="Asignar empleado" onClose={() => setIsAssignEmployeeModalOpen(false)}>
                  <div className="position-form">
                    {assignMessage ? <p className="muted">{assignMessage}</p> : null}
                    <input value={employeeSearch} onChange={(event) => setEmployeeSearch(event.target.value)} placeholder="Buscar empleado" />
                    <select value={assignEmployeeId} onChange={(event) => setAssignEmployeeId(event.target.value)}>
                      <option value="">Seleccione empleado</option>
                      {employeeOptions.map((employee) => (
                        <option key={employee.id} value={employee.id}>
                          {employee.fullName} · {employee.identificationNumber} · {employee.employmentStatus}
                        </option>
                      ))}
                    </select>
                    <input type="date" value={assignStartDate} onChange={(event) => setAssignStartDate(event.target.value)} />
                    <input value={assignReason} onChange={(event) => setAssignReason(event.target.value)} placeholder="Motivo opcional" />
                    <textarea value={assignNotes} onChange={(event) => setAssignNotes(event.target.value)} placeholder="Notas opcionales" />
                    <div className="position-form-actions">
                      <button type="button" onClick={() => void assignEmployee()} disabled={assignPending}>
                        {assignPending ? "Asignando..." : "Asignar"}
                      </button>
                    </div>
                  </div>
                </Modal>
              ) : null}
```

- [ ] **Step 6: Compilar y construir**

```bash
cd apps/sg-superapp-web && node "./node_modules/typescript/bin/tsc" -b . && node "./node_modules/vite/bin/vite.js" build
```

Expected: ambos sin error.

- [ ] **Step 7: Commit**

```bash
git add apps/sg-superapp-web/src/features/positions/PositionsPage.tsx
git commit -m "feat(puestos): modal para asignar empleado a un puesto"
```

---

## Task 7: Frontend — modal "Finalizar asignación" (por tarjeta) + mostrar nombre del empleado

**Files:**
- Modify: `apps/sg-superapp-web/src/features/positions/PositionsPage.tsx`

**Interfaces:**
- Consumes: `finalizePositionAssignment` (`portalApi.ts`, ya existente); `PositionAssignment.employeeFullName`/`employeeIdentificationNumber` (Task 1); `Modal` (Task 5).
- Produces: nada consumido por otras tareas — es la última pieza funcional del plan.

- [ ] **Step 1: Import**

Agregar `finalizePositionAssignment` al import de `portalApi` (el mismo que Task 6 dejó):

```typescript
import { createPositionAssignment, createServicePosition, fetchEmployees, fetchServicePositionAssignments, fetchServicePositionDetail, fetchServicePositionsPage, finalizePositionAssignment, inactivateServicePosition, PortalApiError, updateServicePosition } from "../../services/portalApi";
```

- [ ] **Step 2: Nuevo estado**

Agregar después del estado de asignación (Task 6):

```typescript
  const [finalizingAssignmentId, setFinalizingAssignmentId] = useState<number | null>(null);
  const [finalizeEndDate, setFinalizeEndDate] = useState("");
  const [finalizeReason, setFinalizeReason] = useState("");
  const [finalizeNotes, setFinalizeNotes] = useState("");
  const [finalizePending, setFinalizePending] = useState(false);
  const [finalizeMessage, setFinalizeMessage] = useState<string | null>(null);
```

- [ ] **Step 3: Abrir modal y finalizar**

Agregar después de `assignEmployee()` (Task 6):

```typescript
  function openFinalizeModal(assignmentId: number) {
    setFinalizeEndDate(new Date().toISOString().slice(0, 10));
    setFinalizeReason("");
    setFinalizeNotes("");
    setFinalizeMessage(null);
    setFinalizingAssignmentId(assignmentId);
  }

  async function finalizeAssignment() {
    if (!selectedPosition || finalizingAssignmentId === null) {
      return;
    }

    if (!finalizeEndDate) {
      setFinalizeMessage("La fecha fin es obligatoria.");
      return;
    }

    setFinalizePending(true);
    setFinalizeMessage(null);
    try {
      await finalizePositionAssignment(finalizingAssignmentId, {
        endDate: finalizeEndDate,
        changeReason: finalizeReason.trim() || null,
        notes: finalizeNotes.trim() || null
      });
      await reloadPosition(selectedPosition.id);
      setFinalizingAssignmentId(null);
    } catch (error) {
      setFinalizeMessage(error instanceof Error ? error.message : "No fue posible finalizar la asignacion.");
    } finally {
      setFinalizePending(false);
    }
  }
```

- [ ] **Step 4: Tarjetas de "Asignaciones vigentes" — nombre del empleado + botón Finalizar**

Reemplazar el `.map` de `currentAssignments` (líneas 411-419 originales) por:

```tsx
                {currentAssignments.map((assignment) => (
                  <article key={assignment.id} className="assignment-card">
                    <div>
                      <strong>{assignment.employeeFullName}</strong>
                      <p className="muted">{assignment.employeeIdentificationNumber} · {formatDate(assignment.startDate)} · {assignment.createdBy || "sin usuario"}</p>
                    </div>
                    <div className="employee-row-meta">
                      <span className={`status-chip ${getStatusClass(assignment.status)}`}>{assignment.status}</span>
                      {canManagePositions ? (
                        <button type="button" className="ghost-button" onClick={() => openFinalizeModal(assignment.id)}>
                          Finalizar
                        </button>
                      ) : null}
                    </div>
                  </article>
                ))}
```

- [ ] **Step 5: Tarjetas de "Historial basico" — nombre del empleado**

Reemplazar el `.map` de `historicalAssignments` (líneas 428-437 originales) por:

```tsx
                {historicalAssignments.map((assignment) => (
                  <article key={assignment.id} className="assignment-card">
                    <div>
                      <strong>{assignment.employeeFullName}</strong>
                      <p className="muted">
                        {formatDate(assignment.startDate)} - {formatDate(assignment.endDate)} · {assignment.changeReason || "sin motivo"}
                      </p>
                    </div>
                    <span className={`status-chip ${getStatusClass(assignment.status)}`}>{assignment.status}</span>
                  </article>
                ))}
```

- [ ] **Step 6: Modal de finalizar**

Agregar, después del modal de "Asignar empleado" (Task 6), todavía dentro de `.employee-detail`:

```tsx
              {finalizingAssignmentId !== null ? (
                <Modal title="Finalizar asignación" onClose={() => setFinalizingAssignmentId(null)}>
                  <div className="position-form">
                    {finalizeMessage ? <p className="muted">{finalizeMessage}</p> : null}
                    <input type="date" value={finalizeEndDate} onChange={(event) => setFinalizeEndDate(event.target.value)} />
                    <input value={finalizeReason} onChange={(event) => setFinalizeReason(event.target.value)} placeholder="Motivo opcional" />
                    <textarea value={finalizeNotes} onChange={(event) => setFinalizeNotes(event.target.value)} placeholder="Notas opcionales" />
                    <div className="position-form-actions">
                      <button type="button" onClick={() => void finalizeAssignment()} disabled={finalizePending}>
                        {finalizePending ? "Finalizando..." : "Finalizar"}
                      </button>
                    </div>
                  </div>
                </Modal>
              ) : null}
```

- [ ] **Step 7: Compilar y construir**

```bash
cd apps/sg-superapp-web && node "./node_modules/typescript/bin/tsc" -b . && node "./node_modules/vite/bin/vite.js" build
```

Expected: ambos sin error.

- [ ] **Step 8: Commit**

```bash
git add apps/sg-superapp-web/src/features/positions/PositionsPage.tsx
git commit -m "feat(puestos): finalizar asignacion por tarjeta y mostrar nombre del empleado"
```

---

## Task 8: Verificadores ejecutables (paginación + flujo de asignación) y revisión manual

**Files:**
- Create: `scripts/dev/Verify-SgSuperAppPositionsPagination.ps1`
- Create: `scripts/dev/Verify-SgSuperAppPositionsAssignments.ps1`

**Interfaces:**
- Consumes: `GET /api/portal/positions` (Task 2), `GET/POST /api/portal/employees/{id}/position-assignments`, `POST /api/portal/position-assignments/{id}/finalize`, `GET /api/portal/positions/{id}/assignments` (todos ya existentes, Task 1 les agrega el nombre del empleado a la respuesta).
- Produces: nada — es el último task del plan.

Ambos scripts requieren la API corriendo en `http://localhost:5080` (`scripts/dev/Start-SgSuperAppApi.ps1`) contra una base de datos con al menos un puesto ACTIVO y algunos empleados ACTIVOS — el mismo requisito que ya tienen `Verify-SgSuperAppEmployeesPagination.ps1` y los verificadores de I9.

- [ ] **Step 1: Escribir el verificador de paginación**

```powershell
# scripts/dev/Verify-SgSuperAppPositionsPagination.ps1
param(
    [string]$ApiBaseUrl = "http://localhost:5080/api"
)

$ErrorActionPreference = "Stop"

function Get-SessionHeaders {
    param([string]$Username, [string]$Password)
    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($response.sessionToken)" }
}

function Invoke-PositionsRequest {
    param([string]$Uri, [hashtable]$Headers)
    $response = Invoke-WebRequest -Uri $Uri -Headers $Headers -UseBasicParsing
    $totalCountRaw = $response.Headers["X-Total-Count"]
    return @{
        Status = [int]$response.StatusCode
        Body = ($response.Content | ConvertFrom-Json)
        TotalCount = [int]("$totalCountRaw")
    }
}

$headers = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"

# Sin page/pageSize: comportamiento identico al actual, arreglo completo (no rompe el
# selector de EmployeesPage.tsx, que llama sin estos parametros).
$unpaged = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions" -Headers $headers
if ($unpaged.Body.Count -ne $unpaged.TotalCount) {
    throw "Sin parametros de paginacion, el arreglo completo debe tener el mismo tamano que X-Total-Count. Arreglo: $($unpaged.Body.Count), Total: $($unpaged.TotalCount)."
}

if ($unpaged.TotalCount -lt 2) {
    Write-Output "POSITIONS PAGINATION BLOCKED: se necesitan al menos 2 puestos en la base de datos para ejercitar paginacion real."
    exit 2
}

# Con pageSize=1: la pagina 1 debe traer exactamente 1 y el total debe coincidir con el sin paginar.
$page1 = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?page=1&pageSize=1" -Headers $headers
if ($page1.Body.Count -ne 1) {
    throw "La pagina 1 con pageSize=1 debio traer 1 registro, trajo $($page1.Body.Count)."
}
if ($page1.TotalCount -ne $unpaged.TotalCount) {
    throw "El total con paginacion ($($page1.TotalCount)) debe coincidir con el total sin paginar ($($unpaged.TotalCount))."
}

# La pagina 2 no debe repetir el id de la pagina 1.
$page2 = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?page=2&pageSize=1" -Headers $headers
$page1Ids = @($page1.Body | ForEach-Object { $_.id })
$overlap = @($page2.Body | Where-Object { $page1Ids -contains $_.id })
if ($overlap.Count -gt 0) {
    throw "La pagina 2 no debe repetir ids de la pagina 1."
}

# pageSize fuera de rango se recorta a 100.
$oversized = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?page=1&pageSize=9999" -Headers $headers
if ($oversized.Body.Count -gt 100) {
    throw "pageSize debe limitarse a 100 como maximo, devolvio $($oversized.Body.Count)."
}
if ($oversized.TotalCount -ne $unpaged.TotalCount) {
    throw "El total con pageSize fuera de rango ($($oversized.TotalCount)) debe coincidir con el total sin paginar ($($unpaged.TotalCount))."
}

# page absurdamente grande no debe causar overflow ni un 500.
$hugePage = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?page=99999999&pageSize=5" -Headers $headers
if ($hugePage.Status -ne 200) {
    throw "Un page absurdamente grande debe devolver 200, devolvio $($hugePage.Status)."
}
if ($hugePage.Body.Count -ne 0) {
    throw "Un page absurdamente grande debe devolver un arreglo vacio, devolvio $($hugePage.Body.Count) registros."
}

# page sin pageSize no debe truncar: se ignora y se devuelve el arreglo completo.
$pageOnly = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?page=2" -Headers $headers
if ($pageOnly.Body.Count -ne $unpaged.Body.Count) {
    throw "page=2 sin pageSize debe devolver el arreglo completo. Arreglo: $($pageOnly.Body.Count), esperado: $($unpaged.Body.Count)."
}

# El total con un filtro activo debe seguir siendo consistente.
$filteredUnpaged = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?status=ACTIVO" -Headers $headers
$filteredPaged = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?status=ACTIVO&page=1&pageSize=1" -Headers $headers
if ($filteredPaged.TotalCount -ne $filteredUnpaged.TotalCount) {
    throw "Con status=ACTIVO, el total paginado ($($filteredPaged.TotalCount)) debe coincidir con el total sin paginar ($($filteredUnpaged.TotalCount))."
}

Write-Output "POSITIONS PAGINATION PASS"
```

- [ ] **Step 2: Ejecutar el verificador de paginación**

```powershell
powershell -File "scripts/dev/Verify-SgSuperAppPositionsPagination.ps1"
```

Expected: `POSITIONS PAGINATION PASS` (requiere `Start-SgSuperAppApi.ps1` corriendo). Si la base de datos tiene menos de 2 puestos, `POSITIONS PAGINATION BLOCKED` con exit code 2 — no es una falla del código, es falta de datos de prueba.

- [ ] **Step 3: Escribir el verificador de asignaciones**

```powershell
# scripts/dev/Verify-SgSuperAppPositionsAssignments.ps1
param(
    [string]$ApiBaseUrl = "http://localhost:5080/api"
)

$ErrorActionPreference = "Stop"

function Get-SessionHeaders {
    param([string]$Username, [string]$Password)
    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($response.sessionToken)" }
}

$headers = Get-SessionHeaders -Username "th.sg" -Password "Th123456"

$activePositions = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/positions?status=ACTIVO" -Headers $headers
if (@($activePositions).Count -eq 0) {
    Write-Output "POSITIONS ASSIGNMENTS BLOCKED: no hay puestos ACTIVOS en la base de datos."
    exit 2
}
$position = $activePositions[0]

$activeEmployees = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees?status=ACTIVO&pageSize=50" -Headers $headers

$freeEmployee = $null
foreach ($employee in $activeEmployees) {
    $existing = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees/$($employee.id)/position-assignments" -Headers $headers
    $hasCurrent = @($existing | Where-Object { $_.status -eq "VIGENTE" }).Count -gt 0
    if (-not $hasCurrent) {
        $freeEmployee = $employee
        break
    }
}

if ($null -eq $freeEmployee) {
    Write-Output "POSITIONS ASSIGNMENTS BLOCKED: no se encontro un empleado ACTIVO sin asignacion vigente entre los primeros 50."
    exit 2
}

# Crear asignacion: debe incluir el nombre del empleado en la respuesta (Task 1).
$createBody = @{ positionId = $position.id; startDate = (Get-Date).ToString("yyyy-MM-dd"); changeReason = $null; notes = $null } | ConvertTo-Json
$created = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees/$($freeEmployee.id)/position-assignments" -Method Post -ContentType "application/json" -Headers $headers -Body $createBody
if ($created.employeeFullName -ne $freeEmployee.fullName) {
    throw "La asignacion creada debe traer employeeFullName='$($freeEmployee.fullName)', trajo '$($created.employeeFullName)'."
}
if ($created.status -ne "VIGENTE") {
    throw "La asignacion recien creada debe quedar VIGENTE, quedo '$($created.status)'."
}

# El puesto debe reflejar la nueva asignacion, con el nombre del empleado.
$positionAssignments = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/positions/$($position.id)/assignments" -Headers $headers
$found = @($positionAssignments | Where-Object { $_.id -eq $created.id })
if ($found.Count -ne 1) {
    throw "La asignacion creada (id=$($created.id)) debe aparecer en /portal/positions/$($position.id)/assignments."
}
if ($found[0].employeeFullName -ne $freeEmployee.fullName) {
    throw "La asignacion listada desde el puesto debe traer employeeFullName, trajo '$($found[0].employeeFullName)'."
}

# Reintentar asignar al mismo empleado (ya tiene una vigente) debe devolver 409.
try {
    Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees/$($freeEmployee.id)/position-assignments" -Method Post -ContentType "application/json" -Headers $headers -Body $createBody | Out-Null
    throw "Asignar de nuevo al mismo empleado debio devolver 409, no lanzo error."
} catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 409) {
        throw "Asignar de nuevo al mismo empleado debio devolver 409, devolvio $($_.Exception.Response.StatusCode.value__)."
    }
}

# Finalizar la asignacion creada.
$finalizeBody = @{ endDate = (Get-Date).ToString("yyyy-MM-dd"); changeReason = "Verificacion automatizada"; notes = $null } | ConvertTo-Json
$finalized = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/position-assignments/$($created.id)/finalize" -Method Post -ContentType "application/json" -Headers $headers -Body $finalizeBody
if ($finalized.status -ne "FINALIZADA") {
    throw "La asignacion finalizada debe quedar en estado FINALIZADA, quedo '$($finalized.status)'."
}
if ($finalized.employeeFullName -ne $freeEmployee.fullName) {
    throw "La respuesta de finalizar debe seguir trayendo employeeFullName, trajo '$($finalized.employeeFullName)'."
}

# Ya finalizada, el puesto no debe seguir mostrandola como vigente.
$positionAssignmentsAfter = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/positions/$($position.id)/assignments" -Headers $headers
$stillVigente = @($positionAssignmentsAfter | Where-Object { $_.id -eq $created.id -and $_.status -eq "VIGENTE" })
if ($stillVigente.Count -ne 0) {
    throw "Tras finalizar, la asignacion no debe seguir apareciendo como VIGENTE."
}

# Asignar a un puesto INACTIVO (si existe alguno) debe devolver 409 INACTIVE_POSITION.
$inactivePositions = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/positions?status=INACTIVO" -Headers $headers
if (@($inactivePositions).Count -gt 0) {
    $inactivePosition = $inactivePositions[0]
    $inactiveBody = @{ positionId = $inactivePosition.id; startDate = (Get-Date).ToString("yyyy-MM-dd"); changeReason = $null; notes = $null } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees/$($freeEmployee.id)/position-assignments" -Method Post -ContentType "application/json" -Headers $headers -Body $inactiveBody | Out-Null
        throw "Asignar a un puesto inactivo debio devolver 409, no lanzo error."
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -ne 409) {
            throw "Asignar a un puesto inactivo debio devolver 409, devolvio $($_.Exception.Response.StatusCode.value__)."
        }
    }
} else {
    Write-Output "POSITIONS ASSIGNMENTS: sin puestos INACTIVOS en la base de datos, se omite el chequeo de INACTIVE_POSITION."
}

Write-Output "POSITIONS ASSIGNMENTS PASS"
```

- [ ] **Step 4: Ejecutar el verificador de asignaciones**

```powershell
powershell -File "scripts/dev/Verify-SgSuperAppPositionsAssignments.ps1"
```

Expected: `POSITIONS ASSIGNMENTS PASS` (requiere `Start-SgSuperAppApi.ps1` corriendo y datos reales — al menos un puesto ACTIVO y un empleado ACTIVO sin asignación vigente entre los primeros 50). `POSITIONS ASSIGNMENTS BLOCKED` con exit code 2 si no hay datos suficientes — no es una falla del código.

- [ ] **Step 5: Build final completo**

```bash
"C:\tmp\dotnet6\dotnet.exe" build apps/sg-superapp-api/sg-superapp-api.csproj
cd apps/sg-superapp-web && node "./node_modules/typescript/bin/tsc" -b . && node "./node_modules/vite/bin/vite.js" build
```

Expected: los tres comandos terminan sin error — es el primer build limpio de todo el módulo con los 7 tasks anteriores integrados.

- [ ] **Step 6: Commit**

```bash
git add scripts/dev/Verify-SgSuperAppPositionsPagination.ps1 scripts/dev/Verify-SgSuperAppPositionsAssignments.ps1
git commit -m "test(puestos): verificadores de paginacion y flujo de asignacion"
```

- [ ] **Step 7: Recorrido manual (no automatizable con las herramientas de este entorno)**

Con `Start-SgSuperAppApi.ps1` y `Start-SgSuperAppWeb.ps1` corriendo, iniciar sesión como `th.sg`/`Th123456` y confirmar:
- Paginar el listado de puestos con filtros activos (buscar por texto, filtrar por estado) — la página se reinicia a 1 al cambiar cualquiera de los dos.
- Crear un puesto nuevo por el modal sin tener ningún puesto seleccionado — el panel de Detalle detrás no cambia lo que mostraba.
- Editar un puesto existente por el modal — el resumen (`dl`) se actualiza al guardar.
- Asignar un empleado a un puesto ACTIVO — aparece en "Asignaciones vigentes" con su nombre, no con `Empleado #id`.
- Intentar asignar el mismo empleado a otro puesto — el modal muestra el mensaje de error sin cerrarse.
- Finalizar una asignación cuando el puesto tiene 2 o más vigentes — solo desaparece la finalizada, las demás siguen igual.
- El botón "Asignar empleado" no aparece en un puesto INACTIVO.
- Abrir/cerrar los tres modales por las tres vías (✕, clic en backdrop, tecla Escape).
- Responsive en 375px.
