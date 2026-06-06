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
$testIdentification = "I2-SALARY-TEST"

function Invoke-Postgres {
    param([string]$Sql)
    $result = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -t -A -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
    return ($result | Select-Object -First 1)
}

function Get-ThHeaders {
    $body = @{ username = "th.sg"; password = "Th123456" } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($response.sessionToken)" }
}

try {
    Invoke-Postgres @"
INSERT INTO employees (identification_type, identification_number, full_name, employment_status, job_title, hire_date, record_status, source)
VALUES ('CC', '$testIdentification', 'Empleado Salario I2', 'ACTIVO', 'Guarda', DATE '2026-01-01', 'ACTIVO', 'TEST')
ON CONFLICT (identification_type, identification_number) DO NOTHING;
INSERT INTO employee_salary_history (employee_id, base_salary_amount, effective_from, source)
SELECT id, 1000000, DATE '2026-01-01', 'TEST' FROM employees
WHERE identification_type = 'CC' AND identification_number = '$testIdentification'
  AND NOT EXISTS (SELECT 1 FROM employee_salary_history s WHERE s.employee_id = employees.id);
"@ | Out-Null

    $headers = Get-ThHeaders
    $employee = @(Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees?search=$testIdentification" -Headers $headers)[0]
    $invalidBody = @{
        fullName = "Empleado Salario I2"
        employmentStatus = "RETIRADO"
        jobTitle = "Guarda"
        hireDate = "2026-02-01"
        terminationDate = "2026-01-01"
        terminationReason = "Fecha invalida"
        contractType = "Termino fijo"
        notes = $null
        currentBaseSalary = $null
        salaryEffectiveFrom = $null
    } | ConvertTo-Json
    try {
        Invoke-WebRequest -Uri "$ApiBaseUrl/portal/employees/$($employee.id)" -Method Put -Headers $headers -ContentType "application/json" -Body $invalidBody -UseBasicParsing | Out-Null
        $invalidStatus = 200
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw }
        $invalidStatus = [int]$_.Exception.Response.StatusCode
    }
    if ($invalidStatus -ne 400) {
        throw "Invalid labor edit must return HTTP 400, received $invalidStatus."
    }

    $body = @{
        fullName = "Empleado Salario I2"
        employmentStatus = "RETIRADO"
        jobTitle = "Guarda Senior"
        hireDate = "2026-01-01"
        terminationDate = "2026-02-15"
        terminationReason = "Fin de contrato"
        contractType = "Termino fijo"
        notes = "Retiro controlado"
        currentBaseSalary = 1200000
        salaryEffectiveFrom = "2026-02-01"
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees/$($employee.id)" -Method Put -Headers $headers -ContentType "application/json" -Body $body | Out-Null
    $detail = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees/$($employee.id)" -Headers $headers

    if ($detail.employmentStatus -ne "RETIRADO" -or $detail.terminationReason -ne "Fin de contrato" -or $detail.contractType -ne "Termino fijo") {
        throw "Complete labor fields were not persisted."
    }
    if ($detail.currentBaseSalary -ne 1200000 -or $detail.salaryEffectiveFrom -ne "2026-02-01") {
        throw "New salary version was not exposed as current."
    }

    $salaryPeriods = Invoke-Postgres "SELECT string_agg(base_salary_amount::text || ':' || effective_from::text || ':' || coalesce(effective_to::text, 'OPEN'), ',' ORDER BY effective_from) FROM employee_salary_history WHERE employee_id = $($employee.id);"
    if ($salaryPeriods -ne "1000000.00:2026-01-01:2026-01-31,1200000.00:2026-02-01:OPEN") {
        throw "Salary periods overlap or previous period was not closed correctly: $salaryPeriods"
    }

    $auditFields = @($detail.changeHistory | Where-Object { $_.actorUsername -eq "th.sg" } | Select-Object -ExpandProperty fieldName)
    if ("employment_status" -notin $auditFields -or "base_salary_amount" -notin $auditFields) {
        throw "Labor and salary changes must be audited."
    }

    Write-Host "I2 employee salary versioning verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employees WHERE identification_type = 'CC' AND identification_number = '$testIdentification';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
