# Apps to Install Requires WinGet to be installed, or the switch enabled for automatically installing WinGet
Write-Host -ForegroundColor Green "Install Winget, Winget Auto-Update, and required apps"
Start-Sleep 3

Read-Host -Prompt "Finished! Press Enter to exit"

<#
# Verify/Elevate Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

$InstallPrograms = @(
    "Company Portal"
    "9N0DX20HK701" # Windows Terminal
    "9NRX63209R7B" # Outlook (NEW) for Windows
    "Adobe.Acrobat.Reader.64-bit"
    "7zip.7zip"
    "Zoom.Zoom"
    "Microsoft.Teams" # Microsoft Teams (New)
)

# Install WinGet, Update Apps, and Install Specified Apps

### Refresh and Download the latest Winget Auto Update
$WAUPath = "C:\Temp\WAU_Latest"
$WAUurl = "https://github.com/Romanitho/Winget-AutoUpdate/zipball/master/"
$WAUFile = "$WAUPath\WAU_latest.zip"
# Refresh the directory to allow download and install of latest version
if ((Test-Path -Path $WAUPath)) {
    Remove-Item $WAUPath -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $WAUPath
}
else {
    New-Item -ItemType Directory -Path $WAUPath
}

# Download Winget AutoUpdate
Invoke-WebRequest -Uri $WAUurl -o $WAUFile
Expand-Archive $WAUFile -DestinationPath $WAUPath -Force
Remove-Item $WAUFile -Force

# Move Items around to remove extra directories
Move-Item "$WAUPath\Romanitho*\*" $WAUPath
Remove-Item "$WAUPath\Romanitho*\"

### Execute Winget + Auto Update Installation
& "$WAUPath\Sources\WAU\Winget-AutoUpdate-Install.ps1" -Silent -InstallUserContext -NotificationLevel None -UpdatesAtLogon -UpdatesInterval Daily -DoNotUpdate


# Install Apps

Foreach ($NewApp in $InstallPrograms) {
    $listApp = winget list --exact -q $NewApp
    if (![String]::Join("", $listApp).Contains($NewApp)) {
        Write-host -ForegroundColor Green "Installing: " $NewApp
        winget install -e -h --accept-source-agreements --accept-package-agreements --id $NewApp 
    }
    else {
        Write-host $NewApp " already installed."
    }
}

Read-Host -Prompt "Finished! Press Enter to exit"

#>