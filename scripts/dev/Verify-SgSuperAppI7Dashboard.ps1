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

function Assert-Equals {
    param([object]$Actual, [object]$Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', received '$Actual'."
    }
}

function Assert-Widget {
    param([object[]]$Widgets, [string]$Id, [string]$Scope)
    $match = @($Widgets | Where-Object { $_.id -eq $Id -and $_.scope -eq $Scope })
    if ($match.Count -eq 0) {
        throw "Expected dashboard widget '$Id' with scope '$Scope'."
    }
    if ($null -eq $match[0].metric) {
        throw "Dashboard widget '$Id' must include a metric value."
    }
    if ([string]::IsNullOrWhiteSpace($match[0].title)) {
        throw "Dashboard widget '$Id' must include a title."
    }
    if ([string]::IsNullOrWhiteSpace($match[0].severity)) {
        throw "Dashboard widget '$Id' must include severity."
    }
}

function Assert-NoWidget {
    param([object[]]$Widgets, [string]$Id)
    if (@($Widgets | Where-Object { $_.id -eq $Id }).Count -gt 0) {
        throw "Dashboard widget '$Id' should not be visible for this role."
    }
}

function Assert-ValidActionUrl {
    param([object[]]$Widgets)
    # Ningun actionUrl debe apuntar a una ruta que el frontend no sabe traducir
    # (ver resolveActionUrl en DashboardPage.tsx): o es null (sin boton "Abrir"),
    # o empieza por uno de los prefijos que si se traducen a una pantalla real.
    $knownPrefixes = @("/portal/courses", "/portal/certificates", "/portal/imports", "/portal/positions", "/portal/alerts")
    foreach ($widget in $Widgets) {
        if ($null -eq $widget.actionUrl) { continue }
        $matches = @($knownPrefixes | Where-Object { $widget.actionUrl.StartsWith($_) })
        if ($matches.Count -eq 0) {
            throw "Widget '$($widget.id)' tiene actionUrl '$($widget.actionUrl)' que no coincide con ninguna ruta real conocida por el frontend."
        }
    }
}

$adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
$thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
$gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
$operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"

$adminDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $adminHeaders
Assert-Status -Response $adminDashboard -ExpectedStatus 200 -Message "ADMIN dashboard must be available."
Assert-Equals -Actual $adminDashboard.Body.role -Expected "ADMIN" -Message "ADMIN dashboard must include effective role."
Assert-Widget -Widgets @($adminDashboard.Body.widgets) -Id "platform-users-active" -Scope "ADMIN"
Assert-Widget -Widgets @($adminDashboard.Body.widgets) -Id "platform-imports-errors" -Scope "ADMIN"
Assert-Widget -Widgets @($adminDashboard.Body.widgets) -Id "notifications-unread" -Scope "SYSTEM"
Assert-ValidActionUrl -Widgets @($adminDashboard.Body.widgets)

$thDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $thHeaders
Assert-Status -Response $thDashboard -ExpectedStatus 200 -Message "TH dashboard must be available."
Assert-Equals -Actual $thDashboard.Body.role -Expected "TH" -Message "TH dashboard must include effective role."
Assert-Widget -Widgets @($thDashboard.Body.widgets) -Id "certificates-generated" -Scope "TH"
Assert-Widget -Widgets @($thDashboard.Body.widgets) -Id "training-critical" -Scope "TH"
Assert-Widget -Widgets @($thDashboard.Body.widgets) -Id "imports-data-quality" -Scope "TH"
Assert-NoWidget -Widgets @($thDashboard.Body.widgets) -Id "platform-users-active"
Assert-ValidActionUrl -Widgets @($thDashboard.Body.widgets)

$gerenciaDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $gerenciaHeaders
Assert-Status -Response $gerenciaDashboard -ExpectedStatus 200 -Message "GERENCIA dashboard must be available."
Assert-Equals -Actual $gerenciaDashboard.Body.role -Expected "GERENCIA" -Message "GERENCIA dashboard must include effective role."
Assert-Widget -Widgets @($gerenciaDashboard.Body.widgets) -Id "executive-pilot-value" -Scope "EXECUTIVE"
Assert-Widget -Widgets @($gerenciaDashboard.Body.widgets) -Id "certificates-generated" -Scope "EXECUTIVE"
Assert-NoWidget -Widgets @($gerenciaDashboard.Body.widgets) -Id "platform-users-active"
Assert-ValidActionUrl -Widgets @($gerenciaDashboard.Body.widgets)

$operacionesDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $operacionesHeaders
Assert-Status -Response $operacionesDashboard -ExpectedStatus 200 -Message "OPERACIONES dashboard must be available."
Assert-Equals -Actual $operacionesDashboard.Body.role -Expected "OPERACIONES" -Message "OPERACIONES dashboard must include effective role."
Assert-Widget -Widgets @($operacionesDashboard.Body.widgets) -Id "operations-service-enablement" -Scope "OPERATIONS"
Assert-Widget -Widgets @($operacionesDashboard.Body.widgets) -Id "operations-current-assignments" -Scope "OPERATIONS"
Assert-NoWidget -Widgets @($operacionesDashboard.Body.widgets) -Id "imports-data-quality"
Assert-ValidActionUrl -Widgets @($operacionesDashboard.Body.widgets)

$unauthenticated = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers @{}
Assert-Status -Response $unauthenticated -ExpectedStatus 401 -Message "Dashboard must require authentication."

Write-Host "I7 dashboard verification completed."
