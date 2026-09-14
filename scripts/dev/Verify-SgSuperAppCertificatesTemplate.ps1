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
