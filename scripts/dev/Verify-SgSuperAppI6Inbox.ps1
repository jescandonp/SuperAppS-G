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
$dedupePrefix = "I6-TASK2-INBOX"

function Invoke-Postgres {
    param([string]$Sql)
    $output = & $psqlExe -h localhost -p 5432 -U $AppUser -d $DatabaseName -v ON_ERROR_STOP=1 -t -A -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL command failed." }
    return @($output | Where-Object { $_ -match '\S' })
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

function Assert-Equals {
    param([object]$Actual, [object]$Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', received '$Actual'."
    }
}

function Assert-ContainsTitle {
    param([object[]]$Items, [string]$Title)
    if (-not (@($Items) | Where-Object { $_.title -eq $Title })) {
        throw "Notification '$Title' was not returned."
    }
}

function Assert-NotContainsTitle {
    param([object[]]$Items, [string]$Title)
    if (@($Items) | Where-Object { $_.title -eq $Title }) {
        throw "Notification '$Title' should not be visible."
    }
}

try {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%'); DELETE FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%';" | Out-Null
    Invoke-Postgres "INSERT INTO notification_items (target_type, target_key, title, body, status, source_module, severity, source_type, source_id, dedupe_key, action_url, read_at, archived_at, managed_at, managed_by) VALUES ('USER', 'th.sg', 'I6 personal critica', 'Personal TH', 'UNREAD', 'TRAINING', 'CRITICAL', 'TRAINING_EXPIRY', 'EMP-1', '$dedupePrefix-USER-TH', '/portal/cursos', null, null, null, null), ('ROLE', 'TH', 'I6 rol TH warning', 'Rol TH', 'UNREAD', 'IMPORTS', 'WARNING', 'IMPORT_BATCH', 'BATCH-1', '$dedupePrefix-ROLE-TH', '/portal/imports', null, null, null, null), ('ROLE', 'GERENCIA', 'I6 rol gerencia read', 'Rol gerencia', 'READ', 'CERTIFICATES', 'INFO', 'CERTIFICATE', 'CERT-1', '$dedupePrefix-ROLE-GERENCIA', '/portal/certificates', NOW(), null, null, null), ('ROLE', 'OPERACIONES', 'I6 rol operaciones archived', 'Rol operaciones', 'ARCHIVED', 'TRAINING', 'WARNING', 'TRAINING_EXPIRY', 'EMP-2', '$dedupePrefix-ROLE-OPERACIONES', '/portal/cursos', null, NOW(), NOW(), 'operaciones.sg');" | Out-Null

    $thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"

    $all = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/notifications" -Headers $thHeaders
    Assert-Status -Response $all -ExpectedStatus 200 -Message "Authenticated inbox must be available."
    Assert-ContainsTitle -Items @($all.Body) -Title "I6 personal critica"
    Assert-ContainsTitle -Items @($all.Body) -Title "I6 rol TH warning"
    Assert-NotContainsTitle -Items @($all.Body) -Title "I6 rol gerencia read"
    Assert-NotContainsTitle -Items @($all.Body) -Title "I6 rol operaciones archived"

    $personal = @($all.Body | Where-Object { $_.title -eq "I6 personal critica" } | Select-Object -First 1)
    Assert-Equals -Actual $personal[0].severity -Expected "CRITICAL" -Message "Inbox item must include severity."
    Assert-Equals -Actual $personal[0].sourceModule -Expected "TRAINING" -Message "Inbox item must include source module."
    Assert-Equals -Actual $personal[0].sourceType -Expected "TRAINING_EXPIRY" -Message "Inbox item must include source type."
    Assert-Equals -Actual $personal[0].sourceId -Expected "EMP-1" -Message "Inbox item must include source id."
    Assert-Equals -Actual $personal[0].actionUrl -Expected "/portal/cursos" -Message "Inbox item must include action URL."

    $unread = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/notifications?status=UNREAD" -Headers $thHeaders
    Assert-Status -Response $unread -ExpectedStatus 200 -Message "Inbox status filter must be available."
    Assert-Equals -Actual @($unread.Body).Count -Expected 2 -Message "UNREAD filter must include personal and role unread notifications only."

    $critical = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/notifications?severity=CRITICAL" -Headers $thHeaders
    Assert-Status -Response $critical -ExpectedStatus 200 -Message "Inbox severity filter must be available."
    Assert-Equals -Actual @($critical.Body).Count -Expected 1 -Message "CRITICAL filter must return one item."
    Assert-Equals -Actual $critical.Body[0].title -Expected "I6 personal critica" -Message "CRITICAL filter must return the seeded personal item."

    $imports = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/notifications?sourceModule=IMPORTS" -Headers $thHeaders
    Assert-Status -Response $imports -ExpectedStatus 200 -Message "Inbox source module filter must be available."
    Assert-Equals -Actual @($imports.Body).Count -Expected 1 -Message "IMPORTS filter must return one item."
    Assert-Equals -Actual $imports.Body[0].title -Expected "I6 rol TH warning" -Message "IMPORTS filter must return the seeded role item."

    $count = Invoke-JsonRequest -Method "GET" -Uri "$ApiBaseUrl/portal/notifications/unread-count" -Headers $thHeaders
    Assert-Status -Response $count -ExpectedStatus 200 -Message "Unread counter must be available."
    Assert-Equals -Actual $count.Body.unreadCount -Expected 2 -Message "Unread counter must include personal and role unread notifications."

    Write-Host "I6 inbox verification completed."
}
finally {
    Invoke-Postgres "DELETE FROM notification_events WHERE notification_id IN (SELECT id FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%'); DELETE FROM notification_items WHERE dedupe_key LIKE '$dedupePrefix%';" | Out-Null
    $env:PGPASSWORD = $originalPassword
}
