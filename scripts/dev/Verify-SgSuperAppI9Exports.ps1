param(
    [string]$ApiBaseUrl = "http://localhost:5080/api",
    [long]$VersionId = 1,
    [long]$PositionId = 1,
    [string]$OutputDirectory = ".codex-tmp/i9-exports",
    [string]$VerificationSchema,
    [string]$Database = "sg_superapp_dev",
    [string]$AppPassword = "sg_app_change_me"
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$login = Invoke-RestMethod -Uri "$ApiBaseUrl/auth/login" -Method Post -ContentType application/json -Body (@{username='operaciones.sg';password='Operaciones123'} | ConvertTo-Json)
$headers = @{Authorization="Bearer $($login.sessionToken)"}
foreach ($format in @('pdf','xlsx')) {
    $path = Join-Path $OutputDirectory "schedule.$format"
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "$ApiBaseUrl/portal/scheduling/versions/$VersionId/export.${format}?positionId=$PositionId" -Headers $headers -OutFile $path -PassThru
    } catch {
        if ($null -ne $_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 404) { throw "I9 export endpoint or published version is missing (HTTP 404)." }
        throw
    }
    if ($response.StatusCode -ne 200) { throw "Export $format returned $($response.StatusCode)." }
    if ($response.Headers['Content-Disposition'] -notmatch 'programacion-.*-v[0-9]+') { throw "Export filename is not traceable." }
}
$pdfText = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes((Join-Path $OutputDirectory 'schedule.pdf')))
if (-not $pdfText.StartsWith('%PDF-') -or $pdfText -notmatch '%%EOF') { throw 'Invalid PDF structure.' }
foreach ($label in @('Cliente:','Proyecto:','Periodo:','Version:','Estado: PUBLICADA','Responsable: operaciones.sg')) { if ($pdfText -notmatch [regex]::Escape($label)) { throw "PDF missing $label" } }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path (Join-Path $OutputDirectory 'schedule.xlsx')))
try {
    if (-not ($zip.Entries | Where-Object FullName -eq 'xl/workbook.xml')) { throw 'Invalid XLSX.' }
    $sheet = $zip.Entries | Where-Object FullName -eq 'xl/worksheets/sheet1.xml'
    if ($null -eq $sheet) { throw 'XLSX worksheet missing.' }
    $reader = New-Object IO.StreamReader($sheet.Open())
    try { $sheetXml = $reader.ReadToEnd() } finally { $reader.Dispose() }
    foreach ($label in @('Cliente:','Proyecto:','Periodo:','Version:','PUBLICADA','Responsable: operaciones.sg')) { if ($sheetXml -notmatch [regex]::Escape($label)) { throw "XLSX missing $label" } }
} finally { $zip.Dispose() }
if (-not [string]::IsNullOrWhiteSpace($VerificationSchema)) {
    if ($VerificationSchema -notmatch '^sg_i9_export_[0-9]+_[0-9]{17}$') { throw 'Unsafe verification schema.' }
    $oldPassword=$env:PGPASSWORD; $oldOptions=$env:PGOPTIONS
    try {
        $env:PGPASSWORD=$AppPassword; $env:PGOPTIONS="-c search_path=$VerificationSchema,public"
        $count=& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -X -q -t -A -h localhost -p 5432 -U sg_app -d $Database -c "select count(*) from audit_log where event_type='SCHEDULE_EXPORTED' and entity_id='$VersionId' and detail->>'positionId'='$PositionId' and detail->>'format' in ('pdf','xlsx')"
        if ($LASTEXITCODE -ne 0 -or [int]$count -ne 2) { throw 'Export audit trail is incomplete.' }
    } finally { $env:PGPASSWORD=$oldPassword; $env:PGOPTIONS=$oldOptions }
}
Write-Host 'I9 EXPORTS PASS'
