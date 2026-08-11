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

function Invoke-CycleProjection {
    param([hashtable]$Headers, [object]$Body)

    try {
        $parameters = @{
            Uri = "$ApiBaseUrl/portal/scheduling/cycles/project"
            Method = "POST"
            Headers = $Headers
            ContentType = "application/json"
            Body = ($Body | ConvertTo-Json -Depth 4)
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

function Assert-Projection {
    param(
        [hashtable]$Headers,
        [string[]]$Sequence,
        [string]$AnchorDate,
        [string]$From,
        [string]$To,
        [int]$PhaseOffset,
        [string]$Expected,
        [string]$Message
    )

    $response = Invoke-CycleProjection -Headers $Headers -Body @{
        sequence = $Sequence
        anchorDate = $AnchorDate
        from = $From
        to = $To
        phaseOffset = $PhaseOffset
    }
    if ($response.Status -ne 200) {
        throw "$Message Expected HTTP 200, received $($response.Status)."
    }

    $actual = @($response.Body.days | ForEach-Object { $_.shiftCode }) -join ","
    if ($actual -ne $Expected) {
        throw "$Message Expected '$Expected', received '$actual'."
    }
}

$adminHeaders = Get-SessionHeaders -Username "admin.sg" -Password "Admin123"
$operationsHeaders = Get-SessionHeaders -Username "operaciones.sg" -Password "Operaciones123"
$thHeaders = Get-SessionHeaders -Username "th.sg" -Password "Th123456"

Assert-Projection -Headers $adminHeaders -Sequence @("D", "D", "N", "N", "X", "X") -AnchorDate "2026-07-01" -From "2026-07-01" -To "2026-07-08" -PhaseOffset 0 -Expected "D,D,N,N,X,X,D,D" -Message "2X2 projection failed."
Assert-Projection -Headers $operationsHeaders -Sequence @("D", "D", "D", "D", "N", "N", "X", "X") -AnchorDate "2026-07-01" -From "2026-07-01" -To "2026-07-10" -PhaseOffset 0 -Expected "D,D,D,D,N,N,X,X,D,D" -Message "4X2 projection failed."
Assert-Projection -Headers $adminHeaders -Sequence @("D", "D", "D", "D", "D", "D", "X") -AnchorDate "2026-07-29" -From "2026-07-29" -To "2026-08-06" -PhaseOffset 0 -Expected "D,D,D,D,D,D,X,D,D" -Message "6X1 month boundary projection failed."
Assert-Projection -Headers $adminHeaders -Sequence @("D", "N", "X") -AnchorDate "2026-08-01" -From "2026-07-30" -To "2026-08-03" -PhaseOffset -1 -Expected "D,N,X,D,N" -Message "Negative offset projection failed."

$deterministicBody = @{ sequence = @("D", "D", "D", "D", "N", "N", "X", "X"); anchorDate = "2026-07-01"; from = "2026-07-01"; to = "2026-07-10"; phaseOffset = 0 }
$firstRun = Invoke-CycleProjection -Headers $operationsHeaders -Body $deterministicBody
$secondRun = Invoke-CycleProjection -Headers $operationsHeaders -Body $deterministicBody
if ($firstRun.Status -ne 200 -or $secondRun.Status -ne 200) { throw "Determinism check requests must return HTTP 200." }
$firstJson = $firstRun.Body | ConvertTo-Json -Depth 5 -Compress
$secondJson = $secondRun.Body | ConvertTo-Json -Depth 5 -Compress
if ($firstJson -cne $secondJson) { throw "Identical cycle requests must return identical JSON." }

$empty = Invoke-CycleProjection -Headers $adminHeaders -Body @{ sequence = @(); anchorDate = "2026-07-01"; from = "2026-07-01"; to = "2026-07-02"; phaseOffset = 0 }
if ($empty.Status -ne 400) { throw "Empty sequence must return HTTP 400, received $($empty.Status)." }

$reversed = Invoke-CycleProjection -Headers $adminHeaders -Body @{ sequence = @("D"); anchorDate = "2026-07-01"; from = "2026-07-02"; to = "2026-07-01"; phaseOffset = 0 }
if ($reversed.Status -ne 400) { throw "Reversed range must return HTTP 400, received $($reversed.Status)." }

$forbidden = Invoke-CycleProjection -Headers $thHeaders -Body @{ sequence = @("D"); anchorDate = "2026-07-01"; from = "2026-07-01"; to = "2026-07-01"; phaseOffset = 0 }
if ($forbidden.Status -ne 403) { throw "TH must receive HTTP 403, received $($forbidden.Status)." }

$unauthorized = Invoke-CycleProjection -Headers @{} -Body @{ sequence = @("D"); anchorDate = "2026-07-01"; from = "2026-07-01"; to = "2026-07-01"; phaseOffset = 0 }
if ($unauthorized.Status -ne 401) { throw "Anonymous request must receive HTTP 401, received $($unauthorized.Status)." }

Write-Host "I9 SHIFT CYCLES PASS"
