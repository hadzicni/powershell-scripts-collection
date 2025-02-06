<#
.SYNOPSIS
Dieses Skript überprüft, ob alle Benutzer einer bestimmten AD-Gruppe Mitglied in den erforderlichen Gruppen sind.

.DESCRIPTION
Das Skript fragt den Benutzernamen, die Ziel-AD-Gruppe und die erforderlichen Gruppen ab. Es überprüft dann, ob der Benutzer Mitglied in allen erforderlichen Gruppen ist und gibt eine Nachricht aus, ob er alle Gruppenmitgliedschaften hat oder in welchen Gruppen er fehlt.

.PARAMETER $targetGroup
Die Zielgruppe, deren Mitglieder überprüft werden sollen.

.PARAMETER $requiredGroups
Eine Liste der erforderlichen Gruppen, denen die Benutzer angehören müssen.

.EXAMPLE
Führen Sie das Skript aus, um zu prüfen, ob alle Benutzer in der Zielgruppe Mitglied der erforderlichen Gruppen sind:
.\Check-UserGroupMembership.ps1

.NOTES
Author: Nikola Hadzic
Version: 1.0
Datum: 2025-01-14

#>

$targetGroup = Read-Host "Geben Sie den Namen der Zielgruppe ein (z. B. ICT_B_Augenklinik_Aerzte)"

$requiredGroupsInput = Read-Host "Geben Sie die erforderlichen Gruppen ein, getrennt durch Kommas (z. B. ICT_B_Augenklinik_Alle, ICT_B_FORUM_Users, ICT_B_HeyexUsers)"
$requiredGroups = $requiredGroupsInput.Split(",") | ForEach-Object { $_.Trim() }

$members = Get-ADGroupMember -Identity $targetGroup

foreach ($member in $members) {
    $username = $member.SamAccountName

    $userGroups = (Get-ADUser $username -Properties MemberOf).MemberOf | Get-ADGroup | Select-Object -ExpandProperty SamAccountName

    $missingGroups = $requiredGroups | Where-Object { $_ -notin $userGroups }

    if ($missingGroups.Count -eq 0) {
        Write-Host "Benutzer $username ist Mitglied aller erforderlichen Gruppen."
    }
    else {
        Write-Host "Benutzer $username fehlt in den Gruppen: $($missingGroups -join ', ')"
    }
}
