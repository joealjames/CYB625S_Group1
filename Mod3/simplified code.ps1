# Computer File Inventory Script Group 1
# Mashreef Chowdhury, Brian Fitzgerald, Devanie Gajadar, Joeal James, Wali Sheikh, Oscar Xu

#Check if User is in Admin, if not attempt to relaunch with Admin perms
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
    {Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit}
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + " (Administrator)"
    $Host.UI.RawUI.BackgroundColor = "Black"
	$Host.PrivateData.ProgressBackgroundColor = "Black"
    $Host.PrivateData.ProgressForegroundColor = "Yellow"
    Clear-Host

# Ask user for input
Write-Host "Set parameters, press Enter for default"
$TargetComputer    = Read-Host "Enter Target Computer name ($env:COMPUTERNAME)"
$StartingDirectory = Read-Host "Enter Starting Directory (C:\)"
$OutputFile        = Read-Host "Enter Output File path (.\inventory.html)"

# Set defaults if user pressed Enter
if ($TargetComputer    -eq "") { $TargetComputer    = $env:COMPUTERNAME }
if ($StartingDirectory -eq "") { $StartingDirectory = "C:\" }
if ($OutputFile        -eq "") { $OutputFile        = ".\inventory.html" }
$itemCount
# Get all files and folders recursively
Write-Host "Scanning $StartingDirectory .. please wait" -ForegroundColor Yellow
$Items = Get-ChildItem -LiteralPath $StartingDirectory -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $itemCount++
    Write-Host "`rItems found: $itemCount" -NoNewline
    $_
}

# Build the HTML rows
$Rows = ""
$htmlCounter   = 0
$totalItems = $Items.Count
Write-Host "Found $totalItems items. Processing files.." -ForegroundColor Green

foreach ($Item in $Items) {
$htmlCounter++
        Write-Progress -Activity "Building file database" `
                       -Status "Item $htmlCounter of $totalItems" `
                       -PercentComplete (($htmlCounter / $totalItems) * 100)

    # Student Choice CmdLet: Get-Acl - gets the file owner
    $Owner = (Get-Acl -LiteralPath $Item.FullName -ErrorAction SilentlyContinue).Owner

    # Get only the common attributes
    $Attributes = ""
    if ($Item.Attributes -band [System.IO.FileAttributes]::ReadOnly) { $Attributes += "ReadOnly " }
    if ($Item.Attributes -band [System.IO.FileAttributes]::Hidden)   { $Attributes += "Hidden " }
    if ($Item.Attributes -band [System.IO.FileAttributes]::System)   { $Attributes += "System " }
    if ($Item.Attributes -band [System.IO.FileAttributes]::Archive)  { $Attributes += "Archive " }

    # File size (blank for folders)
    if ($Item.PSIsContainer) {
        $Size = ""
    } else {
        $Size = "$($Item.Length) bytes"
    }

    $Rows += "<tr>
        <td>$($Item.DirectoryName)</td>
        <td>$($Item.Name)</td>
        <td>$Size</td>
        <td>$($Item.LastWriteTime)</td>
        <td>$Owner</td>
        <td>$Attributes</td>
    </tr>`n"
}
Write-Host "File processing complete. Creating HTML report..." -ForegroundColor Green
# Build the full HTML page
$HTML = "
<html>
<head>
    <title>File Inventory - $TargetComputer</title>
    <style>
        body  { font-family: Arial; font-size: 13px; }
        h1    { background: #003366; color: white; padding: 10px; }
        table { border-collapse: collapse; width: 100%; }
        th    { background: #003366; color: white; padding: 6px; text-align: left; }
        td    { padding: 5px; border: 1px solid #ccc; }
        tr:nth-child(even) { background: #f2f2f2; }
    </style>
</head>
<body>
    <h1>File Inventory &mdash; $TargetComputer</h1>
    <p>Starting Directory: $StartingDirectory &nbsp;|&nbsp; Generated: $(Get-Date)</p>
    <table>
        <tr>
            <th>Directory</th>
            <th>File Name</th>
            <th>File Size</th>
            <th>Last Write Time</th>
            <th>Owner</th>
            <th>File Attributes</th>
        </tr>
        $Rows
    </table>
</body>
</html>
"

# Save the file
$HTML | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "Done! Report saved to: $OutputFile" -ForegroundColor Green
Pause