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

Write-Host "Launching De-Bloat Processes..."
Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"C:\Temp\Cleanup\UninstallBloat.ps1`"" -Verb RunAs