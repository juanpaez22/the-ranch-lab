# Keeps the WSL instance available without starting a manually stopped service.
[CmdletBinding()]
param([string]$Distribution = 'Ubuntu')
$ErrorActionPreference = 'Stop'
$wsl = Join-Path $env:SystemRoot 'System32\wsl.exe'
$process = Start-Process -FilePath $wsl -ArgumentList @('-d', $Distribution, '--exec', '/usr/bin/sleep', 'infinity') `
    -WindowStyle Hidden -Wait -PassThru
exit $process.ExitCode
