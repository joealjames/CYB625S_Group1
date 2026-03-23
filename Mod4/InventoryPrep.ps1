# Run on both remote and listener machine
# Check if User is Admin, if not attempt to relaunch with Admin perms
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
    {Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit}
    Clear-Host
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
Get-NetConnectionProfile #verify
Enable-PSRemoting -Force
winrm quickconfig
$promptMessage = "Are you the listener machine? (Y/N)"
do {
    $response = Read-Host -Prompt $promptMessage
} until ($response -match "^(y|n)$") 

if ($response -eq 'y') {
    $RemoteComputer = Read-Host "Enter Target Computer IP:"
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$RemoteComputer" -Force
    Get-Item WSMan:\localhost\Client\TrustedHosts #verify
    winrm enumerate winrm/config/listener
}
Write-Host "Successfully enabled Powershelll remoting" -ForegroundColor Green
pause