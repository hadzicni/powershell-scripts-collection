<#
.SYNOPSIS
Dieses Skript exportiert alle Benutzer einer Active Directory (AD)-Gruppe in eine Excel-Datei.

.DESCRIPTION
Das Skript fragt den Namen einer AD-Gruppe und den Pfad für die Excel-Datei ab, ruft alle Mitglieder der Gruppe ab, filtert die Benutzer und exportiert deren DisplayName, SamAccountName und EmailAddress in die angegebene Excel-Datei.

.PARAMETER $adGroup
Der Name der AD-Gruppe, deren Mitglieder exportiert werden sollen.

.PARAMETER $excelFilePath
Der Pfad, an dem die Excel-Datei gespeichert werden soll.

.EXAMPLE
Führen Sie das Skript aus, um alle Benutzer einer angegebenen Gruppe in eine Excel-Datei zu exportieren und den Speicherort anzugeben:
.\Export-ADGroupMembers.ps1

.NOTES
Author: Nikola Hadzic
Version: 1.0
Datum: 2025-01-14

#>

# Nach der Zielgruppe fragen
$adGroup = Read-Host "Geben Sie den Namen der AD-Gruppe ein, deren Mitglieder exportiert werden sollen"

# Nach dem Pfad für die Excel-Datei fragen
$excelFilePath = Read-Host "Geben Sie den Pfad an, an dem die Excel-Datei gespeichert werden soll (drücken Sie Enter, um den Standardpfad zu verwenden)"

# Wenn kein Pfad angegeben wurde, Standardpfad im aktuellen Verzeichnis setzen
if (-not $excelFilePath) {
    $scriptDirectory = $PSScriptRoot
    if (-not $scriptDirectory) {
        $scriptDirectory = Get-Location
    }
    $excelFilePath = Join-Path -Path $scriptDirectory -ChildPath "$adGroup.xlsx"
}

Write-Host "Excel-Datei wird gespeichert unter: $excelFilePath"

# Versuch, Mitglieder der AD-Gruppe abzurufen
try {
    $groupMembers = Get-ADGroupMember -Identity $adGroup -Recursive | Where-Object { $_.objectClass -eq "user" }
}
catch {
    Write-Host "Fehler beim Abrufen der Mitglieder der Gruppe '$adGroup'. Stellen Sie sicher, dass die Gruppe existiert und der Name korrekt ist." -ForegroundColor Red
    return
}

# Benutzerinformationen sammeln
$userList = @()

foreach ($member in $groupMembers) {
    $user = Get-ADUser -Identity $member.SamAccountName -Properties DisplayName, EmailAddress, SamAccountName
    $userList += New-Object PSObject -property @{
        DisplayName    = $user.DisplayName
        SamAccountName = $user.SamAccountName
        EmailAddress   = $user.EmailAddress
    }
}

# Exportieren der Benutzerinformationen in eine Excel-Datei
$userList | Export-Excel -Path $excelFilePath -AutoSize -Title "AD Users for $adGroup" -Show

Write-Host "Die Benutzer wurden erfolgreich in die Excel-Datei exportiert: $excelFilePath"
