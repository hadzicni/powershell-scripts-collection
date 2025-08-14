<#
.SYNOPSIS
    Comprehensive network connectivity and diagnostic tool.

.DESCRIPTION
    This script performs various network tests including ping, port connectivity,
    DNS resolution, and network trace analysis. Useful for troubleshooting
    network connectivity issues and gathering network information.

.PARAMETER Target
    Target host(s) to test. Can be hostname, IP address, or array of targets.

.PARAMETER TestType
    Type of test to perform: All, Ping, Port, DNS, Trace, or Performance.

.PARAMETER Port
    Specific port(s) to test for port connectivity.

.PARAMETER Timeout
    Timeout in seconds for network tests. Default is 5 seconds.

.PARAMETER Count
    Number of ping packets to send. Default is 4.

.PARAMETER OutputFormat
    Output format: Console, CSV, JSON, or HTML.

.PARAMETER OutputFile
    Path to save results file.

.PARAMETER Detailed
    Include detailed diagnostic information.

.PARAMETER Continuous
    Run tests continuously until stopped.

.PARAMETER LogFile
    Path for log file.

.EXAMPLE
    .\Test-NetworkConnectivity.ps1 -Target "google.com"

.EXAMPLE
    .\Test-NetworkConnectivity.ps1 -Target @("server1", "server2") -TestType Port -Port @(80, 443, 3389)

.EXAMPLE
    .\Test-NetworkConnectivity.ps1 -Target "problematic-server" -TestType All -Detailed -OutputFormat HTML

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Network access, administrative privileges for some tests
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Target host(s) to test")]
    [string[]]$Target,

    [Parameter(Mandatory = $false, HelpMessage = "Type of network test")]
    [ValidateSet("All", "Ping", "Port", "DNS", "Trace", "Performance")]
    [string]$TestType = "All",

    [Parameter(Mandatory = $false, HelpMessage = "Port(s) to test")]
    [int[]]$Port = @(80, 443, 21, 22, 23, 25, 53, 110, 143, 993, 995, 3389, 5985, 5986),

    [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds")]
    [int]$Timeout = 5,

    [Parameter(Mandatory = $false, HelpMessage = "Number of ping packets")]
    [int]$Count = 4,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet("Console", "CSV", "JSON", "HTML")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false, HelpMessage = "Output file path")]
    [string]$OutputFile = "",

    [Parameter(Mandatory = $false, HelpMessage = "Include detailed information")]
    [switch]$Detailed,

    [Parameter(Mandatory = $false, HelpMessage = "Run continuously")]
    [switch]$Continuous,

    [Parameter(Mandatory = $false, HelpMessage = "Log file path")]
    [string]$LogFile = ""
)

# Set up logging
if ([string]::IsNullOrEmpty($LogFile)) {
    $LogFile = Join-Path $PSScriptRoot "NetworkTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
}

function Test-PingConnectivity {
    param(
        [string]$TargetHost,
        [int]$PingCount,
        [int]$TimeoutSeconds
    )

    Write-Host "🔍 Testing ping connectivity to $TargetHost..." -ForegroundColor Cyan

    try {
        $pingResults = Test-Connection -ComputerName $TargetHost -Count $PingCount -ErrorAction Stop

        $stats = $pingResults | Measure-Object ResponseTime -Average -Minimum -Maximum

        $result = [PSCustomObject]@{
            Target = $TargetHost
            TestType = "Ping"
            Status = "Success"
            PacketsSent = $PingCount
            PacketsReceived = $pingResults.Count
            PacketLoss = [math]::Round((($PingCount - $pingResults.Count) / $PingCount) * 100, 1)
            MinResponseTime = $stats.Minimum
            MaxResponseTime = $stats.Maximum
            AvgResponseTime = [math]::Round($stats.Average, 2)
            IPAddress = $pingResults[0].Address
            Details = "Ping successful"
            Timestamp = Get-Date
        }

        Write-Host "  ✅ Ping successful - Avg: $($result.AvgResponseTime)ms, Loss: $($result.PacketLoss)%" -ForegroundColor Green
        return $result

    } catch {
        $result = [PSCustomObject]@{
            Target = $TargetHost
            TestType = "Ping"
            Status = "Failed"
            PacketsSent = $PingCount
            PacketsReceived = 0
            PacketLoss = 100
            MinResponseTime = 0
            MaxResponseTime = 0
            AvgResponseTime = 0
            IPAddress = "N/A"
            Details = $_.Exception.Message
            Timestamp = Get-Date
        }

        Write-Host "  ❌ Ping failed: $($_.Exception.Message)" -ForegroundColor Red
        return $result
    }
}

function Test-PortConnectivity {
    param(
        [string]$TargetHost,
        [int[]]$Ports,
        [int]$TimeoutMs
    )

    Write-Host "🔍 Testing port connectivity to $TargetHost..." -ForegroundColor Cyan

    $results = @()

    foreach ($TestPort in $Ports) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($TargetHost, $TestPort, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutMs * 1000, $false)

            if ($wait) {
                $tcpClient.EndConnect($connect)
                $isOpen = $true
                $tcpClient.Close()
            } else {
                $isOpen = $false
            }

            $result = [PSCustomObject]@{
                Target = $TargetHost
                TestType = "Port"
                Port = $TestPort
                Status = if ($isOpen) { "Open" } else { "Closed/Filtered" }
                Service = Get-ServiceName -Port $TestPort
                Details = if ($isOpen) { "Port is open and accepting connections" } else { "Port is closed or filtered" }
                Timestamp = Get-Date
            }

            $color = if ($isOpen) { "Green" } else { "Red" }
            $symbol = if ($isOpen) { "✅" } else { "❌" }
            Write-Host "  $symbol Port $TestPort ($($result.Service)): $($result.Status)" -ForegroundColor $color

            $results += $result

        } catch {
            $result = [PSCustomObject]@{
                Target = $TargetHost
                TestType = "Port"
                Port = $TestPort
                Status = "Error"
                Service = Get-ServiceName -Port $TestPort
                Details = $_.Exception.Message
                Timestamp = Get-Date
            }

            Write-Host "  ❌ Port $TestPort - Error: $($_.Exception.Message)" -ForegroundColor Red
            $results += $result
        }
    }

    return $results
}

function Test-DNSResolution {
    param([string]$TargetHost)

    Write-Host "🔍 Testing DNS resolution for $TargetHost..." -ForegroundColor Cyan

    try {
        $dnsResults = Resolve-DnsName -Name $TargetHost -ErrorAction Stop

        $results = @()
        foreach ($record in $dnsResults) {
            $result = [PSCustomObject]@{
                Target = $TargetHost
                TestType = "DNS"
                RecordType = $record.Type
                IPAddress = $record.IPAddress
                Name = $record.Name
                TTL = $record.TTL
                Status = "Success"
                Details = "DNS resolution successful"
                Timestamp = Get-Date
            }
            $results += $result
        }

        Write-Host "  ✅ DNS resolution successful - Found $($results.Count) record(s)" -ForegroundColor Green
        return $results

    } catch {
        $result = [PSCustomObject]@{
            Target = $TargetHost
            TestType = "DNS"
            RecordType = "N/A"
            IPAddress = "N/A"
            Name = $TargetHost
            TTL = 0
            Status = "Failed"
            Details = $_.Exception.Message
            Timestamp = Get-Date
        }

        Write-Host "  ❌ DNS resolution failed: $($_.Exception.Message)" -ForegroundColor Red
        return $result
    }
}

function Test-TraceRoute {
    param([string]$TargetHost)

    Write-Host "🔍 Performing trace route to $TargetHost..." -ForegroundColor Cyan

    try {
        $traceResults = Test-NetConnection -ComputerName $TargetHost -TraceRoute -ErrorAction Stop

        $result = [PSCustomObject]@{
            Target = $TargetHost
            TestType = "TraceRoute"
            Status = if ($traceResults.PingSucceeded) { "Success" } else { "Failed" }
            HopCount = $traceResults.TraceRoute.Count
            TraceRoute = $traceResults.TraceRoute -join " -> "
            FinalDestination = $traceResults.RemoteAddress
            Details = "Trace route completed"
            Timestamp = Get-Date
        }

        Write-Host "  ✅ Trace route completed - $($result.HopCount) hops" -ForegroundColor Green
        if ($Detailed) {
            Write-Host "  Route: $($result.TraceRoute)" -ForegroundColor Gray
        }

        return $result

    } catch {
        $result = [PSCustomObject]@{
            Target = $TargetHost
            TestType = "TraceRoute"
            Status = "Failed"
            HopCount = 0
            TraceRoute = "N/A"
            FinalDestination = "N/A"
            Details = $_.Exception.Message
            Timestamp = Get-Date
        }

        Write-Host "  ❌ Trace route failed: $($_.Exception.Message)" -ForegroundColor Red
        return $result
    }
}

function Get-ServiceName {
    param([int]$Port)

    $commonPorts = @{
        21 = "FTP"
        22 = "SSH"
        23 = "Telnet"
        25 = "SMTP"
        53 = "DNS"
        80 = "HTTP"
        110 = "POP3"
        143 = "IMAP"
        443 = "HTTPS"
        993 = "IMAPS"
        995 = "POP3S"
        3389 = "RDP"
        5985 = "WinRM-HTTP"
        5986 = "WinRM-HTTPS"
    }

    return if ($commonPorts.ContainsKey($Port)) { $commonPorts[$Port] } else { "Unknown" }
}

function Export-Results {
    param(
        [object[]]$Results,
        [string]$Format,
        [string]$FilePath
    )

    switch ($Format) {
        "CSV" {
            $Results | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        }
        "JSON" {
            $Results | ConvertTo-Json -Depth 3 | Set-Content -Path $FilePath -Encoding UTF8
        }
        "HTML" {
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Network Connectivity Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .success { color: green; }
        .failed { color: red; }
        .header { background-color: #4CAF50; color: white; padding: 10px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Network Connectivity Test Results</h1>
        <p>Generated: $(Get-Date)</p>
    </div>
    $($Results | ConvertTo-Html -Fragment)
</body>
</html>
"@
            $html | Set-Content -Path $FilePath -Encoding UTF8
        }
    }
}

# Main execution
Write-Host "🌐 Network Connectivity Tester" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Gray

do {
    $AllResults = @()

    foreach ($TargetHost in $Target) {
        Write-Host "`n🎯 Testing connectivity to: $TargetHost" -ForegroundColor Yellow
        Write-Log "Starting network tests for $TargetHost"

        if ($TestType -in @("All", "Ping")) {
            $pingResult = Test-PingConnectivity -TargetHost $TargetHost -PingCount $Count -TimeoutSeconds $Timeout
            $AllResults += $pingResult
        }

        if ($TestType -in @("All", "DNS")) {
            $dnsResults = Test-DNSResolution -TargetHost $TargetHost
            $AllResults += $dnsResults
        }

        if ($TestType -in @("All", "Port")) {
            $portResults = Test-PortConnectivity -TargetHost $TargetHost -Ports $Port -TimeoutMs ($Timeout * 1000)
            $AllResults += $portResults
        }

        if ($TestType -in @("All", "Trace")) {
            $traceResult = Test-TraceRoute -TargetHost $TargetHost
            $AllResults += $traceResult
        }
    }

    # Display summary
    Write-Host "`n📊 TEST SUMMARY" -ForegroundColor White
    Write-Host "================" -ForegroundColor Gray

    $summary = $AllResults | Group-Object Status | Sort-Object Name
    foreach ($group in $summary) {
        $color = switch ($group.Name) {
            "Success" { "Green" }
            "Open" { "Green" }
            "Failed" { "Red" }
            "Closed/Filtered" { "Yellow" }
            default { "White" }
        }
        Write-Host "$($group.Name): $($group.Count) tests" -ForegroundColor $color
    }

    # Export results if requested
    if ($OutputFormat -ne "Console") {
        if ([string]::IsNullOrEmpty($OutputFile)) {
            $extension = $OutputFormat.ToLower()
            $OutputFile = Join-Path $PSScriptRoot "NetworkTestResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').$extension"
        }

        Export-Results -Results $AllResults -Format $OutputFormat -FilePath $OutputFile
        Write-Host "`n📁 Results exported to: $OutputFile" -ForegroundColor Green
    }

    if ($Continuous) {
        Write-Host "`n⏳ Waiting 60 seconds before next test cycle... (Press Ctrl+C to stop)" -ForegroundColor Gray
        Start-Sleep -Seconds 60
    }

} while ($Continuous)

Write-Host "`n✅ Network connectivity testing completed" -ForegroundColor Green
