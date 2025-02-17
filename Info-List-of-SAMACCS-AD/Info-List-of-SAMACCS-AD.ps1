param (
    [string]$InputFilePath = "C:\Users\hadzicni\Desktop\Powershell-Scripts-Collection\Info-List-of-SAMACCS-AD\userlist.txt",
    [string]$OutputFilePath = "C:\Users\hadzicni\Documents\ergebnis.csv"
)

Import-Module ActiveDirectory

try {
    $users = Get-Content -Path $InputFilePath -ErrorAction Stop
} catch {
    Write-Error "Failed to read input file: $($_)"
    exit 1
}

$results = @()

foreach ($user in $users) {
    try {
        $adUser = Get-ADUser -Filter {sAMAccountName -eq $user} -Property GivenName, Surname, Department, Title, Enabled -ErrorAction Stop

        if ($adUser -and $adUser.Enabled) {
            $results += [PSCustomObject]@{
                sAMAccountName = $user
                Vorname = $adUser.GivenName
                Nachname = $adUser.Surname
                Abteilung = $adUser.Department
                Titel = $adUser.Title
            }
        } else {
            Write-Host "Benutzer nicht gefunden oder deaktiviert: $user" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error retrieving user $user" -ForegroundColor Red
    }
}

try {
    $results | Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";" -ErrorAction Stop
    Write-Host "Abfrage abgeschlossen. Ergebnisse gespeichert in $OutputFilePath"
} catch {
    Write-Error "Failed to write output file: $($_)"
    exit 1
}