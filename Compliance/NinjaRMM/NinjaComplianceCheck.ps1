$appName = "NinjaRMMAgent"
$serviceName = "NinjaRMMAgent"

$installed = $false
$running = $false

# Check if the application is installed
$uninstallKeys = @(
    "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*",
    "HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*"
)

foreach ($key in $uninstallKeys) {
    $installedApps = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$appName*" }
    if ($installedApps) {
        $installed = $true
        break
    }
}

# Check if the service is running
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service.Status -eq 'Running') {
    $running = $true
}

$result = @{
    NinjaRMMInstalled = $installed
    NinjaRMMRunning   = $running
}

return $result | ConvertTo-Json -Compress