<#
.SYNOPSIS
Dieses Skript fügt Benutzer zu einer neuen Active Directory (AD)-Gruppe hinzu, basierend auf den Mitgliedern einer Quellgruppe.

.DESCRIPTION
Das Skript liest den Namen einer Quellgruppe und einer Zielgruppe aus und fügt alle Mitglieder der Quellgruppe zur Zielgruppe hinzu.
Das Skript überprüft, ob beide Gruppen existieren, bevor es fortfährt.

.PARAMETER $quelleGruppenname
Der Name der Quellgruppe, deren Mitglieder hinzugefügt werden sollen.

.PARAMETER $zielGruppenname
Der Name der Zielgruppe, zu der die Mitglieder hinzugefügt werden.

.EXAMPLE
Führen Sie das Skript aus und geben Sie die Namen der Quell- und Zielgruppen ein, um Mitglieder von einer Gruppe in eine andere zu verschieben.

.NOTES
Author: Nikola Hadzic
Version: 1.0
Datum: 2025-01-14

#>

# Parameter-Eingabe
$quelleGruppenname = Read-Host "Geben Sie den Namen der Quellgruppe ein"
$zielGruppenname = Read-Host "Geben Sie den Namen der Zielgruppe ein"

# Abrufen der Gruppenobjekte
$quelleGruppe = Get-ADGroup -Filter { Name -eq $quelleGruppenname }
$zielGruppe = Get-ADGroup -Filter { Name -eq $zielGruppenname }

# Überprüfen, ob Gruppen existieren
if ($null -eq $quelleGruppe -or $null -eq $zielGruppe) {
    Write-Host "Eine der Gruppen wurde nicht gefunden. Stelle sicher, dass die Gruppen existieren."
    exit
}

# Abrufen der Mitglieder der Quellgruppe
$quelleGruppenMitglieder = Get-ADGroupMember -Identity $quelleGruppe.DistinguishedName

# Hinzufügen der Mitglieder zur Zielgruppe
foreach ($mitglied in $quelleGruppenMitglieder) {
    Add-ADGroupMember -Identity $zielGruppe -Members $mitglied.DistinguishedName
    Write-Host "Mitglied $($mitglied.SamAccountName) wurde der Zielgruppe hinzugefügt."
}

# Abschlussmeldung
Write-Host
Write-Host "Alle Mitglieder wurden der anderen Gruppe hinzugefügt."
Write-Host "Die Zielgruppe enthält nun alle Mitglieder der Quellgruppe."
Write-Host "Die Mitglieder der Quellgruppe wurden nicht gelöscht."
Write-Host "Operation completed successfully."
