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

foreach ($headers in @($adminHeaders, $thHeaders, $gerenciaHeaders, $operacionesHeaders)) {
    $read = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/training-types" -Headers $headers
    Assert-Status -Response $read -ExpectedStatus 200 -Message "Authorized roles must read training types."
}

foreach ($headers in @($gerenciaHeaders, $operacionesHeaders)) {
    $manage = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/training-types" -Headers $headers -Body @{
        code = "I5-UNAUTHORIZED"
        name = "No autorizado I5"
        category = "CURSO"
        validityDays = 365
        isServiceRequired = $true
        notes = $null
    }
    Assert-Status -Response $manage -ExpectedStatus 403 -Message "GERENCIA and OPERACIONES must not manage training types."
}

foreach ($headers in @($adminHeaders, $thHeaders)) {
    $invalid = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/training-types" -Headers $headers -Body @{
        code = "I5-INVALID-SECURITY"
        name = "Tipo invalido I5"
        category = "CURSO"
        validityDays = -1
        isServiceRequired = $true
        notes = $null
    }
    Assert-Status -Response $invalid -ExpectedStatus 400 -Message "Authorized managers must still be bound by validation."
}

Write-Host "I5 security verification completed."
