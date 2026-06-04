param(
    [string]$ApiBaseUrl = "http://localhost:5080/api"
)

$ErrorActionPreference = "Stop"

function Assert-HttpStatus {
    param(
        [string]$Uri,
        [string]$Method = "Get",
        [int]$ExpectedStatus,
        [hashtable]$Headers = @{}
    )

    try {
        Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers -UseBasicParsing | Out-Null
        $actualStatus = 200
    }
    catch {
        if ($null -eq $_.Exception.Response) {
            throw
        }

        $actualStatus = [int]$_.Exception.Response.StatusCode
    }

    if ($actualStatus -ne $ExpectedStatus) {
        throw "Expected HTTP $ExpectedStatus for $Method $Uri, received $actualStatus."
    }
}

function Get-SessionToken {
    param(
        [string]$Username,
        [string]$Password
    )

    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return $response.sessionToken
}

function Get-BearerHeaders {
    param([string]$Token)
    return @{ Authorization = "Bearer $Token" }
}

Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports" -ExpectedStatus 401
Assert-HttpStatus -Uri "$ApiBaseUrl/portal/employees" -ExpectedStatus 401
Assert-HttpStatus -Uri "$ApiBaseUrl/auth/me" -Headers @{ Authorization = "Bearer invalid-token" } -ExpectedStatus 401

$adminHeaders = Get-BearerHeaders (Get-SessionToken -Username "admin.sg" -Password "Admin123")
$thHeaders = Get-BearerHeaders (Get-SessionToken -Username "th.sg" -Password "Th123456")
$gerenciaHeaders = Get-BearerHeaders (Get-SessionToken -Username "gerencia.sg" -Password "Gerencia123")
$operacionesHeaders = Get-BearerHeaders (Get-SessionToken -Username "operaciones.sg" -Password "Operaciones123")

Assert-HttpStatus -Uri "$ApiBaseUrl/auth/me" -Headers $adminHeaders -ExpectedStatus 200
Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports" -Headers $adminHeaders -ExpectedStatus 200
Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports" -Headers $thHeaders -ExpectedStatus 200
Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports" -Headers $gerenciaHeaders -ExpectedStatus 200
Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports" -Headers $operacionesHeaders -ExpectedStatus 403

Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/1/errors" -Headers $adminHeaders -ExpectedStatus 200
Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/1/errors" -Headers $thHeaders -ExpectedStatus 200
Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/1/errors" -Headers $gerenciaHeaders -ExpectedStatus 403
Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/1/errors" -Headers $operacionesHeaders -ExpectedStatus 403
Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $adminHeaders -ExpectedStatus 403
Assert-HttpStatus -Uri "$ApiBaseUrl/portal/imports/prevalidate" -Method Post -Headers $thHeaders -ExpectedStatus 400

$gerenciaEmployees = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees" -Headers $gerenciaHeaders
$operacionesEmployees = Invoke-RestMethod -Uri "$ApiBaseUrl/portal/employees" -Headers $operacionesHeaders

if ($null -eq $gerenciaEmployees[0].currentBaseSalary) {
    throw "GERENCIA must receive salary details."
}

if ($null -ne $operacionesEmployees[0].currentBaseSalary) {
    throw "OPERACIONES must not receive salary details."
}

Write-Host "I2 security verification completed."
