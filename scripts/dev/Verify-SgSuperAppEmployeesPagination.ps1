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
if ($oversized.TotalCount -ne $unpaged.TotalCount) {
    throw "El total con pageSize fuera de rango ($($oversized.TotalCount)) debe coincidir con el total sin paginar ($($unpaged.TotalCount))."
}

# page absurdamente grande no debe causar overflow de int32 (offset negativo) ni un 500;
# debe recortarse a un maximo interno y devolver una pagina vacia con status 200.
$hugePage = Invoke-EmployeesRequest -Uri "$ApiBaseUrl/portal/employees?page=99999999&pageSize=5" -Headers $headers
if ($hugePage.Status -ne 200) {
    throw "Un page absurdamente grande debe devolver 200, devolvio $($hugePage.Status)."
}
if ($hugePage.Body.Count -ne 0) {
    throw "Un page absurdamente grande (mas alla del total de registros) debe devolver un arreglo vacio, devolvio $($hugePage.Body.Count) registros."
}

# page sin pageSize no debe causar overflow de int32 ni truncar: pageSize se resuelve al
# sentinel "sin limite" (int.MaxValue), por lo que page se ignora y se fuerza a 1, devolviendo
# el arreglo completo igual que sin parametros.
$pageOnly = Invoke-EmployeesRequest -Uri "$ApiBaseUrl/portal/employees?page=2" -Headers $headers
if ($pageOnly.Status -ne 200) {
    throw "page sin pageSize debe devolver 200, devolvio $($pageOnly.Status)."
}
if ($pageOnly.Body.Count -ne $unpaged.Body.Count) {
    throw "page=2 sin pageSize debe devolver el arreglo completo (identico a sin parametros). Arreglo: $($pageOnly.Body.Count), esperado: $($unpaged.Body.Count)."
}
if ($pageOnly.TotalCount -ne $unpaged.TotalCount) {
    throw "El total con page=2 sin pageSize ($($pageOnly.TotalCount)) debe coincidir con el total sin paginar ($($unpaged.TotalCount))."
}

Write-Host "Employees pagination verification completed."
