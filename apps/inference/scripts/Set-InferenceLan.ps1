# Run in elevated Windows PowerShell. See docs/INFERENCE.md for validation/rollback.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][System.Net.IPAddress]$ListenAddress,
    [string[]]$AllowedClients = @('LocalSubnet'),
    [ValidateRange(1024, 65535)][int]$Port = 19331,
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
if (-not $Remove -and -not (Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -eq $ListenAddress.ToString())) {
    throw 'ListenAddress is not assigned to this Windows host.'
}
$ruleName = "RanchInference-$Port"
$netsh = Join-Path $env:SystemRoot 'System32\netsh.exe'
$stateDir = Join-Path $env:USERPROFILE '.config\RanchInference'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

function Invoke-PortProxy([string[]]$Arguments) {
    $process = Start-Process -FilePath $netsh -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $stateDir 'portproxy.stdout.txt') `
        -RedirectStandardError (Join-Path $stateDir 'portproxy.stderr.txt')
    if ($process.ExitCode -ne 0) { throw "netsh failed with exit code $($process.ExitCode). See $stateDir." }
}

if ($Remove) {
    Invoke-PortProxy @('interface', 'portproxy', 'delete', 'v4tov4', "listenaddress=$ListenAddress", "listenport=$Port")
    Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Write-Output 'Inference LAN listener and its firewall rule removed.'
    return
}

if ($AllowedClients.Count -eq 0) { throw 'Specify at least one client address, IPv4 CIDR, or LocalSubnet.' }
foreach ($scope in $AllowedClients) {
    if ($scope -eq 'LocalSubnet') { continue }
    $parts = $scope.Split('/')
    $address = $null
    $prefix = 0
    if ($parts.Count -gt 2 -or -not [System.Net.IPAddress]::TryParse($parts[0], [ref]$address) -or
        $address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Invalid IPv4 client address or CIDR: $scope"
    }
    if ($parts.Count -eq 2 -and
        (-not [int]::TryParse($parts[1], [ref]$prefix) -or $prefix -lt 1 -or $prefix -gt 32)) {
        throw "Use an IPv4 CIDR prefix between 1 and 32: $scope"
    }
}

# Inspect ownership before replacing any listener at this exact address and port.
$listeners = @(Get-NetTCPConnection -State Listen -LocalAddress $ListenAddress.ToString() -LocalPort $Port -ErrorAction SilentlyContinue)
if ($listeners.Count -gt 0 -and -not (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue)) {
    throw 'An existing listener uses this address/port without the managed firewall rule. Inspect it before proceeding.'
}
Start-Service iphlpsvc
# Binding only the LAN address leaves Windows localhost forwarding to WSL intact.
Invoke-PortProxy @('interface', 'portproxy', 'add', 'v4tov4', "listenaddress=$ListenAddress", "listenport=$Port", 'connectaddress=127.0.0.1', "connectport=$Port")
$rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
if ($rule) {
    $rule | Set-NetFirewallRule -Enabled True -Direction Inbound -Action Allow -Profile Private `
        -LocalAddress $ListenAddress.ToString() -RemoteAddress $AllowedClients `
        -Protocol TCP -LocalPort $Port
} else {
    New-NetFirewallRule -Name $ruleName -DisplayName "Ranch inference TCP $Port" `
        -Enabled True -Direction Inbound -Action Allow -Profile Private `
        -LocalAddress $ListenAddress.ToString() -RemoteAddress $AllowedClients `
        -Protocol TCP -LocalPort $Port | Out-Null
}
Write-Output "Inference LAN listener configured on ${ListenAddress}:$Port for scope $($AllowedClients -join ', ')."
