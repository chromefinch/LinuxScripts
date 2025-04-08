<#
.SYNOPSIS
Deletes the oldest AOMEI Backupper backup file, keeping a specified number of recent ones.

.DESCRIPTION
This script identifies backup files within a specified parent directory, presumably created by
AOMEI Backupper. It sorts them by creation date and deletes the oldest ones, ensuring a
configurable number of the most recent backups are retained. It includes a safety check
to never delete the last remaining backup file.

Designed to be run via Windows Task Scheduler.

.PARAMETER BackupParentPath
The full path to the directory containing the individual AOMEI backup files.
Example: 'D:\AOMEI Backups\Disk Backup Job'

.PARAMETER KeepCount
The number of the most recent backup files to keep. Must be 1 or greater.
Defaults to 3.

.EXAMPLE
.\Prune-AOMEIBackups.ps1 -BackupParentPath "E:\Backups\SystemBackup" -KeepCount 5
Deletes all but the 5 newest backup files found directly inside "E:\Backups\SystemBackup".

.EXAMPLE
.\Prune-AOMEIBackups.ps1 -BackupParentPath "C:\MyAOMEIBackups"
Deletes all but the 3 (default) newest backup files found directly inside "C:\MyAOMEIBackups".

.Schedule
How to Use with Task Scheduler:
Save the script: Save the updated code as a .ps1 file (e.g., DeleteOldestBackup.ps1).
Open Task Scheduler: Search for "Task Scheduler" in the Start Menu and open it.
Edit the existing task (or create a new one): Find the task you created earlier. Right-click on it and select "Properties". Go to the "Actions" tab, select the existing action, and click "Edit...".
Add arguments (optional): In the "Add arguments (optional)" field, update the arguments to include the -KeepCount parameter. Replace "C:\YourBackupPath" with your actual backup path and 2 (or 3) with the desired number of backups to keep:
-ExecutionPolicy Bypass -File "C:\Path\To\Your\DeleteOldestBackup.ps1" -backupPath "C:\YourBackupPath" -KeepCount 2
or
-ExecutionPolicy Bypass -File "C:\Path\To\Your\DeleteOldestBackup.ps1" -backupPath "C:\YourBackupPath" -KeepCount 3
OK: Click "OK" to save the changes.

.NOTES
- Requires PowerShell 3.0 or later.
- Run with sufficient permissions to delete files/folders in the target path.
- TEST THOROUGHLY using the -WhatIf switch before enabling actual deletion.
  Example: .\Prune-AOMEIBackups.ps1 -BackupParentPath "E:\Backups" -KeepCount 5 -WhatIf
- Assumes AOMEI creates separate subfolders for backup versions/instances.
- The script uses file CreationTime for sorting.
- Version: 1.1
- Author: AI Assistant
#>
[CmdletBinding(SupportsShouldProcess = $true)] # Enables -WhatIf confirmation
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the directory containing AOMEI backup files.")]
    [string]$BackupParentPath,

    [Parameter(Mandatory = $false, HelpMessage = "Number of recent backup files to keep (must be >= 1).")]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$KeepCount = 3 # Default to keeping 3 backups
)

# --- Script Start ---

Write-Verbose "Starting AOMEI Backup Pruning Script"
Write-Verbose "Parameters: BackupParentPath='$BackupParentPath', KeepCount=$KeepCount"

# Validate the Backup Parent Path
if (-not (Test-Path -Path $BackupParentPath -PathType Container)) {
    Write-Error "Error: Backup parent path '$BackupParentPath' not found or is not a directory. Aborting."
    exit 1 # Exit with an error code
}

Write-Host "Checking for backup files in: $BackupParentPath"
Write-Host "Configured to keep the $KeepCount most recent backup(s)."

# Get all subdirectories, sort by CreationTime (Oldest First)
try {
    $BackupFiles = Get-ChildItem -Path $BackupParentPath -Filter "*.adi" -ErrorAction Stop | Sort-Object CreationTime 
}
catch {
    Write-Error "Error accessing or listing directories in '$BackupParentPath'. Check permissions. Error: $($_.Exception.Message)"
    exit 1
}

$TotalCount = $BackupFiles.Count
Write-Host "Found $TotalCount total backup files(s)."

# Check if pruning is needed
if ($TotalCount -le $KeepCount) {
    Write-Host "Number of backups found ($TotalCount) is less than or equal to the number to keep ($KeepCount). No deletions necessary."
    Write-Verbose "Exiting script."
    exit 0 # Exit successfully
}

# Calculate how many files to delete
$ToDeleteCount = $TotalCount - $KeepCount
Write-Host "Need to delete $ToDeleteCount oldest backup files(s)."

# Select the oldest files to delete
$FilesToDelete = $BackupFiles | Select-Object -First $ToDeleteCount

# --- Deletion Process ---
Write-Host "Starting deletion process..."

foreach ($Files in $FilesToDelete) {
    $FilesPath = $Files.FullName
    Write-Host "Attempting to delete file (Created: $($Files.CreationTime)): '$FilesPath'"

    # Use -WhatIf to preview or $PSCmdlet.ShouldProcess for actual deletion
    if ($PSCmdlet.ShouldProcess($FilesPath, "Delete Backup File")) {
        try {
            Remove-Item -Path $FilesPath -Force -ErrorAction Stop
            Write-Host "Successfully deleted: '$FilesPath'"
        }
        catch {
            Write-Error "Failed to delete file '$FilesPath'. Error: $($_.Exception.Message)"
            # Consider whether to continue or stop on error. Currently continues.
        }
    }
     # else { # This part is handled implicitly by SupportsShouldProcess=$true when -WhatIf is used
     #    Write-Warning "Deletion SKIPPED for '$FilesPath' due to -WhatIf parameter."
     # }
}

Write-Host "Backup pruning process finished."
Write-Verbose "Exiting script."
exit 0 # Exit successfully
# --- Script End ---
