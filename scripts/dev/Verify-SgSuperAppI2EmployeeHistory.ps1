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
$testActor = "i2-history-test"
$testIdentification = "1012345678"

function Invoke-Postgres {
    param([string]$Sql)

    & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -c $Sql | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL command failed."
    }
}

function Get-SessionToken {
    $body = @{ username = "th.sg"; password = "Th123456" } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return $response.sessionToken
}

if (-not (Test-Path -LiteralPath $psqlExe)) {
    throw "psql executable not found: $psqlExe"
}

try {
    Invoke-Postgres @"
INSERT INTO employee_change_log (employee_id, actor_username, field_name, previous_value, new_value)
SELECT id, '$testActor', 'job_title', 'Guarda', 'Guarda de Seguridad'
FROM employees
WHERE identification_type = 'CC' AND identification_number = '$testIdentification';
"@

    $headers = @{ Authorization = "Bearer $(Get-SessionToken)" }
    $employees = @(Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees?search=$testIdentification" -Headers $headers)
    if ($employees.Count -ne 1) {
        throw "Expected one employee for history verification."
    }

    $detail = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees/$($employees[0].id)" -Headers $headers
    $testChange = @($detail.changeHistory | Where-Object { $_.actorUsername -eq $testActor })

    if ($testChange.Count -ne 1) {
        throw "Employee detail must include the basic change history."
    }

    if ($testChange[0].fieldName -ne "job_title" -or $testChange[0].previousValue -ne "Guarda" -or $testChange[0].newValue -ne "Guarda de Seguridad") {
        throw "Employee history must expose field, previous value and new value."
    }

    Write-Host "I2 employee history verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employee_change_log WHERE actor_username = '$testActor';"
    $env:PGPASSWORD = $originalPassword
}
