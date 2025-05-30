param (
    [Parameter(Mandatory = $true)]
    [string]$File
)

if (-Not (Test-Path $File)) {
    Write-Output "Datei nicht gefunden: $File"
    exit
}

$bytes = Get-Content $File -AsByteStream -TotalCount 4096
for ($i = 0; $i -lt $bytes.Length - 2; $i++) {
    if ($bytes[$i] -eq 0x4D -and $bytes[$i + 1] -eq 0x5A) {
        $peOffset = [BitConverter]::ToInt32($bytes, $i + 0x3C)
        if ($peOffset + 6 -gt $bytes.Length) {
            "Unbekannt oder nicht PE"
            break
        }
        $machineType = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
        switch ($machineType) {
            0x14c  { "32-bit (x86)" }
            0x8664 { "64-bit (x64)" }
            0x1c0  { "ARM" }
            Default { "Unbekannt oder nicht PE" }
        }
        break
    }
}
