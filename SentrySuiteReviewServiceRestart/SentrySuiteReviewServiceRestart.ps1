<#
.SYNOPSIS
    Startet den Windows-Dienst "SentrySuiteReviewService", falls dieser nicht läuft.

.DESCRIPTION
    Überprüft, ob der Dienst "SentrySuiteReviewService" vorhanden ist und gestartet wurde. 
    Falls der Dienst nicht gestartet ist, wird ein Startversuch unternommen.

.AUTHOR
    Nikola Hadzic
    Universitätsspital Basel

.NEED
    Sicherstellen, dass der Dienst "SentrySuiteReviewService" aktiv ist, zur Gewährleistung der Systemverfügbarkeit von SentrySuite.
#>

function Write-Log {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp`t$message" | Out-File -FilePath ".\SentrySuiteReviewServiceRestart.log" -Append -Encoding UTF8
}

$svc = Get-Service -Name "SentrySuiteReviewService" -ErrorAction SilentlyContinue

if ($null -eq $svc) {
    Write-Log "Service SentrySuiteReviewService was not found."
    exit 1
}

if ($svc.Status -ne 'Running') {
    Start-Service -Name "SentrySuiteReviewService"
    Start-Sleep -Seconds 5
    $svc.Refresh()

    if ($svc.Status -eq 'Running') {
        Write-Log "Service SentrySuiteReviewService was started."
    } else {
        Write-Log "Service SentrySuiteReviewService could not be started."
    }
}
