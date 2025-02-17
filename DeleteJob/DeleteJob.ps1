# Description: Dieses Skript löscht beliebige Dateien mit gewählten Alter in gewählten Verzeichnis automatisch.
# Author: Nikola Hadzic
# Version: 1.0
# Datum: 2025-01-14

$path = "C:\Users\hadzicni\Documents\Test_XML_Files"

$altersGrenze = 1

$heutigesDatum = Get-Date

$altersDatum = $heutigesDatum.AddDays(-$altersGrenze)

# 
$alteDateien = Get-ChildItem -Path $path | Where-Object { $_.LastWriteTime -lt $altersDatum }

foreach ($datei in $alteDateien) {
    Write-Host "Lösche Datei: $($datei.FullName)"
    Remove-Item $datei.FullName -Force
}

Write-Host "Löschvorgang abgeschlossen."