<#
.SYNOPSIS
Dieses Skript liest das Gerät aus, auf dem ein Benutzer zuletzt eingeloggt war.

.DESCRIPTION
Das Skript fragt nach einem Benutzernamen und durchsucht dann alle Domain-Computer, um das letzte Logon-Ereignis für diesen Benutzer zu ermitteln. Es zeigt das Gerät an, auf dem der Benutzer zuletzt eingeloggt war, oder gibt eine entsprechende Nachricht aus, wenn kein Logon gefunden wurde.

.PARAMETER $Username
Der Benutzername des Benutzers, dessen letztes Logon-Gerät ermittelt werden soll.

.EXAMPLE
Führen Sie das Skript aus und geben Sie einen Benutzernamen ein, um das letzte Gerät zu ermitteln, auf dem der Benutzer eingeloggt war:
.\Get-UserDevice.ps1 -Username "johndoe"

.NOTES
Author: Nikola Hadzic
Version: 1.0
Datum: 2025-01-14

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [string]$Username
)

# Importieren des Active Directory Moduls
Import-Module ActiveDirectory -ErrorAction Stop

try {
    # Abrufen des AD-Benutzers
    $user = Get-ADUser -Identity $Username -Properties LastLogonTimestamp

    if (-not $user) {
        Write-Host "Benutzer $Username wurde nicht im Active Directory gefunden." -ForegroundColor Red
        return
    }

    # Abrufen aller Domain-Computer
    $computers = Get-ADComputer -Filter * -Property LastLogonTimestamp

    # Initialisieren der Variablen für das letzte Logon
    $mostRecentLogon = $null
    $mostRecentComputer = $null

    foreach ($computer in $computers) {
        try {
            # Überprüfen der Benutzer-Logon-Ereignisse auf dem Computer
            $logonEvents = Get-WinEvent -LogName Security -ComputerName $computer.Name -FilterHashtable @{Id = 4624 } -ErrorAction SilentlyContinue |
            Where-Object { $_.Properties[5].Value -eq $Username }

            foreach ($event in $logonEvents) {
                if (-not $mostRecentLogon -or $event.TimeCreated -gt $mostRecentLogon) {
                    $mostRecentLogon = $event.TimeCreated
                    $mostRecentComputer = $computer.Name
                }
            }
        }
        catch {
            Write-Host "Konnte auf die Protokolle von $($computer.Name) nicht zugreifen: $_" -ForegroundColor Yellow
        }
    }

    if ($mostRecentComputer) {
        Write-Host "Das letzte Logon-Gerät für Benutzer $Username ist: $mostRecentComputer" -ForegroundColor Green
    }
    else {
        Write-Host "Kein kürzliches Logon für Benutzer $Username gefunden." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Ein Fehler ist aufgetreten: $_" -ForegroundColor Red
}
