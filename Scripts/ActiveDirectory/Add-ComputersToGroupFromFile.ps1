<#
.SYNOPSIS
    Adds computers from a text file to an Active Directory group.

.DESCRIPTION
    This script reads computer names from a specified text file and adds them to a target Active Directory group.
    It validates device existence, checks for existing memberships, and provides detailed reporting.

.PARAMETER ComputerListPath
    Path to the text file containing computer names (one per line).

.PARAMETER TargetGroupName
    Name of the Active Directory group to add devices to.

.PARAMETER LogFile
    Optional path for log file. If not specified, creates a log in the script directory.

.EXAMPLE
    .\Add-ComputersToGroupFromFile.ps1 -ComputerListPath "C:\temp\pcs.txt" -TargetGroupName "LaptopGroup"

.NOTES
    Author: Nikola Hadzic
    Version: 1.0
    Date: 2025-08-14
    Requirements: Active Directory PowerShell module, appropriate permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$ComputerListPath,

    [Parameter(Mandatory = $true)]
    [string]$TargetGroupName,

    [Parameter(Mandatory = $false)]
    [string]$LogFile = ""
)

# Import Active Directory module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "✅ Active Directory module loaded successfully" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to load Active Directory module: $($_.Exception.Message)"
    exit 1
}

# Logging setup
if ([string]::IsNullOrEmpty($LogFile)) {
    $LogFile = Join-Path $PSScriptRoot "ComputerGroupChanges_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry

    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        default { Write-Host $Message }
    }
}

Write-Log "Starting computer group addition process"
Write-Log "Computer list file: $ComputerListPath"
Write-Log "Target group: $TargetGroupName"

# Read file
try {
    $ComputerList = Get-Content -Path $ComputerListPath | Where-Object { $_.Trim() -ne "" } | Select-Object -Unique
    Write-Log "Successfully read $($ComputerList.Count) unique computers from file" "SUCCESS"
} catch {
    Write-Log "Failed to read computer list file: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Validate target group
try {
    $TargetGroup = Get-ADGroup -Filter { Name -eq $TargetGroupName } -ErrorAction Stop
    Write-Log "Target group found: $($TargetGroup.DistinguishedName)" "SUCCESS"
} catch {
    Write-Log "Target group not found: $TargetGroupName" "ERROR"
    exit 1
}

# Existing members
try {
    $ExistingMembers = Get-ADGroupMember -Identity $TargetGroup.DistinguishedName | Select-Object -ExpandProperty SamAccountName
    Write-Log "Retrieved $($ExistingMembers.Count) existing group members"
} catch {
    Write-Log "Could not retrieve existing group members: $($_.Exception.Message)" "WARNING"
    $ExistingMembers = @()
}

# Counters
$Stats = @{
    Added = 0
    AlreadyMember = 0
    NotFound = 0
    Errors = 0
}

$Results = @()

Write-Host "`n📋 Processing computers..." -ForegroundColor Cyan

foreach ($ComputerName in $ComputerList) {
    $ComputerName = $ComputerName.Trim()
    if ([string]::IsNullOrEmpty($ComputerName)) { continue }

    Write-Host "Processing: $ComputerName" -NoNewline

    try {
        # AD Computer retrieval (considering $ ending)
        $ADDevice = Get-ADComputer -Filter {
            Name -eq $ComputerName -or SamAccountName -eq "$ComputerName$"
        } -ErrorAction Stop

        if (-not $ADDevice) {
            Write-Host " ❌ Not found" -ForegroundColor Red
            Write-Log "Device not found in AD: $ComputerName" "WARNING"
            $Stats.NotFound++
            continue
        }

        # Check if already a member
        if ($ExistingMembers -contains $ADDevice.SamAccountName) {
            Write-Host " 🔹 Already member" -ForegroundColor Cyan
            Write-Log "Device already member: $ComputerName"
            $Stats.AlreadyMember++
            continue
        }

        # Add device
        Add-ADGroupMember -Identity $TargetGroup -Members $ADDevice.DistinguishedName -ErrorAction Stop
        Write-Host " ✅ Added" -ForegroundColor Green
        Write-Log "Device added: $ComputerName" "SUCCESS"
        $Stats.Added++

    } catch {
        Write-Host " ❌ Error" -ForegroundColor Red
        Write-Log "Error processing $ComputerName $($_.Exception.Message)" "ERROR"
        $Stats.Errors++
    }
}

# Final report
Write-Host "`n========= FINAL REPORT =========" -ForegroundColor White
Write-Host "Target Group: $TargetGroupName"
Write-Host "✅ Added: $($Stats.Added)" -ForegroundColor Green
Write-Host "🔹 Already Members: $($Stats.AlreadyMember)" -ForegroundColor Cyan
Write-Host "❌ Not Found: $($Stats.NotFound)" -ForegroundColor Yellow
Write-Host "⚠️ Errors: $($Stats.Errors)" -ForegroundColor Red
Write-Host "📁 Log File: $LogFile"

# Export results
$CsvPath = Join-Path $PSScriptRoot "ComputerGroupResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$Results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
Write-Host "📊 Results exported to: $CsvPath"
