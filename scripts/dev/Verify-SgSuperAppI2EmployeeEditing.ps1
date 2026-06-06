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
$testIdentification = "I2-EDIT-TEST"

function Invoke-Postgres {
    param([string]$Sql)

    & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -c $Sql | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL command failed."
    }
}

function Get-SessionHeaders {
    param([string]$Username, [string]$Password)

    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($response.sessionToken)" }
}

function Assert-UpdateStatus {
    param([long]$EmployeeId, [hashtable]$Headers, [int]$ExpectedStatus, [string]$JobTitle)

    $body = @{
        fullName = "Empleado Edicion I2"
        employmentStatus = "ACTIVO"
        jobTitle = $JobTitle
        hireDate = "2026-01-01"
        terminationDate = $null
        terminationReason = $null
        contractType = "Termino fijo"
        notes = "Edicion controlada Task 4"
        currentBaseSalary = $null
        salaryEffectiveFrom = $null
    } | ConvertTo-Json
    try {
        Invoke-WebRequest -Uri "$ApiBaseUrl/portal/employees/$EmployeeId" -Method Put -Headers $Headers -ContentType "application/json" -Body $body -UseBasicParsing | Out-Null
        $actualStatus = 200
    }
    catch {
        if ($null -eq $_.Exception.Response) {
            throw
        }

        $actualStatus = [int]$_.Exception.Response.StatusCode
    }

    if ($actualStatus -ne $ExpectedStatus) {
        throw "Expected HTTP $ExpectedStatus for employee update, received $actualStatus."
    }
}

try {
    Invoke-Postgres @"
INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, notes, record_status, source)
VALUES ('CC', '$testIdentification', 'Empleado Edicion I2', 'ACTIVO', 'Guarda', DATE '2026-01-01', 'Antes de editar', 'ACTIVO', 'TEST')
ON CONFLICT (identification_type, identification_number) DO UPDATE SET job_title = 'Guarda', notes = 'Antes de editar';
"@

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"
    $employee = @(Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees?search=$testIdentification" -Headers $thHeaders)[0]

    Assert-UpdateStatus -EmployeeId $employee.id -Headers $adminHeaders -ExpectedStatus 403 -JobTitle "No autorizado ADMIN"
    Assert-UpdateStatus -EmployeeId $employee.id -Headers $gerenciaHeaders -ExpectedStatus 403 -JobTitle "No autorizado GERENCIA"
    Assert-UpdateStatus -EmployeeId $employee.id -Headers $operacionesHeaders -ExpectedStatus 403 -JobTitle "No autorizado OPERACIONES"
    Assert-UpdateStatus -EmployeeId $employee.id -Headers $thHeaders -ExpectedStatus 200 -JobTitle "Guarda Senior"

    $detail = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees/$($employee.id)" -Headers $thHeaders
    if ($detail.jobTitle -ne "Guarda Senior") {
        throw "TH employee update was not persisted."
    }

    $jobTitleChange = @($detail.changeHistory | Where-Object { $_.fieldName -eq "job_title" -and $_.actorUsername -eq "th.sg" })
    if ($jobTitleChange.Count -ne 1 -or $jobTitleChange[0].previousValue -ne "Guarda" -or $jobTitleChange[0].newValue -ne "Guarda Senior") {
        throw "TH employee update must audit previous and new values."
    }

    Write-Host "I2 employee editing verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employees WHERE identification_type = 'CC' AND identification_number = '$testIdentification';"
    $env:PGPASSWORD = $originalPassword
}
