# Script Title: Force Remove Blackpoint ZTAC Agent
# Description: This script performs a force removal of the Blackpoint ZTAC agent. It stops the service, uninstalls via MSI, and forcibly removes the driver, registry keys, and associated files. It concludes by verifying the core Blackpoint Snap Agent service is running.

# Script Name and Type
$ScriptName = "Force Remove Blackpoint ZTAC Agent"
$ScriptType = "Remediation" # Or "Remediation", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$ztacDriverPath = "C:\Windows\System32\drivers\ZtacFltr.sys"
$ztacDriverName = "ZtacFltr"
$ztacFolderPath = "C:\Program Files (x86)\Blackpoint\ZTAC"
$snapAgentPath = "C:\Program Files (x86)\Blackpoint\SnapAgent\SnapAgent.exe"
$localLogDirectory = "C:\ProgramData\Blackpoint\ZTAC"
$localLogFile = Join-Path -Path $localLogDirectory -ChildPath "ZTAC_Removal_RMM.log"


## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get' 

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# enableLocalLogging (Checkbox): Default: false. Set to 'true' to create a local log file at C:\ProgramData\Blackpoint\ZTAC\.

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

try {
    # Cast RMM variables
    [bool]$enableLocalLogging = $env:enableLocalLogging -eq 'true'

    # A simple function to centralize logging for both RMM Diag and optional local file.
    function Write-Log {
        param ([string]$message)
        
        $Global:DiagMsg += $message
        
        if ($enableLocalLogging) {
            try {
                if (-not (Test-Path $localLogDirectory)) {
                    New-Item -Path $localLogDirectory -ItemType Directory -Force | Out-Null
                }
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Add-Content -Path $localLogFile -Value "$timestamp - $message"
            }
            catch {
                $Global:DiagMsg += "Warning: Failed to write to local log file: $($_.Exception.Message)"
            }
        }
    }

    # === Cleanup Helpers ===
    function Get-ZTACGUIDs {
        $programName = "ZTAC"
        $uninstallPaths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        return $uninstallPaths | ForEach-Object {
            Get-ItemProperty -Path $_ -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*$programName*" } |
            ForEach-Object {
                [PSCustomObject]@{
                    DisplayName = $_.DisplayName
                    GUID        = Split-Path $_.PSPath -Leaf
                    PSPath      = $_.PSPath
                }
            }
        }
    }

    function Remove-RegistryKey {
        param ([string]$guid)
        $regPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$guid"
        $wowRegPath = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$guid"

        if (Test-Path $regPath) {
            Write-Log "Removing registry key: $regPath"
            try {
                Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Log "Error removing registry key $regPath : $_"
            }
        }
        if (Test-Path $wowRegPath) {
            Write-Log "Removing registry key: $wowRegPath"
            try {
                Remove-Item -Path $wowRegPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Log "Error removing registry key $wowRegPath : $_"
            }
        }
    }

    function Schedule-FileForDelete([string]$FilePath) {
        Write-Log "Scheduling locked file for deletion on next reboot: $FilePath"
        $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
        $valueName = "PendingFileRenameOperations"
        try {
            $currentValue = Get-ItemProperty -Path $regKey -Name $valueName -ErrorAction SilentlyContinue
            $newValue = if ($null -ne $currentValue) { $currentValue.PendingFileRenameOperations } else { @() }
            
            $formattedPath = "\??\$FilePath"
            $newValue += $formattedPath, ""
            
            Set-ItemProperty -Path $regKey -Name $valueName -Value $newValue -Type MultiString -Force -ErrorAction Stop
            Write-Log "Successfully scheduled file for deletion."
        }
        catch {
            Write-Log "ERROR: Could not schedule file for deletion via registry. $_"
            $Global:AlertMsg = "ZTAC Removal: Failed to schedule locked driver file for deletion. | Last Checked $Date"
        }
    }

    function Verify-SnapService {
        param ([string]$PathToCheck)
        Write-Log "Verifying status of the Blackpoint Snap service..."
        if (Test-Path $PathToCheck) {
            $snapService = Get-Service -Name "Snap" -ErrorAction SilentlyContinue
            if ($snapService) {
                if ($snapService.Status -ne 'Running') {
                    Write-Log "WARNING: Snap service was found but is NOT running. Attempting to start it."
                    try {
                        Start-Service -Name "Snap" -ErrorAction Stop
                        Write-Log "Snap service started successfully."
                    }
                    catch {
                        Write-Log "ERROR: Failed to start the Snap service: $_"
                        $Global:AlertMsg = "ZTAC Removal: Blackpoint Snap service found but failed to start. | Last Checked $Date"
                    }
                }
                else {
                    Write-Log "SUCCESS: Snap service is present and running correctly."
                }
            }
            else {
                Write-Log "ERROR: Snap service is not installed, but Snap Agent path exists. The service may be corrupted."
                $Global:AlertMsg = "ZTAC Removal: Blackpoint Snap service is missing/corrupted. | Last Checked $Date"
            }
        }
        else {
            Write-Log "INFO: Blackpoint Snap Agent not found on this system."
        }
    }

    # === Main Script Execution ===
    Write-Log "ZTAC force removal process started."
    $removalSummary = "ZTAC Removal Complete. "
    $errorsEncountered = $false

    # Step 1: Stop and remove the ZTAC service
    $ztacService = Get-Service -Name "ZTAC" -ErrorAction SilentlyContinue
    if ($ztacService) {
        Write-Log "ZTAC service found. Stopping..."
        Stop-Service -Name "ZTAC" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
        Write-Log "Removing ZTAC service..."
        try {
            sc.exe delete "ZTAC" | Out-Null
            Write-Log "ZTAC service removed successfully."
            $removalSummary += "Service removed. "
        }
        catch {
            Write-Log "Failed to remove ZTAC service: $_"
            $errorsEncountered = $true
        }
    }
    else {
        Write-Log "ZTAC service not found."
    }

    # Step 2: Attempt to uninstall via MSI package codes
    $existingEntries = Get-ZTACGUIDs
    if ($existingEntries) {
        Write-Log "Found ZTAC installation entries. Attempting MSI uninstall..."
        foreach ($entry in $existingEntries) {
            $guid = $entry.GUID
            Write-Log "Attempting to uninstall package with GUID: $guid"
            $uninstallProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x{$guid} /quiet /norestart" -Wait -PassThru
            Write-Log "MSI uninstall process for $guid finished with exit code: $($uninstallProcess.ExitCode)"
            Remove-RegistryKey -guid $guid
        }
        $removalSummary += "Registry entries cleaned. "
    }
    else {
        Write-Log "No ZTAC installation GUIDs found in registry."
    }

    # Step 3: Forcefully remove driver and files
    Write-Log "Performing final file and driver cleanup..."
    if (Test-Path $ztacDriverPath) {
        Write-Log "Attempting to unload driver: $ztacDriverName"
        fltmc.exe unload $ztacDriverName | Out-Null

        try {
            Remove-Item -Path $ztacDriverPath -Force -ErrorAction Stop
            Write-Log "Driver file deleted successfully: $ztacDriverPath"
            $removalSummary += "Driver file deleted. "
        }
        catch {
            Write-Log "Failed to delete driver file immediately. It is likely locked."
            Schedule-FileForDelete -FilePath $ztacDriverPath
            $removalSummary += "Driver file scheduled for deletion. "
        }
    }
    else {
        Write-Log "Driver file not found at $ztacDriverPath."
    }

    if (Test-Path $ztacFolderPath) {
        Write-Log "Removing ZTAC installation folder: $ztacFolderPath"
        Remove-Item -Path $ztacFolderPath -Recurse -Force -ErrorAction SilentlyContinue
        $removalSummary += "Folder removed. "
    }
    else {
        Write-Log "ZTAC installation folder not found."
    }

    Write-Log "ZTAC removal process completed."

    # Step 4: Verify the status of the Snap service
    Verify-SnapService -PathToCheck $snapAgentPath
    
    # Final Status
    if ($errorsEncountered -or $Global:AlertMsg) {
        $Global:customFieldMessage = "ZTAC removal finished with errors. See logs. ($Date)"
        if (-not $Global:AlertMsg) {
            # If no specific alert was set, set a generic one
            $Global:AlertMsg = "ZTAC removal script finished but encountered one or more errors. | Last Checked $Date"
        }
    }
    else {
        $Global:customFieldMessage = "$($removalSummary.Trim()) ($Date)"
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