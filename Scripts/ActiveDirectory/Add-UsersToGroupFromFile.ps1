<#
.SYNOPSIS
    Adds users from a text file to an Active Directory group.

.DESCRIPTION
    This script reads usernames from a specified text file and adds them to a target Active Directory group.
    It validates user existence, checks for existing memberships, and provides detailed reporting.

.PARAMETER UserListPath
    Path to the text file containing usernames (one per line).

.PARAMETER TargetGroupName
    Name of the Active Directory group to add users to.

.PARAMETER LogFile
    Optional path for log file. If not specified, creates a log in the script directory.

.EXAMPLE
    .\Add-UsersToGroupFromFile.ps1 -UserListPath "C:\temp\users.txt" -TargetGroupName "IT_Department"

.EXAMPLE
    .\Add-UsersToGroupFromFile.ps1 -UserListPath ".\userlist.txt" -TargetGroupName "ProjectTeam" -LogFile "C:\logs\group_changes.log"

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Active Directory PowerShell module, appropriate permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the text file containing usernames")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$UserListPath,

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
    $LogFile = Join-Path $PSScriptRoot "UserGroupChanges_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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

Write-Log "Starting user group addition process"
Write-Log "User list file: $UserListPath"
Write-Log "Target group: $TargetGroupName"

# Validate input file
if (-not (Test-Path $UserListPath)) {
    Write-Log "User list file not found: $UserListPath" "ERROR"
    exit 1
}

# Read user list
try {
    $UserList = Get-Content -Path $UserListPath | Where-Object { $_.Trim() -ne "" } | Select-Object -Unique
    Write-Log "Successfully read $($UserList.Count) unique users from file" "SUCCESS"
} catch {
    Write-Log "Failed to read user list file: $($_.Exception.Message)" "ERROR"
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

# Get existing group members for comparison
try {
    $ExistingMembers = Get-ADGroupMember -Identity $TargetGroup.DistinguishedName | Select-Object -ExpandProperty SamAccountName
    Write-Log "Retrieved $($ExistingMembers.Count) existing group members"
} catch {
    Write-Log "Warning: Could not retrieve existing group members: $($_.Exception.Message)" "WARNING"
    $ExistingMembers = @()
}

# Initialize counters
$Stats = @{
    Added = 0
    AlreadyMember = 0
    NotFound = 0
    Errors = 0
}

$Results = @()

# Process each user
Write-Host "`n📋 Processing users..." -ForegroundColor Cyan
foreach ($Username in $UserList) {
    $Username = $Username.Trim()
    if ([string]::IsNullOrEmpty($Username)) { continue }

    Write-Host "Processing: $Username" -NoNewline

    try {
        # Check if user exists in AD
        $ADUser = Get-ADUser -Filter { SamAccountName -eq $Username } -ErrorAction Stop

        if (-not $ADUser) {
            Write-Host " ❌ Not found" -ForegroundColor Red
            Write-Log "User not found in AD: $Username" "WARNING"
            $Stats.NotFound++
            $Results += [PSCustomObject]@{
                Username = $Username
                Status = "Not Found"
                Message = "User does not exist in Active Directory"
            }
            continue
        }

        # Check if already a member
        if ($ExistingMembers -contains $Username) {
            Write-Host " 🔹 Already member" -ForegroundColor Cyan
            Write-Log "User already member of group: $Username"
            $Stats.AlreadyMember++
            $Results += [PSCustomObject]@{
                Username = $Username
                Status = "Already Member"
                Message = "User is already a member of the group"
            }
            continue
        }

        # Add user to group
        Add-ADGroupMember -Identity $TargetGroup -Members $ADUser.DistinguishedName -ErrorAction Stop
        Write-Host " ✅ Added" -ForegroundColor Green
        Write-Log "Successfully added user to group: $Username" "SUCCESS"
        $Stats.Added++
        $Results += [PSCustomObject]@{
            Username = $Username
            Status = "Added"
            Message = "Successfully added to group"
        }

    } catch {
        Write-Host " ❌ Error" -ForegroundColor Red
        Write-Log "Error processing user $Username`: $($_.Exception.Message)" "ERROR"
        $Stats.Errors++
        $Results += [PSCustomObject]@{
            Username = $Username
            Status = "Error"
            Message = $_.Exception.Message
        }
    }
}

# Generate final report
Write-Host "`n========= FINAL REPORT =========" -ForegroundColor White
Write-Host "Target Group: $TargetGroupName" -ForegroundColor White
Write-Host "✅ Successfully Added: $($Stats.Added)" -ForegroundColor Green
Write-Host "🔹 Already Members: $($Stats.AlreadyMember)" -ForegroundColor Cyan
Write-Host "❌ Not Found: $($Stats.NotFound)" -ForegroundColor Yellow
Write-Host "⚠️  Errors: $($Stats.Errors)" -ForegroundColor Red
Write-Host "📁 Log File: $LogFile" -ForegroundColor Gray

# Export detailed results to CSV
$CsvPath = Join-Path $PSScriptRoot "UserGroupResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$Results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
Write-Host "📊 Detailed results exported to: $CsvPath" -ForegroundColor Gray

Write-Log "Process completed. Added: $($Stats.Added), Already Members: $($Stats.AlreadyMember), Not Found: $($Stats.NotFound), Errors: $($Stats.Errors)"
