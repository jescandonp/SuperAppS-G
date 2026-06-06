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
$testCode = "I3-POS-001"
$thCode = "I3-POS-TH"

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

function Invoke-JsonRequest {
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
        return @{ Status = [int]$response.StatusCode; Body = ($response.Content | ConvertFrom-Json) }
    }
    catch {
        if ($null -eq $_.Exception.Response) {
            throw
        }

        return @{ Status = [int]$_.Exception.Response.StatusCode; Body = $null }
    }
}

function Assert-Status {
    param([hashtable]$Response, [int]$ExpectedStatus, [string]$Message)

    if ($Response.Status -ne $ExpectedStatus) {
        throw "$Message Expected HTTP $ExpectedStatus, received $($Response.Status)."
    }
}

try {
    Invoke-Postgres "DELETE FROM employee_position_assignments WHERE position_id IN (SELECT id FROM service_positions WHERE code IN ('$testCode', '$thCode')); DELETE FROM service_positions WHERE code IN ('$testCode', '$thCode');"

    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"

    $blank = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions" -Headers $adminHeaders -Body @{
        code = "I3-BLANK"
        name = " "
        clientText = "Cliente"
        locationText = "Bogota"
        notes = "No valido"
    }
    Assert-Status -Response $blank -ExpectedStatus 400 -Message "Blank name must be rejected."

    $adminCreate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions" -Headers $adminHeaders -Body @{
        code = $testCode
        name = "Puesto Contrato I3"
        clientText = "Cliente Texto"
        locationText = "Bogota"
        notes = "Creado por verificacion"
    }
    Assert-Status -Response $adminCreate -ExpectedStatus 200 -Message "ADMIN must create positions."
    $positionId = [long]$adminCreate.Body.id

    $thCreate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions" -Headers $thHeaders -Body @{
        code = $thCode
        name = "Puesto TH I3"
        clientText = "Cliente TH"
        locationText = "Cali"
        notes = $null
    }
    Assert-Status -Response $thCreate -ExpectedStatus 200 -Message "TH must create positions."

    foreach ($headers in @($gerenciaHeaders, $operacionesHeaders)) {
        $forbidden = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions" -Headers $headers -Body @{
            code = "I3-FORBIDDEN"
            name = "No autorizado"
            clientText = "Cliente"
            locationText = "Bogota"
            notes = $null
        }
        Assert-Status -Response $forbidden -ExpectedStatus 403 -Message "Read-only roles must not create positions."
    }

    $list = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/positions?search=Contrato&status=ACTIVO" -Headers $operacionesHeaders
    Assert-Status -Response $list -ExpectedStatus 200 -Message "OPERACIONES must list positions."
    $match = @($list.Body | Where-Object { $_.code -eq $testCode })
    if ($match.Count -ne 1 -or $match[0].activeAssignmentsCount -ne 0) {
        throw "Position list must include active assignment count."
    }

    $detail = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/positions/$positionId" -Headers $gerenciaHeaders
    Assert-Status -Response $detail -ExpectedStatus 200 -Message "GERENCIA must read position detail."
    if ($detail.Body.clientText -ne "Cliente Texto" -or $detail.Body.status -ne "ACTIVO") {
        throw "Position detail did not return expected fields."
    }

    $update = Invoke-JsonRequest -Method "PUT" -Uri "$ApiBaseUrl/portal/positions/$positionId" -Headers $thHeaders -Body @{
        code = $testCode
        name = "Puesto Contrato I3 Actualizado"
        clientText = "Cliente Texto Actualizado"
        locationText = "Medellin"
        notes = "Actualizado por TH"
    }
    Assert-Status -Response $update -ExpectedStatus 200 -Message "TH must update positions."

    $inactivate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/positions/$positionId/inactivate" -Headers $adminHeaders
    Assert-Status -Response $inactivate -ExpectedStatus 200 -Message "ADMIN must inactivate positions."
    if ($inactivate.Body.status -ne "INACTIVO") {
        throw "Inactivated position must return INACTIVO status."
    }

    Write-Host "I3 positions verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM employee_position_assignments WHERE position_id IN (SELECT id FROM service_positions WHERE code IN ('$testCode', '$thCode')); DELETE FROM service_positions WHERE code IN ('$testCode', '$thCode');"
    $env:PGPASSWORD = $originalPassword
}
