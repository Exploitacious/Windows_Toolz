Write-Host "Starting the process to disable Shared Computer Activation..." -ForegroundColor Yellow

# --- PART 1: Disable SCA in the Registry ---

$regPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$regName = "SharedComputerLicensing"
$regValue = "0"

try {
    # Check if the registry property exists and is not already set to 0
    $currentProp = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if ($null -ne $currentProp -and $currentProp.$regName -ne $regValue) {
        Write-Host "SCA is enabled. Setting SharedComputerLicensing to 0..."
        Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Type String -Force
        Write-Host "Successfully disabled SCA at the machine level." -ForegroundColor Green
    }
    else {
        Write-Host "SCA is already disabled or was never enabled. No registry change needed."
    }
}
catch {
    Write-Error "Could not access the registry. Please run this script as an Administrator. Error: $_"
    exit 1
}

# --- PART 2: Clear Existing SCA License Tokens from User Profiles ---

Write-Host "`nSearching for and clearing old SCA license tokens..." -ForegroundColor Yellow

try {
    # Get all user profile directories under C:\Users, excluding public/system profiles
    $userFolders = Get-ChildItem -Path "C:\Users" -Directory | Where-Object { $_.Name -notin "Public", "Default" }

    foreach ($folder in $userFolders) {
        $licensingPath = Join-Path -Path $folder.FullName -ChildPath "AppData\Local\Microsoft\Office\16.0\Licensing"
        
        if (Test-Path $licensingPath) {
            Write-Host " - Found licensing folder for user '$($folder.Name)'. Clearing contents..."
            # Get child items and remove them to clear the folder
            Get-ChildItem -Path $licensingPath -Recurse | Remove-Item -Force -Recurse
            Write-Host "   -> Successfully cleared '$licensingPath'." -ForegroundColor Green
        }
    }
}
catch {
    Write-Error "An error occurred while clearing user license tokens. Error: $_"
    exit 1
}

Write-Host "`nProcess complete." -ForegroundColor Cyan
Write-Host "The machine is now configured for dedicated licensing." -ForegroundColor Cyan
Write-Host "Users will be prompted to sign in and activate Office on their next launch." -ForegroundColor Cyan

exit 0