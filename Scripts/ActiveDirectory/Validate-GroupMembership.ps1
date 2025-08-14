<#
.SYNOPSIS
    Validates group membership requirements for users in a target Active Directory group.

.DESCRIPTION
    This script checks if all members of a target AD group are also members of required groups.
    It provides detailed reporting on which users are missing from required groups and can
    optionally add them automatically.

.PARAMETER TargetGroupName
    Name of the Active Directory group whose members need to be validated.

.PARAMETER RequiredGroups
    Array of group names that all target group members should belong to.

.PARAMETER AutoFix
    Automatically add users to missing required groups.

.PARAMETER LogFile
    Path for log file. If not specified, creates a log in the script directory.

.PARAMETER ExportReport
    Export detailed report to CSV file.

.EXAMPLE
    .\Validate-GroupMembership.ps1 -TargetGroupName "IT_Doctors" -RequiredGroups @("IT_AllUsers", "ForumUsers", "HeyexUsers")

.EXAMPLE
    .\Validate-GroupMembership.ps1 -TargetGroupName "IT_Doctors" -RequiredGroups @("IT_AllUsers", "ForumUsers") -AutoFix -ExportReport

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Active Directory PowerShell module, appropriate permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the target Active Directory group")]
    [string]$TargetGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "Array of required group names")]
    [string[]]$RequiredGroups,

    [Parameter(Mandatory = $false, HelpMessage = "Automatically add users to missing groups")]
    [switch]$AutoFix,

    [Parameter(Mandatory = $false, HelpMessage = "Path for log file")]
    [string]$LogFile = "",

    [Parameter(Mandatory = $false, HelpMessage = "Export detailed report to CSV")]
    [switch]$ExportReport
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
    $LogFile = Join-Path $PSScriptRoot "GroupValidation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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

Write-Log "Starting group membership validation"
Write-Log "Target group: $TargetGroupName"
Write-Log "Required groups: $($RequiredGroups -join ', ')"
if ($AutoFix) { Write-Log "AutoFix enabled - will add users to missing groups" "WARNING" }

# Validate target group
try {
    $TargetGroup = Get-ADGroup -Filter { Name -eq $TargetGroupName } -ErrorAction Stop
    if (-not $TargetGroup) {
        Write-Log "Target group '$TargetGroupName' not found" "ERROR"
        exit 1
    }
    Write-Log "Target group found: $($TargetGroup.DistinguishedName)" "SUCCESS"
} catch {
    Write-Log "Error accessing target group: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Validate all required groups exist
$ValidatedRequiredGroups = @()
foreach ($GroupName in $RequiredGroups) {
    try {
        $Group = Get-ADGroup -Filter { Name -eq $GroupName } -ErrorAction Stop
        if ($Group) {
            $ValidatedRequiredGroups += $Group
            Write-Log "Required group found: $GroupName" "SUCCESS"
        } else {
            Write-Log "Required group not found: $GroupName" "ERROR"
            exit 1
        }
    } catch {
        Write-Log "Error accessing required group '$GroupName': $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# Get target group members
try {
    $TargetMembers = Get-ADGroupMember -Identity $TargetGroup.DistinguishedName | Where-Object { $_.objectClass -eq "user" }
    Write-Log "Found $($TargetMembers.Count) user members in target group" "SUCCESS"

    if ($TargetMembers.Count -eq 0) {
        Write-Log "Target group has no user members" "WARNING"
        exit 0
    }
} catch {
    Write-Log "Error retrieving target group members: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Initialize tracking variables
$ValidationResults = @()
$Stats = @{
    CompliantUsers = 0
    NonCompliantUsers = 0
    FixedUsers = 0
    Errors = 0
}

# Process each member
Write-Host "`n🔍 Validating group memberships..." -ForegroundColor Cyan
foreach ($Member in $TargetMembers) {
    Write-Host "Checking: $($Member.SamAccountName)" -NoNewline

    try {
        # Get user's current group memberships
        $UserGroups = (Get-ADUser $Member.SamAccountName -Properties MemberOf).MemberOf |
                      Get-ADGroup |
                      Select-Object -ExpandProperty SamAccountName

        # Check which required groups the user is missing
        $MissingGroups = @()
        $HasGroups = @()

        foreach ($RequiredGroup in $ValidatedRequiredGroups) {
            if ($UserGroups -contains $RequiredGroup.SamAccountName) {
                $HasGroups += $RequiredGroup.SamAccountName
            } else {
                $MissingGroups += $RequiredGroup
            }
        }

        # Create result object
        $Result = [PSCustomObject]@{
            Username = $Member.SamAccountName
            DisplayName = $Member.Name
            IsCompliant = ($MissingGroups.Count -eq 0)
            HasGroups = $HasGroups -join '; '
            MissingGroups = ($MissingGroups | Select-Object -ExpandProperty SamAccountName) -join '; '
            ActionTaken = ""
            Status = ""
        }

        if ($MissingGroups.Count -eq 0) {
            Write-Host " ✅ Compliant" -ForegroundColor Green
            $Result.Status = "Compliant"
            $Stats.CompliantUsers++
        } else {
            Write-Host " ❌ Missing: $($MissingGroups.Count) groups" -ForegroundColor Red
            $Result.Status = "Non-Compliant"
            $Stats.NonCompliantUsers++

            Write-Log "User $($Member.SamAccountName) missing groups: $($MissingGroups.SamAccountName -join ', ')" "WARNING"

            # Auto-fix if requested
            if ($AutoFix) {
                $AddedGroups = @()
                $FailedGroups = @()

                foreach ($MissingGroup in $MissingGroups) {
                    try {
                        Add-ADGroupMember -Identity $MissingGroup -Members $Member.DistinguishedName -ErrorAction Stop
                        $AddedGroups += $MissingGroup.SamAccountName
                        Write-Log "Added $($Member.SamAccountName) to group $($MissingGroup.SamAccountName)" "SUCCESS"
                    } catch {
                        $FailedGroups += $MissingGroup.SamAccountName
                        Write-Log "Failed to add $($Member.SamAccountName) to group $($MissingGroup.SamAccountName): $($_.Exception.Message)" "ERROR"
                    }
                }

                if ($AddedGroups.Count -gt 0) {
                    $Result.ActionTaken = "Added to: $($AddedGroups -join ', ')"
                    $Stats.FixedUsers++
                }
                if ($FailedGroups.Count -gt 0) {
                    $Result.ActionTaken += " | Failed to add to: $($FailedGroups -join ', ')"
                }
            }
        }

        $ValidationResults += $Result

    } catch {
        Write-Host " ❌ Error" -ForegroundColor Red
        Write-Log "Error processing $($Member.SamAccountName): $($_.Exception.Message)" "ERROR"
        $Stats.Errors++

        $ValidationResults += [PSCustomObject]@{
            Username = $Member.SamAccountName
            DisplayName = $Member.Name
            IsCompliant = $false
            HasGroups = ""
            MissingGroups = ""
            ActionTaken = ""
            Status = "Error: $($_.Exception.Message)"
        }
    }
}

# Generate summary report
Write-Host "`n========= VALIDATION SUMMARY =========" -ForegroundColor White
Write-Host "🎯 Target Group: $TargetGroupName" -ForegroundColor White
Write-Host "📋 Required Groups: $($RequiredGroups -join ', ')" -ForegroundColor White
Write-Host "✅ Compliant Users: $($Stats.CompliantUsers)" -ForegroundColor Green
Write-Host "❌ Non-Compliant Users: $($Stats.NonCompliantUsers)" -ForegroundColor Red
if ($AutoFix) {
    Write-Host "🔧 Fixed Users: $($Stats.FixedUsers)" -ForegroundColor Yellow
}
Write-Host "⚠️  Errors: $($Stats.Errors)" -ForegroundColor Red
Write-Host "📁 Log File: $LogFile" -ForegroundColor Gray

# Show detailed non-compliant users
if ($Stats.NonCompliantUsers -gt 0) {
    Write-Host "`n📋 Non-Compliant Users:" -ForegroundColor Yellow
    $NonCompliantUsers = $ValidationResults | Where-Object { -not $_.IsCompliant -and $_.Status -ne "Error" }
    foreach ($User in $NonCompliantUsers) {
        Write-Host "   • $($User.Username) - Missing: $($User.MissingGroups)" -ForegroundColor Yellow
        if ($User.ActionTaken) {
            Write-Host "     → $($User.ActionTaken)" -ForegroundColor Cyan
        }
    }
}

# Export detailed report if requested
if ($ExportReport) {
    $ReportPath = Join-Path $PSScriptRoot "GroupValidationReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $ValidationResults | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
    Write-Host "📊 Detailed report exported to: $ReportPath" -ForegroundColor Gray
}

Write-Log "Validation completed. Compliant: $($Stats.CompliantUsers), Non-Compliant: $($Stats.NonCompliantUsers), Fixed: $($Stats.FixedUsers), Errors: $($Stats.Errors)"
