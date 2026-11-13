# Run in Windows PowerShell after copying Keep-InferenceWsl.ps1 beside this file.
[CmdletBinding()]
param([string]$Distribution = 'Ubuntu')
$ErrorActionPreference = 'Stop'
if ($Distribution -notmatch '^[A-Za-z0-9._-]+$') { throw 'Use a simple WSL distribution name.' }
$stateDir = Join-Path $env:USERPROFILE '.config\RanchInference'
$keepalive = Join-Path $stateDir 'Keep-InferenceWsl.ps1'
if (-not (Test-Path -LiteralPath $keepalive)) { throw "Missing $keepalive" }
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"& '$keepalive' -Distribution '$Distribution'`"" `
    -WorkingDirectory $stateDir
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$existing = Get-ScheduledTask -TaskName 'RanchInference-WSL' -ErrorAction SilentlyContinue
if ($existing) {
    if ($existing.Actions.Arguments -notmatch 'Keep-InferenceWsl\.ps1') {
        throw 'Existing RanchInference-WSL task has an unexpected action; inspect it before replacing.'
    }
    Stop-ScheduledTask -TaskName 'RanchInference-WSL'
    Set-ScheduledTask -TaskName 'RanchInference-WSL' -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
} else {
    Register-ScheduledTask -TaskName 'RanchInference-WSL' -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
}
Start-ScheduledTask -TaskName 'RanchInference-WSL'
