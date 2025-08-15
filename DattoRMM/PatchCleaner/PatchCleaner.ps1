#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Automates the PatchCleaner utility to safely clean the C:\Windows\Installer folder.
.DESCRIPTION
    This script checks if PatchCleaner is installed. If not, it prompts the user to
    download and install it automatically. It then provides a menu to either move
    or delete orphaned installer files. The 'Move' option is recommended for safety.
.NOTES
    Author: Gemini
    Prerequisite: An active internet connection for the initial setup.
#>

# --- 1. Find or Install PatchCleaner ---
Write-Host "Searching for PatchCleaner.exe..." -ForegroundColor Cyan

# Define possible installation paths and the download URL
$possiblePaths = @(
    "$env:ProgramFiles\HomeDev\PatchCleaner\PatchCleaner.exe",
    "$env:ProgramFiles(x86)\HomeDev\PatchCleaner\PatchCleaner.exe"
)
$downloadUrl = "https://files4.majorgeeks.com/1f0a990e3eb119bf19039e10bdaf771ec6dbb570/drives/PatchCleaner_1.4.2.0.exe"
$installerTempPath = Join-Path $env:TEMP "PatchCleanerInstaller.exe"

# Find the first path that exists
$patchCleanerPath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

# If not found, prompt to download and install
if (-not $patchCleanerPath) {
    Write-Host "PatchCleaner not found." -ForegroundColor Yellow
    $permission = Read-Host "Would you like to download and install it automatically? (Y/N)"
    
    if ($permission -eq 'Y') {
        try {
            # --- Download ---
            Write-Host "Downloading from MajorGeeks..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerTempPath
            Write-Host "Download complete." -ForegroundColor Green

            # --- Install ---
            Write-Host "Installing silently... Please wait." -ForegroundColor Cyan
            # Use /VERYSILENT for an unattended installation and -Wait to pause the script
            Start-Process -FilePath $installerTempPath -ArgumentList "/VERYSILENT" -Wait -ErrorAction Stop
            Write-Host "Installation complete." -ForegroundColor Green

            # --- Clean up installer file ---
            Remove-Item $installerTempPath -Force
        }
        catch {
            Write-Host "ERROR: An error occurred during download or installation." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            Read-Host "Press Enter to exit."
            exit
        }
        
        # --- Re-check for the path after installation ---
        $patchCleanerPath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $patchCleanerPath) {
            Write-Host "ERROR: Installation seems to have failed. Could not find PatchCleaner.exe." -ForegroundColor Red
            Read-Host "Press Enter to exit."
            exit
        }
    }
    else {
        Write-Host "Script cannot continue without PatchCleaner. Exiting." -ForegroundColor Yellow
        Read-Host "Press Enter to exit."
        exit
    }
}

Write-Host "Found PatchCleaner at: $patchCleanerPath" -ForegroundColor Green
Write-Host "" # Newline for spacing

# --- 2. Display User Menu ---
while ($true) {
    Write-Host "What action would you like to perform?" -ForegroundColor Cyan
    Write-Host "  [1] Move orphaned files (Safest Option)"
    Write-Host "  [2] Delete orphaned files (Permanent)"
    Write-Host "  [Q] Quit"
    $choice = Read-Host "Enter your choice (1, 2, or Q)"

    switch ($choice) {
        '1' {
            # --- Move Action ---
            $destination = Read-Host "Enter the full path to move the files to (e.g., D:\Installer_Backup)"
            if ([string]::IsNullOrWhiteSpace($destination)) {
                Write-Host "Path cannot be empty. Please try again." -ForegroundColor Yellow
                continue
            }

            if (-not (Test-Path $destination)) {
                $createPath = Read-Host "The path '$destination' does not exist. Create it now? (Y/N)"
                if ($createPath -eq 'Y') {
                    try {
                        New-Item -Path $destination -ItemType Directory -ErrorAction Stop | Out-Null
                        Write-Host "Successfully created directory: $destination" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "ERROR: Failed to create directory. Please check permissions." -ForegroundColor Red
                        continue
                    }
                }
                else {
                    Write-Host "Action cancelled." -ForegroundColor Yellow
                    continue
                }
            }
            
            Write-Host "Executing PatchCleaner to MOVE orphaned files..." -ForegroundColor Cyan
            & $patchCleanerPath /m "$destination"
            break
        }
        '2' {
            # --- Delete Action ---
            $confirmation = Read-Host "WARNING: This will permanently delete files. Are you absolutely sure? (Y/N)"
            if ($confirmation -eq 'Y') {
                Write-Host "Executing PatchCleaner to DELETE orphaned files..." -ForegroundColor Cyan
                & $patchCleanerPath /d
            }
            else {
                Write-Host "Delete action cancelled." -ForegroundColor Yellow
            }
            break
        }
        'Q' {
            # --- Quit Action ---
            Write-Host "Exiting script."
            exit
        }
        default {
            Write-Host "Invalid choice. Please select 1, 2, or Q." -ForegroundColor Yellow
        }
    }
}

Write-Host "" # Newline
Write-Host "Process complete." -ForegroundColor Green
Read-Host "Press Enter to close this window."