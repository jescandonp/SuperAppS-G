param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [Nullable[long]]$ScheduleVersionId,
    [string]$VerificationSchema,
    [string]$Database = "sg_superapp_dev",
    [string]$HostName = "localhost",
    [int]$Port = 5432,
    [string]$AppUser = "sg_app",
    [string]$AppPassword = "sg_app_change_me"
)

$ErrorActionPreference = "Stop"

$login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" `
    -Body (@{ username="operaciones.sg"; password="Operaciones123" } | ConvertTo-Json)
$headers = @{ Authorization="Bearer $($login.sessionToken)" }

$eligible = @{ eligible=$true; requiresException=$false; reasons=@() }
$subsanable = @{ eligible=$true; requiresException=$true; reasons=@(@{ code="COURSE_RENEWAL"; severity="SUBSANABLE"; message="Curso subsanable." }) }
$blocked = @{ eligible=$false; requiresException=$false; reasons=@(@{ code="BLOCKING_ABSENCE"; severity="BLOCKING"; message="Novedad bloqueante." }) }
$weights = @{ continuity=10; equity=3; additionalHoursPenalty=2; distancePenalty=1; exceptionPenalty=5; stabilityPenalty=4 }

function Candidate($id, $kind, $continuity, $equity, $hours, $distance, $change) {
    $eligibility = if ($kind -eq "blocked") { $blocked } elseif ($kind -eq "subsanable") { $subsanable } else { $eligible }
    return @{ employeeId=$id; eligibility=$eligibility; continuity=$continuity; equity=$equity; additionalHours=$hours; distancePenalty=$distance; publishedScheduleChange=$change }
}

$all = @(
    (Candidate 101 "habitual" 5 2 0 0 0),
    (Candidate 102 "subsanable" 4 3 0 0 0),
    (Candidate 103 "relevo" 2 5 0 1 0),
    (Candidate 104 "blocked" 9 9 0 0 0)
)
$shifts = @(
    @{ requiredShiftId=1; positionId=10; date="2026-08-12"; startsAt="06:00"; candidates=$all },
    @{ requiredShiftId=2; positionId=10; date="2026-08-12"; startsAt="18:00"; candidates=$all },
    @{ requiredShiftId=3; positionId=20; date="2026-08-13"; startsAt="06:00"; candidates=$all },
    @{ requiredShiftId=4; positionId=20; date="2026-08-13"; startsAt="18:00"; candidates=$all },
    @{ requiredShiftId=5; positionId=10; date="2026-08-14"; startsAt="06:00"; candidates=$all },
    @{ requiredShiftId=6; positionId=20; date="2026-08-14"; startsAt="18:00"; candidates=@((Candidate 104 "blocked" 9 9 0 0 0)) }
)
$body = @{ scheduleVersionId=$ScheduleVersionId; idempotencyKey="i9-recommendations-fixed"; weights=$weights; shifts=$shifts } | ConvertTo-Json -Depth 10

function Invoke-Recommendation {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "$ApiBaseUrl/portal/scheduling/recommendations/generate" `
            -Method Post -Headers $headers -ContentType "application/json" -Body $body
        return @{ Status=[int]$response.StatusCode; Json=$response.Content; Body=($response.Content | ConvertFrom-Json) }
    } catch {
        if ($null -eq $_.Exception.Response) { throw }
        return @{ Status=[int]$_.Exception.Response.StatusCode; Json=$null; Body=$null }
    }
}

$first = Invoke-Recommendation
if ($first.Status -eq 404) { throw "I9 recommendation endpoint is missing (HTTP 404)." }
if ($first.Status -ne 200) { throw "I9 recommendation endpoint returned HTTP $($first.Status)." }
if (@($first.Body.assignments).Count -ne 6) { throw "Expected six recommendation results." }
if (@($first.Body.assignments | Where-Object status -eq "ASIGNADA").Count -ne 5) { throw "Expected five covered shifts." }
$vacancies = @($first.Body.assignments | Where-Object status -eq "VACANTE")
if ($vacancies.Count -ne 1 -or $vacancies[0].requiredShiftId -ne 6) { throw "Expected one visible vacancy for shift 6." }
if (@($first.Body.assignments | Where-Object employeeId -eq 104).Count -ne 0) { throw "Blocked guard was assigned." }
if (@($first.Body.assignments | Where-Object { @($_.rankingReasons).Count -eq 0 }).Count -ne 0) { throw "Every result must explain its ranking or vacancy." }

$second = Invoke-Recommendation
if ($second.Status -ne 200 -or $first.Json -cne $second.Json) { throw "Identical runs must return deterministic JSON." }

if ($ScheduleVersionId.HasValue) {
    if ([string]::IsNullOrWhiteSpace($VerificationSchema) -or $VerificationSchema -cnotmatch '^sg_i9_recommend_[0-9]+_[0-9]{17}\z') {
        throw "A safe verification schema is required for persistence assertions."
    }
    if ($null -eq $first.Body.runId -or $first.Body.runId -ne $second.Body.runId) { throw "Idempotent retry did not return the existing run." }
    $psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
    $previousPassword = $env:PGPASSWORD
    $previousOptions = $env:PGOPTIONS
    try {
        $env:PGPASSWORD = $AppPassword
        $env:PGOPTIONS = "-c search_path=$VerificationSchema"
        $state = & $psql -X -q -t -A -h $HostName -p $Port -U $AppUser -d $Database -c "select count(*),min(status),count(distinct idempotency_key) from schedule_generation_runs"
        if ($LASTEXITCODE -ne 0 -or $state.Trim() -ne "1|COMPLETADO_CON_VACANTES|1") { throw "Generation run was not persisted idempotently: $state" }
        $persisted = & $psql -X -q -t -A -h $HostName -p $Port -U $AppUser -d $Database -c "select count(*),count(*) filter(where status='ASIGNADA'),count(*) filter(where status='VACANTE') from schedule_assignments"
        if ($LASTEXITCODE -ne 0 -or $persisted.Trim() -ne "6|5|1") { throw "Persisted assignments do not match 6/5/1: $persisted" }
        $snapshots = & $psql -X -q -t -A -h $HostName -p $Port -U $AppUser -d $Database -c "select jsonb_typeof(source_snapshot),jsonb_typeof(parameters_snapshot) from schedule_versions where id=$($ScheduleVersionId.Value)"
        if ($LASTEXITCODE -ne 0 -or $snapshots.Trim() -ne "object|object") { throw "Run snapshots were not persisted: $snapshots" }
    } finally {
        $env:PGPASSWORD = $previousPassword
        $env:PGOPTIONS = $previousOptions
    }
}

Write-Host "I9 RECOMMENDATIONS PASS"
