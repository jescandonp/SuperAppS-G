param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me",
    [string]$DatabaseName = "sg_superapp_dev"
)

$ErrorActionPreference = "Stop"

$psqlExe = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$originalPassword = $env:PGPASSWORD
$env:PGPASSWORD = $AppPassword
$employeeIdentification = "I5-STATUS-EMPLOYEE"
$typeCode = "I5-STATUS-TYPE"
$today = [DateTime]::Today

function Invoke-Postgres {
    param([string]$Sql)
    $output = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -t -A -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
    $lines = @($output | Where-Object { $_ -match '\S' })
    $scalar = @($lines | Where-Object { $_ -match '^\d+$' } | Select-Object -Last 1)
    if ($scalar.Count -gt 0) { return $scalar[0] }
    return @($lines | Select-Object -Last 1)
}

function Get-SessionHeaders {
    param([string]$Username, [string]$Password)
    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($response.sessionToken)" }
}

function Invoke-JsonRequest {
    param([string]$Method, [string]$Uri, [hashtable]$Headers, [object]$Body = $null)
    try {
        $parameters = @{ Uri = $Uri; Method = $Method; Headers = $Headers; UseBasicParsing = $true }
        if ($null -ne $Body) {
            $parameters.ContentType = "application/json"
            $parameters.Body = ($Body | ConvertTo-Json)
        }
        $response = Invoke-WebRequest @parameters
        return @{ Status = [int]$response.StatusCode; Body = ($response.Content | ConvertFrom-Json) }
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw }
        return @{ Status = [int]$_.Exception.Response.StatusCode; Body = $null }
    }
}

function Assert-Status {
    param([hashtable]$Response, [int]$ExpectedStatus, [string]$Message)
    if ($Response.Status -ne $ExpectedStatus) {
        throw "$Message Expected HTTP $ExpectedStatus, received $($Response.Status)."
    }
}

function Assert-CalculatedStatus {
    param([long]$EmployeeId, [long]$TypeId, [hashtable]$Headers, [int]$DaysFromToday, [string]$ExpectedStatus)
    $completedAt = $today.AddDays(-10).ToString("yyyy-MM-dd")
    $expiresAt = $today.AddDays($DaysFromToday).ToString("yyyy-MM-dd")
    $response = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/employees/$EmployeeId/training" -Headers $Headers -Body @{
        requirementTypeId = $TypeId
        completedAt = $completedAt
        expiresAt = $expiresAt
        supportPath = $null
        notes = "Estado esperado $ExpectedStatus"
    }
    Assert-Status -Response $response -ExpectedStatus 200 -Message "Renewal for $ExpectedStatus must be accepted."
    if ($response.Body.complianceStatus -ne $ExpectedStatus) {
        throw "Expected complianceStatus $ExpectedStatus, received '$($response.Body.complianceStatus)'."
    }
    if ($response.Body.daysUntilExpiry -ne $DaysFromToday) {
        throw "Expected daysUntilExpiry $DaysFromToday, received '$($response.Body.daysUntilExpiry)'."
    }
}

try {
    Invoke-Postgres "DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM training_requirement_types WHERE code = '$typeCode';" | Out-Null
    $employeeId = [long](Invoke-Postgres "INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date) VALUES ('CC', '$employeeIdentification', 'Empleado I5 Estados', 'ACTIVO', 'Guarda', CURRENT_DATE - 120) RETURNING id;")
    $typeId = [long](Invoke-Postgres "INSERT INTO training_requirement_types (code, name, category, validity_days, is_service_required) VALUES ('$typeCode', 'Tipo estados I5', 'CURSO', null, true) RETURNING id;")
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"

    Assert-CalculatedStatus -EmployeeId $employeeId -TypeId $typeId -Headers $thHeaders -DaysFromToday -1 -ExpectedStatus "VENCIDO"
    Assert-CalculatedStatus -EmployeeId $employeeId -TypeId $typeId -Headers $thHeaders -DaysFromToday 0 -ExpectedStatus "CRITICO"
    Assert-CalculatedStatus -EmployeeId $employeeId -TypeId $typeId -Headers $thHeaders -DaysFromToday 15 -ExpectedStatus "CRITICO"
    Assert-CalculatedStatus -EmployeeId $employeeId -TypeId $typeId -Headers $thHeaders -DaysFromToday 16 -ExpectedStatus "PREVENTIVO"
    Assert-CalculatedStatus -EmployeeId $employeeId -TypeId $typeId -Headers $thHeaders -DaysFromToday 30 -ExpectedStatus "PREVENTIVO"
    Assert-CalculatedStatus -EmployeeId $employeeId -TypeId $typeId -Headers $thHeaders -DaysFromToday 31 -ExpectedStatus "INFORMATIVO"
    Assert-CalculatedStatus -EmployeeId $employeeId -TypeId $typeId -Headers $thHeaders -DaysFromToday 60 -ExpectedStatus "INFORMATIVO"
    Assert-CalculatedStatus -EmployeeId $employeeId -TypeId $typeId -Headers $thHeaders -DaysFromToday 61 -ExpectedStatus "AL_DIA"

    Write-Host "I5 status rules verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employee_training_records WHERE employee_id IN (SELECT id FROM employees WHERE identification_number = '$employeeIdentification'); DELETE FROM employees WHERE identification_number = '$employeeIdentification'; DELETE FROM training_requirement_types WHERE code = '$typeCode';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
