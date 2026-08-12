param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path)
$ErrorActionPreference = 'Stop'
$failures = New-Object System.Collections.Generic.List[string]
function Require-Pattern([string]$relativePath, [string]$pattern, [string]$label) {
    $path = Join-Path $RepositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path) -or (Get-Content -LiteralPath $path -Raw) -notmatch $pattern) { $failures.Add($label) }
}
$types = 'apps/sg-superapp-web/src/types/portal.ts'
foreach ($name in @('ShiftTemplate','SchedulingProject','ScheduleProposal','ScheduleAssignment','ScheduleException','ScheduleComparison','SchedulingCapabilities')) {
    Require-Pattern $types "(?m)^export interface $name\b" "Missing frontend type $name"
}
Require-Pattern $types '(?m)^export type ScheduleStatus = "BORRADOR" \| "PROPUESTA" \| "APROBADA" \| "PUBLICADA" \| "REEMPLAZADA" \| "CANCELADA";' 'Missing exact ScheduleStatus union'
Require-Pattern $types '(?m)^export type ShiftCode = "D" \| "N" \| "X";' 'Missing exact ShiftCode union'
Require-Pattern $types '(?m)^export type RequirementSeverity = "BLOQUEANTE" \| "SUBSANABLE" \| "INFORMATIVA";' 'Missing requirement severity union'
$api = 'apps/sg-superapp-web/src/services/portalApi.ts'
foreach ($name in @('fetchSchedulingCapabilities','fetchSchedulingProjects','fetchShiftTemplates','generateScheduleProposal','fetchScheduleProposal','updateScheduleAssignment','approveScheduleException','approveSchedule','publishSchedule','replanSchedule','downloadSchedulePdf','downloadScheduleXlsx')) {
    Require-Pattern $api "(?m)^export async function $name\b" "Missing frontend API function $name"
}
Require-Pattern $api 'getSessionHeaders\(\)' 'Scheduling client must use session headers'
Require-Pattern $api 'data\.message' 'Scheduling client must propagate backend messages'
Require-Pattern 'apps/sg-superapp-api/Endpoints/PortalEndpoints.cs' 'MapGet\("/api/portal/scheduling/capabilities"' 'Missing scheduling capabilities endpoint'
Require-Pattern 'apps/sg-superapp-api/Endpoints/PortalEndpoints.cs' 'HasPermissionAsync' 'Capabilities must be calculated from permissions'
Require-Pattern 'apps/sg-superapp-web/src/mock/session.ts' 'code: "scheduling"' 'Missing scheduling mock module'
if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Host "I9 FRONTEND API FAIL: $_" }; exit 1 }
Write-Host 'I9 FRONTEND API PASS'
