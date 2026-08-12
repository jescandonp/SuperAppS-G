param([string]$ApiBaseUrl="http://localhost:5080/api",[long]$ProjectId=1)
$ErrorActionPreference="Stop"
function Login($u,$p){$r=Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType "application/json" -Body (@{username=$u;password=$p}|ConvertTo-Json);@{Authorization="Bearer $($r.sessionToken)"}}
function Status($method,$uri,$headers,$body){try{(Invoke-WebRequest -UseBasicParsing -Uri $uri -Method $method -Headers $headers -ContentType "application/json" -Body ($body|ConvertTo-Json)).StatusCode}catch{if($null-eq$_.Exception.Response){throw};[int]$_.Exception.Response.StatusCode}}
$uri="$ApiBaseUrl/portal/scheduling/projects/$ProjectId/proposals";$body=@{periodStart="2026-10-01";periodEnd="2026-10-31";acceptedVacancy=$false}
if((Status Post $uri @{} $body)-ne 401){throw "Anonymous workflow call was not rejected with 401."}
$th=Login "th.sg" "Th123456";$ger=Login "gerencia.sg" "Gerencia123";$ops=Login "operaciones.sg" "Operaciones123";$admin=Login "admin.sg" "Admin123"
if((Status Post $uri $th $body)-ne 403){throw "TH generated a proposal."};if((Status Post $uri $ger $body)-ne 403){throw "GERENCIA mutated scheduling."}
$proposal=Invoke-RestMethod -Uri $uri -Method Post -Headers $ops -ContentType "application/json" -Body ($body|ConvertTo-Json)
$approve="$ApiBaseUrl/portal/scheduling/proposals/$($proposal.versionId)/approve";$transition=@{expectedVersion=$proposal.versionNumber}
if((Status Post $approve $th $transition)-ne 403){throw "TH approved a proposal."};if((Status Post $approve $ger $transition)-ne 403){throw "GERENCIA approved a proposal."}
if((Status Post $approve $ops $transition)-ne 200){throw "OPERACIONES could not approve."}
$publish="$ApiBaseUrl/portal/scheduling/proposals/$($proposal.versionId)/publish";if((Status Post $publish $th $transition)-ne 403){throw "TH published a proposal."};if((Status Post $publish $ops $transition)-ne 200){throw "OPERACIONES could not publish."}
$adminBody=@{periodStart="2026-11-01";periodEnd="2026-11-30";acceptedVacancy=$false};if((Status Post $uri $admin $adminBody)-ne 201){throw "ADMIN could not generate."}
Write-Host "I9 SECURITY PASS"
