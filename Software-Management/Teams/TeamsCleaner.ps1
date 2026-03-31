# Script Title: Reset and Reinstall Teams Machine-Wide Installer
# Description: This script completely removes all per-user and machine-wide installations of Teams Classic, then reinstalls the latest Teams Machine-Wide Installer from a provided URL. This forces all users to get a fresh Teams profile on their next login.

# Script Name and Type
$ScriptName = "Reset and Reinstall Teams Machine-Wide Installer"
$ScriptType = "Remediation"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ### This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$tempDir = "C:\Temp\TeamsReset"
$msiName = "Teams_windows_x64.msi"
$env:msiDownloadUrl = "https://statics.teams.cdn.office.net/production-windows-x86/lkg/MSTeamsSetup.exe"

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Teams Machine-Wide Installer successfully reset. | Last Checked $Date"

# Log/Diagnostic Messaging
function write-RMMDiag ($messages) {
    Write-Host "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
$Global:DiagMsg = @()

# Alert Messaging
function write-RMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
$Global:AlertMsg = @()

# RMM Custom Field.
$Global:customFieldMessage = @()

# Script UID and intro messaging
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
$ScriptUID = GenRANDString 20
$Global:DiagMsg += "Script Type: $ScriptType"
$Global:DiagMsg += "Script Name: $ScriptName"
$Global:DiagMsg += "Script UID: $ScriptUID"
$Global:DiagMsg += "Executed On: $Date"

##################################
##################################
######## Start of Script #########

try {
    # Ensure RMM variables are present
    if (-not $env:bootstrapperUrl) {
        $env:bootstrapperUrl = "https://statics.teams.cdn.office.net/production-teamsprovision/lkg/teamsbootstrapper.exe"
        $Global:DiagMsg += "RMM variable 'bootstrapperUrl' not set, using default."
    }

    # Create temporary directory
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        $Global:DiagMsg += "Created temporary directory: $tempDir"
    }
    $bootstrapperPath = Join-Path $tempDir $bootstrapperName

    # --- 1. Download Bootstrapper (we need it for removal first) ---
    $Global:DiagMsg += "Downloading bootstrapper from: $env:bootstrapperUrl"
    try {
        Invoke-WebRequest -Uri $env:bootstrapperUrl -OutFile $bootstrapperPath -ErrorAction Stop
        $Global:DiagMsg += "Download complete: $bootstrapperPath"
    }
    catch {
        # Continue even if download fails, we might still be able to clean up
        $Global:DiagMsg += "Warning: Failed to download bootstrapper: $($_.Exception.Message). Will attempt cleanup, but install will fail."
    }

    # --- 2. Uninstall "New Teams" (MSIX) for All Users ---
    $Global:DiagMsg += "--- Starting 'New Teams' (MSIX) Removal ---"
    if (Test-Path $bootstrapperPath) {
        $Global:DiagMsg += "Running bootstrapper uninstall command (-x)..."
        $proc = Start-Process -FilePath $bootstrapperPath -ArgumentList "-x" -Wait -PassThru
        $Global:DiagMsg += "Bootstrapper uninstall finished with exit code: $($proc.ExitCode)."
    }
    else {
        $Global:DiagMsg += "Bootstrapper not found. Trying manual AppxPackage removal."
        $teamsPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "MSTeams" }
        if ($teamsPackage) {
            $Global:DiagMsg += "Found provisioned package 'MSTeams'. Removing..."
            Remove-AppxProvisionedPackage -Online -PackageName $teamsPackage.PackageName -ErrorAction SilentlyContinue
            $Global:DiagMsg += "Removed provisioned package."
        }
        else {
            $Global:DiagMsg += "No 'MSTeams' provisioned package found."
        }
    }

    # --- 3. Uninstall "Classic Teams" Machine-Wide Installer ---
    $Global:DiagMsg += "--- Removing 'Classic Teams' Machine-Wide Installer ---"
    try {
        $installer = Get-Package -Name 'Teams Machine-Wide Installer' -ErrorAction SilentlyContinue
        if ($installer) {
            $Global:DiagMsg += "Found existing Machine-Wide Installer. Removing..."
            $installer | Uninstall-Package -Force -ErrorAction Stop
            $Global:DiagMsg += "Successfully removed old installer."
        }
        else {
            $Global:DiagMsg += "No existing Machine-Wide Installer found. Skipping."
        }
    }
    catch {
        $Global:DiagMsg += "Could not remove existing Machine-Wide Installer: $($_.Exception.Message)."
    }

    # --- 4. Remove all Per-User "Classic Teams" Installations & Data ---
    $Global:DiagMsg += "--- Starting Per-User 'Classic Teams' Removal & Cleanup ---"
    $profiles = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object { $_.ProfileImagePath -like "C:\Users\*" }
    
    foreach ($profile in $profiles) {
        $profilePath = $profile.ProfileImagePath
        $localTeamsDir = Join-Path $profilePath 'AppData\Local\Microsoft\Teams'
        $roamingTeamsDir = Join-Path $profilePath 'AppData\Roaming\Microsoft\Teams'
        $updateExe = Join-Path $localTeamsDir 'Update.exe'

        if (Test-Path $updateExe) {
            $Global:DiagMsg += "Found Classic Teams for user: $($profile.PSChildName). Attempting uninstall..."
            try {
                Start-Process -FilePath $updateExe -ArgumentList "--uninstall -s" -Wait -ErrorAction Stop
                $Global:DiagMsg += "Successfully ran uninstaller."
            }
            catch {
                $Global:DiagMsg += "Failed to run uninstaller for $($profile.PSChildName): $($_.Exception.Message)."
            }
        }
        
        # Force-remove the AppData directories
        if (Test-Path $localTeamsDir) {
            $Global:DiagMsg += "Removing Local AppData folder: $localTeamsDir"
            Remove-Item -Path $localTeamsDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $roamingTeamsDir) {
            $Global:DiagMsg += "Removing Roaming AppData folder: $roamingTeamsDir"
            Remove-Item -Path $roamingTeamsDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $Global:DiagMsg += "--- Finished Per-User Teams Cleanup ---"

    # --- 5. Install New "New Teams" for All Users ---
    $Global:DiagMsg += "--- Installing 'New Teams' for All Users ---"
    if (-not (Test-Path $bootstrapperPath)) {
        throw "Teams bootstrapper was not downloaded successfully. Cannot proceed with installation."
    }

    $Global:DiagMsg += "Starting bootstrapper install command (-p)..."
    $installProc = Start-Process -FilePath $bootstrapperPath -ArgumentList "-p" -Wait -PassThru -ErrorAction Stop
    
    if ($installProc.ExitCode -eq 0) {
        $Global:DiagMsg += "Successfully provisioned 'New Teams' for all users."
    }
    else {
        throw "Bootstrapper install failed with exit code: $($installProc.ExitCode)"
    }

    # Set success message
    $Global:customFieldMessage = "All Teams versions removed. New Teams provisioned for all users. ($Date)"

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed to reset and install 'New Teams'. See diagnostics. | Last Checked $Date"
    $Global:customFieldMessage = "Script failed with an error. ($Date)"
}


######## End of Script ###########
##################################
##################################

# Write the collected information to the specified Custom Field before exiting.
if ($env:customFieldName) {
    $Global:DiagMsg += "Attempting to write '$($Global:customFieldMessage)' to Custom Field '$($env:customFieldName)'."
    try {
        Ninja-Property-Set -Name $env:customFieldName -Value $Global:customFieldMessage
        $Global:DiagMsg += "Successfully updated Custom Field."
    }
    catch {
        $Global:DiagMsg += "Error writing to Custom Field '$($env:customFieldName)': $($_.Exception.Message)"
    }
}
else {
    $Global:DiagMsg += "Custom Field name not provided in RMM variable 'customFieldName'. Skipping update."
}

if ($Global:AlertMsg) {
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-RMMAlert $Global:AlertMsg
    write-RMMDiag $Global:DiagMsg
    Exit 1
}
else {
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"
    write-RMMAlert $Global:AlertHealthy
    write-RMMDiag $Global:DiagMsg
    Exit 0
}