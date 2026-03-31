<#
.SYNOPSIS
    Resets the Microsoft Outlook profile, cache, and authentication tokens to resolve common startup and sign-in issues.
.DESCRIPTION
    This script automates the troubleshooting process for a corrupted Outlook profile. It performs the following actions:
    1. Force-closes the Outlook application.
    2. Backs up the user's current Outlook profile registry keys to the Desktop.
    3. Deletes the existing Outlook profile registry keys.
    4. Clears cached data, including Autodiscover files and Modern Authentication identity caches.
    5. Removes legacy Office credentials from Credential Manager.
    6. Sets a registry key to enforce Modern Authentication for Autodiscover.
    7. Prompts the user to relaunch Outlook, which will trigger the first-run setup wizard.
.NOTES
    Author:  Alex Ivantsov
    Date:    10/08/2025
    Version: 1.0
#>

#------------------------------------------------------------------------------------#
# --- User-Defined Variables ---
# Modify these variables as needed for your environment.
#------------------------------------------------------------------------------------#

# The full path and filename for the Outlook profiles registry backup.
$RegistryBackupPath = "$env:USERPROFILE\Desktop\OutlookProfilesBackup.reg"


#------------------------------------------------------------------------------------#
# --- Functions ---
# The core logic of the script is contained within these functions.
#------------------------------------------------------------------------------------#

Function Stop-OutlookProcess {
    <#
    .SYNOPSIS
        Checks for and terminates the Outlook process.
    #>
    Write-Host "--- Step 1: Checking for Outlook Process ---" -ForegroundColor Cyan

    $outlookProcess = Get-Process -Name "OUTLOOK" -ErrorAction SilentlyContinue

    if ($null -ne $outlookProcess) {
        Write-Host "Outlook process is running. Attempting to close it..." -ForegroundColor Yellow
        try {
            Stop-Process -Name "OUTLOOK" -Force -ErrorAction Stop
            Write-Host "Successfully terminated the Outlook process." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to terminate the Outlook process. Please close Outlook manually and re-run the script."
            # Exit the script if Outlook cannot be closed, as subsequent steps will fail.
            exit 1
        }
    }
    else {
        Write-Host "Outlook is not currently running." -ForegroundColor Green
    }
    Write-Host "" # Add a new line for better readability
}

Function Backup-And-ClearOutlookProfiles {
    <#
    .SYNOPSIS
        Backs up and then deletes the Outlook profile registry keys.
    #>
    Write-Host "--- Step 2: Backing Up and Clearing Outlook Profiles from Registry ---" -ForegroundColor Cyan

    $OutlookProfilesPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles"

    # Check if the registry key exists before trying to back it up or delete it.
    if (Test-Path -Path $OutlookProfilesPath) {
        Write-Host "Outlook profile key found. Backing up to '$RegistryBackupPath'..." -ForegroundColor White
        
        # Use reg.exe to export the key, as it's a reliable method.
        # The /y switch overwrites any existing backup file without prompting.
        $exportArgs = "export `"$OutlookProfilesPath`" `"$RegistryBackupPath`" /y"
        Start-Process -FilePath "reg.exe" -ArgumentList $exportArgs -Wait -WindowStyle Hidden
        
        Write-Host "Backup complete. Now deleting the Outlook profile key..." -ForegroundColor Yellow
        try {
            Remove-Item -Path $OutlookProfilesPath -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully deleted Outlook profiles from the registry." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to delete the Outlook profile registry key: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "No existing Outlook profiles found in the registry to back up or clear." -ForegroundColor Green
    }
    Write-Host ""
}

Function Clear-OutlookCacheAndCredentials {
    <#
    .SYNOPSIS
        Removes various Outlook cache folders and a stored credential from Credential Manager.
    #>
    Write-Host "--- Step 3: Clearing Cached Autodiscover Data and Credentials ---" -ForegroundColor Cyan

    # Define an array of folder paths to be cleared.
    $cachePaths = @(
        "$env:LOCALAPPDATA\Microsoft\Outlook",
        "$env:APPDATA\Microsoft\Outlook",
        "$env:LOCALAPPDATA\Microsoft\IdentityCache"
    )

    # Loop through each path and remove it if it exists.
    foreach ($path in $cachePaths) {
        if (Test-Path -Path $path) {
            Write-Host "Clearing cache at: $path" -ForegroundColor White
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Host "Cache path not found (already clean): $path" -ForegroundColor Green
        }
    }

    # Clear the Modern Auth credential from Credential Manager using cmdkey.exe
    Write-Host "Attempting to remove ADAL credential from Credential Manager..." -ForegroundColor White
    cmdkey.exe /delete:MicrosoftOffice16_Data:ADAL 2>$null
    Write-Host "Credential removal command executed." -ForegroundColor Green
    Write-Host ""
}

Function Set-ModernAuthRegistryKey {
    <#
    .SYNOPSIS
        Adds a registry key to ensure Outlook uses Modern Authentication for Autodiscover.
    #>
    Write-Host "--- Step 4: Enforcing Modern Authentication for Autodiscover ---" -ForegroundColor Cyan
    
    $regPath = "HKCU:\Software\Microsoft\Exchange"
    $regKeyName = "AlwaysUseMSOAuthForAutoDiscover"
    $regValue = 1

    # Ensure the parent registry path exists before trying to set a property in it.
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "Creating registry path: $regPath" -ForegroundColor Yellow
        New-Item -Path $regPath -Force | Out-Null
    }

    # Set the DWORD value. This will create the key if it doesn't exist or overwrite it if it does.
    Write-Host "Setting '$regKeyName' registry key..." -ForegroundColor White
    try {
        Set-ItemProperty -Path $regPath -Name $regKeyName -Value $regValue -Type DWord -Force -ErrorAction Stop
        Write-Host "Successfully set the Modern Authentication registry key." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to set the registry key: $($_.Exception.Message)"
    }
    Write-Host ""
}

Function Launch-Outlook {
    <#
    .SYNOPSIS
        Prompts the user to relaunch Outlook.
    #>
    Write-Host "--- Step 5: Relaunch Outlook ---" -ForegroundColor Cyan
    $response = Read-Host "Outlook has been reset. Would you like to launch it now? (y/n)"
    
    if ($response -eq 'y') {
        Write-Host "Starting Outlook..." -ForegroundColor White
        Start-Process "outlook.exe"
    }
    else {
        Write-Host "Please start Outlook manually at your convenience. The first-run setup wizard will appear." -ForegroundColor White
    }
}

#------------------------------------------------------------------------------------#
# --- Script Execution ---
# This is the main part of the script that calls the functions in order.
#------------------------------------------------------------------------------------#

Write-Host "==============================================" -ForegroundColor Magenta
Write-Host "      Starting Outlook Profile Reset Tool     " -ForegroundColor Magenta
Write-Host "==============================================" -ForegroundColor Magenta
Write-Host "This script will close Outlook, back up and clear its profiles, delete cached data, and reset authentication settings." -ForegroundColor Yellow
Write-Host ""

# Confirm with the user before proceeding with destructive actions.
$confirmation = Read-Host "Are you sure you want to continue? (y/n)"
if ($confirmation -ne 'y') {
    Write-Host "Operation cancelled by user." -ForegroundColor Red
    exit
}
Write-Host ""

# Execute all the functions sequentially.
Stop-OutlookProcess
Backup-And-ClearOutlookProfiles
Clear-OutlookCacheAndCredentials
Set-ModernAuthRegistryKey
Launch-Outlook

Write-Host ""
Write-Host "==============================================" -ForegroundColor Magenta
Write-Host "         Script has finished successfully!      " -ForegroundColor Magenta
Write-Host "==============================================" -ForegroundColor Magenta