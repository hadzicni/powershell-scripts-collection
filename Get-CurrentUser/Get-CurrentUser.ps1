<#
.SYNOPSIS
Dieses Skript liest den derzeit eingeloggten Benutzer eines angegebenen Hosts aus.

.DESCRIPTION
Das Skript fragt den Benutzernamen des Hosts ab und gibt den aktuell angemeldeten Benutzer auf diesem Host aus. Wenn kein Benutzer angemeldet ist, wird eine entsprechende Nachricht angezeigt.

.PARAMETER $ComputerName
Der Name des Computers, von dem der Benutzer abgerufen werden soll. Dies kann ein Remote-Computername oder `localhost` sein.

.EXAMPLE
Führen Sie das Skript aus und geben Sie den Computernamen ein, um den derzeit angemeldeten Benutzer zu ermitteln:
.\Get-LoggedInUser.ps1

.NOTES
Author: Nikola Hadzic
Version: 1.0
Datum: 2025-01-14

#>

# Parameter-Eingabe
$ComputerName = Read-Host "Geben Sie den Computernamen ein (z. B. localhost oder NB549813.ms.uhbs.ch)"

# Abrufen des aktuell angemeldeten Benutzers
try {
    $user = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName | Select-Object -ExpandProperty UserName

    if ($user) {
        Write-Output "Aktuell angemeldeter Benutzer auf ${ComputerName}: ${user}"
    }
    else {
        Write-Output "Kein Benutzer ist aktuell auf $ComputerName angemeldet."
    }
}
catch {
    Write-Output "Fehler beim Abrufen des Benutzers von ${ComputerName}: $(${_})"
}
