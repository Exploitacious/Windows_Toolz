# Verify/Elevate Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

Write-Host " "
Write-Host " "
Write-Host "  ## ##   ####     ### ###    ##     ###  ##  ##  ###  ### ##   "
Write-Host " ##   ##   ##       ##  ##     ##      ## ##  ##   ##   ##  ##  "
Write-Host " ##        ##       ##       ## ##    # ## #  ##   ##   ##  ##  "
Write-Host " ##        ##       ## ##    ##  ##   ## ##   ##   ##   ##  ##  "
Write-Host " ##        ##       ##       ## ###   ##  ##  ##   ##   ## ##   "
Write-Host " ##   ##   ##  ##   ##  ##   ##  ##   ##  ##  ##   ##   ##      "
Write-Host "  ## ##   ### ###  ### ###  ###  ##  ###  ##   ## ##   ####    "
Write-Host " "
Write-Host "  Created by Alex Ivantsov "
Write-Host "  @Exploitacious "

Write-Host
Write-Host
Write-Host
Write-Host

# Check for Files Here
# Required Files (xyz...)

<#
Write-Host "Launching De-Bloat Processes..."
Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"C:\Temp\Cleanup\UninstallBloat.ps1`"" -Verb RunAs

$i = 5 #Seconds
do {
    Write-Host $i
    Sleep 1
    $i--
} while ($i -gt 0)

Write-Host "Launching PS Modules & Windows Updates"
Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"C:\Temp\Cleanup\PSandWindowsUpdates.ps1`"" -Verb RunAs

$i = 180 #Seconds
do {
    Write-Host $i
    Sleep 1
    $i--
} while ($i -gt 0)

Write-Host "Launching Winget Auto Update and New App Installations"
Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"C:\Temp\Cleanup\PSandWindowsUpdates.ps1`"" -Verb RunAs

$i = 5 #Seconds
do {
    Write-Host $i
    Sleep 1
    $i--
} while ($i -gt 0)

#>

Write-Host "Launching Windows tweaks and settings..."
Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"C:\Temp\Cleanup\PS-HKLM.ps1`"" -Verb RunAs



<#

# Implement User Logon Script

Write-Host "Creating Directories 'C:\Windows\FirstUserLogon' and Copying files"
mkdir "C:\Windows\FirstUserLogon" -ErrorAction SilentlyContinue
Copy-Item "DebloatScript-HKCU.ps1" "C:\Windows\FirstUserLogon\DebloatScript-HKCU.ps1"
Copy-Item "FirstLogon.bat" "C:\Windows\FirstUserLogon\FirstLogon.bat"
Write-Host

Write-Host "Enabling Registry Keys to run Logon Script"
REG LOAD HKEY_Users\DefaultUser "C:\Users\Default\NTUSER.DAT"
Set-ItemProperty -Path "REGISTRY::HKEY_USERS\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Run" -Name "FirstUserLogon" -Value "C:\Windows\FirstUserLogon\FirstLogon.bat" -Type "String"
REG UNLOAD HKEY_Users\DefaultUser
	
Write-Host "New User Logon Script Successfully Enabled"


#>