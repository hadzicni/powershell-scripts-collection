<#
.SYNOPSIS
    Exports detailed information about users from a list to CSV format.

.DESCRIPTION
    This script reads usernames from a text file and exports detailed Active Directory information
    for each user to a CSV file. Includes properties like display name, email, department, title, etc.

.PARAMETER InputFilePath
    Path to the text file containing usernames (one per line).

.PARAMETER OutputFilePath
    Path where the CSV file will be saved.

.PARAMETER IncludeDisabled
    Include disabled user accounts in the export.

.PARAMETER Properties
    Additional AD properties to include in the export.

.EXAMPLE
    .\Export-UserInfo.ps1 -InputFilePath ".\userlist.txt" -OutputFilePath ".\users_export.csv"

.EXAMPLE
    .\Export-UserInfo.ps1 -InputFilePath ".\userlist.txt" -OutputFilePath ".\users_export.csv" -IncludeDisabled

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Active Directory PowerShell module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to input file with usernames")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$InputFilePath,

    [Parameter(Mandatory = $false, HelpMessage = "Path for output CSV file")]
    [string]$OutputFilePath = "",

    [Parameter(Mandatory = $false, HelpMessage = "Include disabled user accounts")]
    [switch]$IncludeDisabled,

    [Parameter(Mandatory = $false, HelpMessage = "Additional AD properties to include")]
    [string[]]$Properties = @()
)

# Import Active Directory module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "✅ Active Directory module loaded successfully" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to load Active Directory module: $($_.Exception.Message)"
    exit 1
}

# Set default output path if not provided
if ([string]::IsNullOrEmpty($OutputFilePath)) {
    $OutputFilePath = Join-Path $PSScriptRoot "UserExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
}

Write-Host "📂 Input file: $InputFilePath" -ForegroundColor Cyan
Write-Host "📁 Output file: $OutputFilePath" -ForegroundColor Cyan

# Define standard properties to retrieve
$StandardProperties = @(
    'GivenName', 'Surname', 'DisplayName', 'SamAccountName', 'UserPrincipalName',
    'EmailAddress', 'Department', 'Title', 'Manager', 'Office', 'OfficePhone',
    'MobilePhone', 'Company', 'Enabled', 'LastLogonDate', 'PasswordLastSet',
    'PasswordNeverExpires', 'AccountExpirationDate', 'Created', 'Modified'
)

# Combine with additional properties
$AllProperties = $StandardProperties + $Properties | Select-Object -Unique

# Read usernames from file
try {
    $Usernames = Get-Content -Path $InputFilePath -ErrorAction Stop |
                 Where-Object { $_.Trim() -ne "" } |
                 ForEach-Object { $_.Trim() } |
                 Select-Object -Unique

    Write-Host "📋 Found $($Usernames.Count) unique usernames to process" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to read input file: $($_.Exception.Message)"
    exit 1
}

# Initialize results array and counters
$Results = @()
$Stats = @{
    Found = 0
    NotFound = 0
    Disabled = 0
    Errors = 0
}

# Process each username
Write-Host "`n🔍 Processing users..." -ForegroundColor Cyan
foreach ($Username in $Usernames) {
    Write-Host "Processing: $Username" -NoNewline

    try {
        # Get user from AD
        $User = Get-ADUser -Filter { SamAccountName -eq $Username } -Properties $AllProperties -ErrorAction Stop

        if (-not $User) {
            Write-Host " ❌ Not found" -ForegroundColor Red
            $Stats.NotFound++

            # Add placeholder entry for missing users
            $Results += [PSCustomObject]@{
                SamAccountName = $Username
                Status = "Not Found"
                DisplayName = ""
                GivenName = ""
                Surname = ""
                UserPrincipalName = ""
                EmailAddress = ""
                Department = ""
                Title = ""
                Manager = ""
                Office = ""
                OfficePhone = ""
                MobilePhone = ""
                Company = ""
                Enabled = ""
                LastLogonDate = ""
                PasswordLastSet = ""
                PasswordNeverExpires = ""
                AccountExpirationDate = ""
                Created = ""
                Modified = ""
            }
            continue
        }

        # Check if user is disabled and if we should include them
        if (-not $User.Enabled) {
            $Stats.Disabled++
            if (-not $IncludeDisabled) {
                Write-Host " ⚠️ Disabled (skipped)" -ForegroundColor Yellow
                continue
            }
            Write-Host " ⚠️ Disabled (included)" -ForegroundColor Yellow
        } else {
            Write-Host " ✅ Found" -ForegroundColor Green
        }

        $Stats.Found++

        # Get manager display name if manager exists
        $ManagerDisplayName = ""
        if ($User.Manager) {
            try {
                $ManagerObj = Get-ADUser -Identity $User.Manager -Properties DisplayName -ErrorAction SilentlyContinue
                $ManagerDisplayName = $ManagerObj.DisplayName
            } catch {
                $ManagerDisplayName = $User.Manager
            }
        }

        # Create result object
        $UserResult = [PSCustomObject]@{
            SamAccountName = $User.SamAccountName
            Status = if ($User.Enabled) { "Active" } else { "Disabled" }
            DisplayName = $User.DisplayName
            GivenName = $User.GivenName
            Surname = $User.Surname
            UserPrincipalName = $User.UserPrincipalName
            EmailAddress = $User.EmailAddress
            Department = $User.Department
            Title = $User.Title
            Manager = $ManagerDisplayName
            Office = $User.Office
            OfficePhone = $User.OfficePhone
            MobilePhone = $User.MobilePhone
            Company = $User.Company
            Enabled = $User.Enabled
            LastLogonDate = $User.LastLogonDate
            PasswordLastSet = $User.PasswordLastSet
            PasswordNeverExpires = $User.PasswordNeverExpires
            AccountExpirationDate = $User.AccountExpirationDate
            Created = $User.Created
            Modified = $User.Modified
        }

        # Add any additional properties
        foreach ($Prop in $Properties) {
            if ($User.PSObject.Properties[$Prop]) {
                $UserResult | Add-Member -NotePropertyName $Prop -NotePropertyValue $User.$Prop
            }
        }

        $Results += $UserResult

    } catch {
        Write-Host " ❌ Error" -ForegroundColor Red
        Write-Warning "Error processing $Username`: $($_.Exception.Message)"
        $Stats.Errors++
    }
}

# Export results to CSV
try {
    $Results | Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
    Write-Host "`n✅ Export completed successfully!" -ForegroundColor Green
    Write-Host "📁 File saved: $OutputFilePath" -ForegroundColor Gray
} catch {
    Write-Error "❌ Failed to export CSV: $($_.Exception.Message)"
    exit 1
}

# Display summary
Write-Host "`n========= EXPORT SUMMARY =========" -ForegroundColor White
Write-Host "📊 Total usernames processed: $($Usernames.Count)" -ForegroundColor White
Write-Host "✅ Users found: $($Stats.Found)" -ForegroundColor Green
Write-Host "❌ Users not found: $($Stats.NotFound)" -ForegroundColor Red
Write-Host "⚠️  Disabled users: $($Stats.Disabled)" -ForegroundColor Yellow
Write-Host "❌ Errors: $($Stats.Errors)" -ForegroundColor Red
Write-Host "📁 Output file: $OutputFilePath" -ForegroundColor Gray

# Show file info
$FileInfo = Get-Item $OutputFilePath
Write-Host "📈 File size: $([math]::Round($FileInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
