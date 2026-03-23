# Run on both remote and listener machine
# Check if User is Admin, if not attempt to relaunch with Admin perms
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
    {Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit}
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + " (Administrator)"
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.PrivateData.ProgressBackgroundColor = "Black"
    $Host.PrivateData.ProgressForegroundColor = "Yellow"
    Clear-Host
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
Get-NetConnectionProfile #verify
Enable-PSRemoting
winrm quickconfig
Write-Host "Successfully enabled Powershelll remoting" -ForegroundColor Green
pause