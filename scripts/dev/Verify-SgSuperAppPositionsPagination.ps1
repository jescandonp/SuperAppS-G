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

$unpaged = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions" -Headers $headers
if ($unpaged.Body.Count -ne $unpaged.TotalCount) {
    throw "Sin parametros de paginacion, el arreglo completo debe tener el mismo tamano que X-Total-Count. Arreglo: $($unpaged.Body.Count), Total: $($unpaged.TotalCount)."
}

if ($unpaged.Body.Count -lt 2) {
    Write-Output "POSITIONS PAGINATION BLOCKED: se necesitan al menos 2 puestos en la base de datos para ejercitar paginacion real."
    exit 2
}

if ($unpaged.Body.Count -lt 101) {
    Write-Output "POSITIONS PAGINATION BLOCKED: se necesitan al menos 101 puestos en la base de datos para verificar que pageSize=9999 se limite a 100."
    exit 2
}

$page1 = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?page=1&pageSize=1" -Headers $headers
if ($page1.Body.Count -ne 1) {
    throw "La pagina 1 con pageSize=1 debio traer un registro, trajo $($page1.Body.Count)."
}
if ($page1.TotalCount -ne $unpaged.TotalCount) {
    throw "El total con paginacion ($($page1.TotalCount)) debe coincidir con el total sin paginar ($($unpaged.TotalCount))."
}

$page2 = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?page=2&pageSize=1" -Headers $headers
if ($page2.Body.Count -ne 1) {
    throw "La pagina 2 con pageSize=1 debio traer un registro, trajo $($page2.Body.Count)."
}
if ($page2.Body[0].id -eq $page1.Body[0].id) {
    throw "La pagina 2 no debe repetir el id de la pagina 1."
}

$oversized = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?page=1&pageSize=9999" -Headers $headers
if ($oversized.Body.Count -ne 100) {
    throw "Con al menos 101 puestos, pageSize debe limitarse a 100. Devolvio $($oversized.Body.Count) registros."
}
if ($oversized.TotalCount -ne $unpaged.TotalCount) {
    throw "El total con pageSize fuera de rango ($($oversized.TotalCount)) debe coincidir con el total sin paginar ($($unpaged.TotalCount))."
}

$hugePage = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?page=99999999&pageSize=5" -Headers $headers
if ($hugePage.Status -ne 200) {
    throw "Un page absurdamente grande debe devolver 200, devolvio $($hugePage.Status)."
}
if ($hugePage.Body.Count -ne 0) {
    throw "Un page absurdamente grande debe devolver un arreglo vacio, devolvio $($hugePage.Body.Count) registros."
}

$pageOnly = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?page=2" -Headers $headers
if ($pageOnly.Status -ne 200) {
    throw "page sin pageSize debe devolver 200, devolvio $($pageOnly.Status)."
}
if ($pageOnly.Body.Count -ne $unpaged.Body.Count) {
    throw "page=2 sin pageSize debe devolver el arreglo completo. Arreglo: $($pageOnly.Body.Count), esperado: $($unpaged.Body.Count)."
}
if ($pageOnly.TotalCount -ne $unpaged.TotalCount) {
    throw "El total con page=2 sin pageSize ($($pageOnly.TotalCount)) debe coincidir con el total sin paginar ($($unpaged.TotalCount))."
}

$activeUnpaged = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?status=ACTIVO" -Headers $headers
$activePaged = Invoke-PositionsRequest -Uri "$ApiBaseUrl/portal/positions?status=ACTIVO&page=1&pageSize=1" -Headers $headers
if ($activeUnpaged.Body.Count -eq 0) {
    Write-Output "POSITIONS PAGINATION BLOCKED: se necesita al menos un puesto ACTIVO en la base de datos para verificar la paginacion filtrada."
    exit 2
}
if ($activeUnpaged.Body.Count -ne $activeUnpaged.TotalCount) {
    throw "Con status=ACTIVO sin paginar, el arreglo debe tener el mismo tamano que X-Total-Count. Arreglo: $($activeUnpaged.Body.Count), Total: $($activeUnpaged.TotalCount)."
}
foreach ($activePosition in @($activeUnpaged.Body)) {
    if ($activePosition.status -ne "ACTIVO") {
        throw "La consulta sin paginar con status=ACTIVO no debe incluir puestos con estado '$($activePosition.status)'."
    }
}
if ($activePaged.Body.Count -ne 1) {
    throw "Con al menos un puesto ACTIVO, la pagina 1 con pageSize=1 debe devolver exactamente un registro. Devolvio $($activePaged.Body.Count)."
}
foreach ($activePosition in @($activePaged.Body)) {
    if ($activePosition.status -ne "ACTIVO") {
        throw "La consulta paginada con status=ACTIVO no debe incluir puestos con estado '$($activePosition.status)'."
    }
}
if ($activePaged.TotalCount -ne $activeUnpaged.TotalCount) {
    throw "Con status=ACTIVO, el total paginado ($($activePaged.TotalCount)) debe coincidir con el total sin paginar ($($activeUnpaged.TotalCount))."
}

Write-Output "POSITIONS PAGINATION PASS"
