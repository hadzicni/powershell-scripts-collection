<#
.SYNOPSIS
    Gets information about the currently logged-on user on a local or remote computer.

.DESCRIPTION
    This script retrieves detailed information about the currently logged-on user(s) on a specified computer.
    It can query local or remote systems and provides comprehensive user session information.

.PARAMETER ComputerName
    Name of the computer to query. Defaults to localhost.

.PARAMETER IncludeProcesses
    Include information about user processes.

.PARAMETER IncludeSessions
    Include detailed session information.

.PARAMETER Credential
    Credentials for accessing remote computers.

.EXAMPLE
    .\Get-LoggedOnUser.ps1

.EXAMPLE
    .\Get-LoggedOnUser.ps1 -ComputerName "SERVER01" -IncludeProcesses -IncludeSessions

.EXAMPLE
    .\Get-LoggedOnUser.ps1 -ComputerName "REMOTE-PC" -Credential (Get-Credential)

.NOTES
    Author: Nikola Hadzic
    Version: 2.0
    Date: 2025-08-14
    Requirements: Administrative privileges for remote queries
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Computer name to query")]
    [string]$ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false, HelpMessage = "Include user process information")]
    [switch]$IncludeProcesses,

    [Parameter(Mandatory = $false, HelpMessage = "Include detailed session information")]
    [switch]$IncludeSessions,

    [Parameter(Mandatory = $false, HelpMessage = "Credentials for remote access")]
    [System.Management.Automation.PSCredential]$Credential
)

function Write-ColoredOutput {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

function Get-UserSessionInfo {
    param(
        [string]$Computer,
        [System.Management.Automation.PSCredential]$Cred
    )

    try {
        $params = @{
            ComputerName = $Computer
            ErrorAction = 'Stop'
        }

        if ($Cred) {
            $params.Credential = $Cred
        }

        # Get logged on users using Win32_ComputerSystem
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem @params

        # Get session information using quser command
        $sessionInfo = @()
        try {
            if ($Computer -eq $env:COMPUTERNAME -or $Computer -eq "localhost" -or $Computer -eq ".") {
                $quserOutput = quser.exe 2>$null
            } else {
                $quserOutput = Invoke-Command -ComputerName $Computer -Credential $Cred -ScriptBlock { quser.exe 2>$null } -ErrorAction SilentlyContinue
            }

            if ($quserOutput) {
                # Parse quser output
                $sessions = $quserOutput | Select-Object -Skip 1 | ForEach-Object {
                    $line = $_.Trim() -replace '\s+', ' '
                    $parts = $line.Split(' ')

                    if ($parts.Count -ge 5) {
                        [PSCustomObject]@{
                            Username = $parts[0]
                            SessionName = if ($parts[1] -eq '>') { "console" } else { $parts[1] }
                            SessionId = if ($parts[1] -eq '>') { $parts[2] } else { $parts[2] }
                            State = if ($parts[1] -eq '>') { $parts[3] } else { $parts[3] }
                            IdleTime = if ($parts[1] -eq '>') { $parts[4] } else { $parts[4] }
                            LogonTime = if ($parts[1] -eq '>') { ($parts[5..($parts.Length-1)] -join ' ') } else { ($parts[5..($parts.Length-1)] -join ' ') }
                        }
                    }
                }
                $sessionInfo = $sessions
            }
        } catch {
            Write-Warning "Could not retrieve session information using quser: $($_.Exception.Message)"
        }

        # Get process information if requested
        $userProcesses = @()
        if ($IncludeProcesses) {
            try {
                $processes = Get-WmiObject -Class Win32_Process @params | Where-Object { $_.GetOwner().User -and $_.GetOwner().User -ne "SYSTEM" }
                $userProcesses = $processes | Group-Object { $_.GetOwner().User } | ForEach-Object {
                    [PSCustomObject]@{
                        Username = $_.Name
                        ProcessCount = $_.Count
                        TopProcesses = ($_.Group | Sort-Object WorkingSetSize -Descending | Select-Object -First 5 | ForEach-Object { "$($_.Name) ($($_.ProcessId))" }) -join ', '
                    }
                }
            } catch {
                Write-Warning "Could not retrieve process information: $($_.Exception.Message)"
            }
        }

        return @{
            ComputerSystem = $computerSystem
            Sessions = $sessionInfo
            UserProcesses = $userProcesses
        }

    } catch {
        throw "Failed to get user session information: $($_.Exception.Message)"
    }
}

function Format-IdleTime {
    param([string]$IdleTime)

    if ([string]::IsNullOrEmpty($IdleTime) -or $IdleTime -eq "." -or $IdleTime -eq "none") {
        return "Active"
    }

    return $IdleTime
}

# Main execution
Write-ColoredOutput "🔍 Querying logged-on user information..." "Cyan"
Write-ColoredOutput "Computer: $ComputerName" "Gray"
Write-ColoredOutput "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Gray"

try {
    # Test connection first
    if ($ComputerName -ne $env:COMPUTERNAME -and $ComputerName -ne "localhost" -and $ComputerName -ne ".") {
        Write-ColoredOutput "`n🌐 Testing connection to $ComputerName..." "Yellow"

        $pingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
        if (-not $pingResult) {
            Write-ColoredOutput "❌ Cannot reach $ComputerName" "Red"
            exit 1
        }
        Write-ColoredOutput "✅ Connection successful" "Green"
    }

    # Get user session information
    $sessionData = Get-UserSessionInfo -Computer $ComputerName -Cred $Credential

    # Display computer system information
    if ($sessionData.ComputerSystem) {
        Write-ColoredOutput "`n💻 COMPUTER INFORMATION" "White"
        Write-ColoredOutput "================================" "Gray"
        Write-ColoredOutput "Computer Name: $($sessionData.ComputerSystem.Name)" "White"
        Write-ColoredOutput "Domain: $($sessionData.ComputerSystem.Domain)" "White"
        Write-ColoredOutput "Model: $($sessionData.ComputerSystem.Model)" "White"
        Write-ColoredOutput "Total Physical Memory: $([math]::Round($sessionData.ComputerSystem.TotalPhysicalMemory / 1GB, 2)) GB" "White"

        if ($sessionData.ComputerSystem.UserName) {
            Write-ColoredOutput "Primary User: $($sessionData.ComputerSystem.UserName)" "Green"
        } else {
            Write-ColoredOutput "Primary User: No user currently logged on" "Yellow"
        }
    }

    # Display session information
    if ($sessionData.Sessions -and $sessionData.Sessions.Count -gt 0) {
        Write-ColoredOutput "`n👤 USER SESSIONS" "White"
        Write-ColoredOutput "================================" "Gray"

        foreach ($session in $sessionData.Sessions) {
            Write-ColoredOutput "`n🔹 Session Details:" "Cyan"
            Write-ColoredOutput "   Username: $($session.Username)" "White"
            Write-ColoredOutput "   Session Type: $($session.SessionName)" "Gray"
            Write-ColoredOutput "   Session ID: $($session.SessionId)" "Gray"
            Write-ColoredOutput "   State: $($session.State)" "Gray"
            Write-ColoredOutput "   Idle Time: $(Format-IdleTime $session.IdleTime)" "Gray"
            Write-ColoredOutput "   Logon Time: $($session.LogonTime)" "Gray"
        }

        # Summary
        $activeUsers = $sessionData.Sessions | Where-Object { $_.State -eq "Active" }
        $disconnectedUsers = $sessionData.Sessions | Where-Object { $_.State -eq "Disc" }

        Write-ColoredOutput "`n📊 SESSION SUMMARY" "White"
        Write-ColoredOutput "================================" "Gray"
        Write-ColoredOutput "Total Sessions: $($sessionData.Sessions.Count)" "White"
        Write-ColoredOutput "Active Sessions: $($activeUsers.Count)" "Green"
        Write-ColoredOutput "Disconnected Sessions: $($disconnectedUsers.Count)" "Yellow"

    } elseif ($IncludeSessions) {
        Write-ColoredOutput "`n👤 USER SESSIONS" "White"
        Write-ColoredOutput "================================" "Gray"
        Write-ColoredOutput "No active user sessions found" "Yellow"
    }

    # Display process information if requested
    if ($IncludeProcesses -and $sessionData.UserProcesses -and $sessionData.UserProcesses.Count -gt 0) {
        Write-ColoredOutput "`n⚙️  USER PROCESSES" "White"
        Write-ColoredOutput "================================" "Gray"

        foreach ($userProc in $sessionData.UserProcesses) {
            Write-ColoredOutput "`n🔹 User: $($userProc.Username)" "Cyan"
            Write-ColoredOutput "   Process Count: $($userProc.ProcessCount)" "White"
            Write-ColoredOutput "   Top Processes: $($userProc.TopProcesses)" "Gray"
        }
    }

    # Additional system information
    Write-ColoredOutput "`n🔧 ADDITIONAL INFORMATION" "White"
    Write-ColoredOutput "================================" "Gray"

    try {
        $params = @{
            ComputerName = $ComputerName
            ErrorAction = 'Stop'
        }
        if ($Credential) { $params.Credential = $Credential }

        $os = Get-WmiObject -Class Win32_OperatingSystem @params
        Write-ColoredOutput "Operating System: $($os.Caption)" "White"
        Write-ColoredOutput "OS Version: $($os.Version)" "Gray"
        Write-ColoredOutput "Last Boot Time: $($os.ConvertToDateTime($os.LastBootUpTime))" "Gray"
        Write-ColoredOutput "System Uptime: $((Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime))" "Gray"

        # Get network information
        $network = Get-WmiObject -Class Win32_NetworkAdapterConfiguration @params | Where-Object { $_.IPEnabled -eq $true }
        if ($network) {
            Write-ColoredOutput "IP Address(es): $($network.IPAddress -join ', ')" "Gray"
        }

    } catch {
        Write-Warning "Could not retrieve additional system information: $($_.Exception.Message)"
    }

    Write-ColoredOutput "`n✅ Query completed successfully" "Green"

} catch {
    Write-ColoredOutput "`n❌ Error occurred while querying user information:" "Red"
    Write-ColoredOutput $_.Exception.Message "Red"
    exit 1
}
