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

$thDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $thHeaders
Assert-Status -Response $thDashboard -ExpectedStatus 200 -Message "TH dashboard must be available."
Assert-Equals -Actual $thDashboard.Body.role -Expected "TH" -Message "TH dashboard must include effective role."
Assert-Widget -Widgets @($thDashboard.Body.widgets) -Id "certificates-generated" -Scope "TH"
Assert-Widget -Widgets @($thDashboard.Body.widgets) -Id "training-critical" -Scope "TH"
Assert-Widget -Widgets @($thDashboard.Body.widgets) -Id "imports-data-quality" -Scope "TH"
Assert-NoWidget -Widgets @($thDashboard.Body.widgets) -Id "platform-users-active"

$gerenciaDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $gerenciaHeaders
Assert-Status -Response $gerenciaDashboard -ExpectedStatus 200 -Message "GERENCIA dashboard must be available."
Assert-Equals -Actual $gerenciaDashboard.Body.role -Expected "GERENCIA" -Message "GERENCIA dashboard must include effective role."
Assert-Widget -Widgets @($gerenciaDashboard.Body.widgets) -Id "executive-pilot-value" -Scope "EXECUTIVE"
Assert-Widget -Widgets @($gerenciaDashboard.Body.widgets) -Id "certificates-generated" -Scope "EXECUTIVE"
Assert-NoWidget -Widgets @($gerenciaDashboard.Body.widgets) -Id "platform-users-active"

$operacionesDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $operacionesHeaders
Assert-Status -Response $operacionesDashboard -ExpectedStatus 200 -Message "OPERACIONES dashboard must be available."
Assert-Equals -Actual $operacionesDashboard.Body.role -Expected "OPERACIONES" -Message "OPERACIONES dashboard must include effective role."
Assert-Widget -Widgets @($operacionesDashboard.Body.widgets) -Id "operations-service-enablement" -Scope "OPERATIONS"
Assert-Widget -Widgets @($operacionesDashboard.Body.widgets) -Id "operations-current-assignments" -Scope "OPERATIONS"
Assert-NoWidget -Widgets @($operacionesDashboard.Body.widgets) -Id "imports-data-quality"

$unauthenticated = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers @{}
Assert-Status -Response $unauthenticated -ExpectedStatus 401 -Message "Dashboard must require authentication."

Write-Host "I7 dashboard verification completed."
