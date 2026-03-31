function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    Write-Host '<-End Diagnostic->'
} 

function write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "Alert=$message"
    Write-Host '<-End Result->'
}

$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.3") {
    write-DRRMAlert "Unsupported OS. Only Server 2012R2 and up are supported."
    exit 1
}
$Unsigned = driverquery /si /FO CSV | ConvertFrom-Csv | Where-Object -Property IsSigned -EQ "FALSE"
if ($Unsigned ) {
    write-DRMMAlert "Unhealthy - Some of the used drivers are unsigned. This can indicate a risk."
    write-DRMMDiag ($Unsigned | format-list *)
    exit 1
}
else {
    write-DRMMAlert "Healthy"
}