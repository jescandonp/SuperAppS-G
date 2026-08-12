param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [string]$Database = "sg_superapp_dev",
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me"
)

$ErrorActionPreference = "Stop"

function Get-SessionHeaders([string]$Username, [string]$Password) {
    $body = @{ username = $Username; password = $Password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body $body
    return @{ Authorization = "Bearer $($response.sessionToken)" }
}

function Invoke-Json([string]$Method, [string]$Path, [hashtable]$Headers, [object]$Body) {
    try {
        $parameters = @{
            Uri = "$ApiBaseUrl$Path"
            Method = $Method
            Headers = $Headers
            ContentType = "application/json"
            Body = ($Body | ConvertTo-Json -Depth 5)
            UseBasicParsing = $true
        }
        $response = Invoke-WebRequest @parameters
        return @{ Status = [int]$response.StatusCode; Body = ($response.Content | ConvertFrom-Json) }
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw }
        return @{ Status = [int]$_.Exception.Response.StatusCode; Body = $null }
    }
}

$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$env:PGPASSWORD = $AppPassword
function Get-DbScalar([string]$Sql) {
    $value = & $psql -X -q -t -A -h localhost -p 5432 -U $AppUser -d $Database -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "Database fixture query failed." }
    return ($value -join "`n").Trim()
}

$admin = Get-SessionHeaders "admin.sg" "Admin123"
$operations = Get-SessionHeaders "operaciones.sg" "Operaciones123"
$th = Get-SessionHeaders "th.sg" "Th123456"
$suffix = Get-Date -Format "yyyyMMddHHmmssfff"

try {

$client = Invoke-Json "POST" "/portal/scheduling/clients" $admin @{
    code = "I9-CLIENT-$suffix"; name = "Cliente configuracion $suffix"; status = "ACTIVO"
}
if ($client.Status -eq 404) { throw "I9 configuration endpoints are missing (HTTP 404)." }
if ($client.Status -ne 201) { throw "Client configuration returned HTTP $($client.Status)." }

$project = Invoke-Json "POST" "/portal/scheduling/projects" $operations @{
    clientId = $client.Body.id
    code = "I9-PROJECT-$suffix"
    name = "Proyecto configuracion $suffix"
    effectiveFrom = "2026-08-01"
    effectiveTo = "2026-08-31"
    status = "ACTIVO"
}
if ($project.Status -ne 201) { throw "Project configuration returned HTTP $($project.Status)." }

$invalidProject = Invoke-Json "POST" "/portal/scheduling/projects" $admin @{
    clientId = $client.Body.id; code = "I9-BAD-$suffix"; name = "Invalido"
    effectiveFrom = "2026-09-01"; effectiveTo = "2026-08-01"; status = "ACTIVO"
}
if ($invalidProject.Status -ne 400) { throw "Reversed project validity must return HTTP 400." }

$positionId = [long](Get-DbScalar "select id from service_positions where status='ACTIVO' order by id limit 1")
$templateId = [long](Get-DbScalar "select id from shift_templates where code='2X2' and status='ACTIVO' order by version desc limit 1")
$employeeId = [long](Get-DbScalar "select id from employees where employment_status='ACTIVO' order by id limit 1")
$requirementTypeId = [long](Get-DbScalar "insert into training_requirement_types(code,name,category,status) values ('I9-VERIFY-TYPE','Tipo verificacion I9','CURSO','ACTIVO') on conflict (code) do update set status='ACTIVO' returning id")
Get-DbScalar "delete from audit_log where entity_type='POSITION_COVERAGE_RULE' and entity_id in (select id::text from position_coverage_rules where weekday_scope like 'I9-VERIFY-%'); delete from position_coverage_rules where weekday_scope like 'I9-VERIFY-%'" | Out-Null

$coverage = Invoke-Json "POST" "/portal/scheduling/coverage-rules" $operations @{
    positionId = $positionId; templateId = $templateId; weekdayScope = "I9-VERIFY-$suffix"
    startsAt = "06:00"; endsAt = "18:00"; requiredGuards = 2
    effectiveFrom = "2099-01-01"; effectiveTo = "2099-01-31"; status = "ACTIVO"
}
if ($coverage.Status -ne 201) { throw "Coverage configuration returned HTTP $($coverage.Status)." }

$invalidCoverage = Invoke-Json "POST" "/portal/scheduling/coverage-rules" $admin @{
    positionId = $positionId; templateId = $templateId; weekdayScope = "LUN-DOM"
    startsAt = "06:00"; endsAt = "06:00"; requiredGuards = 0
    effectiveFrom = "2026-08-01"; status = "ACTIVO"
}
if ($invalidCoverage.Status -ne 400) { throw "Invalid coverage must return HTTP 400." }

$availability = Invoke-Json "POST" "/portal/scheduling/availability-exceptions" $th @{
    employeeId = $employeeId; from = "2026-08-10T08:00:00-05:00"; to = "2026-08-10T18:00:00-05:00"
    kind = "NOVEDAD"; blocking = $true; reason = "Verificacion I9 $suffix"
}
if ($availability.Status -ne 201) { throw "TH availability configuration returned HTTP $($availability.Status)." }

$requirement = Invoke-Json "POST" "/portal/scheduling/position-requirements" $admin @{
    positionId = $positionId; requirementTypeId = $requirementTypeId
    severity = "SUBSANABLE"; resolutionDueDate = "2026-08-31"
}
if ($requirement.Status -notin @(201, 409)) { throw "Position requirement returned HTTP $($requirement.Status)." }

$invalidRequirement = Invoke-Json "POST" "/portal/scheduling/position-requirements" $admin @{
    positionId = $positionId; requirementTypeId = $requirementTypeId; severity = "OPCIONAL"
}
if ($invalidRequirement.Status -ne 400) { throw "Invalid severity must return HTTP 400." }

$forbidden = Invoke-Json "POST" "/portal/scheduling/projects" $th @{
    clientId = $client.Body.id; code = "I9-FORBIDDEN-$suffix"; name = "Prohibido"
    effectiveFrom = "2026-08-01"; status = "ACTIVO"
}
if ($forbidden.Status -ne 403) { throw "TH project configuration must return HTTP 403." }

$anonymous = Invoke-Json "POST" "/portal/scheduling/projects" @{} @{
    clientId = $client.Body.id; code = "I9-ANON-$suffix"; name = "Anonimo"
    effectiveFrom = "2026-08-01"; status = "ACTIVO"
}
if ($anonymous.Status -ne 401) { throw "Anonymous configuration must return HTTP 401." }

$auditCount = [int](Get-DbScalar "select count(*) from audit_log where (event_type='SCHEDULING_CLIENT_CREATED' and entity_type='SCHEDULING_CLIENT' and entity_id='$($client.Body.id)') or (event_type='SCHEDULING_PROJECT_CREATED' and entity_type='SCHEDULING_PROJECT' and entity_id='$($project.Body.id)') or (event_type='COVERAGE_RULE_CREATED' and entity_type='POSITION_COVERAGE_RULE' and entity_id='$($coverage.Body.id)') or (event_type='AVAILABILITY_CREATED' and entity_type='EMPLOYEE_AVAILABILITY_EXCEPTION' and entity_id='$($availability.Body.id)')")
if ($auditCount -ne 4) { throw "Expected four transactional I9 audit records, found $auditCount." }

Write-Host "I9 CONFIGURATION PASS"
}
finally {
    $cleanupSql = @"
delete from audit_log where event_type='POSITION_REQUIREMENT_CREATED' and entity_id in
 (select pr.id::text from position_requirements pr join training_requirement_types trt on trt.id=pr.requirement_type_id where trt.code='I9-VERIFY-TYPE');
delete from audit_log where event_type='AVAILABILITY_CREATED' and entity_id in
 (select id::text from employee_availability_exceptions where reason like 'Verificacion I9 %');
delete from audit_log where event_type='COVERAGE_RULE_CREATED' and entity_id in
 (select id::text from position_coverage_rules where weekday_scope like 'I9-VERIFY-%');
delete from audit_log where event_type='SCHEDULING_PROJECT_CREATED' and entity_id in
 (select id::text from service_projects where code like 'I9-PROJECT-%');
delete from audit_log where event_type='SCHEDULING_CLIENT_CREATED' and entity_id in
 (select id::text from clients where code like 'I9-CLIENT-%');
delete from position_requirements where requirement_type_id in (select id from training_requirement_types where code='I9-VERIFY-TYPE');
delete from employee_availability_exceptions where reason like 'Verificacion I9 %';
delete from position_coverage_rules where weekday_scope like 'I9-VERIFY-%';
delete from service_projects where code like 'I9-PROJECT-%';
delete from clients where code like 'I9-CLIENT-%';
delete from training_requirement_types where code='I9-VERIFY-TYPE';
"@
    Get-DbScalar $cleanupSql | Out-Null
}
