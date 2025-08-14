<#
.SYNOPSIS
    Determines the architecture (32-bit or 64-bit) of executable files.

.DESCRIPTION
    This script analyzes PE (Portable Executable) files to determine their target architecture.
    It can process single files or entire directories and supports various executable formats.

.PARAMETER Path
    Path to file or directory to analyze. Can be a single file or directory path.

.PARAMETER Recurse
    When analyzing a directory, include subdirectories recursively.

.PARAMETER FileFilter
    File filter pattern for directory analysis (e.g., "*.exe", "*.dll"). Default is "*.exe".

.PARAMETER OutputFormat
    Output format: Table, List, CSV, or JSON. Default is Table.

.PARAMETER OutputFile
    Path to save results to file (CSV or JSON format).

.PARAMETER IncludeDetails
    Include additional details like file version, size, and creation date.

.PARAMETER ShowProgress
    Show progress bar when processing multiple files.

.EXAMPLE
    .\Get-FileArchitecture.ps1 -Path "C:\Program Files\MyApp\app.exe"

.EXAMPLE
    .\Get-FileArchitecture.ps1 -Path "C:\Program Files" -Recurse -FileFilter "*.exe" -OutputFormat CSV -OutputFile "architecture_report.csv"

.EXAMPLE
    .\Get-FileArchitecture.ps1 -Path ".\MyDLLs" -FileFilter "*.dll" -IncludeDetails -ShowProgress

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Read access to target files
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to file or directory to analyze")]
    [string]$Path,

    [Parameter(Mandatory = $false, HelpMessage = "Include subdirectories recursively")]
    [switch]$Recurse,

    [Parameter(Mandatory = $false, HelpMessage = "File filter pattern")]
    [string]$FileFilter = "*.exe",

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet("Table", "List", "CSV", "JSON")]
    [string]$OutputFormat = "Table",

    [Parameter(Mandatory = $false, HelpMessage = "Output file path")]
    [string]$OutputFile = "",

    [Parameter(Mandatory = $false, HelpMessage = "Include additional file details")]
    [switch]$IncludeDetails,

    [Parameter(Mandatory = $false, HelpMessage = "Show progress bar")]
    [switch]$ShowProgress
)

function Get-PEArchitecture {
    param(
        [string]$FilePath
    )

    try {
        if (-not (Test-Path $FilePath -PathType Leaf)) {
            throw "File not found: $FilePath"
        }

        # Read first 4KB of file to analyze PE header
        $bytes = Get-Content $FilePath -AsByteStream -TotalCount 4096 -ErrorAction Stop

        if ($bytes.Length -lt 64) {
            throw "File too small to be a valid PE file"
        }

        # Look for DOS header signature (MZ)
        $dosSignatureFound = $false
        $peOffset = 0

        for ($i = 0; $i -lt ($bytes.Length - 2); $i++) {
            if ($bytes[$i] -eq 0x4D -and $bytes[$i + 1] -eq 0x5A) {  # "MZ"
                $dosSignatureFound = $true

                # Get PE header offset (at offset 0x3C from DOS header)
                if (($i + 0x3C + 3) -lt $bytes.Length) {
                    $peOffset = [BitConverter]::ToInt32($bytes, $i + 0x3C)
                    break
                }
            }
        }

        if (-not $dosSignatureFound) {
            throw "Not a valid PE file (DOS signature not found)"
        }

        # Validate PE offset
        if (($peOffset + 6) -gt $bytes.Length -or $peOffset -le 0) {
            throw "Invalid PE header offset"
        }

        # Check PE signature (PE\0\0)
        if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45 -or
            $bytes[$peOffset + 2] -ne 0x00 -or $bytes[$peOffset + 3] -ne 0x00) {
            throw "Invalid PE signature"
        }

        # Get machine type from COFF header (2 bytes after PE signature)
        $machineType = [BitConverter]::ToUInt16($bytes, $peOffset + 4)

        # Determine architecture based on machine type
        $architecture = switch ($machineType) {
            0x014c { "x86 (32-bit)" }           # IMAGE_FILE_MACHINE_I386
            0x8664 { "x64 (64-bit)" }           # IMAGE_FILE_MACHINE_AMD64
            0x01c0 { "ARM" }                    # IMAGE_FILE_MACHINE_ARM
            0xaa64 { "ARM64" }                  # IMAGE_FILE_MACHINE_ARM64
            0x0162 { "MIPS R3000" }             # IMAGE_FILE_MACHINE_R3000
            0x0166 { "MIPS R4000" }             # IMAGE_FILE_MACHINE_R4000
            0x0168 { "MIPS R10000" }            # IMAGE_FILE_MACHINE_R10000
            0x0169 { "MIPS WCE v2" }            # IMAGE_FILE_MACHINE_WCEMIPSV2
            0x0184 { "Alpha AXP" }              # IMAGE_FILE_MACHINE_ALPHA
            0x01a2 { "Hitachi SH3" }            # IMAGE_FILE_MACHINE_SH3
            0x01a3 { "Hitachi SH3 DSP" }       # IMAGE_FILE_MACHINE_SH3DSP
            0x01a6 { "Hitachi SH4" }            # IMAGE_FILE_MACHINE_SH4
            0x01a8 { "Hitachi SH5" }            # IMAGE_FILE_MACHINE_SH5
            0x01c2 { "ARM Thumb" }              # IMAGE_FILE_MACHINE_THUMB
            0x01c4 { "ARM Thumb-2" }            # IMAGE_FILE_MACHINE_ARMNT
            0x0200 { "Intel Itanium" }          # IMAGE_FILE_MACHINE_IA64
            0x9041 { "Mitsubishi M32R" }        # IMAGE_FILE_MACHINE_M32R
            0x0284 { "Alpha AXP 64-bit" }       # IMAGE_FILE_MACHINE_ALPHA64
            default { "Unknown (0x$($machineType.ToString('X4')))" }
        }

        return @{
            Success = $true
            Architecture = $architecture
            MachineType = "0x$($machineType.ToString('X4'))"
            Error = $null
        }

    } catch {
        return @{
            Success = $false
            Architecture = "Unknown"
            MachineType = "N/A"
            Error = $_.Exception.Message
        }
    }
}

function Get-FileDetails {
    param([System.IO.FileInfo]$FileInfo)

    try {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FileInfo.FullName)

        return @{
            Size = $FileInfo.Length
            SizeFormatted = Format-FileSize -SizeBytes $FileInfo.Length
            CreationTime = $FileInfo.CreationTime
            LastWriteTime = $FileInfo.LastWriteTime
            Version = $versionInfo.FileVersion
            ProductVersion = $versionInfo.ProductVersion
            CompanyName = $versionInfo.CompanyName
            ProductName = $versionInfo.ProductName
            FileDescription = $versionInfo.FileDescription
        }
    } catch {
        return @{
            Size = $FileInfo.Length
            SizeFormatted = Format-FileSize -SizeBytes $FileInfo.Length
            CreationTime = $FileInfo.CreationTime
            LastWriteTime = $FileInfo.LastWriteTime
            Version = "N/A"
            ProductVersion = "N/A"
            CompanyName = "N/A"
            ProductName = "N/A"
            FileDescription = "N/A"
        }
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

# Main execution
Write-Host "🔍 File Architecture Analyzer" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Gray
Write-Host "Target: $Path" -ForegroundColor White

# Validate input path
if (-not (Test-Path $Path)) {
    Write-Error "❌ Path not found: $Path"
    exit 1
}

# Determine if path is file or directory
$IsDirectory = Test-Path $Path -PathType Container
$FilesToAnalyze = @()

if ($IsDirectory) {
    Write-Host "📁 Analyzing directory..." -ForegroundColor Yellow

    $GetChildItemParams = @{
        Path = $Path
        Filter = $FileFilter
        File = $true
        ErrorAction = 'Continue'
    }

    if ($Recurse) {
        $GetChildItemParams.Recurse = $true
        Write-Host "🔄 Including subdirectories" -ForegroundColor Gray
    }

    $FilesToAnalyze = Get-ChildItem @GetChildItemParams

    if ($FilesToAnalyze.Count -eq 0) {
        Write-Warning "⚠️ No files found matching pattern '$FileFilter'"
        exit 0
    }

    Write-Host "📊 Found $($FilesToAnalyze.Count) files to analyze" -ForegroundColor Green
} else {
    Write-Host "📄 Analyzing single file..." -ForegroundColor Yellow
    $FilesToAnalyze = @(Get-Item $Path)
}

# Analyze files
$Results = @()
$ProcessedCount = 0

foreach ($file in $FilesToAnalyze) {
    $ProcessedCount++

    if ($ShowProgress) {
        Write-Progress -Activity "Analyzing files" -Status "Processing $($file.Name)" -PercentComplete (($ProcessedCount / $FilesToAnalyze.Count) * 100)
    }

    # Get architecture information
    $archInfo = Get-PEArchitecture -FilePath $file.FullName

    # Create result object
    $result = [PSCustomObject]@{
        FileName = $file.Name
        FilePath = $file.FullName
        RelativePath = if ($IsDirectory) { $file.FullName.Substring($Path.Length).TrimStart('\') } else { $file.Name }
        Architecture = $archInfo.Architecture
        MachineType = $archInfo.MachineType
        Status = if ($archInfo.Success) { "Success" } else { "Error" }
        Error = $archInfo.Error
    }

    # Add detailed information if requested
    if ($IncludeDetails) {
        $details = Get-FileDetails -FileInfo $file
        $result | Add-Member -NotePropertyName "Size" -NotePropertyValue $details.SizeFormatted
        $result | Add-Member -NotePropertyName "CreationTime" -NotePropertyValue $details.CreationTime
        $result | Add-Member -NotePropertyName "LastWriteTime" -NotePropertyValue $details.LastWriteTime
        $result | Add-Member -NotePropertyName "Version" -NotePropertyValue $details.Version
        $result | Add-Member -NotePropertyName "ProductName" -NotePropertyValue $details.ProductName
        $result | Add-Member -NotePropertyName "CompanyName" -NotePropertyValue $details.CompanyName
        $result | Add-Member -NotePropertyName "FileDescription" -NotePropertyValue $details.FileDescription
    }

    $Results += $result
}

if ($ShowProgress) {
    Write-Progress -Activity "Analyzing files" -Completed
}

# Display results
Write-Host "`n📋 ANALYSIS RESULTS" -ForegroundColor White
Write-Host "===================" -ForegroundColor Gray

# Generate summary statistics
$SuccessCount = ($Results | Where-Object { $_.Status -eq "Success" }).Count
$ErrorCount = ($Results | Where-Object { $_.Status -eq "Error" }).Count
$ArchSummary = $Results | Where-Object { $_.Status -eq "Success" } | Group-Object Architecture | Sort-Object Count -Descending

Write-Host "📊 Summary:" -ForegroundColor Yellow
Write-Host "   Total files: $($Results.Count)" -ForegroundColor White
Write-Host "   Successfully analyzed: $SuccessCount" -ForegroundColor Green
Write-Host "   Errors: $ErrorCount" -ForegroundColor Red

if ($ArchSummary) {
    Write-Host "`n🏗️ Architecture Distribution:" -ForegroundColor Yellow
    foreach ($arch in $ArchSummary) {
        Write-Host "   $($arch.Name): $($arch.Count) files" -ForegroundColor White
    }
}

# Display detailed results based on output format
switch ($OutputFormat) {
    "Table" {
        if ($IncludeDetails) {
            $Results | Format-Table -Property FileName, Architecture, Size, Version, ProductName -AutoSize
        } else {
            $Results | Format-Table -Property FileName, Architecture, Status -AutoSize
        }
    }
    "List" {
        $Results | Format-List
    }
    "CSV" {
        $Results | Format-Table | Out-String | Write-Host
    }
    "JSON" {
        $Results | ConvertTo-Json -Depth 3 | Write-Host
    }
}

# Export to file if specified
if (-not [string]::IsNullOrEmpty($OutputFile)) {
    try {
        $extension = [System.IO.Path]::GetExtension($OutputFile).ToLower()

        switch ($extension) {
            ".csv" {
                $Results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
                Write-Host "`n📁 Results exported to CSV: $OutputFile" -ForegroundColor Green
            }
            ".json" {
                $Results | ConvertTo-Json -Depth 3 | Set-Content -Path $OutputFile -Encoding UTF8
                Write-Host "`n📁 Results exported to JSON: $OutputFile" -ForegroundColor Green
            }
            default {
                # Auto-detect format based on OutputFormat parameter
                if ($OutputFormat -eq "JSON") {
                    $Results | ConvertTo-Json -Depth 3 | Set-Content -Path $OutputFile -Encoding UTF8
                } else {
                    $Results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
                }
                Write-Host "`n📁 Results exported to: $OutputFile" -ForegroundColor Green
            }
        }
    } catch {
        Write-Error "❌ Failed to export results: $($_.Exception.Message)"
    }
}

Write-Host "`n✅ Analysis completed" -ForegroundColor Green
