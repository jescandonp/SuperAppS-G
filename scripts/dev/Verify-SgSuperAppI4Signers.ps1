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
$signerName = "Firmante I4 Contratos"

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
    Invoke-Postgres "DELETE FROM certificate_signers WHERE full_name LIKE '$signerName%';"

    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"

    $blank = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificate-signers" -Headers $adminHeaders -Body @{
        fullName = " "
        jobTitle = "Representante Legal"
        signaturePath = $null
        validFrom = "2026-01-01"
        validTo = $null
        notes = $null
    }
    Assert-Status -Response $blank -ExpectedStatus 400 -Message "Blank signer name must be rejected."

    $invalidRange = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificate-signers" -Headers $adminHeaders -Body @{
        fullName = "$signerName Rango"
        jobTitle = "Representante Legal"
        signaturePath = $null
        validFrom = "2026-02-01"
        validTo = "2026-01-01"
        notes = $null
    }
    Assert-Status -Response $invalidRange -ExpectedStatus 400 -Message "Invalid signer validity range must be rejected."

    $create = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificate-signers" -Headers $adminHeaders -Body @{
        fullName = $signerName
        jobTitle = "Representante Legal"
        signaturePath = "firmas/i4.png"
        validFrom = "2026-01-01"
        validTo = $null
        notes = "Creado por verificacion"
    }
    Assert-Status -Response $create -ExpectedStatus 200 -Message "ADMIN must create certificate signers."
    $signerId = [long]$create.Body.id
    if ($create.Body.status -ne "ACTIVO" -or $create.Body.fullName -ne $signerName) {
        throw "Created signer did not return expected fields."
    }

    $forbidden = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificate-signers" -Headers $thHeaders -Body @{
        fullName = "$signerName TH"
        jobTitle = "No autorizado"
        signaturePath = $null
        validFrom = "2026-01-01"
        validTo = $null
        notes = $null
    }
    Assert-Status -Response $forbidden -ExpectedStatus 403 -Message "TH must not manage certificate signers."

    $list = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/certificate-signers?status=ACTIVO" -Headers $thHeaders
    Assert-Status -Response $list -ExpectedStatus 200 -Message "TH must read certificate signers."
    if (@($list.Body | Where-Object { $_.id -eq $signerId }).Count -ne 1) {
        throw "Active signer list must include created signer."
    }

    $detail = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/certificate-signers/$signerId" -Headers $gerenciaHeaders
    Assert-Status -Response $detail -ExpectedStatus 200 -Message "GERENCIA must read certificate signer detail."

    $update = Invoke-JsonRequest -Method "PUT" -Uri "$ApiBaseUrl/portal/certificate-signers/$signerId" -Headers $adminHeaders -Body @{
        fullName = "$signerName Actualizado"
        jobTitle = "Directora TH"
        signaturePath = "firmas/i4-v2.png"
        validFrom = "2026-01-01"
        validTo = "2026-12-31"
        notes = "Actualizado por verificacion"
    }
    Assert-Status -Response $update -ExpectedStatus 200 -Message "ADMIN must update certificate signers."
    if ($update.Body.jobTitle -ne "Directora TH" -or $update.Body.validTo -ne "2026-12-31") {
        throw "Updated signer did not return expected fields."
    }

    $inactivate = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificate-signers/$signerId/inactivate" -Headers $adminHeaders
    Assert-Status -Response $inactivate -ExpectedStatus 200 -Message "ADMIN must inactivate certificate signers."
    if ($inactivate.Body.status -ne "INACTIVO") {
        throw "Inactivated signer must return INACTIVO status."
    }

    Write-Host "I4 signers verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM certificate_signers WHERE full_name LIKE '$signerName%';"
    $env:PGPASSWORD = $originalPassword
}
