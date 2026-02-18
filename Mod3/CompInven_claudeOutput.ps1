#==============================================================================
# Script Name:  Get-ComputerInventory.ps1
# Description:  Creates an HTML inventory of all directories and files on a
#               target computer starting from a specified directory.
# Author:       Student Script
# Version:      1.0
#==============================================================================

#region --- Parameters ---
param (
    [Parameter(Mandatory = $false)]
    [string]$TargetComputer = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false)]
    [string]$StartingDirectory = "C:\",

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = ".\ComputerInventory.html"
)
#endregion

#region --- Helper Functions ---

function Get-FileOwner {
    <#
    .SYNOPSIS
        Returns the owner of a file or directory using Get-Acl (Student Choice CmdLet).
    #>
    param ([string]$Path)
    try {
        $acl = Get-Acl -Path $Path -ErrorAction Stop
        return $acl.Owner
    }
    catch {
        return "N/A"
    }
}

function Get-FileAttributeList {
    <#
    .SYNOPSIS
        Converts a FileAttributes enum value into a readable comma-separated string,
        filtering to only the commonly reported flags.
    #>
    param ([System.IO.FileAttributes]$Attributes)

    $flags = @("ReadOnly", "Hidden", "System", "Archive")
    $active = foreach ($flag in $flags) {
        if ($Attributes.HasFlag([System.IO.FileAttributes]$flag)) { $flag }
    }
    if ($active) { return $active -join ", " } else { return "Normal" }
}

#endregion

#region --- Input Validation ---

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "       Computer File System Inventory        " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# If no parameters were passed, prompt the user interactively
if (-not $PSBoundParameters.ContainsKey('TargetComputer')) {
    $inputComputer = Read-Host "Enter Target Computer name (press Enter for localhost [$env:COMPUTERNAME])"
    if ($inputComputer -ne "") { $TargetComputer = $inputComputer }
}

if (-not $PSBoundParameters.ContainsKey('StartingDirectory')) {
    $inputDir = Read-Host "Enter Starting Directory (press Enter for C:\)"
    if ($inputDir -ne "") { $StartingDirectory = $inputDir }
}

if (-not $PSBoundParameters.ContainsKey('OutputFile')) {
    $inputFile = Read-Host "Enter Output File path (press Enter for .\ComputerInventory.html)"
    if ($inputFile -ne "") { $OutputFile = $inputFile }
}

Write-Host ""
Write-Host "Target Computer    : $TargetComputer"   -ForegroundColor Yellow
Write-Host "Starting Directory : $StartingDirectory" -ForegroundColor Yellow
Write-Host "Output File        : $OutputFile"        -ForegroundColor Yellow
Write-Host "Student CmdLet     : Get-Acl (used for Owner resolution)" -ForegroundColor Yellow
Write-Host ""

#endregion

#region --- Remote / Local Path Handling ---

# Build the UNC path if targeting a remote machine
if ($TargetComputer -ne $env:COMPUTERNAME -and $TargetComputer -ne "localhost" -and $TargetComputer -ne ".") {
    # Convert  "C:\" to "\\Server\C$\"
    $uncPath = $StartingDirectory -replace "^([A-Za-z]):\\", "\\$TargetComputer\`$1`$\"
    $scanPath = $uncPath
    Write-Host "Remote scan path   : $scanPath" -ForegroundColor DarkCyan
}
else {
    $scanPath = $StartingDirectory
}

# Validate path
if (-not (Test-Path -Path $scanPath)) {
    Write-Warning "The path '$scanPath' does not exist or is not accessible. Exiting."
    exit 1
}

#endregion

#region --- File System Scan ---

Write-Host "Scanning file system... (this may take a while)" -ForegroundColor Green
Write-Host ""

$allItems = Get-ChildItem -Path $scanPath -Recurse -Force -ErrorAction SilentlyContinue

$totalItems = $allItems.Count
Write-Host "Found $totalItems items. Building inventory..." -ForegroundColor Green

$inventory = [System.Collections.Generic.List[PSCustomObject]]::new()
$counter   = 0

foreach ($item in $allItems) {
    $counter++
    if ($counter % 500 -eq 0) {
        Write-Progress -Activity "Building Inventory" `
                       -Status "Processing item $counter of $totalItems" `
                       -PercentComplete (($counter / $totalItems) * 100)
    }

    # ---- Student Choice CmdLet: Get-Acl ----
    $owner = Get-FileOwner -Path $item.FullName

    if ($item.PSIsContainer) {
        # Directory row
        $inventory.Add([PSCustomObject]@{
            Directory      = $item.FullName
            FileName       = "(Directory)"
            FileSizeBytes  = ""
            LastWriteTime  = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            Owner          = $owner
            FileAttributes = Get-FileAttributeList -Attributes $item.Attributes
            RowType        = "dir"
        })
    }
    else {
        # File row
        $inventory.Add([PSCustomObject]@{
            Directory      = $item.DirectoryName
            FileName       = $item.Name
            FileSizeBytes  = $item.Length
            LastWriteTime  = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            Owner          = $owner
            FileAttributes = Get-FileAttributeList -Attributes $item.Attributes
            RowType        = "file"
        })
    }
}

Write-Progress -Activity "Building Inventory" -Completed
Write-Host "Scan complete. Generating HTML report..." -ForegroundColor Green

#endregion

#region --- HTML Generation ---

$generatedDate = Get-Date -Format "dddd, MMMM dd, yyyy  HH:mm:ss"
$fileCount      = ($inventory | Where-Object { $_.RowType -eq "file" }).Count
$dirCount       = ($inventory | Where-Object { $_.RowType -eq "dir"  }).Count

# Build table rows
$rowsHtml = foreach ($row in $inventory) {

    $sizeDisplay = if ($row.FileSizeBytes -ne "") {
        $bytes = [long]$row.FileSizeBytes
        switch ($bytes) {
            { $_ -ge 1GB } { "{0:N2} GB" -f ($bytes / 1GB); break }
            { $_ -ge 1MB } { "{0:N2} MB" -f ($bytes / 1MB); break }
            { $_ -ge 1KB } { "{0:N2} KB" -f ($bytes / 1KB); break }
            default        { "$bytes B" }
        }
    } else { "" }

    $rowClass = if ($row.RowType -eq "dir") { "dir-row" } else { "file-row" }

    # Escape HTML special characters
    $dirEsc   = [System.Web.HttpUtility]::HtmlEncode($row.Directory)
    $fileEsc  = [System.Web.HttpUtility]::HtmlEncode($row.FileName)
    $ownerEsc = [System.Web.HttpUtility]::HtmlEncode($row.Owner)
    $attrEsc  = [System.Web.HttpUtility]::HtmlEncode($row.FileAttributes)

    "<tr class='$rowClass'>
        <td>$dirEsc</td>
        <td>$fileEsc</td>
        <td class='num'>$sizeDisplay</td>
        <td>$($row.LastWriteTime)</td>
        <td>$ownerEsc</td>
        <td>$attrEsc</td>
    </tr>"
}

$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>File System Inventory &mdash; $TargetComputer</title>
    <style>
        /* ===== Reset & Base ===== */
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            font-size: 13px;
            background: #f0f2f5;
            color: #333;
        }

        /* ===== Header ===== */
        header {
            background: linear-gradient(135deg, #1a237e 0%, #283593 60%, #3949ab 100%);
            color: #fff;
            padding: 28px 40px 20px;
            border-bottom: 4px solid #7986cb;
        }
        header h1 { font-size: 1.8rem; font-weight: 700; letter-spacing: 0.5px; }
        header h1 span { color: #90caf9; }
        header p  { margin-top: 6px; font-size: 0.85rem; opacity: 0.85; }

        /* ===== Summary Cards ===== */
        .summary {
            display: flex;
            gap: 16px;
            flex-wrap: wrap;
            padding: 20px 40px;
            background: #e8eaf6;
            border-bottom: 1px solid #c5cae9;
        }
        .card {
            background: #fff;
            border-left: 5px solid #3949ab;
            border-radius: 6px;
            padding: 14px 22px;
            min-width: 160px;
            box-shadow: 0 1px 4px rgba(0,0,0,.08);
        }
        .card .label { font-size: 0.72rem; text-transform: uppercase; color: #777; letter-spacing: 0.8px; }
        .card .value { font-size: 1.4rem; font-weight: 700; color: #1a237e; margin-top: 4px; }

        /* ===== Search & Filter ===== */
        .toolbar {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 14px 40px;
            background: #fff;
            border-bottom: 1px solid #dde;
            flex-wrap: wrap;
        }
        .toolbar input[type=text] {
            padding: 7px 12px;
            border: 1px solid #ccc;
            border-radius: 4px;
            font-size: 13px;
            width: 320px;
        }
        .toolbar input[type=text]:focus { outline: none; border-color: #3949ab; box-shadow: 0 0 0 2px #c5cae9; }
        .toolbar select {
            padding: 7px 10px;
            border: 1px solid #ccc;
            border-radius: 4px;
            font-size: 13px;
        }
        .toolbar label { font-size: 13px; color: #555; }

        /* ===== Table ===== */
        .table-wrap {
            padding: 20px 40px 40px;
            overflow-x: auto;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background: #fff;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 8px rgba(0,0,0,.08);
        }
        thead tr {
            background: #283593;
            color: #fff;
        }
        thead th {
            padding: 11px 14px;
            text-align: left;
            font-weight: 600;
            font-size: 0.78rem;
            text-transform: uppercase;
            letter-spacing: 0.6px;
            cursor: pointer;
            user-select: none;
            white-space: nowrap;
        }
        thead th:hover { background: #3949ab; }
        thead th::after { content: ' \2195'; opacity: 0.4; font-size: 0.7rem; }

        tbody tr { border-bottom: 1px solid #e8eaf6; transition: background 0.15s; }
        tbody tr:last-child { border-bottom: none; }
        tbody tr:hover { background: #e8eaf6; }

        .dir-row  td:first-child { font-weight: 600; color: #1a237e; }
        .dir-row  td:nth-child(2) { color: #888; font-style: italic; }
        .file-row td { }

        td { padding: 8px 14px; vertical-align: top; word-break: break-word; }
        td.num { text-align: right; white-space: nowrap; }

        /* Attribute badges */
        .badge {
            display: inline-block;
            padding: 1px 7px;
            border-radius: 10px;
            font-size: 0.68rem;
            font-weight: 600;
            margin: 1px 2px;
            white-space: nowrap;
        }
        .b-readonly { background: #fce4ec; color: #c62828; }
        .b-hidden   { background: #e8eaf6; color: #283593; }
        .b-system   { background: #fff3e0; color: #e65100; }
        .b-archive  { background: #e8f5e9; color: #2e7d32; }
        .b-normal   { background: #f5f5f5; color: #757575; }

        /* ===== Footer ===== */
        footer {
            text-align: center;
            padding: 16px;
            font-size: 0.78rem;
            color: #999;
            border-top: 1px solid #e0e0e0;
        }
    </style>
</head>
<body>

<header>
    <h1>&#128193; File System Inventory &mdash; <span>$TargetComputer</span></h1>
    <p>Starting Directory: <strong>$StartingDirectory</strong> &nbsp;&bull;&nbsp; Generated: $generatedDate</p>
    <p style="margin-top:4px; font-size:0.78rem; opacity:0.7;">
        Student Choice CmdLet: <strong>Get-Acl</strong> &mdash; used to resolve file &amp; directory ownership
    </p>
</header>

<div class="summary">
    <div class="card">
        <div class="label">Total Items</div>
        <div class="value">$($inventory.Count)</div>
    </div>
    <div class="card">
        <div class="label">Files</div>
        <div class="value">$fileCount</div>
    </div>
    <div class="card">
        <div class="label">Directories</div>
        <div class="value">$dirCount</div>
    </div>
    <div class="card">
        <div class="label">Computer</div>
        <div class="value" style="font-size:1rem;">$TargetComputer</div>
    </div>
</div>

<div class="toolbar">
    <label for="searchBox">&#128269; Filter:</label>
    <input type="text" id="searchBox" placeholder="Search directory, file name, owner..." oninput="filterTable()">
    <label for="typeFilter">Show:</label>
    <select id="typeFilter" onchange="filterTable()">
        <option value="all">All Items</option>
        <option value="file">Files Only</option>
        <option value="dir">Directories Only</option>
    </select>
    <span id="rowCount" style="margin-left:auto; color:#777; font-size:0.8rem;"></span>
</div>

<div class="table-wrap">
<table id="inventoryTable">
    <thead>
        <tr>
            <th onclick="sortTable(0)">Directory</th>
            <th onclick="sortTable(1)">File Name</th>
            <th onclick="sortTable(2)">File Size</th>
            <th onclick="sortTable(3)">Last Write Time</th>
            <th onclick="sortTable(4)">Owner</th>
            <th onclick="sortTable(5)">File Attributes</th>
        </tr>
    </thead>
    <tbody id="tableBody">
        $($rowsHtml -join "`n")
    </tbody>
</table>
</div>

<footer>
    Generated by <strong>Get-ComputerInventory.ps1</strong> &bull; $generatedDate &bull; Computer: $TargetComputer
</footer>

<script>
    // ---- Attribute badge colorizer ----
    (function colorBadges() {
        const cells = document.querySelectorAll('#tableBody td:last-child');
        cells.forEach(cell => {
            const attrs = cell.textContent.trim().split(',').map(a => a.trim());
            cell.innerHTML = attrs.map(a => {
                let cls = 'b-normal';
                if (a === 'ReadOnly') cls = 'b-readonly';
                else if (a === 'Hidden')   cls = 'b-hidden';
                else if (a === 'System')   cls = 'b-system';
                else if (a === 'Archive')  cls = 'b-archive';
                return '<span class="badge ' + cls + '">' + a + '</span>';
            }).join('');
        });
    })();

    // ---- Filter / Search ----
    function filterTable() {
        const query      = document.getElementById('searchBox').value.toLowerCase();
        const typeFilter = document.getElementById('typeFilter').value;
        const rows       = document.querySelectorAll('#tableBody tr');
        let visible = 0;
        rows.forEach(row => {
            const text     = row.textContent.toLowerCase();
            const rowType  = row.classList.contains('dir-row') ? 'dir' : 'file';
            const matchTxt = text.includes(query);
            const matchTyp = typeFilter === 'all' || typeFilter === rowType;
            if (matchTxt && matchTyp) { row.style.display = ''; visible++; }
            else                      { row.style.display = 'none'; }
        });
        document.getElementById('rowCount').textContent = 'Showing ' + visible + ' of ' + rows.length + ' items';
    }

    // ---- Sort ----
    let sortDir = {};
    function sortTable(colIndex) {
        const tbody = document.getElementById('tableBody');
        const rows  = Array.from(tbody.querySelectorAll('tr'));
        const asc   = !sortDir[colIndex];
        sortDir     = {};
        sortDir[colIndex] = asc;
        rows.sort((a, b) => {
            const aText = a.cells[colIndex].textContent.trim();
            const bText = b.cells[colIndex].textContent.trim();
            return asc ? aText.localeCompare(bText, undefined, {numeric: true})
                       : bText.localeCompare(aText, undefined, {numeric: true});
        });
        rows.forEach(r => tbody.appendChild(r));
        filterTable();
    }

    // Initial row count
    filterTable();
</script>
</body>
</html>
"@

#endregion

#region --- Write Output File ---

# Load System.Web for HtmlEncode (should be available in .NET Framework on Windows)
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

try {
    $htmlContent | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host " Report saved successfully!" -ForegroundColor Green
    Write-Host " Output : $((Resolve-Path $OutputFile).Path)" -ForegroundColor Green
    Write-Host " Items  : $($inventory.Count)  ($fileCount files, $dirCount directories)" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
}
catch {
    Write-Error "Failed to write output file: $_"
    exit 1
}

#endregion
