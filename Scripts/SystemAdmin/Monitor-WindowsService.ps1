<#
.SYNOPSIS
    Monitors and automatically restarts a Windows service if it's not running.

.DESCRIPTION
    This script checks the status of a specified Windows service and automatically starts it
    if it's not running. Includes logging, email notifications, and retry logic.

.PARAMETER ServiceName
    Name of the Windows service to monitor.

.PARAMETER MaxRetries
    Maximum number of restart attempts before giving up. Default is 3.

.PARAMETER RetryDelay
    Delay in seconds between restart attempts. Default is 30 seconds.

.PARAMETER LogPath
    Path for log file. If not specified, creates a log in the script directory.

.PARAMETER EmailNotification
    Enable email notifications for service events.

.PARAMETER SMTPServer
    SMTP server for email notifications.

.PARAMETER EmailFrom
    Sender email address.

.PARAMETER EmailTo
    Recipient email address(es).

.EXAMPLE
    .\Monitor-WindowsService.ps1 -ServiceName "SentrySuiteReviewService"

.EXAMPLE
    .\Monitor-WindowsService.ps1 -ServiceName "SentrySuiteReviewService" -EmailNotification -SMTPServer "smtp.company.com" -EmailFrom "monitoring@company.com" -EmailTo "admin@company.com"

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Administrative privileges for service management
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Windows service to monitor")]
    [string]$ServiceName,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of restart attempts")]
    [int]$MaxRetries = 3,

    [Parameter(Mandatory = $false, HelpMessage = "Delay in seconds between restart attempts")]
    [int]$RetryDelay = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Path for log file")]
    [string]$LogPath = "",

    [Parameter(Mandatory = $false, HelpMessage = "Enable email notifications")]
    [switch]$EmailNotification,

    [Parameter(Mandatory = $false, HelpMessage = "SMTP server for email notifications")]
    [string]$SMTPServer = "",

    [Parameter(Mandatory = $false, HelpMessage = "Sender email address")]
    [string]$EmailFrom = "",

    [Parameter(Mandatory = $false, HelpMessage = "Recipient email address(es)")]
    [string[]]$EmailTo = @()
)

# Set up logging
if ([string]::IsNullOrEmpty($LogPath)) {
    $LogPath = Join-Path $PSScriptRoot "ServiceMonitor_$($ServiceName)_$(Get-Date -Format 'yyyyMMdd').log"
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $LogEntry

    switch ($Level) {
        "ERROR" {
            Write-Host $Message -ForegroundColor Red
            if ($EmailNotification) { Send-AlertEmail -Subject "Service Error: $ServiceName" -Body $Message -Priority High }
        }
        "WARNING" {
            Write-Host $Message -ForegroundColor Yellow
            if ($EmailNotification) { Send-AlertEmail -Subject "Service Warning: $ServiceName" -Body $Message -Priority Normal }
        }
        "SUCCESS" {
            Write-Host $Message -ForegroundColor Green
        }
        default {
            Write-Host $Message
        }
    }
}

function Send-AlertEmail {
    param(
        [string]$Subject,
        [string]$Body,
        [string]$Priority = "Normal"
    )

    if (-not $EmailNotification -or [string]::IsNullOrEmpty($SMTPServer) -or [string]::IsNullOrEmpty($EmailFrom) -or $EmailTo.Count -eq 0) {
        return
    }

    try {
        $EmailBody = @"
Service Monitoring Alert

Computer: $env:COMPUTERNAME
Service: $ServiceName
Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Message: $Body

This is an automated message from the Service Monitor script.
"@

        Send-MailMessage -SmtpServer $SMTPServer -From $EmailFrom -To $EmailTo -Subject $Subject -Body $EmailBody -Priority $Priority
        Write-Log "Email notification sent successfully"
    } catch {
        Write-Log "Failed to send email notification: $($_.Exception.Message)" "ERROR"
    }
}

function Test-ServiceExists {
    param([string]$Name)
    try {
        Get-Service -Name $Name -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Start-ServiceWithRetry {
    param(
        [string]$Name,
        [int]$MaxAttempts,
        [int]$DelaySeconds
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Write-Log "Attempt $attempt of $MaxAttempts to start service '$Name'"
            Start-Service -Name $Name -ErrorAction Stop
            Start-Sleep -Seconds 5

            $service = Get-Service -Name $Name
            if ($service.Status -eq 'Running') {
                Write-Log "Service '$Name' started successfully on attempt $attempt" "SUCCESS"
                return $true
            } else {
                Write-Log "Service '$Name' did not start properly (Status: $($service.Status))" "WARNING"
            }
        } catch {
            Write-Log "Failed to start service '$Name' on attempt $attempt`: $($_.Exception.Message)" "ERROR"
        }

        if ($attempt -lt $MaxAttempts) {
            Write-Log "Waiting $DelaySeconds seconds before next attempt..."
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    return $false
}

# Main execution
Write-Log "Service monitoring started for '$ServiceName'"
Write-Log "Max retries: $MaxRetries, Retry delay: $RetryDelay seconds"
Write-Log "Running on computer: $env:COMPUTERNAME"

# Check if running with appropriate privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Warning: Script is not running with administrator privileges. Service start may fail." "WARNING"
}

# Validate service exists
if (-not (Test-ServiceExists -Name $ServiceName)) {
    Write-Log "Service '$ServiceName' was not found on this system" "ERROR"
    exit 1
}

# Get service information
try {
    $service = Get-Service -Name $ServiceName -ErrorAction Stop
    Write-Log "Service found: $($service.DisplayName) (Status: $($service.Status))"

    # Get additional service details
    $serviceDetails = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'"
    if ($serviceDetails) {
        Write-Log "Service details - StartMode: $($serviceDetails.StartMode), ProcessId: $($serviceDetails.ProcessId), Path: $($serviceDetails.PathName)"
    }

} catch {
    Write-Log "Error retrieving service information: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Check service status and start if necessary
if ($service.Status -eq 'Running') {
    Write-Log "Service '$ServiceName' is already running" "SUCCESS"

    # Send success notification if this is the first check
    if ($EmailNotification) {
        Send-AlertEmail -Subject "Service Status: $ServiceName is Running" -Body "Service '$ServiceName' is running normally on $env:COMPUTERNAME"
    }

    exit 0
} else {
    Write-Log "Service '$ServiceName' is not running (Status: $($service.Status))" "WARNING"

    # Attempt to start the service
    Write-Log "Attempting to start service '$ServiceName'..."
    $startResult = Start-ServiceWithRetry -Name $ServiceName -MaxAttempts $MaxRetries -DelaySeconds $RetryDelay

    if ($startResult) {
        Write-Log "Service '$ServiceName' has been started successfully" "SUCCESS"

        # Verify service is actually running
        Start-Sleep -Seconds 2
        $service.Refresh()
        if ($service.Status -eq 'Running') {
            Write-Log "Confirmed: Service '$ServiceName' is now running" "SUCCESS"
            exit 0
        } else {
            Write-Log "Warning: Service shows as started but status is $($service.Status)" "WARNING"
            exit 1
        }
    } else {
        Write-Log "Failed to start service '$ServiceName' after $MaxRetries attempts" "ERROR"

        # Get additional diagnostic information
        try {
            $eventLogs = Get-WinEvent -LogName System -MaxEvents 10 | Where-Object { $_.LevelDisplayName -eq "Error" -and $_.TimeCreated -gt (Get-Date).AddMinutes(-10) }
            if ($eventLogs) {
                Write-Log "Recent system errors found in Event Log (last 10 minutes):" "WARNING"
                foreach ($logEvent in $eventLogs) {
                    Write-Log "Event ID $($logEvent.Id): $($logEvent.LevelDisplayName) - $($logEvent.TimeCreated)" "WARNING"
                }
            }
        } catch {
            Write-Log "Could not retrieve recent event logs: $($_.Exception.Message)" "WARNING"
        }

        exit 1
    }
}

Write-Log "Service monitoring completed for '$ServiceName'"
