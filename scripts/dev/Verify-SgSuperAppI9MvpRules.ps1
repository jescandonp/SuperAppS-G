[CmdletBinding()]
param([string]$RepositoryRoot)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$requestedRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { Join-Path $PSScriptRoot '..\..' } else { $RepositoryRoot }
if (-not (Test-Path -LiteralPath $requestedRoot -PathType Container)) {
    Write-Host 'I9 MVP RULES FAIL'
    Write-Host " - Invalid repository root: '$requestedRoot'"
    exit 1
}
try { $repoRoot = (Resolve-Path -LiteralPath $requestedRoot -ErrorAction Stop).Path }
catch {
    Write-Host 'I9 MVP RULES FAIL'
    Write-Host " - Invalid repository root: '$requestedRoot'"
    exit 1
}

$failures = New-Object 'System.Collections.Generic.List[string]'

function Remove-FullLineComments {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines,
        [string]$Extension = '.cs'
    )
    $effective = New-Object 'System.Collections.Generic.List[string]'
    $lineMarker = if ($Extension -eq '.ps1') { '#' } elseif ($Extension -eq '.sql') { '--' } else { '//' }
    $blockStart = if ($Extension -eq '.ps1') { '<#' } else { '/*' }
    $blockEnd = if ($Extension -eq '.ps1') { '#>' } else { '*/' }
    $inBlock = $false
    foreach ($line in $Lines) {
        $remaining = $line
        $builder = New-Object System.Text.StringBuilder
        while ($remaining.Length -gt 0) {
            if ($inBlock) {
                $endIndex = $remaining.IndexOf($blockEnd, [System.StringComparison]::Ordinal)
                if ($endIndex -lt 0) { $remaining = ''; break }
                $remaining = $remaining.Substring($endIndex + $blockEnd.Length)
                $inBlock = $false
                continue
            }
            $blockIndex = $remaining.IndexOf($blockStart, [System.StringComparison]::Ordinal)
            $lineIndex = $remaining.IndexOf($lineMarker, [System.StringComparison]::Ordinal)
            if ($lineIndex -ge 0 -and ($blockIndex -lt 0 -or $lineIndex -lt $blockIndex)) {
                [void]$builder.Append($remaining.Substring(0, $lineIndex))
                $remaining = ''
                break
            }
            if ($blockIndex -ge 0) {
                [void]$builder.Append($remaining.Substring(0, $blockIndex))
                $remaining = $remaining.Substring($blockIndex + $blockStart.Length)
                $inBlock = $true
                continue
            }
            [void]$builder.Append($remaining)
            $remaining = ''
        }
        $effectiveLine = $builder.ToString()
        if (-not [string]::IsNullOrWhiteSpace($effectiveLine)) { $effective.Add($effectiveLine) }
    }
    return @($effective)
}

function Get-EffectiveContent {
    param([Parameter(Mandatory = $true)][string]$Path)
    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    return (Remove-FullLineComments -Lines @(Get-Content -LiteralPath $Path) -Extension $extension) -join "`n"
}

function Pattern {
    param([Parameter(Mandatory = $true)][string]$Label, [Parameter(Mandatory = $true)][string]$Regex)
    return [pscustomobject]@{ Label = $Label; Regex = $Regex }
}

function Assert-FileContains {
    param(
        [Parameter(Mandatory = $true)][string]$Requirement,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][object[]]$Patterns
    )
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("$Requirement`: missing file '$RelativePath'")
        return
    }
    $content = Get-EffectiveContent -Path $path
    foreach ($pattern in $Patterns) {
        if (-not [regex]::IsMatch($content, $pattern.Regex)) {
            $failures.Add("$Requirement`: '$RelativePath' is missing $($pattern.Label)")
        }
    }
}

function Test-RuleProfileChecksumLinkage {
    param([string]$RepositoryContent, [string]$ValidatorContent)
    return $RepositoryContent -match '(?s)_validator\.Validate\s*\(\s*result\s*,\s*environment\s*\)' -and
        $ValidatorContent -match '(?s)Validate\s*\(.*?ComputeChecksum\s*\(\s*profile\s*\)' -and
        $ValidatorContent -match '(?s)string\.Equals\s*\(\s*profile\.Checksum\s*,\s*ComputeChecksum'
}

function Test-NumberCanonicalizationLinkage {
    param([string]$ValidatorContent)
    return $ValidatorContent -match '(?s)case\s+JsonValueKind\.Number\s*:\s*return\s+NormalizeJsonNumber\s*\(\s*element\.GetRawText\s*\(\s*\)\s*\)' -and
        $ValidatorContent -match '(?s)NormalizeJsonNumber\s*\(\s*string\s+rawNumber\s*\).*?MaximumNumberDigits.*?MaximumNumberScale' -and
        $ValidatorContent -notmatch '(?i)(GetDouble|double\.Parse)'
}

function Test-SqlChecksumCanonicalizationLinkage {
    param([string]$MigrationContent, [string]$SeedContent, [string]$TestContent)
    return $MigrationContent -match '(?s)CREATE\s+OR\s+REPLACE\s+FUNCTION\s+i9_mvp_canonical_jsonb.*?IMMUTABLE' -and
        $MigrationContent -match '(?s)i9_mvp_canonical_number.*?Maximum|i9_mvp_canonical_number.*?1000' -and
        $SeedContent -match '(?s)string_agg\s*\(.*?i9_mvp_canonical_jsonb\s*\(\s*e?\.?parameters\s*\).*?i9_mvp_canonical_jsonb\s*\(\s*e?\.?catalog_snapshot\s*\)' -and
        $TestContent -match '(?s)i9_mvp_canonical_jsonb\s*\(\s*''1e2''::jsonb\s*\).*?i9_mvp_canonical_jsonb\s*\(\s*''100''::jsonb\s*\)'
}

function Test-StringAndDuplicateCanonicalizationLinkage {
    param([string]$ValidatorContent)
    return $ValidatorContent -match '(?s)CanonicalizeJsonString\s*\(\s*string\s+value\s*\).*?ToString\s*\(\s*"x4"' -and
        $ValidatorContent -match '(?s)Dictionary<string,\s*JsonElement>.*?lastProperties\s*\[\s*property\.Name\s*\]\s*=\s*property\.Value' -and
        $ValidatorContent -match '(?s)CanonicalizeJsonString\s*\(\s*property\.Key\s*\)' -and
        $ValidatorContent -notmatch 'JsonSerializer\.Serialize'
}

function ConvertTo-I9CanonicalStringSelfTest {
    param([string]$Value)
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    foreach ($character in $Value.ToCharArray()) {
        $code = [int]$character
        if ($character -eq '"') { [void]$builder.Append('\"') }
        elseif ($character -eq '\') { [void]$builder.Append('\\') }
        elseif ($code -eq 8) { [void]$builder.Append('\b') }
        elseif ($code -eq 9) { [void]$builder.Append('\t') }
        elseif ($code -eq 10) { [void]$builder.Append('\n') }
        elseif ($code -eq 12) { [void]$builder.Append('\f') }
        elseif ($code -eq 13) { [void]$builder.Append('\r') }
        elseif ($code -lt 32) { [void]$builder.Append(('\u{0:x4}' -f $code)) }
        else { [void]$builder.Append($character) }
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function ConvertTo-I9CanonicalDecimalSelfTest {
    param([string]$RawNumber)
    if ($RawNumber -notmatch '^(?<sign>-?)(?<integer>0|[1-9][0-9]*)(?:\.(?<fraction>[0-9]+))?(?:[eE](?<exponent>[+-]?[0-9]+))?$') { throw 'unsupported number' }
    $fraction = if ($Matches.ContainsKey('fraction')) { $Matches['fraction'] } else { '' }
    $digits = ($Matches.integer + $fraction).TrimStart('0')
    if ($digits.Length -eq 0) { return '0' }
    $exponent = if ($Matches.ContainsKey('exponent')) { [int]$Matches['exponent'] } else { 0 }
    $scale = $fraction.Length - $exponent
    while ($digits.EndsWith('0')) { $digits = $digits.Substring(0, $digits.Length - 1); $scale-- }
    if ($scale -lt -1000 -or $scale -gt 1000) { throw 'unsupported scale' }
    if ($scale -le 0) { $canonical = $digits + ('0' * (-$scale)) }
    elseif ($scale -ge $digits.Length) { $canonical = '0.' + ('0' * ($scale - $digits.Length)) + $digits }
    else { $canonical = $digits.Insert($digits.Length - $scale, '.') }
    return $(if ($Matches.sign -eq '-') { '-' + $canonical } else { $canonical })
}

function Invoke-FocusedVerifier {
    param(
        [Parameter(Mandatory = $true)][string]$Requirement,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$PassPattern
    )
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("$Requirement`: missing file '$RelativePath'")
        return
    }
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = 'powershell.exe'
    $info.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$path`" -RepositoryRoot `"$repoRoot`""
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.CreateNoWindow = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(20000)) {
        try { $process.Kill() } catch { }
        $failures.Add("$Requirement`: '$RelativePath' timed out after 20 seconds")
        return
    }
    $process.WaitForExit()
    $output = $stdoutTask.GetAwaiter().GetResult() + "`n" + $stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0 -or $output -notmatch $PassPattern) {
        $failures.Add("$Requirement`: '$RelativePath' did not execute successfully with PASS")
    }
}

$selfTest = (Remove-FullLineComments -Lines @(
    '// RuleProfile ScopeHash',
    'public sealed record RealContract(string Value); // SIMULATED MVP_TEST PRODUCTION checksum I9-R01 I9-R07',
    '/* BLOCKED EXCEPTION_REQUIRED */'
) -Extension '.cs') -join "`n"
if ($selfTest -match 'RuleProfile|ScopeHash|I9-R01|\bPASS\b|\bACTIVE\b|immutable' -or $selfTest -notmatch 'RealContract') {
    throw 'I9 MVP rules verifier comment-filter self-test failed.'
}
$immutabilityPattern = '(?i)(immutab|inmutab|reject|rechaz)'
$immutabilitySelfTest = (Remove-FullLineComments -Lines @(
    '-- immutability must not pass from a comment',
    "RAISE EXCEPTION 'ACTIVE profile immutability failed';"
) -Extension '.sql') -join "`n"
if ($immutabilitySelfTest -match 'must not pass' -or $immutabilitySelfTest -notmatch $immutabilityPattern) {
    throw 'I9 MVP rules verifier immutability terminology self-test failed.'
}
if (-not (Test-RuleProfileChecksumLinkage '_validator.Validate(result, environment)' 'Validate(profile) { string.Equals(profile.Checksum, ComputeChecksum(profile)); }') -or
    (Test-RuleProfileChecksumLinkage 'return result;' 'Validate(profile) { string.Equals(profile.Checksum, ComputeChecksum(profile)); }')) {
    throw 'I9 MVP rules verifier checksum-linkage negative self-test failed.'
}
if (-not (Test-NumberCanonicalizationLinkage 'case JsonValueKind.Number: return NormalizeJsonNumber(element.GetRawText()); internal static string NormalizeJsonNumber(string rawNumber) { MaximumNumberDigits; MaximumNumberScale; }') -or
    (Test-NumberCanonicalizationLinkage 'case JsonValueKind.Number: return element.GetRawText();')) {
    throw 'I9 MVP rules verifier number-canonicalization linkage self-test failed.'
}
$numberEquivalences = @(@('1e2','100'), @('1.0','1.00','1'), @('-0','0'), @('0.0100','0.01'))
foreach ($equivalentSet in $numberEquivalences) {
    if (@($equivalentSet | ForEach-Object { ConvertTo-I9CanonicalDecimalSelfTest $_ } | Select-Object -Unique).Count -ne 1) {
        throw 'I9 MVP rules verifier decimal equivalence self-test failed.'
    }
}
$unsupportedNumberRejected = $false
try { [void](ConvertTo-I9CanonicalDecimalSelfTest '1e1001') } catch { $unsupportedNumberRejected = $true }
if (-not $unsupportedNumberRejected) { throw 'I9 MVP rules verifier unsupported-number negative self-test failed.' }
$sqlLinkagePositive = Test-SqlChecksumCanonicalizationLinkage `
    -MigrationContent 'CREATE OR REPLACE FUNCTION i9_mvp_canonical_jsonb(value jsonb) RETURNS text IMMUTABLE; i9_mvp_canonical_number 1000' `
    -SeedContent 'string_agg(i9_mvp_canonical_jsonb(parameters) || i9_mvp_canonical_jsonb(catalog_snapshot))' `
    -TestContent "i9_mvp_canonical_jsonb('1e2'::jsonb) = i9_mvp_canonical_jsonb('100'::jsonb)"
$sqlLinkageNegative = Test-SqlChecksumCanonicalizationLinkage `
    -MigrationContent 'CREATE FUNCTION raw_json(value jsonb) RETURNS text IMMUTABLE' `
    -SeedContent 'string_agg(parameters::text || catalog_snapshot::text)' `
    -TestContent "i9_mvp_canonical_jsonb('1e2'::jsonb) = i9_mvp_canonical_jsonb('100'::jsonb)"
if (-not $sqlLinkagePositive -or $sqlLinkageNegative) {
    throw 'I9 MVP rules verifier SQL checksum canonicalization linkage self-test failed.'
}
$stringLinkagePositive = 'CanonicalizeJsonString(string value) { code.ToString("x4"); Dictionary<string, JsonElement> lastProperties; lastProperties[property.Name] = property.Value; CanonicalizeJsonString(property.Key); }'
$stringLinkageNegative = 'JsonSerializer.Serialize(property.Name); foreach (property in properties) { emit(property); }'
if (-not (Test-StringAndDuplicateCanonicalizationLinkage $stringLinkagePositive) -or
    (Test-StringAndDuplicateCanonicalizationLinkage $stringLinkageNegative)) {
    throw 'I9 MVP rules verifier string/duplicate linkage self-test failed.'
}
$verticalTabExpected = '"' + '\' + 'u000b"'
if ((ConvertTo-I9CanonicalStringSelfTest ([string][char]11)) -cne $verticalTabExpected -or
    (ConvertTo-I9CanonicalStringSelfTest 'Bogota ñ 😀') -cne '"Bogota ñ 😀"') {
    throw 'I9 MVP rules verifier UTF-8/control string self-test failed.'
}

Assert-FileContains 'Versioned rule profile persistence' 'db/migrations/012_i9_mvp_rule_profiles.sql' @(
    (Pattern 'scheduling_rule_profiles' '(?i)\bscheduling_rule_profiles\b'),
    (Pattern 'scheduling_rule_profile_entries' '(?i)\bscheduling_rule_profile_entries\b'),
    (Pattern 'scheduling_rule_evaluations' '(?i)\bscheduling_rule_evaluations\b'),
    (Pattern 'profile version' '(?i)\bversion\b'), (Pattern 'profile checksum' '(?i)\bchecksum\b'),
    (Pattern 'exception rule code' '(?i)\brule_code\b'), (Pattern 'exception evaluation id' '(?i)\bevaluation_id\b'),
    (Pattern 'exception scope hash' '(?i)\bscope_hash\b'),
    (Pattern 'schedule profile reference' '(?i)\b(rule_profile|rule_profile_id|rule_profile_version)\b'),
    (Pattern 'simulated marker' '(?i)\bsimulated\b'),
    (Pattern 'immutable canonical JSONB function' '(?is)FUNCTION\s+i9_mvp_canonical_jsonb.*?IMMUTABLE'),
    (Pattern 'canonical number function' '(?i)FUNCTION\s+i9_mvp_canonical_number')
)
Assert-FileContains 'Simulated MVP profile seed' 'db/seeds/011_i9_mvp_simulated_rule_profile.sql' @(
    (Pattern 'SIMULATED' '(?i)\bSIMULATED\b'), (Pattern 'MVP_TEST' '(?i)\bMVP_TEST\b'),
    (Pattern 'I9-R01' 'I9-R01'), (Pattern 'I9-R02' 'I9-R02'), (Pattern 'I9-R03' 'I9-R03'),
    (Pattern 'I9-R04' 'I9-R04'), (Pattern 'I9-R05' 'I9-R05'), (Pattern 'I9-R06' 'I9-R06'),
    (Pattern 'I9-R07' 'I9-R07'),
    (Pattern 'canonical parameters checksum' '(?i)i9_mvp_canonical_jsonb\s*\(\s*e?\.?parameters\s*\)'),
    (Pattern 'canonical catalog checksum' '(?i)i9_mvp_canonical_jsonb\s*\(\s*e?\.?catalog_snapshot\s*\)')
)
Assert-FileContains 'Versioned profile database contract' 'db/tests/008_i9_mvp_rule_profiles_contract.sql' @(
    (Pattern 'executable SQL' '(?i)\b(DO|BEGIN|SELECT)\b'), (Pattern 'active uniqueness' '(?i)(unique|overlap|superpuest|vigencia)'),
    (Pattern 'immutability' $immutabilityPattern), (Pattern 'evaluation history' '(?i)evaluat'),
    (Pattern 'semantic number equivalence' "(?is)i9_mvp_canonical_jsonb\s*\(\s*'1e2'::jsonb\s*\).*?i9_mvp_canonical_jsonb\s*\(\s*'100'::jsonb\s*\)"),
    (Pattern 'canonical seed checksum' '(?i)Seed checksum.*canonical executable'),
    (Pattern 'U+000B lowercase escape' '(?is)to_jsonb\s*\(\s*chr\s*\(\s*11\s*\)\s*\).*?u000b'),
    (Pattern 'nested duplicate last-wins' '(?is)"outer".*?"dup"\s*:\s*1.*?"dup"\s*:\s*2.*?"dup"\s*:\s*2')
)
$migrationChecksumPath = Join-Path $repoRoot 'db/migrations/012_i9_mvp_rule_profiles.sql'
$seedChecksumPath = Join-Path $repoRoot 'db/seeds/011_i9_mvp_simulated_rule_profile.sql'
$testChecksumPath = Join-Path $repoRoot 'db/tests/008_i9_mvp_rule_profiles_contract.sql'
if ((Test-Path $migrationChecksumPath) -and (Test-Path $seedChecksumPath) -and (Test-Path $testChecksumPath)) {
    $sqlChecksumLinked = Test-SqlChecksumCanonicalizationLinkage `
        -MigrationContent (Get-EffectiveContent $migrationChecksumPath) `
        -SeedContent (Get-EffectiveContent $seedChecksumPath) `
        -TestContent (Get-EffectiveContent $testChecksumPath)
    if (-not $sqlChecksumLinked) {
        $failures.Add('Cross-layer checksum contract: migration, seed and SQL test are not linked to canonical JSONB')
    }
}

Assert-FileContains 'Typed profile and result contracts' 'apps/sg-superapp-api/Domain/SchedulingRuleModels.cs' @(
    (Pattern 'ProfileCode' '(?i)ProfileCode'), (Pattern 'Version' '(?i)\bVersion\b'),
    (Pattern 'Origin' '(?i)\bOrigin\b'), (Pattern 'EnvironmentScope' '(?i)EnvironmentScope'),
    (Pattern 'EffectiveFrom' '(?i)EffectiveFrom'), (Pattern 'EffectiveTo' '(?i)EffectiveTo'),
    (Pattern 'Status' '(?i)\bStatus\b'), (Pattern 'Checksum' '(?i)Checksum'),
    (Pattern 'RuleEvaluation' '(?i)(record|class)\s+RuleEvaluation'),
    (Pattern 'COMPLIANT' '(?i)COMPLIANT'), (Pattern 'BLOCKED' '(?i)BLOCKED'),
    (Pattern 'EXCEPTION_REQUIRED' '(?i)EXCEPTION_REQUIRED'), (Pattern 'WARNING' '(?i)WARNING'),
    (Pattern 'NOT_APPLICABLE' '(?i)NOT_APPLICABLE'), (Pattern 'ScopeHash' '(?i)ScopeHash')
)
Assert-FileContains 'Profile repository' 'apps/sg-superapp-api/Services/SchedulingRuleProfileRepository.cs' @(
    (Pattern 'ACTIVE' '(?i)ACTIVE'), (Pattern 'project' '(?i)(project|proyecto)'),
    (Pattern 'period' '(?i)(period|periodo)'), (Pattern 'environment' '(?i)(environment|ambiente)'),
    (Pattern 'profile entries' '(?i)SchedulingRuleProfileEntr'),
    (Pattern 'exactly one fail closed' '(?i)Count\s*!=\s*1'),
    (Pattern 'shared profile validation' '(?i)_validator\.Validate\s*\(')
)
Assert-FileContains 'Profile validation and environment gate' 'apps/sg-superapp-api/Services/SchedulingRuleProfileValidator.cs' @(
    (Pattern 'SIMULATED' '(?i)SIMULATED'), (Pattern 'MVP_TEST' '(?i)MVP_TEST'),
    (Pattern 'PRODUCTION' '(?i)PRODUCTION'), (Pattern 'checksum' '(?i)checksum'),
    (Pattern 'canonical property order' '(?i)OrderBy\s*\('), (Pattern 'SHA-256 checksum' '(?i)SHA256'),
    (Pattern 'PostgreSQL JSONB representation' '(?i)ToPostgresJsonbText'),
    (Pattern 'exact decimal normalization' '(?i)NormalizeJsonNumber'),
    (Pattern 'bounded number digits' '(?i)MaximumNumberDigits'),
    (Pattern 'bounded number scale' '(?i)MaximumNumberScale'),
    (Pattern 'canonical string serializer' '(?i)CanonicalizeJsonString'),
    (Pattern 'lowercase control hex' '(?i)ToString\s*\(\s*"x4"'),
    (Pattern 'duplicate last-wins dictionary' '(?s)Dictionary<string,\s*JsonElement>.*?\[\s*property\.Name\s*\]\s*=\s*property\.Value'),
    (Pattern 'overlap validation' '(?i)RangesOverlap'),
    (Pattern 'I9-R01' 'I9-R01'), (Pattern 'I9-R02' 'I9-R02'), (Pattern 'I9-R03' 'I9-R03'),
    (Pattern 'I9-R04' 'I9-R04'), (Pattern 'I9-R05' 'I9-R05'), (Pattern 'I9-R06' 'I9-R06'),
    (Pattern 'I9-R07' 'I9-R07')
)
$repositoryPath = Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingRuleProfileRepository.cs'
$validatorPath = Join-Path $repoRoot 'apps/sg-superapp-api/Services/SchedulingRuleProfileValidator.cs'
if ((Test-Path -LiteralPath $repositoryPath -PathType Leaf) -and (Test-Path -LiteralPath $validatorPath -PathType Leaf) -and
    -not (Test-RuleProfileChecksumLinkage (Get-EffectiveContent $repositoryPath) (Get-EffectiveContent $validatorPath))) {
    $failures.Add('Rule profile checksum contract: repository is not linked to validator ComputeChecksum comparison')
}
if ((Test-Path -LiteralPath $validatorPath -PathType Leaf) -and
    -not (Test-NumberCanonicalizationLinkage (Get-EffectiveContent $validatorPath))) {
    $failures.Add('Rule profile checksum contract: JSON numbers are not linked to bounded exact canonicalization')
}
if ((Test-Path -LiteralPath $validatorPath -PathType Leaf) -and
    -not (Test-StringAndDuplicateCanonicalizationLinkage (Get-EffectiveContent $validatorPath))) {
    $failures.Add('Rule profile checksum contract: strings or duplicate keys are not PostgreSQL-compatible')
}
Assert-FileContains 'Rule profile dependency registration' 'apps/sg-superapp-api/Program.cs' @(
    (Pattern 'profile validator DI' '(?i)AddSingleton<SchedulingRuleProfileValidator>'),
    (Pattern 'profile repository DI' '(?i)AddSingleton<SchedulingRuleProfileRepository>')
)
Assert-FileContains 'Common evaluator' 'apps/sg-superapp-api/Services/SchedulingRuleEvaluator.cs' @(
    (Pattern 'BLOCKED precedence' '(?i)BLOCKED'), (Pattern 'I9-R03' 'I9-R03'),
    (Pattern 'I9-R05' 'I9-R05'), (Pattern 'scopeHash' '(?i)scopeHash'),
    (Pattern 'parameters' '(?i)(parameter|parametro)'), (Pattern 'facts snapshot' '(?i)(facts|hechos|snapshot)')
)

$implementations = @(
    @{ R='I9-R01/R02 rules'; P='apps/sg-superapp-api/Services/SchedulingWorkRestRules.cs'; X=@((Pattern 'I9-R01' 'I9-R01'),(Pattern 'I9-R02' 'I9-R02'),(Pattern '8' '\b8\b'),(Pattern '10' '\b10\b'),(Pattern '12' '\b12\b'),(Pattern '42' '\b42\b'),(Pattern '60' '\b60\b'),(Pattern 'rest' '(?i)(rest|descanso)')) },
    @{ R='I9-R03/R05 rules'; P='apps/sg-superapp-api/Services/SchedulingOverlapTravelRules.cs'; X=@((Pattern 'I9-R03' 'I9-R03'),(Pattern 'I9-R05' 'I9-R05'),(Pattern 'overlap' '(?i)(overlap|solap)'),(Pattern 'directional' '(?i)(direction|direcc|travel|traslado)'),(Pattern 'prohibited' '(?i)(prohibit|prohibid)')) },
    @{ R='I9-R04/R06 rules'; P='apps/sg-superapp-api/Services/SchedulingNoveltyRequirementRules.cs'; X=@((Pattern 'I9-R04' 'I9-R04'),(Pattern 'I9-R06' 'I9-R06'),(Pattern 'unknown' '(?i)(UNKNOWN|UNVERIFIED)'),(Pattern 'employeeId' '(?i)employeeId'),(Pattern 'position' '(?i)(position|puesto)'),(Pattern 'requirement' '(?i)(requirement|requisito)'),(Pattern 'evidence' '(?i)(evidence|evidencia)'),(Pattern 'validity' '(?i)(valid|vigencia|expiry|expires)')) },
    @{ R='I9-R07 rule'; P='apps/sg-superapp-api/Services/SchedulingTemplateDeviationRule.cs'; X=@((Pattern 'I9-R07' 'I9-R07'),(Pattern 'template' '(?i)(template|plantilla)'),(Pattern 'version' '(?i)version'),(Pattern 'anchor' '(?i)(anchor|anclaje)'),(Pattern 'expected' '(?i)(expected|esperado)'),(Pattern 'proposed' '(?i)(proposed|propuesto)'),(Pattern 'cell' '(?i)(cell|celda)'),(Pattern 'scopeHash' '(?i)scopeHash')) }
)
foreach ($item in $implementations) { Assert-FileContains $item.R $item.P $item.X }

Assert-FileContains 'Rule profile HTTP endpoints' 'apps/sg-superapp-api/Endpoints/SchedulingRuleEndpoints.cs' @(
    (Pattern 'GET mapping' '(?i)MapGet'), (Pattern 'POST mapping' '(?i)MapPost'),
    (Pattern 'rule-profiles' '(?i)rule-profiles'), (Pattern 'id route' '(?i)\{id(?::long)?\}'),
    (Pattern 'activate' '(?i)activate'), (Pattern 'retire' '(?i)retire'), (Pattern 'rules/evaluate' '(?i)rules/evaluate'),
    (Pattern 'VIEW' '(?i)\bVIEW\b'), (Pattern 'CONFIGURE' '(?i)\bCONFIGURE\b'), (Pattern 'GENERATE' '(?i)\bGENERATE\b')
)
Assert-FileContains 'Rule HTTP contracts' 'apps/sg-superapp-api/Contracts/Portal/SchedulingRuleContracts.cs' @(
    (Pattern 'RuleProfile' '(?i)RuleProfile'), (Pattern 'RuleEvaluation summary' '(?i)(RuleEvaluation|RuleSummary)'),
    (Pattern 'scopeHash' '(?i)scopeHash'), (Pattern 'simulated' '(?i)simulated')
)
Assert-FileContains 'Endpoint registration' 'apps/sg-superapp-api/Program.cs' @(
    (Pattern 'rule endpoint mapping' '(?i)(MapSchedulingRule|SchedulingRuleEndpoints)')
)

Assert-FileContains 'Scheduling domain integration' 'apps/sg-superapp-api/Domain/SchedulingModels.cs' @(
    (Pattern 'rule profile' '(?i)RuleProfile(Id|Version|Reference)'), (Pattern 'RuleEvaluation' '(?i)RuleEvaluation'),
    (Pattern 'ScopeHash' '(?i)ScopeHash'), (Pattern 'Simulated' '(?i)Simulated')
)
Assert-FileContains 'Workflow contracts' 'apps/sg-superapp-api/Contracts/Portal/SchedulingContracts.cs' @(
    (Pattern 'workflow response' '(?i)ScheduleWorkflowResponse'), (Pattern 'rule profile' '(?i)RuleProfile'),
    (Pattern 'rule result' '(?i)Rule(Evaluation|Summary|Result)'), (Pattern 'simulated' '(?i)Simulated'),
    (Pattern 'manual edit' '(?i)UpdateScheduleAssignmentRequest'), (Pattern 'exception request' '(?i)CreateScheduleExceptionRequest'),
    (Pattern 'RuleCode' '(?i)RuleCode'), (Pattern 'EvaluationId' '(?i)EvaluationId'), (Pattern 'ScopeHash' '(?i)ScopeHash'),
    (Pattern 'motive code' '(?i)(MotiveCode|ReasonCode)'), (Pattern 'transition' '(?i)ScheduleTransitionRequest')
)
Assert-FileContains 'Eligibility integration' 'apps/sg-superapp-api/Services/SchedulingEligibilityService.cs' @(
    (Pattern 'SchedulingRuleEvaluator' '(?i)SchedulingRuleEvaluator'), (Pattern 'BLOCKED' '(?i)BLOCKED')
)
Assert-FileContains 'Recommendation integration' 'apps/sg-superapp-api/Services/SchedulingRecommendationEngine.cs' @(
    (Pattern 'RuleEvaluation' '(?i)RuleEvaluation'), (Pattern 'EXCEPTION_REQUIRED' '(?i)EXCEPTION_REQUIRED')
)
Assert-FileContains 'Workflow persistence' 'apps/sg-superapp-api/Services/PostgresPortalRepository.cs' @(
    (Pattern 'rule profile' '(?i)(rule.*profile|profile.*rule)'), (Pattern 'scopeHash' '(?i)scopeHash'),
    (Pattern 'simulated' '(?i)simulated'), (Pattern 'rule result' '(?i)(RuleEvaluation|BLOCKED|EXCEPTION_REQUIRED)')
)
Assert-FileContains 'Workflow endpoint enforcement' 'apps/sg-superapp-api/Endpoints/PortalEndpoints.cs' @(
    (Pattern 'exceptions' '(?i)/exceptions'), (Pattern 'approve' '(?i)/approve'), (Pattern 'publish' '(?i)/publish'),
    (Pattern 'RuleCode' '(?i)RuleCode'), (Pattern 'EvaluationId' '(?i)EvaluationId'), (Pattern 'ScopeHash' '(?i)ScopeHash'),
    (Pattern 'rule blocking' '(?i)(RuleEvaluation|BLOCKED|EXCEPTION_REQUIRED)'),
    (Pattern 'stale conflict' '(?i)(Conflict|409|stale|obsolet|desactual)')
)

Assert-FileContains 'Frontend rule types' 'apps/sg-superapp-web/src/types/portal.ts' @(
    (Pattern 'RuleProfile' '(?i)RuleProfile'), (Pattern 'rule result' '(?i)Rule(Evaluation|Summary|Result)'),
    (Pattern 'scopeHash' '(?i)scopeHash'), (Pattern 'simulated' '(?i)simulated')
)
Assert-FileContains 'Frontend API' 'apps/sg-superapp-web/src/services/portalApi.ts' @(
    (Pattern 'rule-profiles' '(?i)rule-profiles'), (Pattern 'rules/evaluate' '(?i)rules/evaluate')
)
Assert-FileContains 'Frontend rule state' 'apps/sg-superapp-web/src/hooks/usePortalShell.ts' @(
    (Pattern 'ruleProfile' '(?i)ruleProfile'), (Pattern 'rule results' '(?i)rule(Evaluation|Summary|Results)'),
    (Pattern 'revalidation' '(?i)(revalid|evaluateRules|ruleEvaluation)')
)
Assert-FileContains 'Frontend rule panel' 'apps/sg-superapp-web/src/features/scheduling/RuleEvaluationPanel.tsx' @(
    (Pattern 'simulated label' '(?i)DATOS SIMULADOS\s*-\s*MVP'), (Pattern 'BLOCKED' '(?i)BLOCKED'),
    (Pattern 'EXCEPTION_REQUIRED' '(?i)EXCEPTION_REQUIRED'), (Pattern 'WARNING' '(?i)WARNING'),
    (Pattern 'accessible status' '(?i)(aria-live|role=.status)')
)
Assert-FileContains 'Scheduling page rule panel' 'apps/sg-superapp-web/src/features/scheduling/SchedulingPage.tsx' @(
    (Pattern 'RuleEvaluationPanel' '(?i)RuleEvaluationPanel'), (Pattern 'simulated' '(?i)simulated')
)
Assert-FileContains 'Exception panel snapshot' 'apps/sg-superapp-web/src/features/scheduling/ExceptionPanel.tsx' @(
    (Pattern 'ruleCode' '(?i)ruleCode'), (Pattern 'scopeHash' '(?i)scopeHash')
)

$focused = @(
    @{ R='I9-R01/R02 verifier'; P='scripts/dev/Verify-SgSuperAppI9R01R02.ps1'; Pass='I9 R01 R02 PASS' },
    @{ R='I9-R03/R05 verifier'; P='scripts/dev/Verify-SgSuperAppI9R03R05.ps1'; Pass='I9 R03 R05 PASS' },
    @{ R='I9-R04/R06 verifier'; P='scripts/dev/Verify-SgSuperAppI9R04R06.ps1'; Pass='I9 R04 R06 PASS' },
    @{ R='I9-R07 verifier'; P='scripts/dev/Verify-SgSuperAppI9R07.ps1'; Pass='I9 R07 PASS' }
)
foreach ($verifier in $focused) { Invoke-FocusedVerifier $verifier.R $verifier.P $verifier.Pass }

Assert-FileContains 'MVP generation verifier' 'scripts/dev/Verify-SgSuperAppI9MvpGeneration.ps1' @(
    (Pattern 'BLOCKED' '(?i)BLOCKED'), (Pattern 'candidate' '(?i)(candidate|candidato|assign|asign)'),
    (Pattern 'scopeHash' '(?i)scopeHash'), (Pattern 'invalidation' '(?i)(invalid|recalcul|change|cambi)')
)
Assert-FileContains 'MVP workflow verifier' 'scripts/dev/Verify-SgSuperAppI9MvpWorkflow.ps1' @(
    (Pattern 'scopeHash' '(?i)scopeHash'), (Pattern 'stale' '(?i)(stale|obsolet|desactual|invalid)'),
    (Pattern 'approval' '(?i)(approv|aproba)'), (Pattern 'publication' '(?i)(publish|publica)'),
    (Pattern 'blocking' '(?i)(BLOCKED|EXCEPTION_REQUIRED)')
)
Assert-FileContains 'MVP frontend API verifier' 'scripts/dev/Verify-SgSuperAppI9MvpFrontendApi.ps1' @(
    (Pattern 'ruleProfile' '(?i)ruleProfile'), (Pattern 'simulated' '(?i)simulated')
)
Assert-FileContains 'MVP UI verifier' 'scripts/dev/Verify-SgSuperAppI9MvpUi.ps1' @(
    (Pattern 'simulated label' '(?i)DATOS SIMULADOS\s*-\s*MVP'), (Pattern 'BLOCKED' '(?i)BLOCKED'),
    (Pattern 'EXCEPTION_REQUIRED' '(?i)EXCEPTION_REQUIRED'), (Pattern 'WARNING' '(?i)WARNING')
)
Assert-FileContains 'Existing I9 suite regression' 'scripts/dev/Verify-SgSuperAppI9Integration.ps1' @(
    (Pattern 'MVP rules' '(?i)Verify-SgSuperAppI9MvpRules\.ps1'),
    (Pattern 'MVP integration' '(?i)Verify-SgSuperAppI9MvpIntegration\.ps1'),
    (Pattern 'eligibility' '(?i)Verify-SgSuperAppI9Eligibility\.ps1'),
    (Pattern 'recommendations' '(?i)Verify-SgSuperAppI9Recommendations\.ps1'),
    (Pattern 'workflow' '(?i)Verify-SgSuperAppI9Workflow\.ps1'),
    (Pattern 'security' '(?i)Verify-SgSuperAppI9Security\.ps1'),
    (Pattern 'exports' '(?i)Verify-SgSuperAppI9Exports\.ps1')
)
Assert-FileContains 'Hermetic MVP closure suite' 'scripts/dev/Verify-SgSuperAppI9MvpIntegration.ps1' @(
    (Pattern 'I9-R01' 'I9-R01'), (Pattern 'I9-R02' 'I9-R02'), (Pattern 'I9-R03' 'I9-R03'),
    (Pattern 'I9-R04' 'I9-R04'), (Pattern 'I9-R05' 'I9-R05'), (Pattern 'I9-R06' 'I9-R06'),
    (Pattern 'I9-R07' 'I9-R07'), (Pattern 'MVP_TEST' '(?i)MVP_TEST'), (Pattern 'SIMULATED' '(?i)SIMULATED'),
    (Pattern 'PRODUCTION' '(?i)PRODUCTION'), (Pattern 'production rejection' '(?i)(reject|rechaz|fail|conflict)'),
    (Pattern 'double execution' '(?i)(double|doble|twice|segunda ejecucion)'), (Pattern 'PASS' '(?i)I9 MVP.*PASS')
)

if ($failures.Count -gt 0) {
    Write-Host 'I9 MVP RULES FAIL'
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}
Write-Host 'I9 MVP RULES PASS'
