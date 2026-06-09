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
$typeCode = "I5-TYPE-CONTRACT"

function Invoke-Postgres {
    param([string]$Sql)
    & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -c $Sql | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
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

try {
    Invoke-Postgres "DELETE FROM training_requirement_types WHERE code LIKE '$typeCode%';"

    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"

    $blank = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/training-types" -Headers $adminHeaders -Body @{
        code = "$typeCode-BLANK"
        name = " "
        category = "CURSO"
        validityDays = 365
        isServiceRequired = $true
        notes = $null
    }
    Assert-Status -Response $blank -ExpectedStatus 400 -Message "Blank training type name must be rejected."

    $invalidCategory = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/training-types" -Headers $adminHeaders -Body @{
        code = "$typeCode-CATEGORY"
        name = "Categoria invalida I5"
        category = "LICENCIA"
        validityDays = 365
        isServiceRequired = $true
        notes = $null
    }
    Assert-Status -Response $invalidCategory -ExpectedStatus 400 -Message "Invalid training type category must be rejected."

    $invalidValidity = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/training-types" -Headers $adminHeaders -Body @{
        code = "$typeCode-VALIDITY"
        name = "Vigencia invalida I5"
        category = "CURSO"
        validityDays = 0
        isServiceRequired = $true
        notes = $null
    }
    Assert-Status -Response $invalidValidity -ExpectedStatus 400 -Message "Non-positive validity must be rejected."

    $create = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/training-types" -Headers $adminHeaders -Body @{
        code = $typeCode
        name = "Curso I5 Contratos"
        category = "CURSO"
        validityDays = 365
        isServiceRequired = $true
        notes = "Creado por verificacion I5"
    }
    Assert-Status -Response $create -ExpectedStatus 200 -Message "ADMIN must create training types."
    $typeId = [long]$create.Body.id
    if ($create.Body.status -ne "ACTIVO" -or $create.Body.code -ne $typeCode -or $create.Body.validityDays -ne 365) {
        throw "Created training type did not return expected fields."
    }

    $duplicate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/training-types" -Headers $adminHeaders -Body @{
        code = $typeCode
        name = "Duplicado I5"
        category = "CURSO"
        validityDays = 365
        isServiceRequired = $true
        notes = $null
    }
    Assert-Status -Response $duplicate -ExpectedStatus 409 -Message "Duplicate training type code must be rejected."

    $list = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/training-types?status=ACTIVO" -Headers $gerenciaHeaders
    Assert-Status -Response $list -ExpectedStatus 200 -Message "GERENCIA must list active training types."
    if (@($list.Body | Where-Object { $_.id -eq $typeId }).Count -ne 1) {
        throw "Active training type list must include created type."
    }

    $detail = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/training-types/$typeId" -Headers $gerenciaHeaders
    Assert-Status -Response $detail -ExpectedStatus 200 -Message "GERENCIA must read training type detail."

    $update = Invoke-JsonRequest -Method "PUT" -Uri "$ApiBaseUrl/portal/training-types/$typeId" -Headers $thHeaders -Body @{
        code = "$typeCode-UPDATED"
        name = "Acreditacion I5 Actualizada"
        category = "ACREDITACION"
        validityDays = $null
        isServiceRequired = $false
        notes = "Actualizado por TH"
    }
    Assert-Status -Response $update -ExpectedStatus 200 -Message "TH must update training types."
    if ($update.Body.category -ne "ACREDITACION" -or $update.Body.isServiceRequired -ne $false -or $null -ne $update.Body.validityDays) {
        throw "Updated training type did not return expected fields."
    }

    $inactivate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/training-types/$typeId/inactivate" -Headers $adminHeaders
    Assert-Status -Response $inactivate -ExpectedStatus 200 -Message "ADMIN must inactivate training types."
    if ($inactivate.Body.status -ne "INACTIVO") {
        throw "Inactivated training type must return INACTIVO status."
    }

    Write-Host "I5 training types verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM training_requirement_types WHERE code LIKE '$typeCode%';"
    $env:PGPASSWORD = $originalPassword
}
