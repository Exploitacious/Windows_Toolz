# Script Title: Device Decommissioning and Secure Wipe
# Description: Performs a secure decommission of a device by either rapidly disabling it (corrupting bootloader, clearing TPM) or by securely wiping the drive's free space with SDelete. It also backs up the final BitLocker key.

# Script Name and Type
$ScriptName = "Device Decommissioning and Secure Wipe"
$ScriptType = "Remediation" # This script performs a destructive action.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$finalKeyCustomField = 'decomFinalKey'
$orgBitlockerCF = 'bitlockerDecryptionKey'
$tempDir = 'C:\Temp\NinjaDecommission'
$env:customFieldName = "decomDeviceInfo"

## ORG-LEVEL EXPECTED VARIABLES ##
# This script expects an Organization-level Custom Field to check against the current BitLocker key.

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the final status to.
# decommissionMode (Dropdown: SecureWipe,QuickDisable): The decommissioning method to use. 'SecureWipe' is a lengthy, forensic data wipe. 'QuickDisable' is a fast method to make a device unbootable. Default: SecureWipe.
# sdeletePasses (Number): For SecureWipe mode, the number of overwrite passes for SDelete. Default: 1.
# rebootAfterwards (Checkbox): Reboot or shut down the machine after the operation is complete. Default: true.


# What to Write if Alert is Healthy
$Global:AlertHealthy = "Decommissioning script completed its task successfully. | Last Checked $Date"

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
###### Custom Functions ##########

function Invoke-MaximumPerformanceMode {
    <#
    .SYNOPSIS
        Configures the system for maximum performance and uptime to prevent interruptions.
    #>
    $Global:DiagMsg += "--- Activating Maximum Performance Mode ---"
    try {
        # Part 1: Configure Power Settings using powercfg.exe
        $Global:DiagMsg += "Setting power and sleep timeouts to 'Never' (0 minutes) for the active power scheme..."

        # CORRECTED: Removed the unnecessary GUID. These commands modify the active scheme by default.
        powercfg /change -monitor-timeout-ac 0
        powercfg /change -monitor-timeout-dc 0
        powercfg /change -disk-timeout-ac 0
        powercfg /change -disk-timeout-dc 0
        powercfg /change -standby-timeout-ac 0
        powercfg /change -standby-timeout-dc 0
        powercfg /change -hibernate-timeout-ac 0
        powercfg /change -hibernate-timeout-dc 0
        
        $Global:DiagMsg += "Power settings successfully updated."

        # Part 2: Configure Registry to Hide Power Options
        $Global:DiagMsg += "Configuring registry to hide shutdown/restart options..."
        $explorerPolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        $systemPolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

        if (-not (Test-Path $explorerPolicyPath)) {
            New-Item -Path $explorerPolicyPath -Force | Out-Null
        }
        if (-not (Test-Path $systemPolicyPath)) {
            New-Item -Path $systemPolicyPath -Force | Out-Null
        }

        Set-ItemProperty -Path $explorerPolicyPath -Name "NoClose" -Value 1 -Type DWord -Force
        $Global:DiagMsg += "Set HKLM:...\Explorer\NoClose = 1"

        Set-ItemProperty -Path $systemPolicyPath -Name "ShutdownWithoutLogon" -Value 0 -Type DWord -Force
        $Global:DiagMsg += "Set HKLM:...\System\ShutdownWithoutLogon = 0"

        $Global:DiagMsg += "Registry successfully configured."
        $Global:DiagMsg += "--- Maximum Performance Mode is ACTIVE ---"
    }
    catch {
        throw "Failed to activate Maximum Performance Mode: $($_.Exception.Message)"
    }
}

function Get-TpmAuditInfo {
    <#
    .SYNOPSIS
        Audits the TPM status using the Get-Tpm cmdlet.
    .DESCRIPTION
        This function retrieves the TPM object and formats its key properties into a single diagnostic string. It includes error handling for systems where the TPM is not present or the command fails.
    .OUTPUTS
        [string] A formatted string detailing the TPM status.
    #>
    try {
        $Global:DiagMsg += "Auditing TPM..."
        $tpm = Get-Tpm
        $tpmStatus = "TPM Status: Present=$($tpm.TpmPresent), Ready=$($tpm.TpmReady), Enabled=$($tpm.TpmEnabled), Activated=$($tpm.TpmActivated), Owned=$($tpm.TpmOwned)"
        $Global:DiagMsg += $tpmStatus
        return $tpmStatus
    }
    catch {
        $errorMessage = "TPM Status: Could not retrieve TPM information. It may not be present or enabled. Error: $($_.Exception.Message)"
        $Global:DiagMsg += $errorMessage
        return $errorMessage
    }
}

function Handle-BitLockerPrerequisites {
    <#
    .SYNOPSIS
        Ensures the OS drive is encrypted and its key is backed up before decommissioning.
    .DESCRIPTION
        This function uses the robust Get-BitLockerVolume cmdlet to check the C: drive.
        - If encrypted, it grabs the current recovery key and saves it to the 'decomFinalKey' custom field.
        - If not encrypted, it enables BitLocker using the TPM, then saves the new key.
        This is a critical prerequisite to ensure data can be recovered if the decommission is halted, while guaranteeing the device is secure before wiping.
    #>
    $Global:DiagMsg += "--- Starting BitLocker Prerequisite Check (v2) ---"
    Get-TpmAuditInfo | Out-Null # Run the TPM audit and add its output to the diagnostics
    
    $mountPoint = "C:"
    $driveLetter = "C"

    try {
        $bitlockerVolume = Get-BitLockerVolume -MountPoint $mountPoint
        
        # --- CASE A: BitLocker is ON ---
        if ($bitlockerVolume.ProtectionStatus -eq 'On') {
            $Global:DiagMsg += "BitLocker is ON for $mountPoint. Verifying recovery key protector."
            $keyProtector = $bitlockerVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
            
            if ($keyProtector -and $keyProtector.RecoveryPassword) {
                $recoveryKey = $keyProtector.RecoveryPassword
                $Global:DiagMsg += "Found recovery key for $mountPoint. Backing it up to '$finalKeyCustomField'."
                Ninja-Property-Set -Name $finalKeyCustomField -Value "$($driveLetter):$($recoveryKey)"
                $Global:DiagMsg += "Successfully backed up final recovery key."
            }
            else {
                throw "BitLocker is on, but NO recovery key protector was found for $mountPoint. Cannot proceed."
            }
        }
        # --- CASE B: BitLocker is OFF ---
        else {
            $Global:DiagMsg += "BitLocker is OFF for $mountPoint. Remediation is required."
            $Global:DiagMsg += "Attempting to enable BitLocker on $mountPoint..."
            
            # Use the most compatible settings for automated enablement.
            Enable-BitLocker -MountPoint $mountPoint -TpmProtector -EncryptionMethod Aes256
            $Global:DiagMsg += "Waiting for encryption process to generate key..."
            Start-Sleep -Seconds 20
            
            # Re-check the volume to get the new key
            $newBlVolume = Get-BitLockerVolume -MountPoint $mountPoint
            $newProtector = $newBlVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }

            if ($newProtector -and $newProtector.RecoveryPassword) {
                $recoveryKey = $newProtector.RecoveryPassword
                $Global:DiagMsg += "Successfully enabled BitLocker. Backing up new key to '$finalKeyCustomField'."
                Ninja-Property-Set -Name $finalKeyCustomField -Value "$($driveLetter):$($recoveryKey)"
                $Global:DiagMsg += "Successfully backed up new recovery key."
            }
            else {
                throw "Enabled BitLocker on $mountPoint, but failed to retrieve the new recovery key."
            }
        }
    }
    catch {
        # This will catch errors from Get-BitLockerVolume or any other part of the process
        throw "A critical error occurred during BitLocker prerequisite handling for $mountPoint : $($_.Exception.Message)"
    }
    $Global:DiagMsg += "--- Finished BitLocker Prerequisite Check ---"
}

function Invoke-QuickDisable {
    $Global:DiagMsg += "--- Starting Quick Disable Process ---"

    $Global:DiagMsg += "Clearing Credential Manager..."
    try {
        $Global:DiagMsg += "INFO: Clearing cached credentials from Credential Manager..."
        cmdkey /list | ForEach-Object {
            # Find lines that contain a target and extract the target name.
            if ($_ -match '^\s*Target:\s*(.*)$') {
                $target = $Matches[1]
                cmdkey /delete:$target
            }
        }
    }
    catch {
        $Global:DiagMsg += "Failed to clear credential manager: $($_.Exception.Message). This may not prevent boot."
    }
    
    # Corrupt the Boot Configuration Data (BCD) with multiple commands
    $Global:DiagMsg += "Corrupting the Windows Bootloader (BCD) by deleting key entries..."
    try {
        # Target the default OS loader entry - this is the most critical command.
        $Global:DiagMsg += "Attempting to delete the {default} OS entry..."
        bcdedit /delete '{default}' /f

        # Target the currently running OS entry (which also handles hibernation resume).
        $Global:DiagMsg += "Attempting to delete the {current} OS entry..."
        bcdedit /delete '{current}' /f

        # Target the main boot manager entry as a final step.
        $Global:DiagMsg += "Attempting to delete the {bootmgr} entry..."
        bcdedit /delete '{bootmgr}' /f

        $Global:DiagMsg += "Successfully issued all BCD deletion commands. Errors for non-existent entries are expected."
    } 
    catch {
        # This will only catch a catastrophic failure of bcdedit itself.
        $Global:DiagMsg += "A critical error occurred while running bcdedit: $($_.Exception.Message)"
    }

    $Global:DiagMsg += "Removing non-recovery key protectors."
    try {
        $AllProtectors = (Get-BitLockerVolume -MountPoint $env:SystemDrive).KeyProtector
        foreach ($Protector in $AllProtectors) {
            if ($Protector.KeyProtectorType -ne "RecoveryPassword") {
                $Global:DiagMsg += "Removing protector ID $($Protector.KeyProtectorId) of type $($Protector.KeyProtectorType)..."
                Remove-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $Protector.KeyProtectorId
            }
        }
        $Global:DiagMsg += "Successfully removed all non-recovery key protectors."
    }
    catch {
        $Global:DiagMsg += "WARNING: An error occurred while removing key protectors. $_"
    }

    $Global:DiagMsg += "Resetting the TPM. This will clear TPM keys."
    try {
        Clear-Tpm -UsePPI
        $Global:DiagMsg += "TPM reset command issued successfully."
    }
    catch {
        $Global:DiagMsg += "Could not clear the TPM (it may not be present or enabled): $($_.Exception.Message)"
    }
    
    $Global:DiagMsg += "--- Quick Disable Process Complete ---"
}

function Invoke-SecureWipe {
    param(
        [int]$Passes = 1
    )

    # Check for an existing SDelete process before starting.
    $Global:DiagMsg += "Checking for an existing SDelete process..."
    $existingProcess = Get-Process -Name "sdelete64" -ErrorAction SilentlyContinue

    if ($existingProcess) {
        $processId = $existingProcess.Id
        $Global:DiagMsg += "SDelete is already running with Process ID: $processId. Please allow time for SDelete to complete its passes."
        # Exit the function immediately since the wipe is already in progress.
        return
    }

    $Global:DiagMsg += "--- Starting Secure Wipe Process ---"
    $sdeleteUrl = 'https://download.sysinternals.com/files/SDelete.zip'
    $sdeleteZipPath = Join-Path $tempDir "SDelete.zip"
    $sdeleteExePath = Join-Path $tempDir "sdelete64.exe"

    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory | Out-Null
        $Global:DiagMsg += "Created temporary directory: $tempDir"
    }

    if (-not (Test-Path $sdeleteExePath)) {
        $Global:DiagMsg += "Downloading SDelete..."
        Invoke-WebRequest -Uri $sdeleteUrl -OutFile $sdeleteZipPath
        $Global:DiagMsg += "Extracting SDelete..."
        Expand-Archive -Path $sdeleteZipPath -DestinationPath $tempDir -Force
    }

    if (-not (Test-Path $sdeleteExePath)) {
        throw "Failed to find sdelete64.exe after download and extraction."
    }

    # Identify all fixed drives and loop through them.
    $Global:DiagMsg += "Identifying all fixed NTFS drives to wipe..."
    $drivesToWipe = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter -and $_.FileSystemType -eq 'NTFS' }

    if (-not $drivesToWipe) {
        throw "No fixed NTFS drives found to wipe. This is unexpected and prevents the script from proceeding."
    }

    $Global:DiagMsg += "Found NTFS drives to wipe: $($drivesToWipe.DriveLetter -join ', ')"

    foreach ($drive in $drivesToWipe) {
        $driveLetter = $drive.DriveLetter
        $mountPoint = "$($driveLetter):"

        $Global:DiagMsg += "Launching SDelete with $Passes pass(es) in the background for drive $mountPoint."
        $sdeleteArgs = @(
            "-p", $Passes,
            "-z",
            "-nobanner",
            $mountPoint
        )
    }

    try {
        $Global:DiagMsg += "Executing SDelete with $Passes pass(es) to zero free space on C: drive. This may take a long time."
        Start-Process -FilePath $sdeleteExePath -ArgumentList $sdeleteArgs -NoNewWindow
    }
    catch {
        $Global:DiagMsg += "Failed to launch SDelete with parameters: $sdeleteArgs : ErrorMessage : $($_.Exception.Message)"
    }
    
    $Global:DiagMsg += "--- SDELETE Wipe Process Started ---"
}


##################################
##################################
######## Start of Script #########

try {
    # Validate and cast RMM parameters
    $decommissionMode = $env:decommissionMode
    if (-not ($decommissionMode -in @('QuickDisable', 'SecureWipe'))) {
        throw "Invalid decommissionMode specified: '$decommissionMode'. Must be 'QuickDisable' or 'SecureWipe'."
    }
    $sdeletePasses = 1
    if ($env:sdeletePasses) {
        try { $sdeletePasses = [int]$env:sdeletePasses }
        catch { throw "Could not convert sdeletePasses '$($env:sdeletePasses)' to an integer." }
    }
    $rebootAfterwards = $true
    if ($env:rebootAfterwards) {
        try { $rebootAfterwards = [bool]$env:rebootAfterwards }
        catch { throw "Could not convert rebootAfterwards '$($env:rebootAfterwards)' to a boolean." }
    }
    $Global:DiagMsg += "Mode: $decommissionMode, SDelete Passes: $sdeletePasses, Reboot: $rebootAfterwards"

    # Disable Power Options and Sleep
    Invoke-MaximumPerformanceMode

    # Handle BitLocker key backup
    Handle-BitLockerPrerequisites

    # Execute the chosen decommission mode
    if ($decommissionMode -eq 'QuickDisable') {
        Invoke-QuickDisable
        $Global:customFieldMessage = "Quick Disable completed successfully. Bootloader corrupted and TPM cleared. ($Date)"

        if ($rebootAfterwards) {
            $Global:DiagMsg += "Final destructive action complete. Rebooting machine..."
            Shutdown.exe -r -t 15
        }
        else {
            $Global:DiagMsg += "Final destructive action complete. Shutdown skipped as per configuration."
        }
    } 
    
    if ($decommissionMode -eq 'SecureWipe') {
        # First, run the full secure wipe process.
        Invoke-SecureWipe -Passes $sdeletePasses
        
        # Next, run the quick disable process to corrupt the bootloader and TPM.
        $Global:DiagMsg += "S-Delete Secure Wipe verified. Proceeding with disablement actions."
        Invoke-QuickDisable

        # Update the final status message to reflect that both actions were taken.
        $Global:customFieldMessage = "Combined Secure Wipe and disablement actions successfully launched. ($Date)"

        if ($rebootAfterwards) {
            $Global:DiagMsg += "Please allow time for the machine to securely erase all data."
            $Global:DiagMsg += "If you would like this computer to quickly reboot and be disabled, please run this script again in 'Quick Disable' mode."
        }
        else {
            $Global:DiagMsg += "Final destructive actions launched. Please allow time for the machine to securely erase all data."
        }
    }

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. DESTRUCTIVE ACTIONS MAY HAVE FAILED. | Last Checked $Date"
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