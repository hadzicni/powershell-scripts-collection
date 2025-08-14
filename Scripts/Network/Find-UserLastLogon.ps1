<#
.SYNOPSIS
    Finds the computer where a user was last logged on in the Active Directory domain.

.DESCRIPTION
    This script searches through domain computers to find where a specific user last logged on.
    It checks Windows Security Event Logs for successful logon events and identifies the most recent one.

.PARAMETER Username
    The username (SamAccountName) to search for.

.PARAMETER MaxDaysBack
    Maximum number of days to search back in event logs. Default is 30 days.

.PARAMETER ComputerFilter
    Filter for computer names to search (e.g., "WS-*", "NB-*"). Default searches all computers.

.PARAMETER LogFile
    Path for log file. If not specified, creates a log in the script directory.

.PARAMETER IncludeOfflineComputers
    Include computers that are currently offline in the search.

.PARAMETER Detailed
    Show detailed information about all found logon events.

.EXAMPLE
    .\Find-UserLastLogon.ps1 -Username "john.doe"

.EXAMPLE
    .\Find-UserLastLogon.ps1 -Username "jane.smith" -MaxDaysBack 7 -ComputerFilter "WS-*" -Detailed

.EXAMPLE
    .\Find-UserLastLogon.ps1 -Username "admin.user" -IncludeOfflineComputers

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Active Directory PowerShell module, appropriate permissions to query event logs
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Username to search for")]
    [string]$Username,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum days to search back")]
    [int]$MaxDaysBack = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Filter for computer names")]
    [string]$ComputerFilter = "*",

    [Parameter(Mandatory = $false, HelpMessage = "Path for log file")]
    [string]$LogFile = "",

    [Parameter(Mandatory = $false, HelpMessage = "Include offline computers")]
    [switch]$IncludeOfflineComputers,

    [Parameter(Mandatory = $false, HelpMessage = "Show detailed information")]
    [switch]$Detailed
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
    $LogFile = Join-Path $PSScriptRoot "UserLastLogonSearch_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
        default { Write-Host $Message }
    }
}

function Test-ComputerConnectivity {
    param([string]$ComputerName, [int]$TimeoutMs = 1000)

    try {
        Test-Connection -ComputerName $ComputerName -Count 1 -TimeToLive 32 -Delay 1 -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-LogonEventsFromComputer {
    param(
        [string]$ComputerName,
        [string]$TargetUsername,
        [DateTime]$StartTime
    )

    $logonEvents = @()

    try {
        # Query Security Event Log for successful logon events (Event ID 4624)
        $filterHashtable = @{
            LogName = 'Security'
            ID = 4624
            StartTime = $StartTime
        }

        $events = Get-WinEvent -ComputerName $ComputerName -FilterHashtable $filterHashtable -ErrorAction Stop

        foreach ($logEvent in $events) {
            # Parse event XML to extract username
            $eventXml = [xml]$logEvent.ToXml()
            $eventData = $eventXml.Event.EventData.Data

            # Find the TargetUserName field
            $targetUserName = ($eventData | Where-Object { $_.Name -eq 'TargetUserName' }).'#text'
            $logonType = ($eventData | Where-Object { $_.Name -eq 'LogonType' }).'#text'
            $workstationName = ($eventData | Where-Object { $_.Name -eq 'WorkstationName' }).'#text'
            $sourceNetworkAddress = ($eventData | Where-Object { $_.Name -eq 'IpAddress' }).'#text'

            # Check if this is the user we're looking for
            if ($targetUserName -eq $TargetUsername) {
                $logonEvents += [PSCustomObject]@{
                    ComputerName = $ComputerName
                    Username = $targetUserName
                    LogonTime = $logEvent.TimeCreated
                    LogonType = $logonType
                    LogonTypeDescription = Get-LogonTypeDescription -LogonType $logonType
                    WorkstationName = $workstationName
                    SourceIP = $sourceNetworkAddress
                    EventId = $logEvent.Id
                    RecordId = $logEvent.RecordId
                }
            }
        }

    } catch [System.UnauthorizedAccessException] {
        Write-Log "Access denied to Security log on $ComputerName" "WARNING"
    } catch [System.Exception] {
        if ($_.Exception.Message -like "*No events were found*") {
            # No events found is normal, not an error
            Write-Log "No logon events found on $ComputerName for the specified time period"
        } else {
            Write-Log "Error querying $ComputerName`: $($_.Exception.Message)" "WARNING"
        }
    }

    return $logonEvents
}

function Get-LogonTypeDescription {
    param([string]$LogonType)

    switch ($LogonType) {
        "2" { return "Interactive (Console)" }
        "3" { return "Network" }
        "4" { return "Batch" }
        "5" { return "Service" }
        "7" { return "Unlock" }
        "8" { return "NetworkCleartext" }
        "9" { return "NewCredentials" }
        "10" { return "RemoteInteractive (RDP)" }
        "11" { return "CachedInteractive" }
        default { return "Unknown ($LogonType)" }
    }
}

# Main execution
Write-Log "Starting user last logon search"
Write-Log "Target user: $Username"
Write-Log "Search period: Last $MaxDaysBack days"
Write-Log "Computer filter: $ComputerFilter"

$StartTime = (Get-Date).AddDays(-$MaxDaysBack)
Write-Log "Searching events from: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"

# Validate user exists in AD
try {
    $ADUser = Get-ADUser -Filter { SamAccountName -eq $Username } -ErrorAction Stop
    if (-not $ADUser) {
        Write-Log "User '$Username' not found in Active Directory" "ERROR"
        exit 1
    }
    Write-Log "User found in AD: $($ADUser.DisplayName) ($($ADUser.UserPrincipalName))" "SUCCESS"
} catch {
    Write-Log "Error searching for user in AD: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Get list of domain computers
Write-Host "`n🔍 Retrieving domain computers..." -ForegroundColor Cyan
try {
    $AllComputers = Get-ADComputer -Filter { Name -like $ComputerFilter } -Properties LastLogonDate, OperatingSystem
    Write-Log "Found $($AllComputers.Count) computers matching filter '$ComputerFilter'" "SUCCESS"
} catch {
    Write-Log "Error retrieving computers from AD: $($_.Exception.Message)" "ERROR"
    exit 1
}

if ($AllComputers.Count -eq 0) {
    Write-Log "No computers found matching filter '$ComputerFilter'" "WARNING"
    exit 0
}

# Filter computers if not including offline ones
$ComputersToSearch = $AllComputers
if (-not $IncludeOfflineComputers) {
    Write-Host "🌐 Testing computer connectivity..." -ForegroundColor Yellow
    $OnlineComputers = @()
    $OfflineCount = 0

    foreach ($computer in $AllComputers) {
        Write-Progress -Activity "Testing connectivity" -Status "Testing $($computer.Name)" -PercentComplete (([Array]::IndexOf($AllComputers, $computer) / $AllComputers.Count) * 100)

        if (Test-ComputerConnectivity -ComputerName $computer.Name) {
            $OnlineComputers += $computer
        } else {
            $OfflineCount++
        }
    }

    Write-Progress -Activity "Testing connectivity" -Completed
    $ComputersToSearch = $OnlineComputers
    Write-Log "Online computers: $($OnlineComputers.Count), Offline: $OfflineCount"
}

# Search for logon events
Write-Host "`n🔎 Searching for logon events..." -ForegroundColor Cyan
$AllLogonEvents = @()
$SearchedCount = 0
$ErrorCount = 0

foreach ($computer in $ComputersToSearch) {
    $SearchedCount++
    Write-Progress -Activity "Searching logon events" -Status "Searching $($computer.Name)" -PercentComplete (($SearchedCount / $ComputersToSearch.Count) * 100)

    try {
        $events = Get-LogonEventsFromComputer -ComputerName $computer.Name -TargetUsername $Username -StartTime $StartTime
        if ($events.Count -gt 0) {
            $AllLogonEvents += $events
            Write-Log "Found $($events.Count) logon events on $($computer.Name)"
        }
    } catch {
        Write-Log "Error searching $($computer.Name): $($_.Exception.Message)" "ERROR"
        $ErrorCount++
    }
}

Write-Progress -Activity "Searching logon events" -Completed

# Analyze results
Write-Host "`n📊 SEARCH RESULTS" -ForegroundColor White
Write-Host "================================" -ForegroundColor Gray

if ($AllLogonEvents.Count -eq 0) {
    Write-Host "❌ No logon events found for user '$Username' in the last $MaxDaysBack days" -ForegroundColor Red
    Write-Log "No logon events found for user '$Username'" "WARNING"
} else {
    Write-Host "✅ Found $($AllLogonEvents.Count) logon events for user '$Username'" -ForegroundColor Green

    # Sort by logon time to find the most recent
    $SortedEvents = $AllLogonEvents | Sort-Object LogonTime -Descending
    $MostRecentLogon = $SortedEvents | Select-Object -First 1

    Write-Host "`n🎯 MOST RECENT LOGON:" -ForegroundColor Green
    Write-Host "Computer: $($MostRecentLogon.ComputerName)" -ForegroundColor White
    Write-Host "Logon Time: $($MostRecentLogon.LogonTime)" -ForegroundColor White
    Write-Host "Logon Type: $($MostRecentLogon.LogonTypeDescription)" -ForegroundColor White
    if ($MostRecentLogon.WorkstationName) {
        Write-Host "Workstation: $($MostRecentLogon.WorkstationName)" -ForegroundColor White
    }
    if ($MostRecentLogon.SourceIP -and $MostRecentLogon.SourceIP -ne "-" -and $MostRecentLogon.SourceIP -ne "127.0.0.1") {
        Write-Host "Source IP: $($MostRecentLogon.SourceIP)" -ForegroundColor White
    }

    Write-Log "Most recent logon: $($MostRecentLogon.ComputerName) at $($MostRecentLogon.LogonTime)" "SUCCESS"

    # Show detailed information if requested
    if ($Detailed -and $AllLogonEvents.Count -gt 1) {
        Write-Host "`n📋 ALL LOGON EVENTS:" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Gray

        foreach ($userLogEvent in $SortedEvents) {
            Write-Host "`n🔹 Logon Event:" -ForegroundColor Cyan
            Write-Host "   Computer: $($userLogEvent.ComputerName)" -ForegroundColor White
            Write-Host "   Time: $($userLogEvent.LogonTime)" -ForegroundColor Gray
            Write-Host "   Type: $($userLogEvent.LogonTypeDescription)" -ForegroundColor Gray
            if ($userLogEvent.WorkstationName) {
                Write-Host "   Workstation: $($userLogEvent.WorkstationName)" -ForegroundColor Gray
            }
            if ($logEvent.SourceIP -and $logEvent.SourceIP -ne "-" -and $logEvent.SourceIP -ne "127.0.0.1") {
                Write-Host "   Source IP: $($logEvent.SourceIP)" -ForegroundColor Gray
            }
        }
    }

    # Show summary by computer
    $ComputerSummary = $AllLogonEvents | Group-Object ComputerName | Sort-Object Count -Descending
    Write-Host "`n📈 LOGON SUMMARY BY COMPUTER:" -ForegroundColor Yellow
    Write-Host "================================" -ForegroundColor Gray
    foreach ($group in $ComputerSummary) {
        $latestOnComputer = $group.Group | Sort-Object LogonTime -Descending | Select-Object -First 1
        Write-Host "$($group.Name): $($group.Count) logons (latest: $($latestOnComputer.LogonTime))" -ForegroundColor White
    }
}

# Show search statistics
Write-Host "`n📊 SEARCH STATISTICS:" -ForegroundColor White
Write-Host "================================" -ForegroundColor Gray
Write-Host "Computers searched: $SearchedCount" -ForegroundColor White
Write-Host "Search errors: $ErrorCount" -ForegroundColor White
Write-Host "Total logon events found: $($AllLogonEvents.Count)" -ForegroundColor White
Write-Host "Search period: $MaxDaysBack days" -ForegroundColor White
Write-Host "Log file: $LogFile" -ForegroundColor Gray

# Export detailed results to CSV
if ($AllLogonEvents.Count -gt 0) {
    $CsvPath = Join-Path $PSScriptRoot "UserLogonEvents_$($Username)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $AllLogonEvents | Sort-Object LogonTime -Descending | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "📊 Detailed results exported to: $CsvPath" -ForegroundColor Gray
}

Write-Log "User last logon search completed"
