# EXIF and Hash PowerShell Menu Group 1
# Mashreef Chowdhury, Brian Fitzgerald, Devanie Gajadar, Joeal James, Wali Sheikh, Oscar Xu

# Python Executable Definition
$Python = "python.exe"
# Check if Python is installed
Write-Host "1. Checking Python Installation"
try {
    # Attempt to find the python executable in the system's PATH
    # The -ErrorAction Stop makes this a terminating error if the command fails
    where.exe python | Out-Null
}
catch {
    # This block runs if the 'where.exe python' command fails, indicating Python is not in the PATH
    Write-Error "Python is not installed or not found in the system's PATH. Please install Python to run this script."

    # Exit the script with a non-zero exit code (e.g., 1 for failure)
    # The 'exit' command terminates the script execution
    exit 1
}

#Install PILLOW and prettytable modules for Python
py.exe -m pip install PILLOW
py.exe -m pip install prettytable

# Load Windows Forms for folder/file dialogs
Add-Type -AssemblyName System.Windows.Forms

# Pick the Python script to run
Write-Host "2. Confirm the location of pyExifHash"
$scriptDialog = New-Object System.Windows.Forms.OpenFileDialog
$scriptDialog.Title  = "Select the Python Script"
$scriptDialog.Filter = "Python Scripts (*.py)|*.py"
$scriptDialog.ShowDialog() | Out-Null
$Script = $scriptDialog.FileName


# Display menu and get choice
Write-Host "3. EXIF Hash Extractor"
Write-Host "==================="
Write-Host "1. Select a single file"
Write-Host "2. Select a folder"
$choice = Read-Host "Enter choice (1 or 2). Insert any other character to quit."

if ($choice -eq "1") {

    # Single file picker dialog
    Write-Host "4. Select file to analyze"
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "JPEG Images (*.jpg;*.jpeg)|*.jpg;*.jpeg"
    $dialog.ShowDialog() | Out-Null
    $files = Get-Item $dialog.FileName

} elseif ($choice -eq "2") {

    # Folder picker dialog
    Write-Host "4. Select folder to analyze"
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title            = "Select a Folder"
    $dialog.Filter           = "Folder|."
    $dialog.FileName         = "Select Folder"
    $dialog.CheckFileExists  = $false
    $dialog.ValidateNames    = $false
    $dialog.ShowDialog() | Out-Null
    $selectedPath = Split-Path $dialog.FileName
    $files = Get-ChildItem $selectedPath -Include "*.jpg","*.jpeg" -Recurse

} else {
    Write-Host "Exiting."
    exit
}

# Pick where to save the CSV output
Write-Host "5. Select save location for CSV"
$saveDialog = New-Object System.Windows.Forms.SaveFileDialog
$saveDialog.Title      = "Save CSV Output"
$saveDialog.Filter     = "CSV Files (*.csv)|*.csv"
$saveDialog.FileName   = "LatLonHash.csv"
$saveDialog.ShowDialog() | Out-Null
$savePath = $saveDialog.FileName

$jpegList = $files | Select-Object FullName | Format-Table -HideTableHeaders

$jpegList | & $Python $Script $savePath
