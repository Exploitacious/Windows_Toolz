<#
.SYNOPSIS
    Irreversibly deletes saved passwords from Chromium-based browsers (Chrome, Edge, Brave)
    and Firefox for all user profiles on the local machine.

.DESCRIPTION
    This script performs a destructive action to enhance security by removing all stored
    login credentials from major web browsers. It operates by:
    1.  Checking for Administrator privileges, which are required for some actions.
    2.  Optionally setting a policy to disable password synchronization in Google Chrome.
    3.  Terminating all running browser processes to release file locks.
    4.  Iterating through every user profile on the computer.
    5.  For each user, it locates and deletes the specific files and SQLite databases
        where passwords are stored for each supported browser.

.PARAMETER DisableChromeSync
    A switch parameter that, if present, will set a Windows policy to disable
    password and data synchronization in Google Chrome. Requires Administrator rights.

.NOTES
    Author:      Alex Ivantsov
    Version:     2.0
    Created:     2025-06-10
    Requires:    Administrator privileges for full functionality (e.g., stopping processes
                 for other users and setting Chrome policy).
    
    WARNING: THIS SCRIPT'S ACTIONS ARE IRREVERSIBLE. PASSWORDS CANNOT BE RECOVERED
             AFTER THE SCRIPT IS RUN.
#>

[CmdletBinding()]
param (
    [switch]$DisableChromeSync
)

#==============================================================================
# SCRIPT-WIDE CONFIGURATION & INITIALIZATION
#==============================================================================

# Use 'Stop' to turn terminating errors into exceptions, allowing try/catch blocks to handle them.
$ErrorActionPreference = 'Stop'

# Define browser targets in a structured list for easy management and scaling.
$BrowserTargets = @(
    @{
        Name        = "Google Chrome"
        ProcessName = "chrome"
        Path        = "AppData\Local\Google\Chrome\User Data"
        Type        = "Chromium"
    },
    @{
        Name        = "Microsoft Edge"
        ProcessName = "msedge"
        Path        = "AppData\Local\Microsoft\Edge\User Data"
        Type        = "Chromium"
    },
    @{
        Name        = "Brave Browser"
        ProcessName = "brave"
        Path        = "AppData\Local\BraveSoftware\Brave-Browser\User Data"
        Type        = "Chromium"
    },
    @{
        Name        = "Mozilla Firefox"
        ProcessName = "firefox"
        Path        = "AppData\Roaming\Mozilla\Firefox\Profiles"
        Type        = "Firefox"
    }
)

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

function Test-IsAdmin {
    # Returns $true if the script is running with elevated (Administrator) permissions.
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Warning "Failed to check for administrator privileges. Assuming non-admin."
        return $false
    }
}

function Get-AllUserProfiles {
    # Retrieves all user profile directories, excluding system/public accounts.
    $ExcludedUsers = @('Default', 'Default User', 'Public', 'All Users')
    Get-ChildItem -Path 'C:\Users' -Directory | Where-Object { $_.Name -notin $ExcludedUsers }
}

function Stop-BrowserProcesses {
    param(
        [string[]]$ProcessNames
    )
    
    foreach ($ProcessName in $ProcessNames) {
        Write-Verbose "Attempting to stop processes named '$ProcessName'."
        $Processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        
        if ($Processes) {
            Write-Output "Stopping $ProcessName processes..."
            $Processes | Stop-Process -Force
            Write-Output "$ProcessName processes stopped."
        }
    }
}

#==============================================================================
# MAIN LOGIC
#==============================================================================

# --- PRE-FLIGHT CHECKS AND SETUP ---

Write-Output "Starting browser password removal process..."
Write-Warning "THIS ACTION IS IRREVERSIBLE AND WILL DELETE SAVED PASSWORDS."

$IsAdmin = Test-IsAdmin

if ($DisableChromeSync.IsPresent) {
    if ($IsAdmin) {
        try {
            Write-Output "Disabling Google Chrome synchronization via policy..."
            $PolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
            # Ensure the registry key exists before setting the property.
            if (-not (Test-Path $PolicyPath)) {
                New-Item -Path $PolicyPath -Force | Out-Null
            }
            Set-ItemProperty -Path $PolicyPath -Name "SyncDisabled" -Value 1
            Write-Output "Chrome synchronization policy has been set."
        }
        catch {
            Write-Warning "Failed to set Chrome synchronization policy. Error: $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "Administrator privileges are required to disable Chrome Sync. Skipping."
    }
}

# --- PROCESS TERMINATION ---

# Stop all relevant browser processes to unlock database files.
$AllProcessNames = $BrowserTargets.ProcessName | Select-Object -Unique
Stop-BrowserProcesses -ProcessNames $AllProcessNames -ErrorAction SilentlyContinue

# --- PASSWORD FILE REMOVAL ---

# Get the list of users once to avoid redundant calls.
$UserProfiles = Get-AllUserProfiles
Write-Output "Found $($UserProfiles.Count) user profiles to process."

foreach ($UserProfile in $UserProfiles) {
    Write-Output "--- Processing user: $($UserProfile.Name) ---"
    
    foreach ($Browser in $BrowserTargets) {
        Write-Verbose "Checking for $($Browser.Name) data for user $($UserProfile.Name)"
        $BrowserDataPath = Join-Path -Path $UserProfile.FullName -ChildPath $Browser.Path
        
        if (Test-Path $BrowserDataPath) {
            Write-Output "Found $($Browser.Name) data. Clearing passwords..."
            try {
                if ($Browser.Type -eq 'Chromium') {
                    # For Chromium, find all profiles (Default, Profile 1, etc.) and replace 'Login Data'.
                    Get-ChildItem -Path $BrowserDataPath -Directory | ForEach-Object {
                        $LoginDataFile = Join-Path -Path $_.FullName -ChildPath "Login Data"
                        if (Test-Path $LoginDataFile) {
                            Write-Verbose "Replacing file: $LoginDataFile"
                            # Overwrite the file with a new, empty file.
                            New-Item -Path $LoginDataFile -ItemType File -Force | Out-Null
                        }
                    }
                }
                elseif ($Browser.Type -eq 'Firefox') {
                    # For Firefox, find all profiles and delete the password/key files.
                    Get-ChildItem -Path $BrowserDataPath -Directory | ForEach-Object {
                        $LoginsFile = Join-Path -Path $_.FullName -ChildPath "logins.json"
                        $KeyFile = Join-Path -Path $_.FullName -ChildPath "key4.db"
                        
                        if (Test-Path $LoginsFile) {
                            Write-Verbose "Removing file: $LoginsFile"
                            Remove-Item -Path $LoginsFile -Force
                        }
                        if (Test-Path $KeyFile) {
                            Write-Verbose "Removing file: $KeyFile"
                            Remove-Item -Path $KeyFile -Force
                        }
                    }
                }
                Write-Output "Successfully cleared $($Browser.Name) passwords."
            }
            catch {
                Write-Warning "Could not clear passwords for $($Browser.Name). Error: $($_.Exception.Message)"
            }
        }
    }
}

Write-Output "------------------------------------------"
Write-Output "Password removal process completed."