# Script Title: Datto RMM Agent Removal
# Description: This script performs a comprehensive removal of the Datto RMM (formerly AEM/CentraStage) agent. It terminates the agent processes, runs the uninstaller silently, and then cleans up residual files, folders, and registry entries.

# Script Name and Type
$ScriptName = "Datto RMM Agent Removal"
$ScriptType = "Remediation" # Or "Remediation", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$DattoInstallDir = "C:\Program Files (x86)\CentraStage"

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get' 
# None for this script

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# uninstallWaitSeconds (Text, Default: 30): The number of seconds to wait for the silent uninstaller to complete before proceeding with file cleanup.


# What to Write if Alert is Healthy
$Global:AlertHealthy = "System state is nominal. | Last Checked $Date"

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
function Test-NinjaAgentHealth {
    $Global:DiagMsg += "--- Starting Ninja RMM Health Check ---"
    $ninjaInstallDir = "C:\Program Files (x86)\NinjaOne"
    $ninjaServiceName = "NinjaRMMAgent"
    $isHealthy = $true

    # Check 1: Installation Directory
    if (-not (Test-Path -Path $ninjaInstallDir -PathType Container)) {
        $Global:DiagMsg += "Ninja RMM Health Check FAIL: Installation directory not found at '$ninjaInstallDir'."
        $isHealthy = $false
    }
    else {
        $Global:DiagMsg += "Ninja RMM Health Check PASS: Installation directory found."
    }

    # Check 2: Service Status
    try {
        $ninjaService = Get-Service -Name $ninjaServiceName -ErrorAction Stop
        if ($ninjaService.Status -ne 'Running') {
            $Global:DiagMsg += "Ninja RMM Health Check FAIL: Service '$ninjaServiceName' is present but not running. Status: $($ninjaService.Status)."
            $isHealthy = $false
        }
        else {
            $Global:DiagMsg += "Ninja RMM Health Check PASS: Service '$ninjaServiceName' is running."
        }
    }
    catch {
        $Global:DiagMsg += "Ninja RMM Health Check FAIL: Service '$ninjaServiceName' not found or could not be queried."
        $isHealthy = $false
    }
    
    return $isHealthy
}

try {
    # Cast RMM variables to their correct types
    $wait = if ($env:uninstallWaitSeconds) { [int]$env:uninstallWaitSeconds } else { 30 }
    $Global:DiagMsg += "Configuration: Wait time set to $wait seconds."

    # Initial check: If the main Datto directory doesn't exist, assume it's already uninstalled.
    if (-not (Test-Path -Path $DattoInstallDir -PathType Container)) {
        $Global:DiagMsg += "Datto RMM installation directory '$DattoInstallDir' not found. Agent is likely already removed."
        $Global:customFieldMessage = "Datto RMM not detected. No action taken. ($Date)"
    }
    else {
        # --- Step 1: Terminate Datto RMM Processes ---
        $Global:DiagMsg += "Attempting to stop Datto RMM processes."
        $dattoProcessNames = @(
            "CentraStage",
            "CagService",
            "AEMAgent"
        )

        foreach ($processName in $dattoProcessNames) {
            $dattoProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($dattoProcess) {
                try {
                    Stop-Process -Name $processName -Force -ErrorAction Stop
                    $Global:DiagMsg += "Process '$($processName)' terminated successfully."
                }
                catch {
                    $Global:DiagMsg += "Failed to terminate process '$($processName)': $($_.Exception.Message)"
                }
            }
            else {
                $Global:DiagMsg += "Process '$($processName)' was not running."
            }
        }

        # --- Step 2: Run Silent Uninstaller ---
        $uninstallerPath = Join-Path -Path $DattoInstallDir -ChildPath "uninst.exe"
        if (Test-Path -Path $uninstallerPath) {
            $Global:DiagMsg += "Executing silent uninstaller at '$uninstallerPath'."
            Start-Process -FilePath $uninstallerPath -ArgumentList "/S" -Wait -ErrorAction SilentlyContinue
            $Global:DiagMsg += "Uninstaller process completed. Waiting for $wait seconds before cleanup."
            Start-Sleep -Seconds $wait
        }
        else {
            $Global:DiagMsg += "Uninstaller not found at '$uninstallerPath'. Proceeding directly to cleanup."
        }

        # --- Step 3: Cleanup Residual Directories ---
        $Global:DiagMsg += "Performing cleanup of residual directories."
        $dirsToRemove = @(
            $DattoInstallDir,
            "C:\Windows\System32\config\systemprofile\AppData\Local\CentraStage",
            "C:\Windows\SysWOW64\config\systemprofile\AppData\Local\CentraStage",
            "$env:USERPROFILE\AppData\Local\CentraStage",
            "$env:ALLUSERSPROFILE\CentraStage"
        )

        foreach ($dir in $dirsToRemove) {
            if (Test-Path -Path $dir) {
                try {
                    Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
                    $Global:DiagMsg += "Successfully removed directory: $dir"
                }
                catch {
                    $Global:DiagMsg += "Failed to remove directory '$dir': $($_.Exception.Message)"
                }
            }
            else {
                $Global:DiagMsg += "Directory not found, skipping: $dir"
            }
        }

        # --- Step 4: Cleanup Registry Entry ---
        $regPath = "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"
        $regValueName = "CentraStage"
        $Global:DiagMsg += "Checking for registry startup entry."
        if (Get-ItemProperty -Path $regPath -Name $regValueName -ErrorAction SilentlyContinue) {
            try {
                Remove-ItemProperty -Path $regPath -Name $regValueName -Force -ErrorAction Stop
                $Global:DiagMsg += "Successfully removed registry entry '$regValueName' from '$regPath'."
            }
            catch {
                $Global:DiagMsg += "Failed to remove registry entry '$regValueName': $($_.Exception.Message)"
            }
        }
        else {
            $Global:DiagMsg += "Registry startup entry not found."
        }

        # --- Step 5: Final Verification ---
        if (Test-Path -Path $DattoInstallDir -PathType Container) {
            # This is a hard failure, Datto removal did not work.
            $Global:AlertMsg = "Datto RMM removal failed. The main installation directory still exists. Manual intervention may be required. | Last Checked $Date"
            $Global:customFieldMessage = "Datto RMM removal failed. ($Date)"
        }
        else {
            # Datto removal was successful, now check Ninja's health.
            $Global:DiagMsg += "Verification successful. Datto RMM installation directory no longer exists."
            
            if (Test-NinjaAgentHealth) {
                # Ideal state: Datto is gone and Ninja is healthy.
                $Global:customFieldMessage = "Datto RMM removed successfully and Ninja RMM agent is healthy. ($Date)"
            }
            else {
                # Datto is gone, but Ninja is not healthy. This requires an alert.
                $Global:AlertMsg = "Datto RMM was removed, but the Ninja RMM agent is not installed or running correctly. Please investigate. | Last Checked $Date"
                $Global:customFieldMessage = "Datto RMM removed, but Ninja RMM agent is unhealthy. ($Date)"
            }
        }
    }
}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
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