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
$entityPrefix = "I7-TASK3-SECURITY"

function Invoke-Postgres {
    param([string]$Sql)
    $sqlFile = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -LiteralPath $sqlFile -Value $Sql -Encoding UTF8
        $output = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -t -A -f $sqlFile
        if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
        return @($output | Where-Object { $_ -match '\S' })
    }
    finally {
        Remove-Item -LiteralPath $sqlFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-SessionHeaders {
    param([string]$Username, [string]$Password)
    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($response.sessionToken)" }
}

function Invoke-JsonRequest {
    param([string]$Method, [string]$Uri, [hashtable]$Headers, [string]$Body = $null)
    try {
        $parameters = @{
            Uri = $Uri
            Method = $Method
            Headers = $Headers
            UseBasicParsing = $true
        }
        if (-not [string]::IsNullOrEmpty($Body)) {
            $parameters.ContentType = "application/json"
            $parameters.Body = $Body
        }

        $response = Invoke-WebRequest @parameters
        $parsedBody = $null
        if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
            $parsedBody = $response.Content | ConvertFrom-Json
        }

        return @{ Status = [int]$response.StatusCode; Body = $parsedBody }
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

function Assert-StatusIn {
    param([hashtable]$Response, [int[]]$ExpectedStatuses, [string]$Message)
    if ($ExpectedStatuses -notcontains $Response.Status) {
        throw "$Message Expected one of '$($ExpectedStatuses -join ',')', received $($Response.Status)."
    }
}

function Assert-Widget {
    param([object[]]$Widgets, [string]$Id, [string]$Message)
    if (-not (@($Widgets) | Where-Object { $_.id -eq $Id })) {
        throw $Message
    }
}

function Assert-NoWidget {
    param([object[]]$Widgets, [string]$Id, [string]$Message)
    if (@($Widgets) | Where-Object { $_.id -eq $Id }) {
        throw $Message
    }
}

function Assert-ContainsEntity {
    param([object[]]$Events, [string]$EntityId, [string]$Message)
    if (-not (@($Events) | Where-Object { $_.entityId -eq $EntityId })) {
        throw $Message
    }
}

function Assert-NotContainsEntity {
    param([object[]]$Events, [string]$EntityId, [string]$Message)
    if (@($Events) | Where-Object { $_.entityId -eq $EntityId }) {
        throw $Message
    }
}

try {
    Invoke-Postgres "DELETE FROM audit_log WHERE entity_id LIKE '$entityPrefix%';" | Out-Null
    Invoke-Postgres @"
INSERT INTO audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail, created_at)
SELECT id, 'th.sg', 'TRAINING_RECORD_CREATED', 'EMPLOYEE_TRAINING_RECORD', '$entityPrefix-TRAINING', 'SUCCESS', '{"summary":"Seguridad TH I7"}'::jsonb, NOW() - INTERVAL '4 days' FROM app_users WHERE username = 'th.sg';
INSERT INTO audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail, created_at)
SELECT id, 'th.sg', 'CERTIFICATE_GENERATED', 'LABOR_CERTIFICATE', '$entityPrefix-CERTIFICATE', 'SUCCESS', '{"summary":"Seguridad certificado I7"}'::jsonb, NOW() - INTERVAL '3 days' FROM app_users WHERE username = 'th.sg';
INSERT INTO audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail, created_at)
SELECT id, 'operaciones.sg', 'POSITION_ASSIGNMENT_CREATED', 'POSITION_ASSIGNMENT', '$entityPrefix-POSITION', 'SUCCESS', '{"summary":"Seguridad operaciones I7"}'::jsonb, NOW() - INTERVAL '2 days' FROM app_users WHERE username = 'operaciones.sg';
INSERT INTO audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail, created_at)
SELECT id, 'admin.sg', 'USER_UPDATED', 'APP_USER', '$entityPrefix-USER', 'SUCCESS', '{"summary":"Seguridad admin I7"}'::jsonb, NOW() - INTERVAL '1 day' FROM app_users WHERE username = 'admin.sg';
"@ | Out-Null

    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"

    foreach ($path in @("dashboard", "audit")) {
        $unauthenticated = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/$path" -Headers @{}
        Assert-Status -Response $unauthenticated -ExpectedStatus 401 -Message "$path must require authentication."
    }

    $adminDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $adminHeaders
    Assert-Status -Response $adminDashboard -ExpectedStatus 200 -Message "ADMIN dashboard must be available."
    Assert-Widget -Widgets @($adminDashboard.Body.widgets) -Id "platform-users-active" -Message "ADMIN must see platform widgets."
    Assert-Widget -Widgets @($adminDashboard.Body.widgets) -Id "platform-imports-errors" -Message "ADMIN must see import risk widgets."

    $thDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $thHeaders
    Assert-Status -Response $thDashboard -ExpectedStatus 200 -Message "TH dashboard must be available."
    Assert-Widget -Widgets @($thDashboard.Body.widgets) -Id "training-critical" -Message "TH must see training indicators."
    Assert-Widget -Widgets @($thDashboard.Body.widgets) -Id "certificates-generated" -Message "TH must see certificate indicators."
    Assert-NoWidget -Widgets @($thDashboard.Body.widgets) -Id "operations-current-assignments" -Message "TH must not see operations assignment indicators."
    Assert-NoWidget -Widgets @($thDashboard.Body.widgets) -Id "platform-users-active" -Message "TH must not see admin platform indicators."

    $gerenciaDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $gerenciaHeaders
    Assert-Status -Response $gerenciaDashboard -ExpectedStatus 200 -Message "GERENCIA dashboard must be available."
    Assert-Widget -Widgets @($gerenciaDashboard.Body.widgets) -Id "executive-pilot-value" -Message "GERENCIA must see executive indicators."
    Assert-NoWidget -Widgets @($gerenciaDashboard.Body.widgets) -Id "platform-users-active" -Message "GERENCIA must not see admin platform indicators."
    Assert-NoWidget -Widgets @($gerenciaDashboard.Body.widgets) -Id "operations-current-assignments" -Message "GERENCIA must not see operations widgets as editable context."

    $operacionesDashboard = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/dashboard" -Headers $operacionesHeaders
    Assert-Status -Response $operacionesDashboard -ExpectedStatus 200 -Message "OPERACIONES dashboard must be available."
    Assert-Widget -Widgets @($operacionesDashboard.Body.widgets) -Id "operations-service-enablement" -Message "OPERACIONES must see service enablement."
    Assert-Widget -Widgets @($operacionesDashboard.Body.widgets) -Id "operations-current-assignments" -Message "OPERACIONES must see current assignments."
    Assert-NoWidget -Widgets @($operacionesDashboard.Body.widgets) -Id "certificates-generated" -Message "OPERACIONES must not see TH certificate indicators."
    Assert-NoWidget -Widgets @($operacionesDashboard.Body.widgets) -Id "imports-data-quality" -Message "OPERACIONES must not see TH import indicators."

    $adminAudit = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit" -Headers $adminHeaders
    Assert-Status -Response $adminAudit -ExpectedStatus 200 -Message "ADMIN audit must be available."
    Assert-ContainsEntity -Events @($adminAudit.Body.events) -EntityId "$entityPrefix-TRAINING" -Message "ADMIN must see TH audit."
    Assert-ContainsEntity -Events @($adminAudit.Body.events) -EntityId "$entityPrefix-CERTIFICATE" -Message "ADMIN must see certificate audit."
    Assert-ContainsEntity -Events @($adminAudit.Body.events) -EntityId "$entityPrefix-POSITION" -Message "ADMIN must see operations audit."
    Assert-ContainsEntity -Events @($adminAudit.Body.events) -EntityId "$entityPrefix-USER" -Message "ADMIN must see platform audit."

    $thAudit = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit" -Headers $thHeaders
    Assert-Status -Response $thAudit -ExpectedStatus 200 -Message "TH audit must be available."
    Assert-ContainsEntity -Events @($thAudit.Body.events) -EntityId "$entityPrefix-TRAINING" -Message "TH must see training audit."
    Assert-ContainsEntity -Events @($thAudit.Body.events) -EntityId "$entityPrefix-CERTIFICATE" -Message "TH must see certificate audit."
    Assert-NotContainsEntity -Events @($thAudit.Body.events) -EntityId "$entityPrefix-POSITION" -Message "TH must not see operations audit."
    Assert-NotContainsEntity -Events @($thAudit.Body.events) -EntityId "$entityPrefix-USER" -Message "TH must not see platform user audit."

    $gerenciaAudit = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit" -Headers $gerenciaHeaders
    Assert-Status -Response $gerenciaAudit -ExpectedStatus 200 -Message "GERENCIA audit must be available."
    Assert-ContainsEntity -Events @($gerenciaAudit.Body.events) -EntityId "$entityPrefix-TRAINING" -Message "GERENCIA must see TH audit."
    Assert-ContainsEntity -Events @($gerenciaAudit.Body.events) -EntityId "$entityPrefix-CERTIFICATE" -Message "GERENCIA must see certificate audit."
    Assert-ContainsEntity -Events @($gerenciaAudit.Body.events) -EntityId "$entityPrefix-POSITION" -Message "GERENCIA must see operations audit."
    Assert-NotContainsEntity -Events @($gerenciaAudit.Body.events) -EntityId "$entityPrefix-USER" -Message "GERENCIA must not see platform user audit."

    $operacionesAudit = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit" -Headers $operacionesHeaders
    Assert-Status -Response $operacionesAudit -ExpectedStatus 200 -Message "OPERACIONES audit must be available."
    Assert-ContainsEntity -Events @($operacionesAudit.Body.events) -EntityId "$entityPrefix-POSITION" -Message "OPERACIONES must see operations audit."
    Assert-ContainsEntity -Events @($operacionesAudit.Body.events) -EntityId "$entityPrefix-TRAINING" -Message "OPERACIONES must see enablement-related training audit."
    Assert-NotContainsEntity -Events @($operacionesAudit.Body.events) -EntityId "$entityPrefix-CERTIFICATE" -Message "OPERACIONES must not see certificate audit."
    Assert-NotContainsEntity -Events @($operacionesAudit.Body.events) -EntityId "$entityPrefix-USER" -Message "OPERACIONES must not see platform user audit."

    foreach ($headers in @($thHeaders, $gerenciaHeaders, $operacionesHeaders)) {
        $mutation = Invoke-JsonRequest -Method "POST" -Uri "$ApiBaseUrl/portal/audit" -Headers $headers
        Assert-StatusIn -Response $mutation -ExpectedStatuses @(404, 405) -Message "Audit must not expose mutation endpoints for consultation roles."
    }

    Write-Host "I7 security verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM audit_log WHERE entity_id LIKE '$entityPrefix%';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
