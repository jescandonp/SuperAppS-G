param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [long]$ProjectId = 1,
    [string]$PeriodStart = "2026-09-01",
    [string]$PeriodEnd = "2026-09-30",
    [string]$VerificationSchema,
    [string]$Database = "sg_superapp_dev",
    [string]$AppPassword = "sg_app_change_me"
)
$ErrorActionPreference="Stop"
function Login($user,$password){$r=Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body (@{username=$user;password=$password}|ConvertTo-Json);return @{Authorization="Bearer $($r.sessionToken)"}}
function Call($method,$uri,$headers,$body){try{$r=Invoke-WebRequest -UseBasicParsing -Uri $uri -Method $method -Headers $headers -ContentType "application/json" -Body ($body|ConvertTo-Json -Depth 8);return @{Status=[int]$r.StatusCode;Body=($r.Content|ConvertFrom-Json)}}catch{if($null-eq$_.Exception.Response){throw};return @{Status=[int]$_.Exception.Response.StatusCode;Body=$null}}}
$h=Login "operaciones.sg" "Operaciones123"
$p1=Call Post "$ApiBaseUrl/portal/scheduling/projects/$ProjectId/proposals" $h @{periodStart=$PeriodStart;periodEnd=$PeriodEnd;acceptedVacancy=$true}
if($p1.Status-eq 404){throw "I9 workflow endpoint is missing (HTTP 404)."};if($p1.Status-ne 201-or$p1.Body.status-ne"PROPUESTA"-or-not$p1.Body.acceptedVacancy){throw "Proposal/vacancy snapshot failed."}
if(-not[string]::IsNullOrWhiteSpace($VerificationSchema)){
  if($VerificationSchema-notmatch'^sg_i9_workflow_[0-9]+_[0-9]{17}$'){throw "Unsafe verification schema."}
  $oldPassword=$env:PGPASSWORD;$oldOptions=$env:PGOPTIONS
  try{$env:PGPASSWORD=$AppPassword;$env:PGOPTIONS="-c search_path=$VerificationSchema,public";$psql='C:\Program Files\PostgreSQL\18\bin\psql.exe'
    $assignment=& $psql -X -q -t -A -h localhost -p 5432 -U sg_app -d $Database -c "with p as (insert into service_positions(code,name,project_id) values('WF-POS','Workflow Position',$ProjectId) returning id),r as (insert into required_shifts(schedule_version_id,position_id,shift_date,starts_at,ends_at) select $($p1.Body.versionId),id,'2026-09-01','06:00','18:00' from p returning id) insert into schedule_assignments(schedule_version_id,required_shift_id,status,reasons) select $($p1.Body.versionId),id,'VACANTE','[]' from r returning id";if($LASTEXITCODE-ne 0){throw "Could not prepare assignment fixture."}
  }finally{$env:PGPASSWORD=$oldPassword;$env:PGOPTIONS=$oldOptions}
  $adjusted=Call Put "$ApiBaseUrl/portal/scheduling/proposals/$($p1.Body.versionId)/assignments/$($assignment.Trim())" $h @{employeeId=$null;status="VACANTE";reasons=@("Vacante aceptada y revalidada");expectedVersion=$p1.Body.versionNumber}
  if($adjusted.Status-ne 200-or$adjusted.Body.vacancyCount-ne 1){throw "Manual adjustment did not revalidate metrics."}
}
$bad=Call Post "$ApiBaseUrl/portal/scheduling/proposals/$($p1.Body.versionId)/exceptions" $h @{assignmentId=$null;exceptionType="SUBSANABLE";reason="";responsible="";resolutionDate="";expectedVersion=$p1.Body.versionNumber}
if($bad.Status-ne 400){throw "Subsanable exception accepted without reason/responsible/date."}
$ex=Call Post "$ApiBaseUrl/portal/scheduling/proposals/$($p1.Body.versionId)/exceptions" $h @{assignmentId=$null;exceptionType="SUBSANABLE";reason="Compromiso documentado";responsible="operaciones.sg";resolutionDate="2026-09-10";expectedVersion=$p1.Body.versionNumber}
if($ex.Status-ne 200-or$ex.Body.exceptionCount-ne 1){throw "Valid exception was not persisted."}
$stale=Call Post "$ApiBaseUrl/portal/scheduling/proposals/$($p1.Body.versionId)/approve" $h @{expectedVersion=999};if($stale.Status-ne 409){throw "Stale expected version was not rejected."}
$approved=Call Post "$ApiBaseUrl/portal/scheduling/proposals/$($p1.Body.versionId)/approve" $h @{expectedVersion=$p1.Body.versionNumber};if($approved.Status-ne 200-or$approved.Body.status-ne"APROBADA"){throw "Approval failed."}
$published=Call Post "$ApiBaseUrl/portal/scheduling/proposals/$($p1.Body.versionId)/publish" $h @{expectedVersion=$p1.Body.versionNumber};if($published.Status-ne 200-or$published.Body.status-ne"PUBLICADA"){throw "Publication failed."}
$p2=Call Post "$ApiBaseUrl/portal/scheduling/projects/$ProjectId/proposals" $h @{periodStart=$PeriodStart;periodEnd=$PeriodEnd;acceptedVacancy=$false};$null=Call Post "$ApiBaseUrl/portal/scheduling/proposals/$($p2.Body.versionId)/approve" $h @{expectedVersion=$p2.Body.versionNumber};$null=Call Post "$ApiBaseUrl/portal/scheduling/proposals/$($p2.Body.versionId)/publish" $h @{expectedVersion=$p2.Body.versionNumber}
$old=Call Get "$ApiBaseUrl/portal/scheduling/proposals/$($p1.Body.versionId)" $h $null;if($old.Body.status-ne"REEMPLAZADA"-or-not$old.Body.acceptedVacancy){throw "Previous publication/vacancy snapshot was not preserved."}
$audit=Call Get "$ApiBaseUrl/portal/scheduling/versions/$($p2.Body.versionId)/audit" $h $null;if($audit.Status-ne 200-or@($audit.Body).Count-lt 3-or-not(@($audit.Body)|Where-Object{$_.eventType-eq'SCHEDULE_PUBLISHED'-and$_.detail-match'"selfManaged": true'})){throw "Workflow publication audit is incomplete."}
Write-Host "I9 WORKFLOW PASS"
