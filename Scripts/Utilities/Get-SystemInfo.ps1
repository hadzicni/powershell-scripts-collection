<#
.SYNOPSIS
    Comprehensive system information collector for Windows computers.

.DESCRIPTION
    This script collects detailed system information including hardware, operating system,
    network configuration, storage, and optional components like software and services.
    Supports both local and remote computer analysis with proper credential handling.

.PARAMETER ComputerName
    Target computer name or IP address. Default is localhost.

.PARAMETER Credential
    PSCredential object for authenticating to remote computers.

.PARAMETER IncludeStorage
    Include detailed storage/disk information.

.PARAMETER IncludeNetworking
    Include network adapter configuration details.

.PARAMETER IncludeSoftware
    Include installed software inventory (WARNING: Can be slow).

.PARAMETER IncludeServices
    Include Windows services information.

.PARAMETER IncludeEventLogs
    Include recent critical/error events from System log.

.PARAMETER IncludePerformance
    Include basic performance metrics.

.PARAMETER OutputFormat
    Output format: Console, HTML, JSON, or CSV.

.PARAMETER OutputPath
    File path for exported reports (HTML, JSON, CSV formats).

.EXAMPLE
    .\Get-SystemInfo.ps1

.EXAMPLE
    .\Get-SystemInfo.ps1 -ComputerName "SERVER01" -IncludeStorage -IncludeNetworking

.EXAMPLE
    .\Get-SystemInfo.ps1 -OutputFormat HTML -OutputPath "C:\Reports\SystemInfo.html"

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requires: PowerShell 3.0+, WMI access to target computers
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Target computer name or IP address")]
    [string]$ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false, HelpMessage = "Credentials for remote computer access")]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false, HelpMessage = "Include storage information")]
    [switch]$IncludeStorage,

    [Parameter(Mandatory = $false, HelpMessage = "Include networking information")]
    [switch]$IncludeNetworking,

    [Parameter(Mandatory = $false, HelpMessage = "Include software inventory")]
    [switch]$IncludeSoftware,

    [Parameter(Mandatory = $false, HelpMessage = "Include services information")]
    [switch]$IncludeServices,

    [Parameter(Mandatory = $false, HelpMessage = "Include event log information")]
    [switch]$IncludeEventLogs,

    [Parameter(Mandatory = $false, HelpMessage = "Include performance metrics")]
    [switch]$IncludePerformance,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet("Console", "HTML", "JSON", "CSV")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false, HelpMessage = "Output file path")]
    [string]$OutputPath
)

$result = Get-ComputerSystemInfo -ComputerName $ComputerName -Cred $Credential

function Get-ComputerSystemInfo {
    param(
        [string]$Computer,
        [System.Management.Automation.PSCredential]$Cred
    )

    $params = @{
        ComputerName = $Computer
        ErrorAction  = 'Stop'
    }
    if ($Cred) { $params.Credential = $Cred }

    try {
        Write-Host "🔍 Gathering system information from $Computer..." -ForegroundColor Cyan

        $computerSystem  = Get-WmiObject -Class Win32_ComputerSystem @params
        $operatingSystem = Get-WmiObject -Class Win32_OperatingSystem @params
        $processor       = Get-WmiObject -Class Win32_Processor @params | Select-Object -First 1
        $bios            = Get-WmiObject -Class Win32_BIOS @params
        $motherboard     = Get-WmiObject -Class Win32_BaseBoard @params
        $physicalMemory  = Get-WmiObject -Class Win32_PhysicalMemory @params
        $totalRAM        = ($physicalMemory | Measure-Object Capacity -Sum).Sum

        $systemInfo = [PSCustomObject]@{
            ComputerName = $Computer
            Domain = $computerSystem.Domain
            Workgroup = $computerSystem.Workgroup
            Manufacturer = $computerSystem.Manufacturer
            Model = $computerSystem.Model
            SystemType = $computerSystem.SystemType
            TotalPhysicalMemory = [math]::Round($totalRAM / 1GB, 2)
            NumberOfProcessors = $computerSystem.NumberOfProcessors
            NumberOfLogicalProcessors = $computerSystem.NumberOfLogicalProcessors
            OSName = $operatingSystem.Caption
            OSVersion = $operatingSystem.Version
            OSBuild = $operatingSystem.BuildNumber
            OSArchitecture = $operatingSystem.OSArchitecture
            ServicePack = $operatingSystem.ServicePackMajorVersion
            InstallDate = $operatingSystem.ConvertToDateTime($operatingSystem.InstallDate)
            LastBootUpTime = $operatingSystem.ConvertToDateTime($operatingSystem.LastBootUpTime)
            WindowsDirectory = $operatingSystem.WindowsDirectory
            SystemDirectory = $operatingSystem.SystemDirectory
            ProcessorName = $processor.Name
            ProcessorManufacturer = $processor.Manufacturer
            ProcessorArchitecture = $processor.Architecture
            ProcessorCores = $processor.NumberOfCores
            ProcessorLogicalProcessors = $processor.NumberOfLogicalProcessors
            ProcessorMaxClockSpeed = $processor.MaxClockSpeed
            BIOSManufacturer = $bios.Manufacturer
            BIOSVersion = $bios.Version
            BIOSReleaseDate = if ($bios.ReleaseDate) { $bios.ConvertToDateTime($bios.ReleaseDate) } else { "N/A" }
            MotherboardManufacturer = $motherboard.Manufacturer
            MotherboardProduct = $motherboard.Product
            MotherboardVersion = $motherboard.Version
            ReportGenerated = Get-Date
            UptimeDays = [math]::Round(((Get-Date) - $operatingSystem.ConvertToDateTime($operatingSystem.LastBootUpTime)).TotalDays, 2)
        }

        if ($IncludeStorage) {
            $systemInfo | Add-Member -NotePropertyName "StorageInfo" -NotePropertyValue (Get-StorageInfo -ComputerName $Computer -Credential $Cred)
        }
        if ($IncludeNetworking) {
            $systemInfo | Add-Member -NotePropertyName "NetworkInfo" -NotePropertyValue (Get-NetworkInfo -ComputerName $Computer -Credential $Cred)
        }
        if ($IncludeSoftware) {
            $systemInfo | Add-Member -NotePropertyName "SoftwareInfo" -NotePropertyValue (Get-SoftwareInfo -ComputerName $Computer -Credential $Cred)
        }
        if ($IncludeServices) {
            $systemInfo | Add-Member -NotePropertyName "ServicesInfo" -NotePropertyValue (Get-ServicesInfo -ComputerName $Computer -Credential $Cred)
        }
        if ($IncludeEventLogs) {
            $systemInfo | Add-Member -NotePropertyName "EventLogInfo" -NotePropertyValue (Get-EventLogInfo -ComputerName $Computer -Credential $Cred)
        }
        if ($IncludePerformance) {
            $systemInfo | Add-Member -NotePropertyName "PerformanceInfo" -NotePropertyValue (Get-PerformanceInfo -ComputerName $Computer -Credential $Cred)
        }

        return $systemInfo
    } catch {
        Write-Error "❌ Failed to get system information from $Computer`: $($_.Exception.Message)"
        return $null
    }
}


function Get-StorageInfo {
    param(
        [string]$ComputerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    try {
        $params = @{ ComputerName = $ComputerName; ErrorAction = 'Stop' }
        if ($Credential) { $params.Credential = $Credential }

        $logicalDisks = Get-WmiObject -Class Win32_LogicalDisk @params | Where-Object { $_.DriveType -eq 3 }

        $storageInfo = foreach ($disk in $logicalDisks) {
            [PSCustomObject]@{
                Drive = $disk.DeviceID
                Label = $disk.VolumeName
                FileSystem = $disk.FileSystem
                SizeGB = [math]::Round($disk.Size / 1GB, 2)
                FreeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                UsedSpaceGB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
                PercentFree = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
            }
        }

        return $storageInfo
    } catch {
        return "Error retrieving storage information: $($_.Exception.Message)"
    }
}

function Get-NetworkInfo {
    param(
        [string]$ComputerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    try {
        $params = @{ ComputerName = $ComputerName; ErrorAction = 'Stop' }
        if ($Credential) { $params.Credential = $Credential }

        $adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration @params | Where-Object { $_.IPEnabled -eq $true }

        $networkInfo = foreach ($adapter in $adapters) {
            [PSCustomObject]@{
                Description = $adapter.Description
                MACAddress = $adapter.MACAddress
                IPAddress = $adapter.IPAddress -join '; '
                SubnetMask = $adapter.IPSubnet -join '; '
                DefaultGateway = $adapter.DefaultIPGateway -join '; '
                DNSServers = $adapter.DNSServerSearchOrder -join '; '
                DHCPEnabled = $adapter.DHCPEnabled
                DHCPServer = $adapter.DHCPServer
            }
        }

        return $networkInfo
    } catch {
        return "Error retrieving network information: $($_.Exception.Message)"
    }
}

function Get-SoftwareInfo {
    param(
        [string]$ComputerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    try {
        $params = @{ ComputerName = $ComputerName; ErrorAction = 'Stop' }
        if ($Credential) { $params.Credential = $Credential }

        # Get installed programs from registry
        $software = Get-WmiObject -Class Win32_Product @params |
                   Select-Object Name, Version, Vendor, InstallDate |
                   Sort-Object Name

        return $software
    } catch {
        return "Error retrieving software information: $($_.Exception.Message)"
    }
}

function Get-ServicesInfo {
    param(
        [string]$ComputerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    try {
        $params = @{ ComputerName = $ComputerName; ErrorAction = 'Stop' }
        if ($Credential) { $params.Credential = $Credential }

        $services = Get-WmiObject -Class Win32_Service @params |
                   Select-Object Name, DisplayName, State, StartMode, StartName |
                   Sort-Object DisplayName

        return $services
    } catch {
        return "Error retrieving services information: $($_.Exception.Message)"
    }
}

function Get-EventLogInfo {
    param(
        [string]$ComputerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    try {
        $params = @{ ComputerName = $ComputerName; ErrorAction = 'Stop' }
        if ($Credential) { $params.Credential = $Credential }

        $systemEvents = Get-WinEvent -LogName System @params -MaxEvents 50 |
                       Where-Object { $_.LevelDisplayName -in @("Critical", "Error") } |
                       Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
                       Sort-Object TimeCreated -Descending

        return $systemEvents
    } catch {
        return "Error retrieving event log information: $($_.Exception.Message)"
    }
}

function Get-PerformanceInfo {
    param(
        [string]$ComputerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    try {
        $params = @{ ComputerName = $ComputerName; ErrorAction = 'Stop' }
        if ($Credential) { $params.Credential = $Credential }

        # Get performance counters
        $perfData = [PSCustomObject]@{
            CPUUsage = "N/A"
            MemoryUsage = "N/A"
            ProcessCount = (Get-WmiObject -Class Win32_Process @params | Measure-Object).Count
            ServiceCount = (Get-WmiObject -Class Win32_Service @params | Measure-Object).Count
        }

        return $perfData
    } catch {
        return "Error retrieving performance information: $($_.Exception.Message)"
    }
}

function Export-ToHTML {
    param($SystemInfo, $FilePath)

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Information Report - $($SystemInfo.ComputerName)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; margin-bottom: 20px; }
        .section { margin-bottom: 20px; }
        .section h2 { color: #2c3e50; border-bottom: 2px solid #3498db; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .value { font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>System Information Report</h1>
        <p>Computer: $($SystemInfo.ComputerName)</p>
        <p>Generated: $($SystemInfo.ReportGenerated)</p>
    </div>
"@

    # Add sections to HTML
    $html += "<div class='section'><h2>System Overview</h2><table>"
    $html += "<tr><th>Property</th><th>Value</th></tr>"

    $SystemInfo.PSObject.Properties | Where-Object { $_.Name -notlike "*Info" } | ForEach-Object {
        $html += "<tr><td>$($_.Name)</td><td class='value'>$($_.Value)</td></tr>"
    }

    $html += "</table></div>"
    $html += "</body></html>"

    $html | Set-Content -Path $FilePath -Encoding UTF8
}

# Main execution
try {
    Write-Host "🖥️  System Information Collector" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Gray

    # Collect system information
    $result = Get-ComputerSystemInfo -Computer $ComputerName -Cred $Credential

    if (-not $result) {
        Write-Error "Failed to collect system information."
        exit 1
    }

    # Output based on format
    switch ($OutputFormat) {
        "Console" {
            Write-Host "`n📋 SYSTEM INFORMATION REPORT" -ForegroundColor Green
            Write-Host "============================" -ForegroundColor Gray

            $result | Format-List | Out-Host
        }

        "HTML" {
            if (-not $OutputPath) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "SystemInfo_$($ComputerName)_$timestamp.html"
            }

            Export-ToHTML -SystemInfo $result -FilePath $OutputPath
            Write-Host "📄 HTML report exported to: $OutputPath" -ForegroundColor Green
        }

        "JSON" {
            if (-not $OutputPath) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "SystemInfo_$($ComputerName)_$timestamp.json"
            }

            $result | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
            Write-Host "📄 JSON report exported to: $OutputPath" -ForegroundColor Green
        }

        "CSV" {
            if (-not $OutputPath) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $OutputPath = "SystemInfo_$($ComputerName)_$timestamp.csv"
            }

            $result | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            Write-Host "📄 CSV report exported to: $OutputPath" -ForegroundColor Green
        }
    }

    Write-Host "`n✅ System information collection completed successfully!" -ForegroundColor Green

} catch {
    Write-Error "❌ Script execution failed: $($_.Exception.Message)"
    exit 1
}
