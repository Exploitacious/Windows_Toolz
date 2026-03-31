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
    write-DRRMAlert "Unsupported OS. Only Windows 8.1 and up are supported."
    exit 1
}

$ExcludedList = $ENV:ExcludedList -split ','
 
$StrangeProcesses = Get-Process -IncludeUserName | Where-Object { $_.username -like "*SYSTEM" -and $_.SessionId -ne 0 -and $_.ProcessName -notin $ExcludedList }
 
if ($StrangeProcesses) {
    write-DRMMAlert "Processes found running as system inside an interactive session. Please investigate"
    write-DRMMdiag ($StrangeProcesses | Out-String)
    exit 1
}
else {
    write-DRMMAlert "Healthy. No processes found."
}