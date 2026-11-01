# Run in elevated Windows PowerShell. See docs/MONITORING.md for validation and rollback.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9-]+$')][string]$Name,
    [Parameter(Mandatory)][System.Net.IPAddress]$ListenAddress,
    [string[]]$AllowedClients = @('LocalSubnet'),
    [Parameter(Mandatory)][ValidateRange(1024, 65535)][int]$Port,
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

$ruleName = "RanchWslMetrics-$Name-$Port"
$netsh = Join-Path $env:SystemRoot 'System32\netsh.exe'
$stateDir = Join-Path $env:USERPROFILE '.config\RanchWslMetrics'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

function Invoke-PortProxy([string[]]$Arguments) {
    $process = Start-Process -FilePath $netsh -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $stateDir 'portproxy.stdout.txt') `
        -RedirectStandardError (Join-Path $stateDir 'portproxy.stderr.txt')
    if ($process.ExitCode -ne 0) {
        throw "netsh failed with exit code $($process.ExitCode). See $stateDir."
    }
}

if ($Remove) {
    Invoke-PortProxy @('interface', 'portproxy', 'delete', 'v4tov4',
        "listenaddress=$ListenAddress", "listenport=$Port")
    Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Write-Output "Removed WSL metrics listener $Name on ${ListenAddress}:$Port."
    return
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

$listeners = @(Get-NetTCPConnection -State Listen -LocalAddress $ListenAddress.ToString() `
    -LocalPort $Port -ErrorAction SilentlyContinue)
if ($listeners.Count -gt 0 -and
    -not (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue)) {
    throw 'An existing listener uses this address and port without the managed firewall rule.'
}

Start-Service iphlpsvc
Invoke-PortProxy @('interface', 'portproxy', 'add', 'v4tov4',
    "listenaddress=$ListenAddress", "listenport=$Port", 'connectaddress=127.0.0.1',
    "connectport=$Port")

$ruleArgs = @{
    Enabled = 'True'
    Direction = 'Inbound'
    Action = 'Allow'
    Profile = 'Private'
    LocalAddress = $ListenAddress.ToString()
    RemoteAddress = $AllowedClients
    Protocol = 'TCP'
    LocalPort = $Port
}
Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -Name $ruleName -DisplayName "Ranch WSL metrics $Name TCP $Port" `
    @ruleArgs | Out-Null
Write-Output "Configured WSL metrics listener $Name on ${ListenAddress}:$Port for $($AllowedClients -join ', ')."
