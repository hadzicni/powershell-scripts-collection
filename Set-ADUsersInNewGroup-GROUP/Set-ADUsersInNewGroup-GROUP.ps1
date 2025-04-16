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

$quelleGruppenname = "Alle_Ressort_ICT"
$zielGruppenname = "ICT_B_BelegungsplanWeb_User"

$quelleGruppe = Get-ADGroup -Filter { Name -eq $quelleGruppenname }
$zielGruppe = Get-ADGroup -Filter { Name -eq $zielGruppenname }

if ($null -eq $quelleGruppe -or $null -eq $zielGruppe) {
    Write-Host "Eine der Gruppen wurde nicht gefunden. Stelle sicher, dass die Gruppen existieren." -ForegroundColor Red
    exit
}

$quelleGruppenMitglieder = Get-ADGroupMember -Identity $quelleGruppe.DistinguishedName
$zielGruppenMitglieder = Get-ADGroupMember -Identity $zielGruppe.DistinguishedName | Select-Object -ExpandProperty DistinguishedName

$hinzugefuegt = 0
$bereitsMitglied = 0
$log = @()

foreach ($mitglied in $quelleGruppenMitglieder) {
    if ($zielGruppenMitglieder -contains $mitglied.DistinguishedName) {
        $log += "🔹 Bereits Mitglied: $($mitglied.SamAccountName)"
        $bereitsMitglied++
    } else {
        try {
            Add-ADGroupMember -Identity $zielGruppe -Members $mitglied.DistinguishedName -ErrorAction Stop
            Write-Host "Mitglied $($mitglied.SamAccountName) wurde der Zielgruppe hinzugefügt." -ForegroundColor Green
            $log += "✅ Erfolgreich hinzugefügt: $($mitglied.SamAccountName)"
            $hinzugefuegt++
        } catch {
            Write-Host "Fehler beim Hinzufügen von $($mitglied.SamAccountName)." -ForegroundColor Red
            $log += "⚠️ Fehler: $($mitglied.SamAccountName)"
        }
    }
}

Write-Host "`n========= Abschlussbericht =========" -ForegroundColor White
Write-Host "Zielgruppe: $zielGruppenname" -ForegroundColor White
Write-Host "✔ Erfolgreich hinzugefügt: $hinzugefuegt" -ForegroundColor Green
Write-Host "🔹 Bereits in der Gruppe: $bereitsMitglied" -ForegroundColor Cyan
