# Computer File Inventory Script

# Ask user for input
$TargetComputer    = Read-Host "Enter Target Computer (press Enter for this computer)"
$StartingDirectory = Read-Host "Enter Starting Directory (e.g. C:\Users)"
$OutputFile        = Read-Host "Enter Output File path (e.g. C:\inventory.html)"

# Set defaults if user pressed Enter
if ($TargetComputer    -eq "") { $TargetComputer    = $env:COMPUTERNAME }
if ($StartingDirectory -eq "") { $StartingDirectory = "C:\" }
if ($OutputFile        -eq "") { $OutputFile        = ".\inventory.html" }

# Get all files and folders recursively
Write-Host "Scanning $StartingDirectory ... please wait"
$Items = Get-ChildItem -Path $StartingDirectory -Recurse -Force -ErrorAction SilentlyContinue

# Build the HTML rows
$Rows = ""
foreach ($Item in $Items) {

    # Student Choice CmdLet: Get-Acl - gets the file owner
    $Owner = (Get-Acl -Path $Item.FullName -ErrorAction SilentlyContinue).Owner

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
Write-Host "Done! Report saved to: $OutputFile"