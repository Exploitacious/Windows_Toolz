#
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Install or Update WinGet (and Winget-AutoUpdate)" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
$env:usrUDF = 17 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrForceUpdate = $false # Datto User Input variable. Set to $true to force reinstall of WinGet.
$env:usrInstallAutoUpdate = $true # Datto User Input variable. Set to $true to install Winget-AutoUpdate.

<#
This Script is a Remediation compoenent, meaning it performs only one task with a log of granular detail.
#>
# DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog).
$Global:varUDFString = "" # String which will be written to UDF.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date
##################################
##################################
######## Start of Script #########



<#
.SYNOPSIS
    Installs or updates WinGet and optionally installs or runs Winget-AutoUpdate.

.DESCRIPTION
    This script provides a fully automated method for managing WinGet and the Winget-AutoUpdate utility.
    It writes a summary of its actions to a specified UDF.
#>

#------------------------------------------------------------------------------------
# --- USER CONFIGURABLE VARIABLES ---
#------------------------------------------------------------------------------------
if ($env:usrForceUpdate -eq 'true' -or $env:usrForceUpdate -eq 1) {
    $Global:ForceUpdate = $true
    $Global:DiagMsg += "Datto RMM variable 'usrForceUpdate' is set. Forcing reinstall of WinGet."
}
else {
    $Global:ForceUpdate = $false
}

if ($env:usrInstallAutoUpdate -eq 'true' -or $env:usrInstallAutoUpdate -eq 1) {
    $Global:InstallAutoUpdate = $true
    $Global:DiagMsg += "Datto RMM variable 'usrInstallAutoUpdate' is set. Will manage Winget-AutoUpdate."
}
else {
    $Global:InstallAutoUpdate = $false
}

#------------------------------------------------------------------------------------
# --- HELPER FUNCTIONS (Condensed for brevity) ---
#------------------------------------------------------------------------------------
function Get-SystemInfo {
    Write-Host "Gathering system information..."
    $is64BitOS = [System.Environment]::Is64BitOperatingSystem
    $architecture = switch ($env:PROCESSOR_ARCHITECTURE) { "AMD64" { "x64" } "x86" { "x86" } default { if ($is64BitOS) { "x64" } else { "x86" } } }
    return [PSCustomObject]@{ OSVersion = [System.Environment]::OSVersion.Version; Architecture = $architecture; IsElevated = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator); TempPath = $env:TEMP }
}
function Test-Prerequisites {
    param([PSCustomObject]$SystemInfo)
    Write-Host "Verifying system prerequisites..."
    if ([System.Version]'10.0.17763.0' -gt $SystemInfo.OSVersion) { Write-Error "SCRIPT HALTED: WinGet requires Windows 10 build 17763 or newer."; return $false }
    if (-not (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet)) { Write-Error "SCRIPT HALTED: An active internet connection is required."; return $false }
    Write-Host "Prerequisites met." -ForegroundColor Green; return $true
}
function Get-AllUserAppxPackages {
    param([PSCustomObject]$SystemInfo)
    if ($SystemInfo.IsElevated) { return @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue) } else {
        Write-Warning "Elevation is required to check system-wide packages. A UAC prompt will appear."
        $tempFile = Join-Path $SystemInfo.TempPath ([System.Guid]::NewGuid().ToString() + ".clixml")
        Start-Process "powershell.exe" -ArgumentList "-NoProfile -Command `"Get-AppxPackage -AllUsers | Export-Clixml -Path '$tempFile' -Force`"" -Verb RunAs -WindowStyle Hidden -Wait
        if (Test-Path $tempFile) { $packages = Import-Clixml -Path $tempFile; Remove-Item $tempFile -Force; return @($packages) } else { Write-Error "Failed to retrieve AppX package info."; return @() }
    }
}
function Find-WinGetExecutable {
    $userPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe"; $systemPath = "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe\winget.exe"
    if (Test-Path $systemPath) { try { return (Get-Item $systemPath | Sort-Object -Property FileVersionRaw | Select-Object -Last 1).FullName } catch {} }; if (Test-Path $userPath) { return $userPath }; return $null
}
function Test-WinGetInstallation {
    param([Array]$AllUserPackages)
    Write-Host "Checking for existing WinGet installation..."
    $desktopAppInstaller = $AllUserPackages | Where-Object { $_.Name -eq "Microsoft.DesktopAppInstaller" }
    if ($desktopAppInstaller) { try { Add-AppxPackage -DisableDevelopmentMode -Register ($desktopAppInstaller.InstallLocation + "\AppxManifest.xml") -ErrorAction Stop | Out-Null; Start-Sleep -Seconds 2 } catch { Write-Warning "Could not re-register the existing Microsoft Desktop App Installer package." } }
    $wingetPath = Find-WinGetExecutable
    if (-not $wingetPath) { Write-Host "WinGet is not installed."; return 'NotFound' }
    try {
        $versionString = (& $wingetPath --version).Replace("v", ""); $currentVersion = [System.Version]$versionString
        if ($currentVersion -lt [System.Version]'1.3.0.0') { Write-Warning "Found a retired version of WinGet ($currentVersion). Update required."; return 'Retired' }
        Write-Host "Found a functional and up-to-date version of WinGet ($currentVersion)." -ForegroundColor Green
        $Global:varUDFString += "WinGet OK (v$currentVersion); "
        return 'OK'
    }
    catch { Write-Warning "Found winget.exe, but could not verify its version."; return 'NotFound' }
}
# Main installation function is complex and not condensed
function Resolve-And-Install-WinGet {
    param([PSCustomObject]$SystemInfo, [Array]$AllUserPackages)
    Write-Host "Downloading the latest WinGet package..."; $Global:varUDFString += "WinGet Installing; "
    $wingetUrl = "https://aka.ms/getwinget"; $tempWingetBundle = Join-Path $SystemInfo.TempPath "winget.msixbundle"
    try { Invoke-WebRequest -Uri $wingetUrl -OutFile $tempWingetBundle -UseBasicParsing -ErrorAction Stop } catch { Write-Error "Failed to download WinGet package."; return $false }
    Write-Host "WinGet package downloaded successfully." -ForegroundColor Green
    Write-Host "Resolving WinGet dependencies..."; $dependenciesToInstall = [System.Collections.Generic.List[string]]::new(); $tempExtractionDir = Join-Path $SystemInfo.TempPath ([System.Guid]::NewGuid().ToString()); New-Item -Path $tempExtractionDir -ItemType Directory -Force | Out-Null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory($tempWingetBundle, $tempExtractionDir)
        $msixFile = Get-ChildItem -Path $tempExtractionDir -Filter "*.msix" | Where-Object { $_.Name -like "*$($SystemInfo.Architecture)*" } | Select-Object -First 1
        if (-not $msixFile) { throw "Could not find a matching .msix file for architecture '$($SystemInfo.Architecture)'." }
        $msixExtractionDir = Join-Path $SystemInfo.TempPath ([System.Guid]::NewGuid().ToString()); [System.IO.Compression.ZipFile]::ExtractToDirectory($msixFile.FullName, $msixExtractionDir); [xml]$manifest = Get-Content -Path (Join-Path $msixExtractionDir "AppxManifest.xml")
        foreach ($dependency in $manifest.Package.Dependencies.PackageDependency) {
            $depName = $dependency.Name; $depMinVersion = [System.Version]$dependency.MinVersion
            if ($AllUserPackages | Where-Object { $_.Name -eq $depName -and [System.Version]$_.Version -ge $depMinVersion }) { Write-Host " -> Dependency '$depName' is satisfied." -ForegroundColor Green; continue }
            Write-Warning " -> Dependency '$depName' is missing. Downloading."; $depFile = ""; if ($depName -like "Microsoft.UI.Xaml*") { $nupkgUrl = "https://www.nuget.org/api/v2/package/$depName/$($depMinVersion.ToString())"; $nupkgFile = Join-Path $SystemInfo.TempPath "$depName.nupkg"; if (Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgFile -UseBasicParsing) { $nupkgExtractionDir = Join-Path $SystemInfo.TempPath "$depName-nupkg"; [System.IO.Compression.ZipFile]::ExtractToDirectory($nupkgFile, $nupkgExtractionDir); $appxInNupkg = Get-ChildItem -Path $nupkgExtractionDir -Recurse -Filter "*.appx" | Select-Object -First 1; if ($appxInNupkg) { $depFile = Join-Path $SystemInfo.TempPath $appxInNupkg.Name; Move-Item -Path $appxInNupkg.FullName -Destination $depFile -Force } } } elseif ($depName -like "Microsoft.VCLibs*") { $vcLibsVersion = "$($depMinVersion.Major).00"; $vcLibsFileName = "Microsoft.VCLibs.$($SystemInfo.Architecture).$vcLibsVersion.Desktop.appx"; $vcLibsUrl = "https://aka.ms/$vcLibsFileName"; $depFile = Join-Path $SystemInfo.TempPath $vcLibsFileName; if (-not (Invoke-WebRequest -Uri $vcLibsUrl -OutFile $depFile -UseBasicParsing)) { $depFile = "" } }
            if ([string]::IsNullOrEmpty($depFile)) { throw "Failed to download dependency: $depName" }
            $dependenciesToInstall.Add($depFile)
        }
    }
    catch { Write-Error "Error during dependency resolution: $($_.Exception.Message)"; return $false } finally { Remove-Item -Path $tempExtractionDir, $msixExtractionDir -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host "Starting WinGet installation..."; try { $installParams = @{ Path = $tempWingetBundle; ForceTargetApplicationShutdown = $true; ErrorAction = 'Stop' }; if ($dependenciesToInstall.Count -gt 0) { $installParams.Add("DependencyPath", $dependenciesToInstall) }; Add-AppxPackage @installParams } catch { Write-Error "WinGet installation failed: $($_.Exception.Message)"; return $false } finally { Remove-Item -Path $tempWingetBundle -Force -ErrorAction SilentlyContinue; foreach ($dep in $dependenciesToInstall) { Remove-Item -Path $dep -Force -ErrorAction SilentlyContinue } }
    return $true
}

#------------------------------------------------------------------------------------
# --- SCRIPT EXECUTION ---
#------------------------------------------------------------------------------------
Clear-Host
Write-Host "========================================"
Write-Host "  Automated WinGet Installer"
Write-Host "  Author: Alex Ivantsov"
Write-Host "========================================"; Write-Host

$systemInfo = Get-SystemInfo
if (-not (Test-Prerequisites -SystemInfo $systemInfo)) { Exit 1 }
$allUserPackages = Get-AllUserAppxPackages -SystemInfo $systemInfo
if ($allUserPackages.Count -eq 0) { Write-Error "Could not retrieve AppX packages."; Exit 1 }

$wingetStatus = Test-WinGetInstallation -AllUserPackages $allUserPackages
$needsInstall = $false
if ($wingetStatus -eq 'NotFound' -or $wingetStatus -eq 'Retired') { $needsInstall = $true }
elseif ($Global:ForceUpdate) { Write-Host "ForceUpdate is set. Proceeding with reinstallation."; $needsInstall = $true }
else { Write-Host "WinGet is already installed and up to date." }

if ($needsInstall) {
    if (Resolve-And-Install-WinGet -SystemInfo $systemInfo -AllUserPackages $allUserPackages) {
        Write-Host "Verifying installation..."; Start-Sleep -Seconds 3
        $wingetStatus = Test-WinGetInstallation -AllUserPackages (Get-AllUserAppxPackages -SystemInfo $systemInfo)
        if ($wingetStatus -ne 'OK') { Write-Error "`nSCRIPT FAILED: WinGet is still not functional after install."; $needsInstall = $false }
        else { Write-Host "`nSCRIPT COMPLETE: WinGet successfully installed." -ForegroundColor Green }
    }
    else { Write-Error "`nSCRIPT FAILED: Installation process failed."; $needsInstall = $false }
}

# This entire block now runs if WinGet is confirmed OK (either pre-existing or just installed)
if (($wingetStatus -eq 'OK') -and $Global:InstallAutoUpdate) {
    Write-Host "----------------------------------------"
    $upgradeScriptPath = "C:\Program Files\Winget-AutoUpdate\Winget-Upgrade.ps1"
    if (Test-Path $upgradeScriptPath) {
        Write-Host "'$upgradeScriptPath' is available. Launching as logged-in user."
        $explorerProcess = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" | Select-Object -First 1
        if ($explorerProcess) {
            $ownerInfo = Invoke-CimMethod -InputObject $explorerProcess -MethodName GetOwner; $currentUser = "$($ownerInfo.Domain)\$($ownerInfo.User)"
            try {
                $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$upgradeScriptPath`""
                Register-ScheduledTask -TaskName "RunWingetAutoUpdateOnce" -Action $taskAction -User $currentUser -RunLevel Limited -Force | Out-Null
                Start-ScheduledTask -TaskName "RunWingetAutoUpdateOnce"; Start-Sleep -Seconds 5; Unregister-ScheduledTask -TaskName "RunWingetAutoUpdateOnce" -Confirm:$false
                Write-Host "Auto Upgrade Launched" -ForegroundColor Cyan; $Global:varUDFString += "WAU Launched; "
            }
            catch { Write-Error "Failed to run scheduled task: $($_.Exception.Message)"; $Global:varUDFString += "WAU Launch Fail; " }
        }
        else { Write-Warning "No logged-in user found. Skipping upgrade launch."; $Global:varUDFString += "WAU No User; " }
    }
    else {
        Write-Host "'$upgradeScriptPath' not found. Checking installation status..."
        $wingetExePath = Find-WinGetExecutable
        $autoUpdatePackageId = "Romanitho.Winget-AutoUpdate"
        if ($wingetExePath -and (& $wingetExePath list --id $autoUpdatePackageId --source winget --accept-source-agreements 2>$null)) {
            Write-Host "Winget-AutoUpdate is already installed." -ForegroundColor Green; $Global:varUDFString += "WAU Installed; "
        }
        else {
            Write-Host "Attempting to install Winget-AutoUpdate..."
            try {
                $arguments = "install --id $autoUpdatePackageId --source winget --accept-package-agreements --accept-source-agreements --silent"
                Start-Process -FilePath $wingetExePath -ArgumentList $arguments -Wait -NoNewWindow -ErrorAction Stop
                Write-Host "Successfully installed Winget-AutoUpdate." -ForegroundColor Green; $Global:varUDFString += "WAU Newly Installed; "
            }
            catch { Write-Error "Failed to install Winget-AutoUpdate: $($_.Exception.Message)"; $Global:varUDFString += "WAU Install Fail; " }
        }
    }
}
elseif ($wingetStatus -eq 'OK' -and !$Global:InstallAutoUpdate) {
    $Global:varUDFString += "WAU Skipped; "
}

Write-Host "`n========================================"

# Clean up trailing characters for a clean UDF string
if ($Global:varUDFString.EndsWith('; ')) { $Global:varUDFString = $Global:varUDFString.Substring(0, $Global:varUDFString.Length - 2) }


######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString
        # Limit UDF Entry to 255 Characters
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($Global:varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($Global:varUDFString) -Force
    }
}
### Info to be sent to into JSON POST to API Endpoint (Optional)
$APIinfoHashTable = @{ 'CS_PROFILE_UID' = $env:CS_PROFILE_UID; 'Script_Diag' = $Global:DiagMsg; 'Script_UID' = $ScriptUID }
#######################################################################
### Exit script with proper Datto diagnostic and API Results.
if ($null -ne $env:APIEndpoint) {
    $Global:DiagMsg += " - Sending Results to API"
    Invoke-WebRequest -Uri $env:APIEndpoint -Method POST -Body ($APIinfoHashTable | ConvertTo-Json) -ContentType "application/json"
}
write-DRMMDiag $Global:DiagMsg
Exit 0