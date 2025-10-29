<#
.SYNOPSIS
    A universal script to aggressively uninstall and remove software from a Windows system, with support for vendor-provided companion scripts.

.DESCRIPTION
    This script combines graceful uninstallation with forceful removal techniques to thoroughly eliminate applications.
    It operates in a sequence:
    1. Terminates running processes.
    2. Stops and deletes associated services.
    3. Executes any companion uninstall scripts found in the same directory.
    4. Attempts a standard, silent uninstallation via Add/Remove Programs.
    5. Forcefully removes leftover directories and files.
    6. Scrubs specified registry values and keys.

    ---
    COMPANION SCRIPTS:
    To run vendor-provided scripts, place them in the same folder as this script and name them following the pattern:
    Companion-Uninstall-*.ps1 (e.g., Companion-Uninstall-VendorX.ps1)
    
    They will be executed automatically with a 10-minute timeout.
    ---

.NOTES
    Author: Gemini AI
    Version: 4.0
    
    WARNING: This script performs destructive actions. Use with caution and test in a non-production environment first.
    Run this script with the highest administrative privileges for it to function correctly.
#>

# =================================================================================================================
# SCRIPT CONFIGURATION
# Add the names/paths for the items you want to completely remove in the variables below.
# =================================================================================================================

# 1. PROCESSES: Names of processes to terminate (without .exe extension).
$ProcessesToTerminate = @(
    "WRSA"
)

# 2. SERVICES: Names of Windows services to stop and delete.
$ServicesToStopAndRemove = @(
    "WRSVC",
    "WRCoreService",
    "WRSkyClient"
)

# 3. SOFTWARE: Display names of software to uninstall via Add/Remove Programs. Wildcards (*) supported.
$SoftwareNamesToUninstall = @(
    "SolarWinds*",
    "N-able*",
    "*Passportal*",
    "Webroot SecureAnywhere*",
    "MSP360*",
    "AnyDesk",
    "TeamViewer"
)

# 4. DIRECTORIES: Full paths of directories to forcefully delete. Environment variables are supported.
$DirectoriesToRemove = @(
    "$env:ProgramData\WRData",
    "$env:ProgramData\WRCore",
    "$env:ProgramFiles\Webroot",
    "$env:ProgramFiles(x86)\Webroot",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Webroot SecureAnywhere",
    "$env:ProgramFiles\SolarWinds MSP",
    "$env:ProgramFiles\N-able Technologies",
    "$env:ProgramFiles\MspPlatform",
    "$env:ProgramFiles(x86)\SolarWinds MSP",
    "$env:ProgramFiles(x86)\N-able Technologies",
    "$env:ProgramFiles(x86)\MspPlatform"
)

# 5. REGISTRY: Full paths of registry keys and specific registry values to delete.
$RegistryKeysToRemove = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\WRUNINST",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST",
    "HKLM:\SOFTWARE\WOW6432Node\WRData",
    "HKLM:\SOFTWARE\WOW6432Node\WRCore",
    "HKLM:\SOFTWARE\WOW6432Node\WRMIDData",
    "HKLM:\SOFTWARE\WOW6432Node\webroot",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WRUNINST",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST",
    "HKLM:\SOFTWARE\WRData",
    "HKLM:\SOFTWARE\WRMIDData",
    "HKLM:\SOFTWARE\WRCore",
    "HKLM:\SOFTWARE\webroot",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRSVC",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRkrn"
)

# Specific registry values to remove (e.g., startup items). Format: @{ Path = "KEY_PATH"; Name = "VALUE_NAME" }
$RegistryValuesToRemove = @(
    @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; Name = "WRSVC" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Name = "WRSVC" }
)


## =================================================================================================================
## Main Script Logic - DO NOT EDIT BELOW THIS LINE
## =================================================================================================================

Write-Host "Starting the aggressive software removal process." -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------------------------"

# Step 1: Terminate running processes
Terminate-RunningProcesses -ProcessNames $ProcessesToTerminate

# Step 2: Stop and remove services
Stop-And-Remove-Services -ServiceNames $ServicesToStopAndRemove

# Step 3: Run companion uninstall scripts
Run-CompanionScripts

# Step 4: Attempt graceful uninstallation
Uninstall-Software -SoftwareNames $SoftwareNamesToUninstall

# Step 5: Remove leftover directories
Remove-LeftoverDirectories -Directories $DirectoriesToRemove

# Step 6: Remove specific registry values and then entire keys
Remove-RegistryValues -RegistryValues $RegistryValuesToRemove
Remove-RegistryKeys -RegistryKeys $RegistryKeysToRemove

Write-Host "----------------------------------------------------------------------------------"
Write-Host "Universal uninstaller script has completed." -ForegroundColor Green
Write-Host "A REBOOT is highly recommended to finalize the removal of all components."

## =================================================================================================================
## Function Definitions
## =================================================================================================================

function Terminate-RunningProcesses {
    param ([string[]]$ProcessNames)
    if ($ProcessNames.Count -eq 0) { return }

    Write-Host "`n[Step 1] Terminating configured processes..." -ForegroundColor Yellow
    foreach ($name in $ProcessNames) {
        $process = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($process) {
            Write-Host "  -> Stopping process: $name"
            Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Host "  -> Process not found: $name"
        }
    }
}

function Stop-And-Remove-Services {
    param ([string[]]$ServiceNames)
    if ($ServiceNames.Count -eq 0) { return }

    Write-Host "`n[Step 2] Stopping and removing configured services..." -ForegroundColor Yellow
    foreach ($service in $ServiceNames) {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Write-Host "  -> Stopping and deleting service: $service"
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Start-Process -FilePath "sc.exe" -ArgumentList "delete `"$service`"" -Wait -WindowStyle Hidden
        }
        else {
            Write-Host "  -> Service not found: $service"
        }
    }
}

function Run-CompanionScripts {
    Write-Host "`n[Step 3] Searching for companion uninstall scripts..." -ForegroundColor Yellow
    $companionScriptPath = $PSScriptRoot
    $companionScripts = Get-ChildItem -Path $companionScriptPath -Filter "Companion-Uninstall-*.ps1" -ErrorAction SilentlyContinue

    if (-not $companionScripts) {
        Write-Host "  -> No companion scripts found."
        return
    }

    foreach ($script in $companionScripts) {
        Write-Host "  -> Found and executing: $($script.Name)"
        try {
            # Execute the script in a new process to isolate it and prevent it from halting the main script.
            $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$($script.FullName)`"" -PassThru -WindowStyle Hidden
            
            # Wait for the process to exit, with a 10-minute timeout.
            $timeoutMilliseconds = 600000 
            $hasExited = $process.WaitForExit($timeoutMilliseconds)

            if ($hasExited) {
                Write-Host "     Companion script finished with exit code: $($process.ExitCode)" -ForegroundColor Green
            }
            else {
                Write-Warning "     Companion script '$($script.Name)' timed out after 10 minutes. Terminating it."
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Error "     Failed to run companion script '$($script.Name)'. Error: $_"
        }
    }
}


function Uninstall-Software {
    param ([string[]]$SoftwareNames)
    if ($SoftwareNames.Count -eq 0) { return }

    Write-Host "`n[Step 4] Attempting graceful uninstallation..." -ForegroundColor Yellow
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $AllInstalledSoftware = Get-ItemProperty $RegistryPaths -ErrorAction SilentlyContinue | Select-Object DisplayName, UninstallString

    foreach ($SoftwareName in $SoftwareNames) {
        $SoftwareToUninstall = $AllInstalledSoftware | Where-Object { $_.DisplayName -like $SoftwareName }
        if ($SoftwareToUninstall) {
            foreach ($app in $SoftwareToUninstall) {
                if ($app.UninstallString) {
                    Write-Host "  -> Uninstalling '$($app.DisplayName)'"
                    Execute-UninstallString -UninstallString $app.UninstallString
                }
            }
        }
        else {
            Write-Host "  -> No software found matching '$SoftwareName' in Add/Remove Programs."
        }
    }
}

function Execute-UninstallString {
    param ([string]$UninstallString)
    $UninstallString = $UninstallString.Trim() -replace '"', ''
    $Command = $UninstallString.Split(' ')[0]
    $Arguments = ($UninstallString -split ' ', 2)[1]

    # CORRECTED LINE: The '-match' operator is already case-insensitive by default.
    if ($UninstallString -match 'msiexec\.exe') {
        $productCodeMatch = $UninstallString -match '\{[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}\}'
        if ($productCodeMatch) {
            $Arguments = "/x $($matches[0]) /qn /norestart"
            $Command = "msiexec.exe"
        }
    }
    elseif ($UninstallString -match 'unins\d{3}\.exe') {
        $Arguments = "/SILENT /NORESTART /SUPPRESSMSGBOXES"
    }
    
    try {
        Start-Process -FilePath $Command -ArgumentList $Arguments -Wait -ErrorAction Stop | Out-Null
        Write-Host "     Success." -ForegroundColor Green
    }
    catch {
        # This is not a critical error, as the file may already be gone.
    }
}

function Remove-LeftoverDirectories {
    param ([string[]]$Directories)
    if ($Directories.Count -eq 0) { return }

    Write-Host "`n[Step 5] Removing configured directories..." -ForegroundColor Yellow
    foreach ($dir in $Directories) {
        $expandedDir = [System.Environment]::ExpandEnvironmentVariables($dir)
        if (Test-Path -Path $expandedDir) {
            Write-Host "  -> Deleting directory: $expandedDir"
            Remove-Item -Path $expandedDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Host "  -> Directory not found: $expandedDir"
        }
    }
}

function Remove-RegistryValues {
    param ([array]$RegistryValues)
    if ($RegistryValues.Count -eq 0) { return }

    Write-Host "`n[Step 6a] Removing configured registry values..." -ForegroundColor Yellow
    foreach ($item in $RegistryValues) {
        if ((Get-Item -Path $item.Path -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path $item.Path -Name $item.Name -ErrorAction SilentlyContinue)) {
            Write-Host "  -> Deleting value '$($item.Name)' from '$($item.Path)'"
            Remove-ItemProperty -Path $item.Path -Name $item.Name -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Host "  -> Registry value not found: '$($item.Name)' in '$($item.Path)'"
        }
    }
}

function Remove-RegistryKeys {
    param ([string[]]$RegistryKeys)
    if ($RegistryKeys.Count -eq 0) { return }

    Write-Host "`n[Step 6b] Removing configured registry keys..." -ForegroundColor Yellow
    foreach ($key in $RegistryKeys) {
        if (Test-Path -Path $key) {
            Write-Host "  -> Deleting key: $key"
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Host "  -> Registry key not found: $key"
        }
    }
}