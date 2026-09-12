# UX de Empleados: paginación, detalle agrupado y modales — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Quitar la etiqueta stale "I2 en curso", paginar el listado de empleados sin romper el picker de Certificaciones, reorganizar el panel de Detalle en 4 bloques de solo lectura, e introducir el primer componente `Modal` compartido del repo para "Editar información" y "Gestionar asignación".

**Architecture:** Backend: `GetEmployeesAsync` gana `page`/`pageSize` opcionales (default = todo el conjunto, igual que hoy) y devuelve además un total; el endpoint expone ese total en el header `X-Total-Count` y la política CORS lo declara como header expuesto. Frontend: una función nueva `fetchEmployeesPage` (no se toca `fetchEmployees`, que sigue usando el picker de Certificaciones) alimenta un estado de paginación en `EmployeesPage`; el panel de Detalle se reorganiza en 4 bloques agrupados; un componente `Modal` nuevo y genérico aloja los dos formularios que hoy viven siempre expandidos.

**Tech Stack:** ASP.NET Core 6 minimal APIs + Npgsql (backend), React 18 + TypeScript + Vite (frontend), Sentinel Enterprise design tokens en `styles.css`. Sin librerías nuevas.

**Spec:** `docs/superpowers/specs/2026-09-12-sg-empleados-ux-paginacion-modales-design.md`

**Nota sobre "tests" en este repo:** no hay framework de test unitario ni en backend ni en frontend (`dotnet test` no está configurado; `package.json` no tiene `vitest`/`jest`). La convención establecida en todo este proyecto es verificar contra la API real corriendo en local con scripts `scripts/dev/Verify-SgSuperApp*.ps1`, más recorrido manual en el navegador para UI. Cada tarea de este plan sigue esa convención en vez de un ciclo red/green de test unitario.

**Convenciones de entorno de este repo (necesarias para ejecutar los comandos de cada tarea):**
- `dotnet` no está en el PATH; el ejecutable real es `C:\tmp\dotnet6\dotnet.exe`, y antes de invocarlo hay que fijar `$env:DOTNET_CLI_HOME = "C:\tmp\dotnet-home"`.
- La ruta del repo contiene un `&` (`...\ProyectoS&G\...`), lo cual rompe `npx`/`dotnet` cuando se invocan por nombre en PowerShell — siempre usar la ruta completa al ejecutable (`C:\tmp\dotnet6\dotnet.exe`, `node .\node_modules\typescript\bin\tsc`, `node .\node_modules\vite\bin\vite.js`) en vez de `dotnet`/`npx tsc`/`npx vite`.
- El servidor API en `:5080` normalmente ya está corriendo; si se edita un `.cs`, hay que detener el proceso (`Get-Process -Id <pid> | Stop-Process -Force`, el PID se obtiene con `netstat -ano | findstr :5080`), reconstruir, y volver a lanzarlo (`& "C:\tmp\dotnet6\dotnet.exe" run --urls http://localhost:5080 --project apps\sg-superapp-api\sg-superapp-api.csproj`) antes de verificar. El frontend en `:3000` corre con Vite + HMR y normalmente refleja los cambios de `.tsx`/`.css` sin reiniciar.
- Credenciales de prueba ya sembradas: `admin.sg` / `Admin123` (ADMIN), `th.sg` / `Th123456` (TH).

## Global Constraints

- La paginación es aditiva: `page`/`pageSize` son opcionales en `GET /api/portal/employees`; sin ellos, el comportamiento es idéntico al actual (arreglo completo, sin límite). El picker de empleados de `CertificatesPage.tsx` (que llama `fetchEmployees` sin esos parámetros) no se modifica y debe seguir funcionando exactamente igual.
- El cuerpo de la respuesta sigue siendo el mismo arreglo JSON plano de siempre — no se introduce un sobre `{ items, total }`. El total viaja en el header de respuesta `X-Total-Count`.
- `Modal` es el primer primitivo de UI compartida del repo: vive en `apps/sg-superapp-web/src/components/Modal.tsx` (directorio nuevo, no existía `components/` antes).
- Los modales son centrados con backdrop oscurecido (no un panel lateral/drawer), y cierran por botón "✕", clic en el backdrop, y tecla Escape.
- No se toca ningún otro módulo del portal, ni se hace la revisión integral de experiencia de toda la aplicación que el usuario mencionó como ambición futura.

---

## Task 1: Backend — paginación real en `GET /api/portal/employees`

**Files:**
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs:1114-1174` (método `GetEmployeesAsync`)
- Modify: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs:636-652` (endpoint `GET /api/portal/employees`)
- Modify: `apps/sg-superapp-api/Program.cs:23-32` (política CORS)
- Create: `scripts/dev/Verify-SgSuperAppEmployeesPagination.ps1`

**Interfaces:**
- Produces: `PostgresPortalRepository.GetEmployeesAsync(string? search, string? status, string? jobTitle, string? completeness, bool includeSalary, int page, int pageSize, CancellationToken cancellationToken = default)` devuelve `Task<(IReadOnlyList<EmployeeSummaryResponse> Items, int TotalCount)>`. Con `page = 1` y `pageSize = int.MaxValue` el resultado es idéntico al método actual (todo el conjunto, mismo orden).
- Produces: `GET /api/portal/employees` acepta `page`/`pageSize` opcionales (query string) y agrega el header de respuesta `X-Total-Count` con el total de registros que matchean los filtros (independiente de la página pedida).

- [x] **Step 1: Modificar `GetEmployeesAsync` para aceptar paginación y devolver el total**

Reemplazar el método completo (líneas 1114-1174 de `PostgresPortalRepository.cs`) por:

```csharp
    public async Task<(IReadOnlyList<EmployeeSummaryResponse> Items, int TotalCount)> GetEmployeesAsync(string? search, string? status, string? jobTitle, string? completeness, bool includeSalary, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        const string countSql = @"
            select count(*)
            from employees e
            where (@search is null
                or e.identification_number ilike '%' || @search || '%'
                or e.full_name ilike '%' || @search || '%')
              and (@status is null or upper(e.employment_status) = upper(@status))
              and (@jobTitle is null or e.job_title ilike '%' || @jobTitle || '%')
              and (@completeness is null
                or (upper(@completeness) = 'INCOMPLETO' and e.record_status = 'INCOMPLETO')
                or (upper(@completeness) = 'COMPLETO' and e.record_status <> 'INCOMPLETO'));";

        const string sql = @"
            select
                e.id,
                e.identification_type,
                e.identification_number,
                e.full_name,
                e.employment_status,
                e.job_title,
                e.record_status,
                e.current_service_position_text,
                salary.base_salary_amount
            from employees e
            left join lateral (
                select esh.base_salary_amount
                from employee_salary_history esh
                where esh.employee_id = e.id
                order by esh.effective_from desc
                limit 1
            ) salary on true
            where (@search is null
                or e.identification_number ilike '%' || @search || '%'
                or e.full_name ilike '%' || @search || '%')
              and (@status is null or upper(e.employment_status) = upper(@status))
              and (@jobTitle is null or e.job_title ilike '%' || @jobTitle || '%')
              and (@completeness is null
                or (upper(@completeness) = 'INCOMPLETO' and e.record_status = 'INCOMPLETO')
                or (upper(@completeness) = 'COMPLETO' and e.record_status <> 'INCOMPLETO'))
            order by e.full_name
            limit @pageSize offset @offset;";

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var countCommand = new NpgsqlCommand(countSql, connection);
        countCommand.Parameters.Add("search", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        countCommand.Parameters.Add("status", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(status) ? DBNull.Value : status.Trim().ToUpperInvariant();
        countCommand.Parameters.Add("jobTitle", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(jobTitle) ? DBNull.Value : jobTitle.Trim();
        countCommand.Parameters.Add("completeness", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(completeness) ? DBNull.Value : completeness.Trim().ToUpperInvariant();
        var totalCount = Convert.ToInt32(await countCommand.ExecuteScalarAsync(cancellationToken));

        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add("search", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(search) ? DBNull.Value : search.Trim();
        command.Parameters.Add("status", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(status) ? DBNull.Value : status.Trim().ToUpperInvariant();
        command.Parameters.Add("jobTitle", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(jobTitle) ? DBNull.Value : jobTitle.Trim();
        command.Parameters.Add("completeness", NpgsqlDbType.Text).Value = string.IsNullOrWhiteSpace(completeness) ? DBNull.Value : completeness.Trim().ToUpperInvariant();
        command.Parameters.Add("pageSize", NpgsqlDbType.Integer).Value = pageSize;
        command.Parameters.Add("offset", NpgsqlDbType.Integer).Value = (page - 1) * pageSize;

        var employees = new List<EmployeeSummaryResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            employees.Add(new EmployeeSummaryResponse(
                reader.GetInt64(reader.GetOrdinal("id")),
                reader.GetString(reader.GetOrdinal("identification_type")),
                reader.GetString(reader.GetOrdinal("identification_number")),
                reader.GetString(reader.GetOrdinal("full_name")),
                reader.GetString(reader.GetOrdinal("employment_status")),
                reader.GetString(reader.GetOrdinal("job_title")),
                reader.GetString(reader.GetOrdinal("record_status")),
                !includeSalary || reader.IsDBNull(reader.GetOrdinal("base_salary_amount"))
                    ? null
                    : reader.GetDecimal(reader.GetOrdinal("base_salary_amount")),
                reader.IsDBNull(reader.GetOrdinal("current_service_position_text"))
                    ? null
                    : reader.GetString(reader.GetOrdinal("current_service_position_text"))));
        }

        return (employees, totalCount);
    }
```

Nota: cuando el llamador pasa `pageSize = int.MaxValue` y `page = 1`, `offset` es `0` y `limit int.MaxValue` no recorta nada — el resultado es idéntico al método actual sin paginación.

- [x] **Step 2: Actualizar el endpoint para resolver page/pageSize, llamar al repositorio y exponer el total**

Reemplazar el bloque actual (líneas 636-652 de `PortalEndpoints.cs`) por:

```csharp
        app.MapGet("/api/portal/employees", async (string? search, string? status, string? jobTitle, string? completeness, int? page, int? pageSize, HttpContext httpContext, PortalAuthorizationService authorization, PostgresPortalRepository repository, RequestUserContext userContext, CancellationToken cancellationToken) =>
        {
            var denied = await authorization.RequireAsync("EMPLOYEES", "VIEW", cancellationToken);
            if (denied is not null)
            {
                return denied;
            }

            if (!await repository.CanConnectAsync(cancellationToken))
            {
                return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
            }

            var resolvedPage = page.HasValue && page.Value > 0 ? page.Value : 1;
            var resolvedPageSize = pageSize.HasValue ? Math.Clamp(pageSize.Value, 1, 100) : int.MaxValue;

            var includeSalary = await repository.HasPermissionAsync(userContext.User!.Id, "EMPLOYEES", "VIEW_SALARY", cancellationToken);
            var (employees, totalCount) = await repository.GetEmployeesAsync(search, status, jobTitle, completeness, includeSalary, resolvedPage, resolvedPageSize, cancellationToken);
            httpContext.Response.Headers["X-Total-Count"] = totalCount.ToString();
            return Results.Ok(employees);
        });
```

- [x] **Step 3: Exponer el header `X-Total-Count` en la política CORS**

Por defecto, CORS solo expone a JavaScript un puñado de headers "simples" (no incluye headers personalizados) aunque el request esté permitido — sin este cambio, `response.headers.get("X-Total-Count")` devolvería `null` en el navegador aunque el header sí viaje por la red (esto no lo detecta un test con `Invoke-WebRequest` de PowerShell, que no aplica reglas de CORS; solo se ve en un navegador real).

En `apps/sg-superapp-api/Program.cs`, modificar el bloque (líneas 23-32):

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("LocalFrontend", policy =>
    {
        policy
            .WithOrigins("http://localhost:3000", "http://127.0.0.1:3000")
            .AllowAnyHeader()
            .AllowAnyMethod()
            .WithExposedHeaders("X-Total-Count");
    });
});
```

- [x] **Step 4: Compilar el backend**

```powershell
$env:DOTNET_CLI_HOME = "C:\tmp\dotnet-home"
& "C:\tmp\dotnet6\dotnet.exe" build "apps\sg-superapp-api\sg-superapp-api.csproj"
```

Esperado: `Compilación correcta. 0 Advertencia(s). 0 Errores.`

- [x] **Step 5: Reiniciar la API con el binario recién compilado**

```powershell
$pid = (netstat -ano | Select-String ":5080.*LISTENING") -replace '.*\s(\d+)$','$1' | Select-Object -First 1
if ($pid) { Stop-Process -Id $pid -Force }
Start-Sleep -Seconds 1
$env:DOTNET_CLI_HOME = "C:\tmp\dotnet-home"
Start-Process -FilePath "C:\tmp\dotnet6\dotnet.exe" -ArgumentList "run","--urls","http://localhost:5080","--project","apps\sg-superapp-api\sg-superapp-api.csproj" -WindowStyle Hidden
Start-Sleep -Seconds 6
```

- [x] **Step 6: Crear el verificador de paginación**

Crear `scripts/dev/Verify-SgSuperAppEmployeesPagination.ps1`:

```powershell
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

function Invoke-EmployeesRequest {
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

# Sin page/pageSize: comportamiento identico al actual, arreglo completo.
$unpaged = Invoke-EmployeesRequest -Uri "$ApiBaseUrl/portal/employees" -Headers $headers
if ($unpaged.Body.Count -ne $unpaged.TotalCount) {
    throw "Sin parametros de paginacion, el arreglo completo debe tener el mismo tamano que X-Total-Count. Arreglo: $($unpaged.Body.Count), Total: $($unpaged.TotalCount)."
}

# Con pageSize=5: la pagina 1 debe traer exactamente 5 (si hay al menos 5 empleados) y el total debe coincidir con el sin paginar.
$page1 = Invoke-EmployeesRequest -Uri "$ApiBaseUrl/portal/employees?page=1&pageSize=5" -Headers $headers
if ($page1.Body.Count -ne 5) {
    throw "La pagina 1 con pageSize=5 debio traer 5 registros, trajo $($page1.Body.Count)."
}
if ($page1.TotalCount -ne $unpaged.TotalCount) {
    throw "El total con paginacion ($($page1.TotalCount)) debe coincidir con el total sin paginar ($($unpaged.TotalCount))."
}

# La pagina 2 no debe repetir ningun id de la pagina 1.
$page2 = Invoke-EmployeesRequest -Uri "$ApiBaseUrl/portal/employees?page=2&pageSize=5" -Headers $headers
$page1Ids = @($page1.Body | ForEach-Object { $_.id })
$overlap = @($page2.Body | Where-Object { $page1Ids -contains $_.id })
if ($overlap.Count -gt 0) {
    throw "La pagina 2 no debe repetir ids de la pagina 1."
}

# pageSize fuera de rango se recorta a 100 (no debe fallar ni devolver mas de 100).
$oversized = Invoke-EmployeesRequest -Uri "$ApiBaseUrl/portal/employees?page=1&pageSize=9999" -Headers $headers
if ($oversized.Body.Count -gt 100) {
    throw "pageSize debe limitarse a 100 como maximo, devolvio $($oversized.Body.Count)."
}

Write-Host "Employees pagination verification completed."
```

- [x] **Step 7: Ejecutar el verificador**

```bash
pwsh -File scripts/dev/Verify-SgSuperAppEmployeesPagination.ps1
```

Esperado: `Employees pagination verification completed.` sin excepciones.

- [x] **Step 8: Confirmar que el picker de Certificaciones no se rompió (regresión sin paginar)**

```bash
pwsh -File scripts/dev/Verify-SgSuperAppI2EmployeeFilters.ps1
```

Esperado: `I2 employee filter verification completed.` (este script llama `/api/portal/employees?completeness=...` sin `page`/`pageSize`, exactamente como lo hace `CertificatesPage.tsx`).

- [x] **Step 9: Confirmar en un navegador real que el header es legible desde `fetch` (CORS)**

Con el frontend en `http://localhost:3000` y sesión iniciada, en la consola del navegador (o vía `javascript_tool`):

```javascript
fetch("http://localhost:5080/api/portal/employees?page=1&pageSize=5", {
  headers: { Authorization: `Bearer ${sessionStorage.getItem("sg.superapp.sessionToken")}` }
}).then((r) => r.headers.get("X-Total-Count"))
```

Esperado: un número (string), no `null`. Si devuelve `null`, el Step 3 (CORS) no se aplicó correctamente — revisar que la API se haya reiniciado con el `Program.cs` actualizado.

- [x] **Step 10: Commit**

```bash
git add apps/sg-superapp-api/Services/PostgresPortalRepository.cs apps/sg-superapp-api/Endpoints/PortalEndpoints.cs apps/sg-superapp-api/Program.cs scripts/dev/Verify-SgSuperAppEmployeesPagination.ps1
git commit -m "feat(portal): paginacion real en GET /api/portal/employees"
```

---

## Task 2: Frontend — `fetchEmployeesPage` y listado paginado en `EmployeesPage`

**Files:**
- Modify: `apps/sg-superapp-web/src/services/portalApi.ts` (agregar `EmployeesPageResult` y `fetchEmployeesPage`, junto a `fetchEmployees` existente en la línea 352 — no se toca `fetchEmployees`)
- Modify: `apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx` (quitar etiqueta stale, estado y controles de paginación)
- Modify: `apps/sg-superapp-web/src/styles.css` (agregar `.pagination-controls`)

**Interfaces:**
- Consumes: nada de la Task 1 salvo el contrato HTTP ya confirmado (`page`/`pageSize` opcionales, header `X-Total-Count`).
- Produces: `fetchEmployeesPage(filters: { search?: string; status?: string; jobTitle?: string; completeness?: string; page: number; pageSize: number }): Promise<EmployeesPageResult>` donde `EmployeesPageResult = { items: EmployeeSummary[]; totalCount: number }`. Las Tasks 3-5 siguen usando `employees`/`selectedEmployee`/`selectedId` tal como ya existen en `EmployeesPage`.

- [x] **Step 1: Agregar `fetchEmployeesPage` en `portalApi.ts`**

Inmediatamente después de la función `fetchEmployees` existente (después de su cierre, antes de `fetchEmployeeDetail`), agregar:

```typescript
export interface EmployeesPageResult {
  items: EmployeeSummary[];
  totalCount: number;
}

export async function fetchEmployeesPage(filters: {
  search?: string;
  status?: string;
  jobTitle?: string;
  completeness?: string;
  page: number;
  pageSize: number;
}): Promise<EmployeesPageResult> {
  const params = new URLSearchParams();

  if (filters.search) {
    params.set("search", filters.search);
  }

  if (filters.status) {
    params.set("status", filters.status);
  }

  if (filters.jobTitle) {
    params.set("jobTitle", filters.jobTitle);
  }

  if (filters.completeness) {
    params.set("completeness", filters.completeness);
  }

  params.set("page", String(filters.page));
  params.set("pageSize", String(filters.pageSize));

  const response = await fetch(`${API_BASE_URL}/portal/employees?${params.toString()}`, {
    headers: getSessionHeaders()
  });

  if (!response.ok) {
    throw new PortalApiError(await readProblem(response));
  }

  const items = (await response.json()) as EmployeeSummary[];
  const totalCount = Number(response.headers.get("X-Total-Count") ?? items.length);
  return { items, totalCount };
}
```

- [x] **Step 2: Quitar la etiqueta stale y agregar estado de paginación en `EmployeesPage.tsx`**

En el import de `portalApi` (línea 2-11), agregar `fetchEmployeesPage` a la lista de imports.

Cambiar la línea 313 (`<p className="eyebrow">I2 en curso</p>`) por:

```tsx
          <p className="eyebrow">Empleados y guardas</p>
```

Agregar, junto a los demás `useState` del listado (después de `const [completeness, setCompleteness] = useState("");`):

```typescript
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);
  const [totalCount, setTotalCount] = useState(0);
  const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
```

- [x] **Step 3: Reiniciar a página 1 cuando cambian los filtros**

Agregar un efecto nuevo, antes del efecto que carga empleados:

```typescript
  useEffect(() => {
    setPage(1);
  }, [search, status, jobTitle, completeness]);
```

- [x] **Step 4: Usar `fetchEmployeesPage` en el efecto de carga y guardar el total**

Reemplazar el cuerpo de `loadEmployees` (dentro del primer `useEffect`, que hoy llama `fetchEmployees({ search, status, jobTitle, completeness })`) por:

```typescript
      try {
        const { items, totalCount: total } = await fetchEmployeesPage({ search, status, jobTitle, completeness, page, pageSize });
        if (ignore) {
          return;
        }

        setEmployees(items);
        setTotalCount(total);

        if (items.length === 0) {
          setSelectedId(null);
          setSelectedEmployee(null);
          return;
        }

        const nextId = selectedId !== null && items.some((employee) => employee.id === selectedId)
          ? selectedId
          : items[0].id;
        setSelectedId(nextId);
      } catch (error) {
        if (!ignore) {
          const message = error instanceof Error ? error.message : "No fue posible cargar empleados.";
          setErrorMessage(message);
          setEmployees([]);
          setTotalCount(0);
          setSelectedId(null);
          setSelectedEmployee(null);
        }
      } finally {
        if (!ignore) {
          setLoading(false);
        }
      }
```

Y agregar `page` y `pageSize` al arreglo de dependencias de ese `useEffect` (hoy `[search, status, jobTitle, completeness, selectedId]`):

```typescript
  }, [search, status, jobTitle, completeness, selectedId, page, pageSize]);
```

- [x] **Step 5: Agregar los controles de paginación bajo la tabla**

Dentro de `.employee-list-panel`, inmediatamente después del bloque:

```tsx
            {!loading && employees.length === 0 ? <div className="panel-empty">No hay registros para los filtros actuales.</div> : null}
          </div>
        </section>
```

(el `</div>` cierra `.employee-table`) agregar, antes del `</section>`:

```tsx
          <div className="pagination-controls">
            <button type="button" className="ghost-button" disabled={page <= 1} onClick={() => setPage((current) => current - 1)}>
              Anterior
            </button>
            <span className="muted">Página {totalCount === 0 ? 0 : page} de {totalPages}</span>
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

- [x] **Step 6: Agregar el estilo de los controles de paginación**

En `styles.css`, después del bloque `.employee-row-meta` (o cualquier punto dentro de la sección de Empleados), agregar:

```css
.pagination-controls {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-top: 1rem;
  flex-wrap: wrap;
}

.pagination-controls select {
  min-height: 40px;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--surface);
  color: var(--text);
  padding: 0 0.75rem;
}
```

- [x] **Step 7: Compilar el frontend**

```powershell
Set-Location "apps\sg-superapp-web"
node ".\node_modules\typescript\bin\tsc" -b .
node ".\node_modules\vite\bin\vite.js" build
```

Esperado: ambos comandos terminan sin errores.

- [x] **Step 8: Verificación manual en el navegador**

Con la API de la Task 1 corriendo y el frontend con HMR activo: iniciar sesión como `admin.sg`, ir a Empleados / Guardas, confirmar: el encabezado ya no dice "I2 en curso"; el listado muestra como máximo 25 filas; el indicador dice "Página 1 de N" con N > 1 (hay ~44 empleados sembrados, así que con 25 por página deben ser 2 páginas); "Anterior" está deshabilitado en la página 1; hacer clic en "Siguiente" cambia el conjunto de filas mostradas y el indicador pasa a "Página 2 de N"; cambiar el filtro de estado reinicia a "Página 1".

- [x] **Step 9: Commit**

```bash
git add apps/sg-superapp-web/src/services/portalApi.ts apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx apps/sg-superapp-web/src/styles.css
git commit -m "feat(employees): listado paginado y etiqueta de estado corregida"
```

---

## Task 3: Panel de Detalle agrupado en 4 bloques de solo lectura

**Files:**
- Modify: `apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx` (reemplazar la `dl` plana)
- Modify: `apps/sg-superapp-web/src/styles.css` (estilos de los bloques agrupados)

**Interfaces:**
- Consumes: `selectedEmployee: EmployeeDetail | null` (ya existe, sin cambios de tipo).
- Produces: ninguna interfaz nueva — es una reorganización visual del mismo `selectedEmployee`. Las Tasks 4-5 agregan los botones de acción justo antes de este bloque.

- [x] **Step 1: Reemplazar la `dl` de 12 campos por 4 bloques agrupados**

Reemplazar el elemento `<dl>...</dl>` completo (dentro de `.employee-detail`, el que va desde `<dl>` hasta su `</dl>` de cierre, con los 12 pares `dt`/`dd`) por:

```tsx
              <div className="employee-detail-groups">
                <div className="employee-detail-group">
                  <h4>Identificación</h4>
                  <dl>
                    <div>
                      <dt>Tipo y número</dt>
                      <dd>{selectedEmployee.identificationType} {selectedEmployee.identificationNumber}</dd>
                    </div>
                    <div>
                      <dt>Nombre completo</dt>
                      <dd>{selectedEmployee.fullName}</dd>
                    </div>
                  </dl>
                </div>

                <div className="employee-detail-group">
                  <h4>Situación laboral</h4>
                  <dl>
                    <div>
                      <dt>Estado laboral</dt>
                      <dd>{selectedEmployee.employmentStatus}</dd>
                    </div>
                    <div>
                      <dt>Estado registro</dt>
                      <dd>{selectedEmployee.recordStatus}</dd>
                    </div>
                    <div>
                      <dt>Cargo</dt>
                      <dd>{selectedEmployee.jobTitle}</dd>
                    </div>
                    <div>
                      <dt>Contrato</dt>
                      <dd>{selectedEmployee.contractType || "No definido"}</dd>
                    </div>
                    <div>
                      <dt>Ingreso</dt>
                      <dd>{selectedEmployee.hireDate || "No definido"}</dd>
                    </div>
                    <div>
                      <dt>Retiro</dt>
                      <dd>{selectedEmployee.terminationDate || "No aplica"}</dd>
                    </div>
                    <div>
                      <dt>Motivo retiro</dt>
                      <dd>{selectedEmployee.terminationReason || "No aplica"}</dd>
                    </div>
                  </dl>
                </div>

                <div className="employee-detail-group">
                  <h4>Puesto</h4>
                  <dl>
                    <div>
                      <dt>Puesto actual normalizado</dt>
                      <dd>{selectedEmployee.currentServicePositionName || "Sin puesto normalizado"}</dd>
                    </div>
                    <div>
                      <dt>Texto importado I2</dt>
                      <dd>{selectedEmployee.currentServicePositionText || "Sin referencia importada"}</dd>
                    </div>
                  </dl>
                </div>

                <div className="employee-detail-group">
                  <h4>Compensación</h4>
                  <dl>
                    <div>
                      <dt>Salario vigente</dt>
                      <dd>{formatCurrency(selectedEmployee.currentBaseSalary)}</dd>
                    </div>
                    <div>
                      <dt>Fuente salario</dt>
                      <dd>{selectedEmployee.salarySource}</dd>
                    </div>
                    <div>
                      <dt>Notas</dt>
                      <dd>{selectedEmployee.notes || "Sin observaciones"}</dd>
                    </div>
                  </dl>
                </div>
              </div>
```

No se toca nada de lo que sigue (`Normalización asistida`, `Historial de puestos`, `Gestión de asignación`, `Historial de cambios`, `Edición manual`) en esta tarea — eso lo mueven las Tasks 4 y 5.

- [x] **Step 2: Estilos de los bloques agrupados**

En `styles.css`, después del bloque `.employee-detail dd` (el que cierra la `dl` plana original), agregar:

```css
.employee-detail-groups {
  display: grid;
  gap: 1rem;
}

.employee-detail-group {
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 0.85rem;
}

.employee-detail-group h4 {
  margin: 0 0 0.65rem;
  color: var(--accent);
  font-size: 0.85rem;
  text-transform: uppercase;
}

.employee-detail-group dl {
  display: grid;
  gap: 0.6rem;
  margin: 0;
}

.employee-detail-group dl div {
  display: grid;
  gap: 0.2rem;
}

.employee-detail-group dt {
  color: var(--primary);
  font-size: 0.7rem;
  text-transform: uppercase;
}

.employee-detail-group dd {
  margin: 0;
}
```

- [x] **Step 3: Compilar el frontend**

```powershell
Set-Location "apps\sg-superapp-web"
node ".\node_modules\typescript\bin\tsc" -b .
node ".\node_modules\vite\bin\vite.js" build
```

- [x] **Step 4: Verificación manual**

Seleccionar un empleado en el listado y confirmar que el panel de Detalle muestra 4 bloques con encabezado propio (Identificación, Situación laboral, Puesto, Compensación) con los mismos datos que antes, y que el resto del panel (asignación, historiales, edición manual) sigue visible debajo sin cambios.

- [x] **Step 5: Commit**

```bash
git add apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx apps/sg-superapp-web/src/styles.css
git commit -m "feat(employees): panel de detalle reorganizado en bloques agrupados"
```

---

## Task 4: Componente `Modal` compartido + "Editar información" como modal

**Files:**
- Create: `apps/sg-superapp-web/src/components/Modal.tsx`
- Modify: `apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx` (botón "Editar información", estado del modal, mover el formulario de Edición manual)
- Modify: `apps/sg-superapp-web/src/styles.css` (estilos del modal)

**Interfaces:**
- Produces: `Modal({ title, onClose, children }: { title: string; onClose: () => void; children: React.ReactNode })` — componente exportado desde `apps/sg-superapp-web/src/components/Modal.tsx`. Cierra al hacer clic en el backdrop, en el botón "✕", o al presionar Escape (llamando a `onClose` en los tres casos). No gestiona estado de formulario ni bloquea el scroll del body — cada consumidor decide cuándo montarlo/desmontarlo condicionalmente.
- Consumes (Task 5): el mismo componente `Modal`, sin cambios.

- [x] **Step 1: Crear el componente `Modal`**

Crear `apps/sg-superapp-web/src/components/Modal.tsx`:

```tsx
import { useEffect } from "react";
import type { ReactNode } from "react";

interface ModalProps {
  title: string;
  onClose: () => void;
  children: ReactNode;
}

export function Modal({ title, onClose, children }: ModalProps) {
  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        onClose();
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [onClose]);

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-dialog" role="dialog" aria-modal="true" aria-label={title} onClick={(event) => event.stopPropagation()}>
        <div className="modal-header">
          <h3>{title}</h3>
          <button type="button" className="ghost-button icon-button" aria-label="Cerrar" onClick={onClose}>
            ✕
          </button>
        </div>
        <div className="modal-body">{children}</div>
      </div>
    </div>
  );
}
```

- [x] **Step 2: Estilos del modal**

En `styles.css`, agregar (por ejemplo junto a los estilos de `.notification-popover`, ya que comparten lenguaje visual):

```css
.modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.5);
  padding: 1.5rem;
}

.modal-dialog {
  width: min(560px, 100%);
  max-height: calc(100vh - 3rem);
  overflow: auto;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.28);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  border-bottom: 1px solid var(--border);
}

.modal-header h3 {
  margin: 0;
}

.modal-body {
  padding: 1rem;
}
```

- [x] **Step 3: Agregar estado del modal y una función de apertura que refresca los campos**

En `EmployeesPage.tsx`, agregar el import: `import { Modal } from "../../components/Modal";`.

Agregar estado nuevo (junto a los demás `useState` de edición):

```typescript
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [editErrorMessage, setEditErrorMessage] = useState<string | null>(null);
```

Agregar una función `openEditModal`, después de la declaración de `saveEmployee`:

```typescript
  function openEditModal() {
    if (!selectedEmployee) {
      return;
    }

    setEditFullName(selectedEmployee.fullName);
    setEditEmploymentStatus(selectedEmployee.employmentStatus);
    setEditJobTitle(selectedEmployee.jobTitle);
    setEditHireDate(selectedEmployee.hireDate || "");
    setEditTerminationDate(selectedEmployee.terminationDate || "");
    setEditTerminationReason(selectedEmployee.terminationReason || "");
    setEditContractType(selectedEmployee.contractType || "");
    setEditNotes(selectedEmployee.notes || "");
    setEditSalary(selectedEmployee.currentBaseSalary?.toString() || "");
    setEditSalaryEffectiveFrom(selectedEmployee.salaryEffectiveFrom || "");
    setEditErrorMessage(null);
    setIsEditModalOpen(true);
  }
```

- [x] **Step 4: Hacer que `saveEmployee` use el error del modal y cierre al guardar**

Reemplazar el cuerpo de `saveEmployee` (la función existente) por:

```typescript
  async function saveEmployee() {
    if (!selectedEmployee) {
      return;
    }

    setEditErrorMessage(null);
    try {
      await updateEmployee(selectedEmployee.id, {
        fullName: editFullName,
        employmentStatus: editEmploymentStatus,
        jobTitle: editJobTitle,
        hireDate: editHireDate,
        terminationDate: editTerminationDate || null,
        terminationReason: editTerminationReason || null,
        contractType: editContractType || null,
        notes: editNotes || null,
        currentBaseSalary: editSalary ? Number(editSalary) : null,
        salaryEffectiveFrom: editSalaryEffectiveFrom || null
      });
      const updated = await fetchEmployeeDetail(selectedEmployee.id);
      setSelectedEmployee(updated);
      setEmployees((current) => current.map((employee) => employee.id === updated.id ? updated : employee));
      setIsEditModalOpen(false);
    } catch (error) {
      setEditErrorMessage(error instanceof Error ? error.message : "No fue posible actualizar el empleado.");
    }
  }
```

- [x] **Step 5: Agregar el botón "Editar información" y mover el formulario al modal**

Inmediatamente antes de `<div className="employee-detail-groups">` (agregado en la Task 3), agregar el botón (solo si el usuario puede editar):

```tsx
              {user.role === "ADMIN" || user.role === "TH" ? (
                <div className="position-form-actions">
                  <button type="button" onClick={openEditModal}>Editar información</button>
                </div>
              ) : null}

```

Quitar por completo el bloque actual de "Edición manual" (el `<div className="employee-history"><h4>Edicion manual</h4>...</div>` con los `<input>`/`<select>`/`<textarea>` sueltos y el botón "Guardar cambios") y colocarlo, envuelto en `Modal` y en `.position-form`/`.position-form-actions`, justo antes del `</div>` que cierra `.employee-detail` (al final, después del bloque de "Historial de cambios"):

```tsx
              {isEditModalOpen ? (
                <Modal title="Editar información" onClose={() => setIsEditModalOpen(false)}>
                  <div className="position-form">
                    {editErrorMessage ? <p className="muted">{editErrorMessage}</p> : null}
                    <input value={editFullName} onChange={(event) => setEditFullName(event.target.value)} placeholder="Nombre completo" />
                    <select value={editEmploymentStatus} onChange={(event) => setEditEmploymentStatus(event.target.value as "ACTIVO" | "RETIRADO")}>
                      <option value="ACTIVO">Activo</option>
                      <option value="RETIRADO">Retirado</option>
                    </select>
                    <input value={editJobTitle} onChange={(event) => setEditJobTitle(event.target.value)} placeholder="Cargo" />
                    <input type="date" value={editHireDate} onChange={(event) => setEditHireDate(event.target.value)} />
                    <input type="date" value={editTerminationDate} onChange={(event) => setEditTerminationDate(event.target.value)} />
                    <input value={editTerminationReason} onChange={(event) => setEditTerminationReason(event.target.value)} placeholder="Motivo de retiro" />
                    <input value={editContractType} onChange={(event) => setEditContractType(event.target.value)} placeholder="Tipo de contrato" />
                    <textarea value={editNotes} onChange={(event) => setEditNotes(event.target.value)} placeholder="Observaciones" />
                    <input type="number" min="0" value={editSalary} onChange={(event) => setEditSalary(event.target.value)} placeholder="Salario base" />
                    <input type="date" value={editSalaryEffectiveFrom} onChange={(event) => setEditSalaryEffectiveFrom(event.target.value)} />
                    <div className="position-form-actions">
                      <button type="button" onClick={() => void saveEmployee()}>Guardar cambios</button>
                    </div>
                  </div>
                </Modal>
              ) : null}
```

- [x] **Step 6: Compilar el frontend**

```powershell
Set-Location "apps\sg-superapp-web"
node ".\node_modules\typescript\bin\tsc" -b .
node ".\node_modules\vite\bin\vite.js" build
```

- [x] **Step 7: Verificación manual**

Con sesión `admin.sg` o `th.sg`: seleccionar un empleado, clic en "Editar información" — debe abrir un modal centrado con fondo oscurecido, con el formulario mostrando los mismos estilos que ya usa "Asignar puesto" (inputs con borde y fondo, no controles crudos del navegador). Cerrar con "✕", reabrir y cerrar con clic fuera del modal, reabrir y cerrar con Escape. Reabrir, cambiar el salario, guardar — el modal debe cerrarse solo y el bloque "Compensación" del resumen debe reflejar el nuevo valor sin recargar la página.

- [x] **Step 8: Commit**

```bash
git add apps/sg-superapp-web/src/components/Modal.tsx apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx apps/sg-superapp-web/src/styles.css
git commit -m "feat(employees): componente Modal compartido y edicion de empleado en modal"
```

---

## Task 5: "Gestionar asignación" como modal

**Files:**
- Modify: `apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx`

**Interfaces:**
- Consumes: `Modal` de la Task 4, sin cambios.

- [x] **Step 1: Agregar estado del modal de asignación**

Junto al estado agregado en la Task 4:

```typescript
  const [isAssignmentModalOpen, setIsAssignmentModalOpen] = useState(false);
```

Agregar una función `openAssignmentModal`, cerca de `openEditModal`:

```typescript
  function openAssignmentModal() {
    setAssignmentMessage(null);
    setIsAssignmentModalOpen(true);
  }
```

- [x] **Step 2: Cerrar el modal cuando una acción de asignación termina con éxito**

En `assignPosition`, después de la línea `setAssignmentMessage("Asignacion creada.");`, agregar:

```typescript
      setIsAssignmentModalOpen(false);
```

En `finalizeCurrentAssignment`, después de la línea `setAssignmentMessage("Asignacion finalizada.");`, agregar:

```typescript
      setIsAssignmentModalOpen(false);
```

- [x] **Step 3: Agregar el botón "Gestionar asignación" y envolver el formulario existente en el modal**

Inmediatamente después del bloque `.position-form-actions` del botón "Editar información" agregado en la Task 4, en un `.position-form-actions` propio (se mantienen como dos grupos de acción separados, no un solo `<div>` compartido), si `canManageAssignments` es verdadero:

```tsx
              {canManageAssignments ? (
                <div className="position-form-actions">
                  <button type="button" onClick={openAssignmentModal}>Gestionar asignación</button>
                </div>
              ) : null}
```

Quitar el `<div className="employee-history"><h4>Gestion de asignacion</h4>...</div>` de su ubicación actual (entre "Historial de puestos" e "Historial de cambios") y colocar su contenido, sin cambios internos, envuelto en `Modal`, junto al modal de edición (después de él, dentro de `.employee-detail`):

```tsx
              {isAssignmentModalOpen ? (
                <Modal title="Gestionar asignación" onClose={() => setIsAssignmentModalOpen(false)}>
                  {assignmentMessage ? <p className="muted">{assignmentMessage}</p> : null}
                  {currentAssignment ? (
                    <div className="position-form">
                      <p className="muted">Para asignar otro puesto primero finalice la asignacion vigente.</p>
                      <input type="date" value={finalizeEndDate} onChange={(event) => setFinalizeEndDate(event.target.value)} />
                      <input value={finalizeReason} onChange={(event) => setFinalizeReason(event.target.value)} placeholder="Motivo de cierre opcional" />
                      <textarea value={finalizeNotes} onChange={(event) => setFinalizeNotes(event.target.value)} placeholder="Notas opcionales" />
                      <div className="position-form-actions">
                        <button type="button" disabled={assignmentPending} onClick={() => void finalizeCurrentAssignment()}>
                          Finalizar asignacion
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="position-form">
                      <select value={assignmentPositionId} onChange={(event) => setAssignmentPositionId(event.target.value)}>
                        <option value="">Seleccione puesto activo</option>
                        {availablePositions.map((position) => (
                          <option key={position.id} value={position.id}>
                            {position.name} {position.code ? `(${position.code})` : ""}
                          </option>
                        ))}
                      </select>
                      <input type="date" value={assignmentStartDate} onChange={(event) => setAssignmentStartDate(event.target.value)} />
                      <input value={assignmentReason} onChange={(event) => setAssignmentReason(event.target.value)} placeholder="Motivo opcional" />
                      <textarea value={assignmentNotes} onChange={(event) => setAssignmentNotes(event.target.value)} placeholder="Notas opcionales" />
                      <div className="position-form-actions">
                        <button type="button" disabled={assignmentPending} onClick={() => void assignPosition()}>
                          Asignar puesto
                        </button>
                      </div>
                    </div>
                  )}
                </Modal>
              ) : null}
```

- [x] **Step 4: Compilar el frontend**

```powershell
Set-Location "apps\sg-superapp-web"
node ".\node_modules\typescript\bin\tsc" -b .
node ".\node_modules\vite\bin\vite.js" build
```

- [x] **Step 5: Verificación manual**

Seleccionar un empleado sin asignación vigente, clic en "Gestionar asignación" — debe abrir el modal con el formulario "Asignar puesto"; completar y guardar — el modal se cierra, "Historial de puestos" muestra la nueva asignación vigente. Reabrir "Gestionar asignación" — ahora debe mostrar "Finalizar asignación" (porque ya hay una vigente); finalizarla y confirmar que el modal se cierra y el historial refleja el cambio.

- [x] **Step 6: Commit**

```bash
git add apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx
git commit -m "feat(employees): gestion de asignacion como modal"
```

---

## Task 6: Cierre — build completo, regresión y registro de ejecución

**Files:**
- Modify: `docs/superpowers/plans/2026-09-12-sg-empleados-ux-paginacion-modales-plan.md` (este archivo — agregar sección de Execution Log al final)

**Interfaces:** Ninguna — tarea de verificación y documentación.

- [x] **Step 1: Build completo de backend y frontend**

```powershell
$env:DOTNET_CLI_HOME = "C:\tmp\dotnet-home"
& "C:\tmp\dotnet6\dotnet.exe" build "apps\sg-superapp-api\sg-superapp-api.csproj"
Set-Location "apps\sg-superapp-web"
node ".\node_modules\typescript\bin\tsc" -b .
node ".\node_modules\vite\bin\vite.js" build
```

Esperado: los tres comandos terminan sin errores.

- [x] **Step 2: Ejecutar los verificadores relacionados**

```bash
pwsh -File scripts/dev/Verify-SgSuperAppEmployeesPagination.ps1
pwsh -File scripts/dev/Verify-SgSuperAppI2EmployeeFilters.ps1
pwsh -File scripts/dev/Verify-SgSuperAppI2EmployeeEditing.ps1
pwsh -File scripts/dev/Verify-SgSuperAppI2EmployeeHistory.ps1
```

Esperado: los cuatro terminan con su mensaje de "...verification completed." sin excepciones.

- [x] **Step 3: Recorrido manual final end-to-end**

Con sesión `admin.sg`: navegar a Empleados / Guardas; confirmar encabezado sin "I2 en curso"; paginar entre página 1 y 2; seleccionar un empleado y confirmar los 4 bloques del resumen; abrir "Editar información", cambiar un campo, guardar, confirmar que el resumen se actualiza; abrir "Gestionar asignación" y confirmar que muestra la opción correcta (asignar o finalizar) según el estado actual; probar el cierre de ambos modales por las tres vías; probar en viewport 375px que ningún modal se desborda.

- [x] **Step 4: Agregar el registro de ejecución a este plan**

Agregar al final de este archivo la sección `## Execution Log`.

- [x] **Step 5: Commit final**

```bash
git add docs/superpowers/plans/2026-09-12-sg-empleados-ux-paginacion-modales-plan.md
git commit -m "docs(plan): cerrar registro de ejecucion - UX empleados paginacion y modales"
```

---

## Execution Log

### 2026-09-12 - Implementación cerrada

- Backend: paginación aditiva en `GetEmployeesAsync`/`GET /api/portal/employees`
  (`page`/`pageSize` opcionales, header `X-Total-Count`, expuesto en CORS).
- Frontend: `fetchEmployeesPage` nuevo (sin tocar `fetchEmployees`, usado sin
  cambios por el picker de Certificaciones); listado con controles de
  paginación; etiqueta "I2 en curso" retirada; panel de Detalle reorganizado
  en 4 bloques agrupados; componente `Modal` compartido nuevo
  (`components/Modal.tsx`); "Editar información" y "Gestionar asignación"
  migrados a modales centrados.
- GREEN: `Verify-SgSuperAppEmployeesPagination.ps1`,
  `Verify-SgSuperAppI2EmployeeFilters.ps1`,
  `Verify-SgSuperAppI2EmployeeHistory.ps1`.
- EXCLUDED: `Verify-SgSuperAppI2EmployeeEditing.ps1` — stale I2-era test that
  asserts ADMIN should get 403 on employee edits, but
  `db/seeds/004_i2_security_users_permissions.sql:35` correctly grants ADMIN
  that permission (matching TH on line 40). Pre-existing test/seed mismatch
  unrelated to this plan; worth a separate fix outside this scope.
- Backend build y frontend build (`tsc -b` + `vite build`) sin errores.
- Recorrido manual completo en navegador (admin.sg login, page 1 y 2,
  4 detail blocks, edit flow with save+refresh, assignment modal, close via
  button/backdrop/Escape, 375px viewport responsive), incluyendo 375px.
