param(
    [string]$PostgresHost = "localhost",
    [int]$PostgresPort = 5432
)

$ErrorActionPreference = "Continue"

function Write-Check {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail = ""
    )

    $line = "{0}: {1}" -f $Name, $Status
    if ($Detail) {
        $line = "{0} - {1}" -f $line, $Detail
    }
    Write-Output $line
}

function Find-CommandVersion {
    param(
        [string]$Command,
        [string]$VersionArg = "--version"
    )

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return $null
    }

    try {
        $version = & $Command $VersionArg 2>$null | Select-Object -First 1
        return $version
    }
    catch {
        return "Detected at $($cmd.Source)"
    }
}

function Find-PostgresClient {
    $psql = Find-CommandVersion "psql" "--version"
    if ($psql) {
        return $psql
    }

    $roots = @(
        "$env:ProgramFiles\PostgreSQL",
        "${env:ProgramFiles(x86)}\PostgreSQL"
    )

    foreach ($root in $roots) {
        if (-not (Test-Path $root)) {
            continue
        }

        $candidates = Get-ChildItem -Path $root -Filter "psql.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($candidates) {
            try {
                $version = & $candidates.FullName --version 2>$null | Select-Object -First 1
                return "$version ($($candidates.FullName))"
            }
            catch {
                return "Detected at $($candidates.FullName)"
            }
        }
    }

    return $null
}

Write-Output "S&G Super App - Local Development Environment Check"
Write-Output "=================================================="

$git = Find-CommandVersion "git"
if ($git) { Write-Check "Git" "OK" $git } else { Write-Check "Git" "MISSING" "Install Git.Git" }

$node = Find-CommandVersion "node" "--version"
if ($node) { Write-Check "Node.js" "OK" $node } else { Write-Check "Node.js" "MISSING" "Install OpenJS.NodeJS.LTS" }

$npm = Find-CommandVersion "npm" "--version"
if ($npm) { Write-Check "npm" "OK" $npm } else { Write-Check "npm" "MISSING" "Installed with Node.js LTS" }

$psql = Find-PostgresClient
if ($psql) { Write-Check "PostgreSQL client" "OK" $psql } else { Write-Check "PostgreSQL client" "MISSING" "Install PostgreSQL.PostgreSQL or add psql to PATH" }

try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $async = $tcp.BeginConnect($PostgresHost, $PostgresPort, $null, $null)
    $connected = $async.AsyncWaitHandle.WaitOne(1500, $false)
    if ($connected) {
        $tcp.EndConnect($async)
        Write-Check "PostgreSQL port $PostgresPort" "OK" "${PostgresHost}:$PostgresPort reachable"
    }
    else {
        Write-Check "PostgreSQL port $PostgresPort" "PENDING" "${PostgresHost}:$PostgresPort not reachable"
    }
    $tcp.Close()
}
catch {
    Write-Check "PostgreSQL port $PostgresPort" "PENDING" $_.Exception.Message
}

$net48 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue
if ($net48 -and $net48.Release -ge 528040) {
    Write-Check ".NET Framework 4.8 runtime" "OK" "Release=$($net48.Release)"
}
else {
    Write-Check ".NET Framework 4.8 runtime" "MISSING" "Install .NET Framework 4.8 Developer Pack/Targeting Pack"
}

$vsWherePaths = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
    "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
)

$vsWhere = $vsWherePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($vsWhere) {
    $vs = & $vsWhere -latest -products * -requires Microsoft.Component.MSBuild -property displayName 2>$null
    if ($vs) {
        Write-Check "Visual Studio / Build Tools" "OK" $vs
    }
    else {
        Write-Check "Visual Studio / Build Tools" "PENDING" "vswhere found, MSBuild workload not confirmed"
    }
}
else {
    Write-Check "Visual Studio / Build Tools" "MISSING" "Install Visual Studio 2022 Community with ASP.NET workload"
}

$dbeaver = Get-Command "dbeaver" -ErrorAction SilentlyContinue
if ($dbeaver) {
    Write-Check "DBeaver" "OK" $dbeaver.Source
}
else {
    Write-Check "DBeaver" "OPTIONAL" "Install dbeaver.dbeaver or use pgAdmin"
}

Write-Output ""
Write-Output "Next: fix MISSING items, then re-run this script before I1 implementation."
