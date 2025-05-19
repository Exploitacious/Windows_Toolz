# Apps to Install Requires WinGet to be installed, or the switch enabled for automatically installing WinGet
Write-Host -ForegroundColor Green "Install Winget, Winget Auto-Update, and required apps"
Start-Sleep 3

# Verify/Elevate Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

$InstallPrograms = @(
    #"Romanitho.Winget-AutoUpdate" # Winget Auto Update, the best package there is. https://github.com/Romanitho/Winget-AutoUpdate Not using Winget cause it's not consistent
    "Company Portal"
    "9N0DX20HK701" # Windows Terminal
    "9NRX63209R7B" # Outlook (NEW) for Windows
    "Adobe.Acrobat.Reader.64-bit"
    "7zip.7zip"
    "Zoom.Zoom"
    "Microsoft.Teams" # Microsoft Teams (New)
    "Microsoft.Edge"
    "Microsoft.PowerToys"
)

### Download and install the latest Winget Auto Update
# Set WAU Variables
$WAUPath = "C:\Temp\Romanitho-WindowsAutoUpdate"
$repo = "Romanitho/Winget-AutoUpdate"
$apiUrl = "https://api.github.com/repos/$repo/releases/latest"

# Test and Create Path
if ((Test-Path -Path $WAUPath)) {
    Remove-Item $WAUPath -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $WAUPath
}
else {
    New-Item -ItemType Directory -Path $WAUPath
}

# GitHub blocks requests without a User-Agent header
$response = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "AnythingReally" }

# Find the .msi asset (you can filter differently if needed)
$asset = $response.assets | Where-Object { $_.name -like "*.msi" } | Select-Object -First 1

if ($asset -ne $null) {
    $downloadUrl = $asset.browser_download_url
    Write-Output "Latest MSI URL: $downloadUrl"

    # Optional: Download it
    Invoke-WebRequest -Uri $downloadUrl -OutFile "$WAUPath\WAU_latest.msi"
}
else {
    Write-Error "No MSI asset found in the latest release."
}

### Execute Winget Auto Update Silent Installation
& "$WAUPath\WAU_latest.msi" /qn RUN_WAU=YES STARTMENUSHORTCUT=1 NOTIFICATIONLEVEL=None


# Install Winget Apps
Write-Host "Installing Applications..."
Foreach ($NewApp in $InstallPrograms) {
    $listApp = winget list --exact -q $NewApp --accept-source-agreements --accept-package-agreements
    if (![String]::Join("", $listApp).Contains($NewApp)) {
        Write-host -ForegroundColor Green "Installing: " $NewApp
        winget install -e -h --accept-source-agreements --accept-package-agreements --id $NewApp 
    }
    else {
        Write-host $NewApp " already installed."
    }
}


Read-Host -Prompt "Finished! Press Enter to exit"