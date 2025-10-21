<#
.SYNOPSIS
    Copies users from one Active Directory group to another group.

.DESCRIPTION
    This script retrieves all members from a source Active Directory group and adds them to a target group.
    It validates both groups exist, checks for existing memberships, and provides comprehensive reporting.

.PARAMETER SourceGroupName
    Name of the source Active Directory group to copy members from.

.PARAMETER TargetGroupName
    Name of the target Active Directory group to add members to.

.PARAMETER LogFile
    Optional path for log file. If not specified, creates a log in the script directory.

.PARAMETER WhatIf
    Shows what would be done without making actual changes.

.EXAMPLE
    .\Copy-GroupMembership.ps1 -SourceGroupName "IT_AllUsers" -TargetGroupName "ProjectAccess_Users"

.EXAMPLE
    .\Copy-GroupMembership.ps1 -SourceGroupName "IT_AllUsers" -TargetGroupName "ProjectAccess_Users" -WhatIf

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Active Directory PowerShell module, appropriate permissions
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the source Active Directory group")]
    [string]$SourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the target Active Directory group")]
    [string]$TargetGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Path for log file")]
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

# Set up logging
if ([string]::IsNullOrEmpty($LogFile)) {
    $LogFile = Join-Path $PSScriptRoot "GroupMembershipCopy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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

Write-Log "Starting group membership copy process"
Write-Log "Source group: $SourceGroupName"
Write-Log "Target group: $TargetGroupName"
if ($WhatIf) { Write-Log "Running in WhatIf mode - no changes will be made" "WARNING" }

# Validate source group
try {
    $SourceGroup = Get-ADGroup -Filter { Name -eq $SourceGroupName } -ErrorAction Stop
    if (-not $SourceGroup) {
        Write-Log "Source group '$SourceGroupName' not found in Active Directory" "ERROR"
        exit 1
    }
    Write-Log "Source group found: $($SourceGroup.DistinguishedName)" "SUCCESS"
} catch {
    Write-Log "Error accessing source group: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Validate target group
try {
    $TargetGroup = Get-ADGroup -Filter { Name -eq $TargetGroupName } -ErrorAction Stop
    if (-not $TargetGroup) {
        Write-Log "Target group '$TargetGroupName' not found in Active Directory" "ERROR"
        exit 1
    }
    Write-Log "Target group found: $($TargetGroup.DistinguishedName)" "SUCCESS"
} catch {
    Write-Log "Error accessing target group: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Get source group members
try {
    $SourceMembers = Get-ADGroupMember -Identity $SourceGroup.DistinguishedName
    Write-Log "Retrieved $($SourceMembers.Count) members from source group" "SUCCESS"

    if ($SourceMembers.Count -eq 0) {
        Write-Log "Source group has no members. Nothing to copy." "WARNING"
        exit 0
    }
} catch {
    Write-Log "Error retrieving source group members: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Get existing target group members
try {
    $ExistingTargetMembers = Get-ADGroupMember -Identity $TargetGroup.DistinguishedName | Select-Object -ExpandProperty DistinguishedName
    Write-Log "Retrieved $($ExistingTargetMembers.Count) existing members from target group"
} catch {
    Write-Log "Warning: Could not retrieve existing target group members: $($_.Exception.Message)" "WARNING"
    $ExistingTargetMembers = @()
}

# Initialize counters
$Stats = @{
    Added = 0
    AlreadyMember = 0
    Errors = 0
}

$Results = @()

# Process each member
Write-Host "`n📋 Processing group members..." -ForegroundColor Cyan
foreach ($Member in $SourceMembers) {
    Write-Host "Processing: $($Member.SamAccountName)" -NoNewline

    try {
        # Check if already a member of target group
        if ($ExistingTargetMembers -contains $Member.DistinguishedName) {
            Write-Host " 🔹 Already member" -ForegroundColor Cyan
            Write-Log "User already member of target group: $($Member.SamAccountName)"
            $Stats.AlreadyMember++
            $Results += [PSCustomObject]@{
                Username = $Member.SamAccountName
                DisplayName = $Member.Name
                Status = "Already Member"
                Message = "User is already a member of the target group"
            }
            continue
        }

        # Add member to target group
        if ($WhatIf) {
            Write-Host " 🔍 Would be added" -ForegroundColor Yellow
            Write-Log "WHATIF: Would add user to target group: $($Member.SamAccountName)" "WARNING"
            $Stats.Added++
            $Results += [PSCustomObject]@{
                Username = $Member.SamAccountName
                DisplayName = $Member.Name
                Status = "Would Add"
                Message = "Would be added to target group (WhatIf mode)"
            }
        } else {
            Add-ADGroupMember -Identity $TargetGroup -Members $Member.DistinguishedName -ErrorAction Stop
            Write-Host " ✅ Added" -ForegroundColor Green
            Write-Log "Successfully added user to target group: $($Member.SamAccountName)" "SUCCESS"
            $Stats.Added++
            $Results += [PSCustomObject]@{
                Username = $Member.SamAccountName
                DisplayName = $Member.Name
                Status = "Added"
                Message = "Successfully added to target group"
            }
        }

    } catch {
        Write-Host " ❌ Error" -ForegroundColor Red
        Write-Log "Error processing member $($Member.SamAccountName): $($_.Exception.Message)" "ERROR"
        $Stats.Errors++
        $Results += [PSCustomObject]@{
            Username = $Member.SamAccountName
            DisplayName = $Member.Name
            Status = "Error"
            Message = $_.Exception.Message
        }
    }
}

# Generate final report
Write-Host "`n========= FINAL REPORT =========" -ForegroundColor White
Write-Host "Source Group: $SourceGroupName" -ForegroundColor White
Write-Host "Target Group: $TargetGroupName" -ForegroundColor White
if ($WhatIf) {
    Write-Host "🔍 Would Add: $($Stats.Added)" -ForegroundColor Yellow
} else {
    Write-Host "✅ Successfully Added: $($Stats.Added)" -ForegroundColor Green
}
Write-Host "🔹 Already Members: $($Stats.AlreadyMember)" -ForegroundColor Cyan
Write-Host "⚠️  Errors: $($Stats.Errors)" -ForegroundColor Red
Write-Host "📁 Log File: $LogFile" -ForegroundColor Gray

# Export detailed results to CSV
$CsvPath = Join-Path $PSScriptRoot "GroupMembershipCopyResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$Results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
Write-Host "📊 Detailed results exported to: $CsvPath" -ForegroundColor Gray

Write-Log "Process completed. Added: $($Stats.Added), Already Members: $($Stats.AlreadyMember), Errors: $($Stats.Errors)"
