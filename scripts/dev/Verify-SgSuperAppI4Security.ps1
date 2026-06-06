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

$adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
$thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
$gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
$operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"

$adminModules = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/modules/ADMIN" -Headers $adminHeaders
Assert-Status -Response $adminModules -ExpectedStatus 200 -Message "ADMIN modules must be readable."
if (@($adminModules.Body | Where-Object { $_.code -eq "certificates" -and $_.enabled -eq $true }).Count -ne 1) {
    throw "ADMIN must see certificates module."
}

foreach ($headers in @($adminHeaders, $thHeaders, $gerenciaHeaders)) {
    $read = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/certificate-signers" -Headers $headers
    Assert-Status -Response $read -ExpectedStatus 200 -Message "Authorized roles must read certificate signers."
}

$operationsRead = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/certificate-signers" -Headers $operacionesHeaders
Assert-Status -Response $operationsRead -ExpectedStatus 403 -Message "OPERACIONES must not read certificate signers."

foreach ($headers in @($thHeaders, $gerenciaHeaders, $operacionesHeaders)) {
    $manage = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/certificate-signers" -Headers $headers -Body @{
        fullName = "No Autorizado I4"
        jobTitle = "No autorizado"
        signaturePath = $null
        validFrom = "2026-01-01"
        validTo = $null
        notes = $null
    }
    Assert-Status -Response $manage -ExpectedStatus 403 -Message "Only ADMIN must manage certificate signers."
}

Write-Host "I4 security verification completed."
