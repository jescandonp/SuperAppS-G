[CmdletBinding()]
param([string]$RepositoryRoot)

$ErrorActionPreference = 'Stop'
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else { (Resolve-Path $RepositoryRoot).Path }

$certificatesDir = Join-Path $repoRoot 'apps\sg-superapp-api\Certificates'
$repositoryPath = Join-Path $repoRoot 'apps\sg-superapp-api\Services\PostgresPortalRepository.cs'
$csprojPath = Join-Path $repoRoot 'apps\sg-superapp-api\sg-superapp-api.csproj'
$frontendPath = Join-Path $repoRoot 'apps\sg-superapp-web\src\features\certificates\CertificatesPage.tsx'
$failures = [System.Collections.Generic.List[string]]::new()

$requiredFiles = @(
    (Join-Path $certificatesDir 'CertificateLetterhead.cs'),
    (Join-Path $certificatesDir 'CertificateDocumentBuilder.cs'),
    (Join-Path $certificatesDir 'CertificateDocumentData.cs'),
    (Join-Path $certificatesDir 'StandardCertificateTemplate.cs'),
    (Join-Path $certificatesDir 'RetirementCertificateTemplate.cs'),
    (Join-Path $certificatesDir 'CertificateSignatureStamp.cs'),
    (Join-Path $certificatesDir 'CertificateFontResolver.cs'),
    (Join-Path $certificatesDir 'Assets\header.jpg'),
    (Join-Path $certificatesDir 'Assets\footer.jpg'),
    (Join-Path $certificatesDir 'Assets\watermark.png')
)
foreach ($required in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        $failures.Add("Missing required file: $required")
    }
}

if ($failures.Count -eq 0) {
    $repositoryContent = Get-Content -LiteralPath $repositoryPath -Raw
    if ($repositoryContent -match 'BuildCertificatePdf\s*\(') {
        $failures.Add('PostgresPortalRepository still calls the old BuildCertificatePdf')
    }
    if ($repositoryContent -match 'EscapePdfText') {
        $failures.Add('EscapePdfText (accent-stripping) was not removed')
    }
    if ($repositoryContent -notmatch 'CertificateDocumentBuilder\.Build\s*\(') {
        $failures.Add('PostgresPortalRepository does not call CertificateDocumentBuilder.Build')
    }
    if ($repositoryContent -notmatch '"I4-MVP-2"') {
        $failures.Add('templateVersion was not bumped to I4-MVP-2')
    }

    $csprojContent = Get-Content -LiteralPath $csprojPath -Raw
    if ($csprojContent -notmatch 'PackageReference Include="PdfSharpCore"') {
        $failures.Add('sg-superapp-api.csproj is missing the PdfSharpCore package reference')
    }

    $frontendContent = Get-Content -LiteralPath $frontendPath -Raw
    foreach ($fieldCheck in @('addressedTo', 'AUXILIO_TRANSPORTE', 'EXTRAS')) {
        if ($frontendContent -notmatch [regex]::Escape($fieldCheck)) {
            $failures.Add("CertificatesPage.tsx is missing reference to '$fieldCheck'")
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "CERTIFICATES TEMPLATE FAIL: $failure" }
    exit 1
}
Write-Output 'CERTIFICATES TEMPLATE STATIC PASS'

# --- Fase ejecutable: genera 3 certificados reales (ACTIVO, RETIRADO/CESANTIAS,
# RETIRADO/TRAMITE_GENERAL) llamando directamente a CertificateDocumentBuilder
# -- sin servidor web, sin base de datos, sin depender de ningun puerto -- y
# valida el TEXTO del PDF resultante (nombre, numero de certificado, bloque
# legal del Decreto 1562 solo para cesantias, disclaimer de emision unica en
# todo retirado, y al menos una tilde/enie en el cuerpo).
$dotnetCandidates = [System.Collections.Generic.List[string]]::new()
$bundledDotnet = 'C:\tmp\dotnet6\dotnet.exe'
if (Test-Path -LiteralPath $bundledDotnet -PathType Leaf) { $dotnetCandidates.Add($bundledDotnet) }
$dotnetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
if ($null -ne $dotnetCommand -and -not [string]::IsNullOrWhiteSpace($dotnetCommand.Source) -and
    (Test-Path -LiteralPath $dotnetCommand.Source -PathType Leaf)) {
    $dotnetCandidates.Add($dotnetCommand.Source)
}
$dotnetPath = $dotnetCandidates | Select-Object -First 1

$pythonCommand = Get-Command python3 -ErrorAction SilentlyContinue
if ($null -eq $pythonCommand) { $pythonCommand = Get-Command python -ErrorAction SilentlyContinue }

if ([string]::IsNullOrWhiteSpace($dotnetPath) -or $null -eq $pythonCommand) {
    Write-Output 'CERTIFICATES TEMPLATE EXECUTABLE PHASE BLOCKED: dotnet o python3 no disponibles'
    exit 2
}

$renderProject = Join-Path $repoRoot 'scripts\dev\CertificateRenderCheck\CertificateRenderCheck.csproj'
$verifyScript = Join-Path $repoRoot 'scripts\dev\verify-certificate-render.py'
$env:DOTNET_CLI_HOME = if ($env:DOTNET_CLI_HOME) { $env:DOTNET_CLI_HOME } else { 'C:\tmp\dotnet-home' }
$renderOutput = Join-Path ([System.IO.Path]::GetTempPath()) ("sg-cert-render-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $renderOutput | Out-Null

try {
    try {
        $renderOutputLines = & $dotnetPath run --project $renderProject -- $renderOutput 2>&1
        $renderOutputLines | ForEach-Object { Write-Output $_ }
        if ($LASTEXITCODE -ne 0) {
            throw "CertificateRenderCheck no pudo generar los certificados de prueba"
        }

        $verifyOutputLines = & $pythonCommand.Source $verifyScript $renderOutput 2>&1
        $verifyOutputLines | ForEach-Object { Write-Output $_ }
        if ($LASTEXITCODE -ne 0) {
            throw "verify-certificate-render.py fallo"
        }
    }
    catch {
        Write-Output "CERTIFICATES TEMPLATE FAIL: $($_.Exception.Message)"
        exit 1
    }
} finally {
    Remove-Item -LiteralPath $renderOutput -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'CERTIFICATES TEMPLATE EXECUTABLE PHASE PASS'
