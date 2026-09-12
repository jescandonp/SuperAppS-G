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
$entityPrefix = "I7-TASK2-AUDIT"

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

function Assert-ContainsEntity {
    param([object[]]$Events, [string]$EntityId)
    if (-not (@($Events) | Where-Object { $_.entityId -eq $EntityId })) {
        throw "Audit event '$EntityId' was not returned."
    }
}

function Assert-NotContainsEntity {
    param([object[]]$Events, [string]$EntityId)
    if (@($Events) | Where-Object { $_.entityId -eq $EntityId }) {
        throw "Audit event '$EntityId' should not be visible."
    }
}

function Assert-EventShape {
    param([object]$Event)
    foreach ($property in @("id", "occurredAt", "actorUsername", "module", "action", "entityType", "entityId", "summary")) {
        if (-not ($Event.PSObject.Properties.Name -contains $property)) {
            throw "Audit event must include property '$property'."
        }
    }
}

try {
    Invoke-Postgres "DELETE FROM audit_log WHERE entity_id LIKE '$entityPrefix%';" | Out-Null
    Invoke-Postgres @"
INSERT INTO audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail, created_at)
SELECT id, 'th.sg', 'TRAINING_RECORD_CREATED', 'EMPLOYEE_TRAINING_RECORD', '$entityPrefix-TRAINING', 'SUCCESS', '{"summary":"Renovacion I7"}'::jsonb, NOW() - INTERVAL '4 days' FROM app_users WHERE username = 'th.sg';
INSERT INTO audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail, created_at)
SELECT id, 'th.sg', 'CERTIFICATE_GENERATED', 'LABOR_CERTIFICATE', '$entityPrefix-CERTIFICATE', 'SUCCESS', '{"summary":"Certificado I7"}'::jsonb, NOW() - INTERVAL '3 days' FROM app_users WHERE username = 'th.sg';
INSERT INTO audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail, created_at)
SELECT id, 'operaciones.sg', 'POSITION_ASSIGNMENT_CREATED', 'POSITION_ASSIGNMENT', '$entityPrefix-POSITION', 'SUCCESS', '{"summary":"Asignacion I7"}'::jsonb, NOW() - INTERVAL '2 days' FROM app_users WHERE username = 'operaciones.sg';
INSERT INTO audit_log (actor_user_id, actor_username, event_type, entity_type, entity_id, result, detail, created_at)
SELECT id, 'admin.sg', 'USER_UPDATED', 'APP_USER', '$entityPrefix-USER', 'SUCCESS', '{"summary":"Usuario I7"}'::jsonb, NOW() - INTERVAL '1 day' FROM app_users WHERE username = 'admin.sg';
"@ | Out-Null

    $adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"
    $gerenciaHeaders = Get-SessionHeaders -Username "gerencia.sg" -Password "Gerencia123"
    $operacionesHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"

    $adminAudit = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit" -Headers $adminHeaders
    Assert-Status -Response $adminAudit -ExpectedStatus 200 -Message "ADMIN audit endpoint must be available."
    Assert-ContainsEntity -Events @($adminAudit.Body.events) -EntityId "$entityPrefix-TRAINING"
    Assert-ContainsEntity -Events @($adminAudit.Body.events) -EntityId "$entityPrefix-CERTIFICATE"
    Assert-ContainsEntity -Events @($adminAudit.Body.events) -EntityId "$entityPrefix-POSITION"
    Assert-ContainsEntity -Events @($adminAudit.Body.events) -EntityId "$entityPrefix-USER"
    Assert-EventShape -Event $adminAudit.Body.events[0]

    $moduleFilter = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit?module=TRAINING" -Headers $adminHeaders
    Assert-Status -Response $moduleFilter -ExpectedStatus 200 -Message "Audit module filter must be available."
    Assert-ContainsEntity -Events @($moduleFilter.Body.events) -EntityId "$entityPrefix-TRAINING"
    Assert-NotContainsEntity -Events @($moduleFilter.Body.events) -EntityId "$entityPrefix-CERTIFICATE"

    $actorFilter = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit?actor=operaciones.sg" -Headers $adminHeaders
    Assert-Status -Response $actorFilter -ExpectedStatus 200 -Message "Audit actor filter must be available."
    Assert-ContainsEntity -Events @($actorFilter.Body.events) -EntityId "$entityPrefix-POSITION"
    Assert-NotContainsEntity -Events @($actorFilter.Body.events) -EntityId "$entityPrefix-TRAINING"

    $from = [Uri]::EscapeDataString((Get-Date).AddDays(-2).ToString("yyyy-MM-dd"))
    $dateFilter = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit?from=$from" -Headers $adminHeaders
    Assert-Status -Response $dateFilter -ExpectedStatus 200 -Message "Audit date filter must be available."
    Assert-ContainsEntity -Events @($dateFilter.Body.events) -EntityId "$entityPrefix-USER"
    Assert-NotContainsEntity -Events @($dateFilter.Body.events) -EntityId "$entityPrefix-TRAINING"

    $thAudit = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit" -Headers $thHeaders
    Assert-Status -Response $thAudit -ExpectedStatus 200 -Message "TH audit endpoint must be available."
    Assert-ContainsEntity -Events @($thAudit.Body.events) -EntityId "$entityPrefix-TRAINING"
    Assert-ContainsEntity -Events @($thAudit.Body.events) -EntityId "$entityPrefix-CERTIFICATE"
    Assert-NotContainsEntity -Events @($thAudit.Body.events) -EntityId "$entityPrefix-USER"

    $operacionesAudit = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit" -Headers $operacionesHeaders
    Assert-Status -Response $operacionesAudit -ExpectedStatus 200 -Message "OPERACIONES audit endpoint must be available."
    Assert-ContainsEntity -Events @($operacionesAudit.Body.events) -EntityId "$entityPrefix-POSITION"
    Assert-NotContainsEntity -Events @($operacionesAudit.Body.events) -EntityId "$entityPrefix-CERTIFICATE"
    Assert-NotContainsEntity -Events @($operacionesAudit.Body.events) -EntityId "$entityPrefix-USER"

    $gerenciaAudit = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit" -Headers $gerenciaHeaders
    Assert-Status -Response $gerenciaAudit -ExpectedStatus 200 -Message "GERENCIA audit endpoint must be available."
    Assert-ContainsEntity -Events @($gerenciaAudit.Body.events) -EntityId "$entityPrefix-TRAINING"
    Assert-ContainsEntity -Events @($gerenciaAudit.Body.events) -EntityId "$entityPrefix-CERTIFICATE"
    Assert-ContainsEntity -Events @($gerenciaAudit.Body.events) -EntityId "$entityPrefix-POSITION"
    Assert-NotContainsEntity -Events @($gerenciaAudit.Body.events) -EntityId "$entityPrefix-USER"

    $unauthenticated = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/audit" -Headers @{}
    Assert-Status -Response $unauthenticated -ExpectedStatus 401 -Message "Audit must require authentication."

    Write-Host "I7 audit verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM audit_log WHERE entity_id LIKE '$entityPrefix%';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
