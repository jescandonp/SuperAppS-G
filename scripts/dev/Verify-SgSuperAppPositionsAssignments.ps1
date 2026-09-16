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

function Invoke-PositionAssignmentRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers,
        [object]$Body = $null
    )

    try {
        $parameters = @{
            Uri = $Uri
            Method = $Method
            Headers = $Headers
            UseBasicParsing = $true
        }

        if ($null -ne $Body) {
            $parameters.ContentType = "application/json"
            $parameters.Body = ($Body | ConvertTo-Json)
        }

        $response = Invoke-WebRequest @parameters
        $totalCountRaw = $response.Headers["X-Total-Count"]
        return @{
            Status = [int]$response.StatusCode
            Body = ($response.Content | ConvertFrom-Json)
            TotalCount = if ([string]::IsNullOrWhiteSpace("$totalCountRaw")) { $null } else { [int]("$totalCountRaw") }
        }
    }
    catch {
        if ($null -eq $_.Exception.Response) {
            throw
        }

        return @{ Status = [int]$_.Exception.Response.StatusCode; Body = $null; TotalCount = $null }
    }
}

function Assert-Status {
    param([hashtable]$Response, [int]$ExpectedStatus, [string]$Message)

    if ($Response.Status -ne $ExpectedStatus) {
        throw "$Message Expected HTTP $ExpectedStatus, received $($Response.Status)."
    }
}

$headers = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
$activePositions = Invoke-PositionAssignmentRequest -Method "GET" -Uri "$ApiBaseUrl/portal/positions?status=ACTIVO" -Headers $headers
Assert-Status -Response $activePositions -ExpectedStatus 200 -Message "TH must list active positions."

if (@($activePositions.Body).Count -eq 0) {
    Write-Output "POSITIONS ASSIGNMENTS BLOCKED: no hay puestos ACTIVOS en la base de datos."
    exit 2
}

$position = @($activePositions.Body)[0]
$employeePageSize = 100
$firstActiveEmployees = Invoke-PositionAssignmentRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees?status=ACTIVO&page=1&pageSize=$employeePageSize" -Headers $headers
Assert-Status -Response $firstActiveEmployees -ExpectedStatus 200 -Message "TH must list active employees."
if ($null -eq $firstActiveEmployees.TotalCount -or $firstActiveEmployees.TotalCount -lt @($firstActiveEmployees.Body).Count) {
    throw "La respuesta paginada de empleados ACTIVOS debe incluir un X-Total-Count consistente para recorrer todas las paginas."
}

$freeEmployee = $null
$activeEmployeePageCount = [int][Math]::Ceiling($firstActiveEmployees.TotalCount / [double]$employeePageSize)
for ($page = 1; $page -le $activeEmployeePageCount -and $null -eq $freeEmployee; $page++) {
    if ($page -eq 1) {
        $activeEmployees = $firstActiveEmployees
    }
    else {
        $activeEmployees = Invoke-PositionAssignmentRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees?status=ACTIVO&page=$page&pageSize=$employeePageSize" -Headers $headers
        Assert-Status -Response $activeEmployees -ExpectedStatus 200 -Message "TH must list active employees on every page."
        if ($activeEmployees.TotalCount -ne $firstActiveEmployees.TotalCount) {
            throw "El X-Total-Count de empleados ACTIVOS cambio durante la verificacion; no se puede afirmar que se recorrio el conjunto completo."
        }
    }

    foreach ($employee in @($activeEmployees.Body)) {
        $employeeAssignments = Invoke-PositionAssignmentRequest -Method "GET" -Uri "$ApiBaseUrl/portal/employees/$($employee.id)/position-assignments" -Headers $headers
        Assert-Status -Response $employeeAssignments -ExpectedStatus 200 -Message "TH must read employee assignment history."

        $currentAssignment = @($employeeAssignments.Body | Where-Object { $_.status -eq "VIGENTE" })
        if ($currentAssignment.Count -eq 0) {
            $freeEmployee = $employee
            break
        }
    }
}

if ($null -eq $freeEmployee) {
    Write-Output "POSITIONS ASSIGNMENTS BLOCKED: no se encontro un empleado ACTIVO sin asignacion vigente despues de revisar todas las paginas."
    exit 2
}

$today = (Get-Date).ToString("yyyy-MM-dd")
$create = Invoke-PositionAssignmentRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$($freeEmployee.id)/position-assignments" -Headers $headers -Body @{
    positionId = $position.id
    startDate = $today
    changeReason = $null
    notes = $null
}
Assert-Status -Response $create -ExpectedStatus 200 -Message "TH must create an employee assignment."

if ($create.Body.employeeFullName -ne $freeEmployee.fullName -or $create.Body.status -ne "VIGENTE") {
    throw "La asignacion creada debe retornar employeeFullName del empleado y estado VIGENTE."
}

$created = $create.Body
$positionAssignments = Invoke-PositionAssignmentRequest -Method "GET" -Uri "$ApiBaseUrl/portal/positions/$($position.id)/assignments" -Headers $headers
Assert-Status -Response $positionAssignments -ExpectedStatus 200 -Message "TH must read position assignments."
$createdInPosition = @($positionAssignments.Body | Where-Object { $_.id -eq $created.id })
if ($createdInPosition.Count -ne 1 -or $createdInPosition[0].employeeFullName -ne $freeEmployee.fullName) {
    throw "La asignacion creada debe aparecer exactamente una vez en las asignaciones del puesto con employeeFullName correcto."
}

$duplicate = Invoke-PositionAssignmentRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$($freeEmployee.id)/position-assignments" -Headers $headers -Body @{
    positionId = $position.id
    startDate = $today
    changeReason = $null
    notes = $null
}
Assert-Status -Response $duplicate -ExpectedStatus 409 -Message "Repetir una asignacion vigente del mismo empleado debe ser rechazado."

$finalize = Invoke-PositionAssignmentRequest -Method "POST" -Uri "$ApiBaseUrl/portal/position-assignments/$($created.id)/finalize" -Headers $headers -Body @{
    endDate = $today
    changeReason = "Verificacion automatizada"
    notes = $null
}
Assert-Status -Response $finalize -ExpectedStatus 200 -Message "TH must finalize the assignment."
if ($finalize.Body.status -ne "FINALIZADA" -or $finalize.Body.employeeFullName -ne $freeEmployee.fullName) {
    throw "La asignacion finalizada debe retornar employeeFullName del empleado y estado FINALIZADA."
}

$positionAssignmentsAfterFinalize = Invoke-PositionAssignmentRequest -Method "GET" -Uri "$ApiBaseUrl/portal/positions/$($position.id)/assignments" -Headers $headers
Assert-Status -Response $positionAssignmentsAfterFinalize -ExpectedStatus 200 -Message "TH must read position assignments after finalizing."
$createdAfterFinalize = @($positionAssignmentsAfterFinalize.Body | Where-Object { $_.id -eq $created.id })
if ($createdAfterFinalize.Count -ne 1 -or $createdAfterFinalize[0].status -eq "VIGENTE") {
    throw "La asignacion creada ya no debe estar VIGENTE despues de finalizarla."
}

$inactivePositions = Invoke-PositionAssignmentRequest -Method "GET" -Uri "$ApiBaseUrl/portal/positions?status=INACTIVO" -Headers $headers
Assert-Status -Response $inactivePositions -ExpectedStatus 200 -Message "TH must list inactive positions."
if (@($inactivePositions.Body).Count -gt 0) {
    $inactiveAttempt = Invoke-PositionAssignmentRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$($freeEmployee.id)/position-assignments" -Headers $headers -Body @{
        positionId = @($inactivePositions.Body)[0].id
        startDate = $today
        changeReason = $null
        notes = $null
    }
    Assert-Status -Response $inactiveAttempt -ExpectedStatus 409 -Message "Inactive positions must be rejected."
}
else {
    Write-Output "POSITIONS ASSIGNMENTS: sin puestos INACTIVOS en la base de datos, se omite el chequeo de INACTIVE_POSITION."
}

Write-Output "POSITIONS ASSIGNMENTS PASS"
