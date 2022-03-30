# New Lenovo Machine Setup Script
# The whole damn THAAANG


# Rename Computer

$Answer = Read-Host "Would you like to rename this computer? Y/N "
    if ($Answer -eq 'y' -or $Answer -eq 'yes') {
        $NewHostname = Read-Host "Please Enter the computer's new name"
        Rename-Computer -NewName $NewHostname
}


# Create Directories and Download Items
	Write-Host "Setting up directories and downloading items for deployment"
    New-Item -Path "c:\" -Name "Temp" -ItemType "directory" -Force
    New-Item -Path "C:\Windows\" -Name "AllUsersFirstLogon" -ItemType "directory" -Force

    Invoke-Webrequest -Uri https://download.lenovo.com/pccbbs/thinkvantage_en/system_update_5.07.0131.exe -OutFile 'C:\Temp\LenovoUpdate.exe'

    CMD

    "C:\Temp\LenovoUpdate.exe" /VERYSILENT /NORESTART

# Uninstall Vantage Services Completely
# "C:\Program Files (x86)\Lenovo\VantageService...
# c:\windows\system32\imcontroller.infinstaller.exe -uninstall


	# Invoke-Item C:\Temp

    # Start Lenovo System Updater
    # Invoke-Item 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\lenovo\System Update.lnk'


# Start and Install Windows Updates
    If (-not(Get-PackageProvider PSWindowsUpdate -ErrorAction silentlycontinue)) {
        Install-PackageProvider NuGet -Confirm:$False -Force
    }

    If (-not(Get-InstalledModule PSWindowsUpdate -ErrorAction silentlycontinue)) {
        Install-Module PSWindowsUpdate -Confirm:$False -Force
    }

    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot | Out-File C:\Temp\PSWindowsUpdate.log



# WinGet Install Chrome, Adobe Reader, and 7zip
#    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

	Find-PackageProvider -Verbose | Install-PackageProvider -Verbose -Force
    Install-Module winget -Force
    Install-Module PackageManagement -Force

    winget install Google.Chrome
    winget install Microsoft.Edge
    winget install Adobe.AdobeAcrobatReaderDC
    winget install 7zip.7zip
    winget install Microsoft.OneDrive
    winget install Cyanfish.NAPS2


