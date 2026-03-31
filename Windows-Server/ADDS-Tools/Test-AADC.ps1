function write-DRMMDiag ($messages) {
    write-host '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End Diagnostic->'
} 

function write-DRMMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}

$suggver = "2.0.91.0"
$reqver = "2.0.3.0"

try {
    $ver = (Get-ADSyncGlobalSettings).Parameters | where 'Name' -eq 'Microsoft.Synchronize.ServerConfigurationVersion' | Select -ExpandProperty Value
}
catch {
    write-DRMMAlert "Error: $($_.Exception.Message)"
    exit 1
}

if ($ver -lt $reqver) {
    write-DRMMAlert "**** ALERT: VERSION IS NO LONGER SUPPORTED ****"
    write-DRMMDiag "Current version: $ver`n", "Supported version: $reqver or above | Suggested Version: $suggver or above`n", "More info: https://docs.microsoft.com/en-us/azure/active-directory/hybrid/reference-connect-version-history"
    Exit 1
}
elseif ($ver -le $suggver) {
    write-DRMMDiag "WARNING: You are running an old version but it is still supported until 15 March 2023`n", "Current version: $ver`n", "Suggested version: $suggver or above`n", "More info: https://docs.microsoft.com/en-us/azure/active-directory/hybrid/reference-connect-version-history"
    Exit 0
}
else {
    write-DRMMDiag "CONGRATULATIONS! Your AAD Connect version is on or above the suggested version. Have a beer!`n", "Current version: $ver`n", "Suggested version: $suggver or above`n", "More info: https://docs.microsoft.com/en-us/azure/active-directory/hybrid/reference-connect-version-history"
    Exit 0
}