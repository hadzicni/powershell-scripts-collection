<#
.SYNOPSIS
Dieses Skript fügt Benutzer aus einer TXT-Datei zu einer Active Directory (AD)-Gruppe hinzu.

.DESCRIPTION
Das Skript liest Benutzernamen aus einer Textdatei ein und fügt sie in eine angegebene AD-Gruppe ein.
Es überprüft, ob die Benutzer existieren und ob sie bereits Mitglieder der Gruppe sind.
Am Ende wird ein Bericht ausgegeben.

.PARAMETER $benutzerDatei
Pfad zur TXT-Datei mit den Benutzernamen (ein Benutzername pro Zeile).

.PARAMETER $zielGruppenname
Der Name der Zielgruppe, zu der die Benutzer hinzugefügt werden sollen.

.EXAMPLE
Führen Sie das Skript aus, geben Sie den Pfad zur Datei an und den Namen der AD-Gruppe.

.NOTES
Author: Nikola Hadzic
Version: 1.0
Datum: 2025-02-17
#>

# Eingabe der Datei mit den Benutzernamen
$benutzerDatei = "C:\Users\hadzicni\Documents\Projects\AA--PowerShell Scripts\Set-ADUsersInNewGroup-USERS\userlist.txt"
$zielGruppenname = "ICT_B_ECP_PHC"

# Überprüfen, ob die Datei existiert
if (-Not (Test-Path $benutzerDatei)) {
    Write-Host "Die Datei $benutzerDatei wurde nicht gefunden!" -ForegroundColor Red
    exit
}

# Einlesen der Benutzernamen aus der Datei
$benutzerListe = Get-Content -Path $benutzerDatei | Select-Object -Unique

# Zielgruppe abrufen
$zielGruppe = Get-ADGroup -Filter { Name -eq $zielGruppenname }

# Überprüfen, ob die Gruppe existiert
if ($null -eq $zielGruppe) {
    Write-Host "Die Gruppe '$zielGruppenname' wurde nicht gefunden!" -ForegroundColor Red
    exit
}

# Mitglieder der Zielgruppe abrufen
$bestehendeMitglieder = Get-ADGroupMember -Identity $zielGruppe.DistinguishedName | Select-Object -ExpandProperty SamAccountName

# Statistiken
$hinzugefuegt = 0
$bereitsMitglied = 0
$nichtGefunden = 0
$log = @()

# Benutzer hinzufügen
foreach ($benutzer in $benutzerListe) {
    # Prüfen, ob der Benutzer existiert
    $adBenutzer = Get-ADUser -Filter { SamAccountName -eq $benutzer } -ErrorAction SilentlyContinue
    
    if ($null -eq $adBenutzer) {
        Write-Host "Benutzer '$benutzer' nicht gefunden." -ForegroundColor Yellow
        $log += "❌ Benutzer nicht gefunden: $benutzer"
        $nichtGefunden++
        continue
    }

    # Prüfen, ob der Benutzer bereits in der Gruppe ist
    if ($bestehendeMitglieder -contains $benutzer) {
        Write-Host "Benutzer '$benutzer' ist bereits Mitglied der Gruppe." -ForegroundColor Cyan
        $log += "🔹 Bereits Mitglied: $benutzer"
        $bereitsMitglied++
        continue
    }

    # Benutzer zur Gruppe hinzufügen
    try {
        Add-ADGroupMember -Identity $zielGruppe -Members $adBenutzer.DistinguishedName -ErrorAction Stop
        Write-Host "Benutzer '$benutzer' wurde erfolgreich hinzugefügt." -ForegroundColor Green
        $log += "✅ Erfolgreich hinzugefügt: $benutzer"
        $hinzugefuegt++
    }
    catch {
        Write-Host "Fehler beim Hinzufügen von '$benutzer'." -ForegroundColor Red
        $log += "⚠️ Fehler: $benutzer"
    }
}

# Bericht ausgeben
Write-Host "`n========= Abschlussbericht =========" -ForegroundColor White
Write-Host "Zielgruppe: $zielGruppenname" -ForegroundColor White
Write-Host "✔ Erfolgreich hinzugefügt: $hinzugefuegt" -ForegroundColor Green
Write-Host "🔹 Bereits in der Gruppe: $bereitsMitglied" -ForegroundColor Cyan
Write-Host "❌ Nicht gefunden: $nichtGefunden" -ForegroundColor Yellow
