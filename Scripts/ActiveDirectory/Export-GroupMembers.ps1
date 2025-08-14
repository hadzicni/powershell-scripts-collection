<#
.SYNOPSIS
    Exports all members of an Active Directory group to an Excel file.

.DESCRIPTION
    This script retrieves all members of a specified Active Directory group and exports their
    detailed information to an Excel file. It can handle nested groups and filter by object type.

.PARAMETER GroupName
    Name of the Active Directory group to export members from.

.PARAMETER OutputPath
    Path where the Excel file will be saved. If not specified, saves to script directory.

.PARAMETER Recursive
    Include members from nested groups.

.PARAMETER ObjectType
    Filter by object type (User, Group, Computer). Default is User.

.PARAMETER Properties
    Additional AD properties to include in the export.

.EXAMPLE
    .\Export-GroupMembers.ps1 -GroupName "IT_Department"

.EXAMPLE
    .\Export-GroupMembers.ps1 -GroupName "IT_Department" -Recursive -OutputPath "C:\Reports\IT_Members.xlsx"

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Active Directory PowerShell module, ImportExcel module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Active Directory group")]
    [string]$GroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Output path for the Excel file")]
    [string]$OutputPath = "",

    [Parameter(Mandatory = $false, HelpMessage = "Include nested group members")]
    [switch]$Recursive,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by object type")]
    [ValidateSet("User", "Group", "Computer", "All")]
    [string]$ObjectType = "User",

    [Parameter(Mandatory = $false, HelpMessage = "Additional AD properties to include")]
    [string[]]$Properties = @()
)

# Check for required modules
$RequiredModules = @("ActiveDirectory")
foreach ($Module in $RequiredModules) {
    try {
        Import-Module $Module -ErrorAction Stop
        Write-Host "✅ $Module module loaded successfully" -ForegroundColor Green
    } catch {
        Write-Error "❌ Failed to load $Module module: $($_.Exception.Message)"
        exit 1
    }
}

# Check for ImportExcel module (optional but recommended)
try {
    Import-Module ImportExcel -ErrorAction Stop
    $UseExcel = $true
    Write-Host "✅ ImportExcel module loaded - will create Excel file" -ForegroundColor Green
} catch {
    $UseExcel = $false
    Write-Warning "⚠️ ImportExcel module not found - will create CSV file instead"
}

# Set output path
if ([string]::IsNullOrEmpty($OutputPath)) {
    $Extension = if ($UseExcel) { "xlsx" } else { "csv" }
    $OutputPath = Join-Path $PSScriptRoot "GroupMembers_$($GroupName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').$Extension"
}

Write-Host "🎯 Target group: $GroupName" -ForegroundColor Cyan
Write-Host "📁 Output file: $OutputPath" -ForegroundColor Cyan
Write-Host "🔄 Recursive: $Recursive" -ForegroundColor Cyan
Write-Host "📋 Object type filter: $ObjectType" -ForegroundColor Cyan

# Validate group exists
try {
    $Group = Get-ADGroup -Filter { Name -eq $GroupName } -ErrorAction Stop
    if (-not $Group) {
        Write-Error "❌ Group '$GroupName' not found in Active Directory"
        exit 1
    }
    Write-Host "✅ Group found: $($Group.DistinguishedName)" -ForegroundColor Green
} catch {
    Write-Error "❌ Error accessing group: $($_.Exception.Message)"
    exit 1
}

# Define standard properties for different object types
$UserProperties = @(
    'GivenName', 'Surname', 'DisplayName', 'SamAccountName', 'UserPrincipalName',
    'EmailAddress', 'Department', 'Title', 'Manager', 'Office', 'OfficePhone',
    'MobilePhone', 'Company', 'Enabled', 'LastLogonDate', 'PasswordLastSet'
)

$GroupProperties = @('DisplayName', 'SamAccountName', 'Description', 'GroupCategory', 'GroupScope', 'Created')
$ComputerProperties = @('DisplayName', 'SamAccountName', 'OperatingSystem', 'OperatingSystemVersion', 'Enabled', 'LastLogonDate')

# Get group members
try {
    Write-Host "`n🔍 Retrieving group members..." -ForegroundColor Cyan
    $Members = Get-ADGroupMember -Identity $Group.DistinguishedName -Recursive:$Recursive
    Write-Host "📊 Found $($Members.Count) members" -ForegroundColor Green

    if ($Members.Count -eq 0) {
        Write-Warning "⚠️ Group has no members"
        exit 0
    }
} catch {
    Write-Error "❌ Error retrieving group members: $($_.Exception.Message)"
    exit 1
}

# Filter by object type if specified
if ($ObjectType -ne "All") {
    $FilteredMembers = $Members | Where-Object { $_.objectClass -eq $ObjectType.ToLower() }
    Write-Host "🔽 Filtered to $($FilteredMembers.Count) $ObjectType objects" -ForegroundColor Yellow
    $Members = $FilteredMembers
}

# Process members and get detailed information
$Results = @()
$ProcessedCount = 0

foreach ($Member in $Members) {
    $ProcessedCount++
    Write-Progress -Activity "Processing members" -Status "Processing $($Member.SamAccountName)" -PercentComplete (($ProcessedCount / $Members.Count) * 100)

    try {
        switch ($Member.objectClass) {
            "user" {
                $AllProps = $UserProperties + $Properties | Select-Object -Unique
                $DetailedInfo = Get-ADUser -Identity $Member.DistinguishedName -Properties $AllProps -ErrorAction Stop

                # Get manager display name
                $ManagerName = ""
                if ($DetailedInfo.Manager) {
                    try {
                        $Manager = Get-ADUser -Identity $DetailedInfo.Manager -Properties DisplayName -ErrorAction SilentlyContinue
                        $ManagerName = $Manager.DisplayName
                    } catch {
                        $ManagerName = $DetailedInfo.Manager
                    }
                }

                $Results += [PSCustomObject]@{
                    ObjectType = "User"
                    DisplayName = $DetailedInfo.DisplayName
                    SamAccountName = $DetailedInfo.SamAccountName
                    UserPrincipalName = $DetailedInfo.UserPrincipalName
                    GivenName = $DetailedInfo.GivenName
                    Surname = $DetailedInfo.Surname
                    EmailAddress = $DetailedInfo.EmailAddress
                    Department = $DetailedInfo.Department
                    Title = $DetailedInfo.Title
                    Manager = $ManagerName
                    Office = $DetailedInfo.Office
                    OfficePhone = $DetailedInfo.OfficePhone
                    MobilePhone = $DetailedInfo.MobilePhone
                    Company = $DetailedInfo.Company
                    Enabled = $DetailedInfo.Enabled
                    LastLogonDate = $DetailedInfo.LastLogonDate
                    PasswordLastSet = $DetailedInfo.PasswordLastSet
                    DistinguishedName = $DetailedInfo.DistinguishedName
                }
            }

            "group" {
                $AllProps = $GroupProperties + $Properties | Select-Object -Unique
                $DetailedInfo = Get-ADGroup -Identity $Member.DistinguishedName -Properties $AllProps -ErrorAction Stop

                $Results += [PSCustomObject]@{
                    ObjectType = "Group"
                    DisplayName = $DetailedInfo.DisplayName
                    SamAccountName = $DetailedInfo.SamAccountName
                    Description = $DetailedInfo.Description
                    GroupCategory = $DetailedInfo.GroupCategory
                    GroupScope = $DetailedInfo.GroupScope
                    Created = $DetailedInfo.Created
                    DistinguishedName = $DetailedInfo.DistinguishedName
                }
            }

            "computer" {
                $AllProps = $ComputerProperties + $Properties | Select-Object -Unique
                $DetailedInfo = Get-ADComputer -Identity $Member.DistinguishedName -Properties $AllProps -ErrorAction Stop

                $Results += [PSCustomObject]@{
                    ObjectType = "Computer"
                    DisplayName = $DetailedInfo.DisplayName
                    SamAccountName = $DetailedInfo.SamAccountName
                    OperatingSystem = $DetailedInfo.OperatingSystem
                    OperatingSystemVersion = $DetailedInfo.OperatingSystemVersion
                    Enabled = $DetailedInfo.Enabled
                    LastLogonDate = $DetailedInfo.LastLogonDate
                    DistinguishedName = $DetailedInfo.DistinguishedName
                }
            }
        }
    } catch {
        Write-Warning "⚠️ Error processing $($Member.SamAccountName): $($_.Exception.Message)"

        # Add basic info even if detailed lookup fails
        $Results += [PSCustomObject]@{
            ObjectType = $Member.objectClass
            DisplayName = $Member.Name
            SamAccountName = $Member.SamAccountName
            Error = $_.Exception.Message
            DistinguishedName = $Member.DistinguishedName
        }
    }
}

Write-Progress -Activity "Processing members" -Completed

# Export results
try {
    if ($UseExcel) {
        # Create Excel file with formatting
        $Results | Export-Excel -Path $OutputPath -AutoSize -FreezeTopRow -BoldTopRow -WorksheetName "Group Members" -Title "Members of $GroupName"
        Write-Host "`n✅ Excel file created successfully!" -ForegroundColor Green
    } else {
        # Export as CSV
        $Results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "`n✅ CSV file created successfully!" -ForegroundColor Green
    }

    Write-Host "📁 File saved: $OutputPath" -ForegroundColor Gray

    # Show file info
    $FileInfo = Get-Item $OutputPath
    Write-Host "📈 File size: $([math]::Round($FileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray

} catch {
    Write-Error "❌ Failed to create output file: $($_.Exception.Message)"
    exit 1
}

# Display summary
Write-Host "`n========= EXPORT SUMMARY =========" -ForegroundColor White
Write-Host "🎯 Group: $GroupName" -ForegroundColor White
Write-Host "📊 Total members exported: $($Results.Count)" -ForegroundColor Green

# Show breakdown by object type
$TypeCounts = $Results | Group-Object ObjectType | Sort-Object Name
foreach ($Type in $TypeCounts) {
    Write-Host "   $($Type.Name): $($Type.Count)" -ForegroundColor Cyan
}

Write-Host "📁 Output file: $OutputPath" -ForegroundColor Gray
