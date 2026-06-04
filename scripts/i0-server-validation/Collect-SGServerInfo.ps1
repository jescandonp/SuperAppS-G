param(
    [string]$OutputRoot = ".",
    [string]$SmtpHost = "",
    [int]$SmtpPort = 25,
    [string]$DbHost = "",
    [int[]]$DbPorts = @(1433, 3306, 5432, 1521),
    [string]$PortalDns = ""
)

$ErrorActionPreference = "Continue"

function New-OutputFolder {
    param([string]$Root)
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $path = Join-Path $Root ("SG-I0-Validation-" + $stamp)
    New-Item -Path $path -ItemType Directory -Force | Out-Null
    return (Resolve-Path $path).Path
}

function Write-Section {
    param([string]$Title)
    Add-Content -Path $global:ReportPath -Value ""
    Add-Content -Path $global:ReportPath -Value ("## " + $Title)
    Add-Content -Path $global:ReportPath -Value ""
}

function Write-Kv {
    param([string]$Key, [string]$Value)
    if ($null -eq $Value -or $Value -eq "") { $Value = "No detectado" }
    Add-Content -Path $global:ReportPath -Value ("- **" + $Key + ":** " + $Value)
}

function Save-Text {
    param([string]$Name, [object]$Value)
    $file = Join-Path $global:OutputPath $Name
    try {
        $Value | Out-String -Width 240 | Set-Content -Path $file -Encoding UTF8
    } catch {
        ("ERROR: " + $_.Exception.Message) | Set-Content -Path $file -Encoding UTF8
    }
}

function Test-TcpPort {
    param([string]$HostName, [int]$Port)
    $result = New-Object PSObject -Property @{
        Host = $HostName
        Port = $Port
        Open = $false
        Error = ""
    }
    if ([string]::IsNullOrWhiteSpace($HostName)) {
        $result.Error = "Host no informado"
        return $result
    }
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne(3000, $false)
        if ($wait -and $client.Connected) {
            $client.EndConnect($async)
            $result.Open = $true
        } else {
            $result.Error = "Timeout o puerto cerrado"
        }
        $client.Close()
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

function Get-DotNetFrameworkInfo {
    $items = @()
    $base = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP"
    if (Test-Path $base) {
        Get-ChildItem $base -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($props.Version -or $props.Release) {
                $items += New-Object PSObject -Property @{
                    RegistryPath = $_.Name
                    Version = $props.Version
                    Release = $props.Release
                    Install = $props.Install
                    SP = $props.SP
                }
            }
        }
    }
    return $items
}

function Get-CommandVersion {
    param([string]$Command, [string]$VersionArg)
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        return "No detectado"
    }
    try {
        $output = & $Command $VersionArg 2>&1 | Out-String
        return (($output -split "`r?`n") | Where-Object { $_ -ne "" } | Select-Object -First 3) -join " | "
    } catch {
        return "Detectado en PATH, version no consultable: " + $_.Exception.Message
    }
}

function Get-InstalledProgramSummary {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    $programs = @()
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Get-ChildItem $path -ErrorAction SilentlyContinue | ForEach-Object {
                $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                if ($p.DisplayName) {
                    $programs += New-Object PSObject -Property @{
                        DisplayName = $p.DisplayName
                        DisplayVersion = $p.DisplayVersion
                        Publisher = $p.Publisher
                        InstallDate = $p.InstallDate
                    }
                }
            }
        }
    }
    return $programs | Sort-Object DisplayName -Unique
}

$global:OutputPath = New-OutputFolder -Root $OutputRoot
$global:ReportPath = Join-Path $global:OutputPath "SG-I0-Server-Report.md"
$transcript = Join-Path $global:OutputPath "transcript.txt"

try { Start-Transcript -Path $transcript -Force | Out-Null } catch {}

Set-Content -Path $global:ReportPath -Encoding UTF8 -Value "# S&G Super App - I0 Server Validation Report"
Add-Content -Path $global:ReportPath -Value ""
Add-Content -Path $global:ReportPath -Value ("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Add-Content -Path $global:ReportPath -Value ("Computer: " + $env:COMPUTERNAME)
Add-Content -Path $global:ReportPath -Value ""

Write-Section "1. Operating System"
$os = Get-WmiObject Win32_OperatingSystem
$cs = Get-WmiObject Win32_ComputerSystem
$cpu = Get-WmiObject Win32_Processor
$bios = Get-WmiObject Win32_BIOS
$isAdmin = $false
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {}

Write-Kv "OS Caption" $os.Caption
Write-Kv "OS Version" $os.Version
Write-Kv "Service Pack" $os.CSDVersion
Write-Kv "Architecture" $os.OSArchitecture
Write-Kv "Is 64-bit OS" ([Environment]::Is64BitOperatingSystem.ToString())
Write-Kv "Computer Domain" $cs.Domain
Write-Kv "Manufacturer/Model" ($cs.Manufacturer + " / " + $cs.Model)
Write-Kv "RAM GB" ([math]::Round($cs.TotalPhysicalMemory / 1GB, 2).ToString())
Write-Kv "CPU" (($cpu | Select-Object -First 1).Name)
Write-Kv "CPU Cores Logical" ((($cpu | Measure-Object NumberOfLogicalProcessors -Sum).Sum).ToString())
Write-Kv "BIOS Serial" $bios.SerialNumber
Write-Kv "Current User" ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
Write-Kv "Running As Admin" ($isAdmin.ToString())
Write-Kv "PowerShell Version" ($PSVersionTable.PSVersion.ToString())
Save-Text "01-os.txt" ($os, $cs, $cpu, $bios, $PSVersionTable)

Write-Section "2. Disks"
$disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, VolumeName, FileSystem, @{Name="SizeGB";Expression={[math]::Round($_.Size/1GB,2)}}, @{Name="FreeGB";Expression={[math]::Round($_.FreeSpace/1GB,2)}}
$disks | ForEach-Object { Write-Kv ("Drive " + $_.DeviceID) ("Free " + $_.FreeGB + " GB / Size " + $_.SizeGB + " GB / FS " + $_.FileSystem) }
Save-Text "02-disks.txt" $disks

Write-Section "3. Network"
$net = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" | Select-Object Description, DHCPEnabled, IPAddress, IPSubnet, DefaultIPGateway, DNSServerSearchOrder, MACAddress
Save-Text "03-network.txt" $net
Write-Kv "Network adapters detected" (($net | Measure-Object).Count.ToString())
try {
    $ipconfig = ipconfig /all
    Save-Text "03-ipconfig-all.txt" $ipconfig
} catch {}

if ($PortalDns -ne "") {
    Write-Section "4. DNS Check"
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($PortalDns) | ForEach-Object { $_.IPAddressToString }
        Write-Kv ("DNS " + $PortalDns) ($resolved -join ", ")
    } catch {
        Write-Kv ("DNS " + $PortalDns) ("ERROR: " + $_.Exception.Message)
    }
}

Write-Section "5. IIS And Windows Features"
$featuresAvailable = $false
try {
    $features = Get-WindowsFeature -ErrorAction Stop | Where-Object { $_.Name -like "Web-*" -or $_.Name -like "*NET*" } | Select-Object Name, DisplayName, Installed
    $featuresAvailable = $true
    Save-Text "04-windows-features.txt" $features
    $iis = $features | Where-Object { $_.Name -eq "Web-Server" }
    if ($iis) { Write-Kv "IIS Web-Server feature" ($iis.Installed.ToString()) }
} catch {
    Write-Kv "Get-WindowsFeature" ("No disponible o sin permisos: " + $_.Exception.Message)
}

try {
    $w3svc = Get-Service W3SVC -ErrorAction SilentlyContinue
    if ($w3svc) { Write-Kv "W3SVC service" ($w3svc.Status.ToString()) } else { Write-Kv "W3SVC service" "No detectado" }
} catch {}

try {
    Import-Module WebAdministration -ErrorAction Stop
    $sites = Get-ChildItem IIS:\Sites | Select-Object Name, State, PhysicalPath, Bindings
    Save-Text "04-iis-sites.txt" $sites
    Write-Kv "IIS Sites" (($sites | Measure-Object).Count.ToString())
} catch {
    Write-Kv "WebAdministration module" ("No disponible: " + $_.Exception.Message)
}

Write-Section "6. Runtimes"
$dotnetFramework = Get-DotNetFrameworkInfo
Save-Text "05-dotnet-framework.txt" $dotnetFramework
Write-Kv ".NET Framework entries" (($dotnetFramework | Measure-Object).Count.ToString())
Write-Kv "Java" (Get-CommandVersion "java" "-version")
Write-Kv "Javac" (Get-CommandVersion "javac" "-version")
Write-Kv "Node.js" (Get-CommandVersion "node" "--version")
Write-Kv "npm" (Get-CommandVersion "npm" "--version")
Write-Kv "PHP" (Get-CommandVersion "php" "-v")
Write-Kv "Python" (Get-CommandVersion "python" "--version")

Write-Section "7. Database Signals"
$services = Get-Service | Select-Object Name, DisplayName, Status
$dbServices = $services | Where-Object {
    $_.Name -match "MSSQL|SQL|MySQL|Maria|Postgre|Oracle|Mongo" -or
    $_.DisplayName -match "SQL Server|MySQL|MariaDB|PostgreSQL|Oracle|Mongo"
}
Save-Text "06-db-services.txt" $dbServices
if (($dbServices | Measure-Object).Count -gt 0) {
    $dbServices | ForEach-Object { Write-Kv ("DB Service " + $_.Name) ($_.DisplayName + " / " + $_.Status) }
} else {
    Write-Kv "DB Services" "No detectados por nombre comun"
}

if ($DbHost -ne "") {
    Write-Section "8. Database Port Connectivity"
    $dbPortResults = @()
    foreach ($port in $DbPorts) {
        $dbPortResults += Test-TcpPort -HostName $DbHost -Port $port
    }
    Save-Text "07-db-port-tests.txt" $dbPortResults
    $dbPortResults | ForEach-Object { Write-Kv ($_.Host + ":" + $_.Port) ("Open=" + $_.Open + " " + $_.Error) }
}

Write-Section "9. SMTP Connectivity"
if ($SmtpHost -ne "") {
    $smtpResult = Test-TcpPort -HostName $SmtpHost -Port $SmtpPort
    Save-Text "08-smtp-test.txt" $smtpResult
    Write-Kv ($SmtpHost + ":" + $SmtpPort) ("Open=" + $smtpResult.Open + " " + $smtpResult.Error)
} else {
    Write-Kv "SMTP test" "No ejecutado. Use -SmtpHost <host> -SmtpPort <port>."
}

Write-Section "10. Firewall And Security Signals"
try {
    $fw = netsh advfirewall show allprofiles
    Save-Text "09-firewall.txt" $fw
    Write-Kv "Firewall report" "Guardado en 09-firewall.txt"
} catch {
    Write-Kv "Firewall report" ("ERROR: " + $_.Exception.Message)
}

try {
    $av = Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntiVirusProduct -ErrorAction Stop
    Save-Text "09-antivirus.txt" $av
    Write-Kv "Antivirus products" (($av | Measure-Object).Count.ToString())
} catch {
    Write-Kv "Antivirus products" "No consultable en este servidor o namespace no disponible"
}

Write-Section "11. Installed Programs Summary"
$programs = Get-InstalledProgramSummary
$programs | Export-Csv -Path (Join-Path $global:OutputPath "10-installed-programs.csv") -NoTypeInformation -Encoding UTF8
Write-Kv "Installed programs CSV" "10-installed-programs.csv"

Write-Section "12. Manual Follow-Up Required"
Add-Content -Path $global:ReportPath -Value "- Confirmar si se permite instalar runtimes nuevos."
Add-Content -Path $global:ReportPath -Value "- Confirmar motor de base de datos autorizado."
Add-Content -Path $global:ReportPath -Value "- Confirmar cuenta SMTP institucional y credenciales."
Add-Content -Path $global:ReportPath -Value "- Confirmar ruta autorizada para PDFs y backups."
Add-Content -Path $global:ReportPath -Value "- Confirmar si el portal sera solo LAN o VPN/acceso remoto."
Add-Content -Path $global:ReportPath -Value "- Confirmar responsable tecnico del servidor."

try { Stop-Transcript | Out-Null } catch {}

Write-Host ""
Write-Host "S&G I0 validation completed."
Write-Host ("Output folder: " + $global:OutputPath)
Write-Host ("Main report: " + $global:ReportPath)
