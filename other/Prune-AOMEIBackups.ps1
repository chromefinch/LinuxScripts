<#
.SYNOPSIS
Deletes the oldest AOMEI Backupper backup folders, keeping a specified number of recent ones.

.DESCRIPTION
This script identifies backup folders within a specified parent directory, presumably created by
AOMEI Backupper. It sorts them by creation date and deletes the oldest ones, ensuring a
configurable number of the most recent backups are retained. It includes a safety check
to never delete the last remaining backup folder.

Designed to be run via Windows Task Scheduler.

.PARAMETER BackupParentPath
The full path to the directory containing the individual AOMEI backup folders.
Example: 'D:\AOMEI Backups\Disk Backup Job'

.PARAMETER KeepCount
The number of the most recent backup folders to keep. Must be 1 or greater.
Defaults to 3.

.EXAMPLE
.\Prune-AOMEIBackups.ps1 -BackupParentPath "E:\Backups\SystemBackup" -KeepCount 5
Deletes all but the 5 newest backup folders found directly inside "E:\Backups\SystemBackup".

.EXAMPLE
.\Prune-AOMEIBackups.ps1 -BackupParentPath "C:\MyAOMEIBackups"
Deletes all but the 3 (default) newest backup folders found directly inside "C:\MyAOMEIBackups".

.NOTES
- Requires PowerShell 3.0 or later.
- Run with sufficient permissions to delete files/folders in the target path.
- TEST THOROUGHLY using the -WhatIf switch before enabling actual deletion.
  Example: .\Prune-AOMEIBackups.ps1 -BackupParentPath "E:\Backups" -KeepCount 5 -WhatIf
- Assumes AOMEI creates separate subfolders for backup versions/instances.
- The script uses folder CreationTime for sorting.
- Version: 1.1
- Author: AI Assistant
#>
[CmdletBinding(SupportsShouldProcess = $true)] # Enables -WhatIf confirmation
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the directory containing AOMEI backup folders.")]
    [string]$BackupParentPath,

    [Parameter(Mandatory = $false, HelpMessage = "Number of recent backup folders to keep (must be >= 1).")]
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

Write-Host "Checking for backup folders in: $BackupParentPath"
Write-Host "Configured to keep the $KeepCount most recent backup(s)."

# Get all subdirectories, sort by CreationTime (Oldest First)
try {
    $BackupFolders = Get-ChildItem -Path $BackupParentPath -Filter "*.adi" -ErrorAction Stop | Sort-Object CreationTime 
}
catch {
    Write-Error "Error accessing or listing directories in '$BackupParentPath'. Check permissions. Error: $($_.Exception.Message)"
    exit 1
}

$TotalCount = $BackupFolders.Count
Write-Host "Found $TotalCount total backup folder(s)."

# Check if pruning is needed
if ($TotalCount -le $KeepCount) {
    Write-Host "Number of backups found ($TotalCount) is less than or equal to the number to keep ($KeepCount). No deletions necessary."
    Write-Verbose "Exiting script."
    exit 0 # Exit successfully
}

# Calculate how many folders to delete
$ToDeleteCount = $TotalCount - $KeepCount
Write-Host "Need to delete $ToDeleteCount oldest backup files(s)."

# Select the oldest folders to delete
$FoldersToDelete = $BackupFolders | Select-Object -First $ToDeleteCount

# --- Deletion Process ---
Write-Host "Starting deletion process..."

foreach ($Folder in $FoldersToDelete) {
    $FolderPath = $Folder.FullName
    Write-Host "Attempting to delete file (Created: $($Folder.CreationTime)): '$FolderPath'"

    # Use -WhatIf to preview or $PSCmdlet.ShouldProcess for actual deletion
    if ($PSCmdlet.ShouldProcess($FolderPath, "Delete Backup File")) {
        try {
            Remove-Item -Path $FolderPath -Force -ErrorAction Stop
            Write-Host "Successfully deleted: '$FolderPath'"
        }
        catch {
            Write-Error "Failed to delete folder '$FolderPath'. Error: $($_.Exception.Message)"
            # Consider whether to continue or stop on error. Currently continues.
        }
    }
     # else { # This part is handled implicitly by SupportsShouldProcess=$true when -WhatIf is used
     #    Write-Warning "Deletion SKIPPED for '$FolderPath' due to -WhatIf parameter."
     # }
}

Write-Host "Backup pruning process finished."
Write-Verbose "Exiting script."
exit 0 # Exit successfully
# --- Script End ---
