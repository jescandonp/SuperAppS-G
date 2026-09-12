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
    param([string]$Method, [string]$Uri, [hashtable]$Headers)
    try {
        $response = Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers -UseBasicParsing
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

function Assert-ModuleStatus {
    param([object[]]$Modules, [string]$Code, [string]$ExpectedStatus)
    $match = @($Modules | Where-Object { $_.code -eq $Code })
    if ($match.Count -eq 0) {
        throw "Modulo '$Code' no aparece en la respuesta."
    }
    if ($match[0].status -ne $ExpectedStatus) {
        throw "Modulo '$Code' deberia reportar status '$ExpectedStatus', reporto '$($match[0].status)'."
    }
}

function Assert-ModuleOrder {
    param([object[]]$Modules, [string[]]$ExpectedOrder)
    $actualCodes = @($Modules | ForEach-Object { $_.code })
    $expectedVisible = @($ExpectedOrder | Where-Object { $actualCodes -contains $_ })
    for ($i = 0; $i -lt $expectedVisible.Count; $i++) {
        if ($actualCodes[$i] -ne $expectedVisible[$i]) {
            throw "Orden de modulos incorrecto: en la posicion $i se esperaba '$($expectedVisible[$i])', se recibio '$($actualCodes[$i])'. Orden completo recibido: $($actualCodes -join ', ')"
        }
    }
}

$workflowOrder = @(
    "dashboard", "employees", "positions", "scheduling", "certificates",
    "courses", "alerts", "imports", "notifications", "settings", "novedades"
)

$adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"

$adminModules = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/modules/ADMIN" -Headers $adminHeaders
Assert-Status -Response $adminModules -ExpectedStatus 200 -Message "El catalogo de modulos debe estar disponible para ADMIN."

# Modulos cerrados tecnicamente deben reportar Disponible, no Pendiente.
Assert-ModuleStatus -Modules @($adminModules.Body) -Code "employees" -ExpectedStatus "Disponible"
Assert-ModuleStatus -Modules @($adminModules.Body) -Code "positions" -ExpectedStatus "Disponible"
Assert-ModuleStatus -Modules @($adminModules.Body) -Code "certificates" -ExpectedStatus "Disponible"
Assert-ModuleStatus -Modules @($adminModules.Body) -Code "courses" -ExpectedStatus "Disponible"
Assert-ModuleStatus -Modules @($adminModules.Body) -Code "alerts" -ExpectedStatus "Disponible"
Assert-ModuleStatus -Modules @($adminModules.Body) -Code "scheduling" -ExpectedStatus "Disponible"

# Modulos sin funcionalidad real deben reportar Pendiente, no Disponible.
Assert-ModuleStatus -Modules @($adminModules.Body) -Code "settings" -ExpectedStatus "Pendiente"
Assert-ModuleStatus -Modules @($adminModules.Body) -Code "novedades" -ExpectedStatus "Pendiente"

# El orden debe seguir el flujo de trabajo, no el alfabetico.
Assert-ModuleOrder -Modules @($adminModules.Body) -ExpectedOrder $workflowOrder

Write-Host "Modules catalog verification completed."
