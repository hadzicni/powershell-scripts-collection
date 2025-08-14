<#
.SYNOPSIS
    Automatically deletes files older than a specified age from target directories.

.DESCRIPTION
    This script performs automated cleanup of files based on age criteria. It can target multiple
    directories, supports various file filters, and provides detailed logging and reporting.

.PARAMETER Path
    Target directory path(s) to clean up. Supports multiple paths.

.PARAMETER AgeInDays
    Delete files older than this many days. Default is 30 days.

.PARAMETER FilePattern
    File pattern to match (e.g., "*.log", "*.tmp"). Default is "*" (all files).

.PARAMETER Recurse
    Include subdirectories in the cleanup operation.

.PARAMETER WhatIf
    Show what would be deleted without actually deleting files.

.PARAMETER LogFile
    Path for log file. If not specified, creates a log in the script directory.

.PARAMETER MinimumFileSize
    Only delete files larger than this size (in bytes). Default is 0.

.PARAMETER MaximumFileSize
    Only delete files smaller than this size (in bytes). No limit by default.

.PARAMETER ExcludePattern
    File patterns to exclude from deletion (e.g., "*.config", "important_*").

.PARAMETER PreserveCount
    Number of newest files to preserve even if they meet age criteria.

.EXAMPLE
    .\Remove-OldFiles.ps1 -Path "C:\Temp" -AgeInDays 7

.EXAMPLE
    .\Remove-OldFiles.ps1 -Path @("C:\Logs", "C:\Temp") -AgeInDays 30 -FilePattern "*.log" -Recurse

.EXAMPLE
    .\Remove-OldFiles.ps1 -Path "C:\Downloads" -AgeInDays 90 -WhatIf -MinimumFileSize 1MB

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Appropriate file system permissions
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Target directory path(s) to clean up")]
    [string[]]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "Delete files older than this many days")]
    [int]$AgeInDays = 30,

    [Parameter(Mandatory = $false, HelpMessage = "File pattern to match")]
    [string]$FilePattern = "*",

    [Parameter(Mandatory = $false, HelpMessage = "Include subdirectories")]
    [switch]$Recurse,

    [Parameter(Mandatory = $false, HelpMessage = "Show what would be deleted without deleting")]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false, HelpMessage = "Path for log file")]
    [string]$LogFile = "",

    [Parameter(Mandatory = $false, HelpMessage = "Minimum file size in bytes")]
    [long]$MinimumFileSize = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum file size in bytes")]
    [long]$MaximumFileSize = [long]::MaxValue,

    [Parameter(Mandatory = $false, HelpMessage = "File patterns to exclude")]
    [string[]]$ExcludePattern = @(),

    [Parameter(Mandatory = $false, HelpMessage = "Number of newest files to preserve")]
    [int]$PreserveCount = 0
)

# Set up logging
if ([string]::IsNullOrEmpty($LogFile)) {
    $LogFile = Join-Path $PSScriptRoot "FileCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry

    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "INFO" { Write-Host $Message }
        default { Write-Host $Message }
    }
}

function Format-FileSize {
    param([long]$SizeBytes)

    if ($SizeBytes -ge 1TB) { return "{0:N2} TB" -f ($SizeBytes / 1TB) }
    elseif ($SizeBytes -ge 1GB) { return "{0:N2} GB" -f ($SizeBytes / 1GB) }
    elseif ($SizeBytes -ge 1MB) { return "{0:N2} MB" -f ($SizeBytes / 1MB) }
    elseif ($SizeBytes -ge 1KB) { return "{0:N2} KB" -f ($SizeBytes / 1KB) }
    else { return "$SizeBytes bytes" }
}

function Test-ExcludePattern {
    param(
        [string]$FileName,
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($FileName -like $pattern) {
            return $true
        }
    }
    return $false
}

# Initialize variables
$CutoffDate = (Get-Date).AddDays(-$AgeInDays)
$Stats = @{
    TotalScanned = 0
    FilesDeleted = 0
    TotalSizeDeleted = 0
    FilesSkipped = 0
    Errors = 0
    DirectoriesProcessed = 0
}

$DeletedFiles = @()
$SkippedFiles = @()

Write-Log "File cleanup operation started"
Write-Log "Parameters:"
Write-Log "  Paths: $($Path -join ', ')"
Write-Log "  Age threshold: $AgeInDays days (cutoff date: $($CutoffDate.ToString('yyyy-MM-dd HH:mm:ss')))"
Write-Log "  File pattern: $FilePattern"
Write-Log "  Recurse subdirectories: $Recurse"
Write-Log "  Minimum file size: $(Format-FileSize $MinimumFileSize)"
Write-Log "  Maximum file size: $(Format-FileSize $MaximumFileSize)"
Write-Log "  Exclude patterns: $($ExcludePattern -join ', ')"
Write-Log "  Preserve count: $PreserveCount"
if ($WhatIf) { Write-Log "  WhatIf mode: Enabled (no files will be deleted)" "WARNING" }

# Process each directory
foreach ($Directory in $Path) {
    Write-Log "`nProcessing directory: $Directory"

    # Validate directory exists
    if (-not (Test-Path $Directory -PathType Container)) {
        Write-Log "Directory not found: $Directory" "ERROR"
        $Stats.Errors++
        continue
    }

    $Stats.DirectoriesProcessed++

    try {
        # Get files matching criteria
        $GetChildItemParams = @{
            Path = $Directory
            Filter = $FilePattern
            File = $true
            ErrorAction = 'Continue'
        }

        if ($Recurse) {
            $GetChildItemParams.Recurse = $true
        }

        $AllFiles = Get-ChildItem @GetChildItemParams

        if ($AllFiles.Count -eq 0) {
            Write-Log "No files found matching pattern '$FilePattern' in $Directory"
            continue
        }

        Write-Log "Found $($AllFiles.Count) files matching pattern '$FilePattern'"

        # Filter files by age, size, and exclusion patterns
        $FilteredFiles = $AllFiles | Where-Object {
            $file = $_

            # Check age
            $meetsAgeCriteria = $file.LastWriteTime -lt $CutoffDate
            if (-not $meetsAgeCriteria) { return $false }

            # Check size constraints
            $meetsSizeCriteria = ($file.Length -ge $MinimumFileSize) -and ($file.Length -le $MaximumFileSize)
            if (-not $meetsSizeCriteria) { return $false }

            # Check exclusion patterns
            $isExcluded = Test-ExcludePattern -FileName $file.Name -Patterns $ExcludePattern
            if ($isExcluded) { return $false }

            return $true
        }

        Write-Log "Files meeting deletion criteria: $($FilteredFiles.Count)"
        $Stats.TotalScanned += $AllFiles.Count

        if ($FilteredFiles.Count -eq 0) {
            Write-Log "No files meet the deletion criteria in $Directory"
            continue
        }

        # Apply preserve count if specified
        if ($PreserveCount -gt 0) {
            $FilesToDelete = $FilteredFiles | Sort-Object LastWriteTime -Descending | Select-Object -Skip $PreserveCount
            $PreservedFiles = $FilteredFiles | Sort-Object LastWriteTime -Descending | Select-Object -First $PreserveCount

            if ($PreservedFiles.Count -gt 0) {
                Write-Log "Preserving $($PreservedFiles.Count) newest files as requested"
                foreach ($preserved in $PreservedFiles) {
                    $SkippedFiles += [PSCustomObject]@{
                        FullName = $preserved.FullName
                        Size = $preserved.Length
                        LastWriteTime = $preserved.LastWriteTime
                        Reason = "Preserved (newest $PreserveCount files)"
                    }
                }
            }
        } else {
            $FilesToDelete = $FilteredFiles
        }

        Write-Log "Files to delete: $($FilesToDelete.Count)"

        # Process files for deletion
        foreach ($file in $FilesToDelete) {
            try {
                $fileInfo = [PSCustomObject]@{
                    FullName = $file.FullName
                    Size = $file.Length
                    LastWriteTime = $file.LastWriteTime
                    Age = (Get-Date) - $file.LastWriteTime
                }

                if ($WhatIf) {
                    Write-Log "WHATIF: Would delete '$($file.FullName)' ($(Format-FileSize $file.Length), $($fileInfo.Age.Days) days old)" "WARNING"
                } else {
                    Remove-Item $file.FullName -Force -ErrorAction Stop
                    Write-Log "Deleted: '$($file.FullName)' ($(Format-FileSize $file.Length), $($fileInfo.Age.Days) days old)" "SUCCESS"
                }

                $DeletedFiles += $fileInfo
                $Stats.FilesDeleted++
                $Stats.TotalSizeDeleted += $file.Length

            } catch {
                Write-Log "Failed to delete '$($file.FullName)': $($_.Exception.Message)" "ERROR"
                $Stats.Errors++

                $SkippedFiles += [PSCustomObject]@{
                    FullName = $file.FullName
                    Size = $file.Length
                    LastWriteTime = $file.LastWriteTime
                    Reason = "Error: $($_.Exception.Message)"
                }
            }
        }

    } catch {
        Write-Log "Error processing directory '$Directory': $($_.Exception.Message)" "ERROR"
        $Stats.Errors++
    }
}

# Generate summary report
Write-Log "`n========= CLEANUP SUMMARY ========="
Write-Log "Operation completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Log "Directories processed: $($Stats.DirectoriesProcessed)"
Write-Log "Total files scanned: $($Stats.TotalScanned)"
if ($WhatIf) {
    Write-Log "Files that WOULD be deleted: $($Stats.FilesDeleted)" "WARNING"
    Write-Log "Total size that WOULD be freed: $(Format-FileSize $Stats.TotalSizeDeleted)" "WARNING"
} else {
    Write-Log "Files deleted: $($Stats.FilesDeleted)" "SUCCESS"
    Write-Log "Total size freed: $(Format-FileSize $Stats.TotalSizeDeleted)" "SUCCESS"
}
Write-Log "Files skipped/preserved: $($SkippedFiles.Count)"
Write-Log "Errors encountered: $($Stats.Errors)"
Write-Log "Log file: $LogFile"

# Export detailed reports if files were processed
if ($DeletedFiles.Count -gt 0 -or $SkippedFiles.Count -gt 0) {
    $ReportPath = Join-Path $PSScriptRoot "FileCleanupReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

    $AllResults = @()

    foreach ($deleted in $DeletedFiles) {
        $AllResults += [PSCustomObject]@{
            Action = if ($WhatIf) { "Would Delete" } else { "Deleted" }
            FullName = $deleted.FullName
            SizeBytes = $deleted.Size
            SizeFormatted = Format-FileSize $deleted.Size
            LastWriteTime = $deleted.LastWriteTime
            AgeDays = $deleted.Age.Days
            Reason = ""
        }
    }

    foreach ($skipped in $SkippedFiles) {
        $AllResults += [PSCustomObject]@{
            Action = "Skipped"
            FullName = $skipped.FullName
            SizeBytes = $skipped.Size
            SizeFormatted = Format-FileSize $skipped.Size
            LastWriteTime = $skipped.LastWriteTime
            AgeDays = ((Get-Date) - $skipped.LastWriteTime).Days
            Reason = $skipped.Reason
        }
    }

    $AllResults | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
    Write-Log "Detailed report exported to: $ReportPath"
}

Write-Log "File cleanup operation completed"

# Exit with appropriate code
if ($Stats.Errors -gt 0) {
    exit 1
} else {
    exit 0
}
