# Run in elevated Windows PowerShell. See docs/SETUP.md for prerequisites and rollback.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][System.Net.IPAddress]$ListenAddress,
    [string[]]$AllowedClients = @('LocalSubnet'),
    [ValidateRange(1024, 65535)][int]$Port = 9182,
    [string]$MsiPath,
    [string]$ExpectedVersion,
    [ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSha256,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script in an elevated Windows PowerShell window.'
}
if ($ListenAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or
    [System.Net.IPAddress]::IsLoopback($ListenAddress) -or $ListenAddress.ToString() -eq '0.0.0.0') {
    throw 'ListenAddress must be a specific LAN IPv4 address assigned to Windows.'
}
if (-not $Remove -and -not (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object IPAddress -eq $ListenAddress.ToString())) {
    throw 'ListenAddress is not assigned to this Windows host.'
}

$ruleName = "RanchWindowsMetrics-windows-exporter-$Port"
$uninstallRoots = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
function Get-WindowsExporterProduct {
    Get-ItemProperty $uninstallRoots -ErrorAction SilentlyContinue |
        Where-Object DisplayName -eq 'windows_exporter' |
        Select-Object -First 1
}
function Invoke-MsiExec([string[]]$Arguments) {
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        $process = Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" `
            -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -in @(0, 3010)) {
            return
        }
        if ($process.ExitCode -ne 1618 -or $attempt -eq 6) {
            throw "msiexec failed with exit code $($process.ExitCode)."
        }
        Start-Sleep -Seconds 5
    }
}

if ($Remove) {
    Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    $product = Get-WindowsExporterProduct
    if ($product) {
        Invoke-MsiExec @('/x', $product.PSChildName, '/qn', '/norestart')
    }
    Write-Output 'Removed Windows Exporter and its Ranch firewall rule.'
    return
}

if (-not $MsiPath -or -not $ExpectedVersion -or -not $ExpectedSha256) {
    throw 'MsiPath, ExpectedVersion, and ExpectedSha256 are required for installation.'
}
if (-not (Test-Path -LiteralPath $MsiPath -PathType Leaf)) {
    throw "MSI not found: $MsiPath"
}
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $MsiPath).Hash -ne $ExpectedSha256.ToUpperInvariant()) {
    throw 'MSI SHA-256 does not match the repository pin.'
}
if ($AllowedClients.Count -eq 0) {
    throw 'Specify at least one client address, IPv4 CIDR, or LocalSubnet.'
}
foreach ($scope in $AllowedClients) {
    if ($scope -eq 'LocalSubnet') { continue }
    $parts = $scope.Split('/')
    $address = $null
    $prefix = 0
    if ($parts.Count -gt 2 -or
        -not [System.Net.IPAddress]::TryParse($parts[0], [ref]$address) -or
        $address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Invalid IPv4 client address or CIDR: $scope"
    }
    if ($parts.Count -eq 2 -and
        (-not [int]::TryParse($parts[1], [ref]$prefix) -or $prefix -lt 1 -or $prefix -gt 32)) {
        throw "Use an IPv4 CIDR prefix between 1 and 32: $scope"
    }
}

$service = Get-Service windows_exporter -ErrorAction SilentlyContinue
$listeners = @(Get-NetTCPConnection -State Listen -LocalAddress $ListenAddress.ToString() `
    -LocalPort $Port -ErrorAction SilentlyContinue)
if (-not $service -and $listeners.Count -gt 0) {
    throw 'An unrelated process already uses the requested address and port.'
}

$collectors = 'cpu,cpu_info,logical_disk,memory,net,os,physical_disk,service,system'
Invoke-MsiExec @(
    '/i', (Resolve-Path -LiteralPath $MsiPath).Path, '/qn', '/norestart',
    "ENABLED_COLLECTORS=$collectors", "LISTEN_ADDR=$ListenAddress", "LISTEN_PORT=$Port"
)

$product = Get-WindowsExporterProduct
if (-not $product -or
    ($product.DisplayVersion -ne $ExpectedVersion -and $product.DisplayVersion -notlike "$ExpectedVersion.*")) {
    throw "Expected Windows Exporter $ExpectedVersion after installation."
}
$service = Get-Service windows_exporter -ErrorAction Stop
if ($service.Status -ne 'Running') {
    Start-Service windows_exporter
}

Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -Name $ruleName -DisplayName "Ranch Windows metrics TCP $Port" `
    -Enabled True -Direction Inbound -Action Allow -Profile Private `
    -LocalAddress $ListenAddress.ToString() -RemoteAddress $AllowedClients `
    -Protocol TCP -LocalPort $Port | Out-Null

$health = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 `
    -Uri "http://${ListenAddress}:$Port/health"
if ($health.StatusCode -ne 200) {
    throw 'Windows Exporter health endpoint did not return HTTP 200.'
}
Write-Output "Configured Windows Exporter $ExpectedVersion on ${ListenAddress}:$Port for $($AllowedClients -join ', ')."
