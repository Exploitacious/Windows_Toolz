# Script Title: Device Decommissioning and Secure Wipe
# Description: Performs a secure decommission of a device by either rapidly disabling it (corrupting bootloader, clearing TPM) or by securely wiping the drive's free space with SDelete. It also backs up the final BitLocker key.

# Script Name and Type
$ScriptName = "Device Decommissioning and Secure Wipe"
$ScriptType = "Remediation" # This script performs a destructive action.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ### This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$finalKeyCustomField = 'decomFinalKey'
$orgBitlockerCF = 'bitlockerDecryptionKey'
$tempDir = 'C:\Temp\NinjaDecommission'
$env:customFieldName = "decomDeviceInfo"

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# corruptBootloader (Checkbox): If checked, will also corrupt the bootloader (BCD) to make the device unbootable. Default: false.
# finalAction (Dropdown: SecureWipe,Reboot): The final action to take. 'SecureWipe' launches SDelete. 'Reboot' finalizes the Quick Disable. Default: Reboot.
# sdeletePasses (Number): For SecureWipe mode, the number of overwrite passes for SDelete. Default: 1.

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
        - If not encrypted, it attempts to enable BitLocker using the TPM.
        - If enabling fails (e.g., no TPM), it throws a terminating error to be caught by the main script.
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
            # CRITICAL FIX: Added -ErrorAction Stop to force a terminating error on TPM failure.
            Enable-BitLocker -MountPoint $mountPoint -TpmProtector -EncryptionMethod Aes256 -ErrorAction Stop
            
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
                # This 'throw' should now only be reachable if BitLocker enabled but somehow failed to make a key.
                throw "Enabled BitLocker on $mountPoint, but failed to retrieve the new recovery key."
            }
        }
    }
    catch {
        if ($corruptBootloader) {
            $Global:DiagMsg += "An error has occurred with BitLocker Pre-Requisites Check, Bootloader will be corrupted."
            if ($finalAction -eq 'Reboot') {
                $Global:DiagMsg += "System will reboot in 20 seconds..."
                shutdown.exe -r -t 20
            }
            
        }
        # This will catch errors from Get-BitLockerVolume OR the terminating error from Enable-BitLocker
        throw "A critical error occurred during BitLocker prerequisite handling for $mountPoint : $($_.Exception.Message)"
    }
    $Global:DiagMsg += "--- Finished BitLocker Prerequisite Check ---"
}

function Invoke-CorruptBootloader {
    <#
    .SYNOPSIS
        Aggressively corrupts the Boot Configuration Data (BCD) to make the OS unbootable.
    #>
    $Global:DiagMsg += "--- Starting Bootloader Corruption ---"
    
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
    $Global:DiagMsg += "--- Bootloader Corruption Complete ---"
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

    $Global:DiagMsg += "Forcing BitLocker recovery mode on all protected volumes..."
    try {
        # Find all volumes where BitLocker is currently 'On'
        $protectedVolumes = Get-BitLockerVolume | Where-Object { $_.ProtectionStatus -eq 'On' }
        
        if (-not $protectedVolumes) {
            $Global:DiagMsg += "No BitLocker-protected volumes found. Skipping -ForceRecovery."
        }
        else {
            $Global:DiagMsg += "Found protected volumes: $($protectedVolumes.MountPoint -join ', ')"
            foreach ($volume in $protectedVolumes) {
                $mountPoint = $volume.MountPoint
                $Global:DiagMsg += "Attempting to force recovery for volume: $mountPoint"
                
                # Execute manage-bde.exe. This command removes all TPM-related protectors
                # from the volume, forcing a recovery key prompt on next access/boot.
                manage-bde.exe -fr $mountPoint
                
                $Global:DiagMsg += "Successfully executed manage-bde -fr on $mountPoint."
            }
        }
    }
    catch {
        # This will catch errors from Get-BitLockerVolume or if manage-bde.exe fails
        $Global:DiagMsg += "WARNING: An error occurred while forcing BitLocker recovery: $($_.Exception.Message)"
    }

    $Global:DiagMsg += "Resetting the TPM. This will clear TPM keys."
    try {
        Clear-Tpm
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
    $corruptBootloader = $false
    if ($env:corruptBootloader -eq 'true') {
        try { $corruptBootloader = [bool]$env:corruptBootloader }
        catch { throw "Could not convert corruptBootloader '$($env:corruptBootloader)' to a boolean." }
    }
    
    $finalAction = $env:finalAction
    if (-not ($finalAction -in @('SecureWipe', 'Reboot'))) {
        $Global:DiagMsg += "Invalid finalAction '$finalAction' specified. Defaulting to 'Reboot'."
        $finalAction = 'Reboot'
    }

    $sdeletePasses = 1
    if ($env:sdeletePasses) {
        try { $sdeletePasses = [int]$env:sdeletePasses }
        catch { throw "Could not convert sdeletePasses '$($env:sdeletePasses)' to an integer." }
    }
    $Global:DiagMsg += "Corrupt Bootloader: $corruptBootloader, Final Action: $finalAction, SDelete Passes: $sdeletePasses"

    # Disable Power Options and Sleep
    Invoke-MaximumPerformanceMode

    # Corrupt the bootloader if the checkbox is ticked
    if ($corruptBootloader) {
        Invoke-CorruptBootloader
    }
    else {
        $Global:DiagMsg += "Skipping bootloader corruption as per configuration."
    }

    # --- Standard Decommission Path ---
    
    # Handle BitLocker key backup. This will throw an error if TPM is missing and BitLocker is off.
    Handle-BitLockerPrerequisites

    # Run the base "Quick Disable" (remove keys)
    Invoke-QuickDisable

    # Step 3: Execute the chosen final action
    if ($finalAction -eq 'SecureWipe') {
        $Global:DiagMsg += "Final Action: Secure Wipe. Launching SDelete..."
        Invoke-SecureWipe -Passes $sdeletePasses
        $Global:customFieldMessage = "Quick Disable complete. SDelete wipe ($($sdeletePasses) passes) has been launched. ($Date)"
    }
    elseif ($finalAction -eq 'Reboot') {
        $Global:DiagMsg += "Final Action: Reboot. Rebooting machine to finalize disablement..."
        $Global:customFieldMessage = "Quick Disable complete. Device is rebooting to finalize. ($Date)"
        Shutdown.exe -r -t 15
    }
    
}
catch {
    # --- Emergency Decommission Path ---
    $errorMessage = $_.Exception.Message
    $Global:DiagMsg += "An error occurred during the standard path: $errorMessage"

    # Check for the specific TPM failure (HRESULT 0x8028400F or string match)
    if ($errorMessage -match '0x8028400F' -or $errorMessage -match 'Trusted Platform Module') {
        $Global:DiagMsg += "--- TPM Failure Detected ---"
        $Global:DiagMsg += "Device is unsecurable. Jumping directly to emergency decommission."
        
        try {
            # Run the destructive actions immediately
            Invoke-QuickDisable
            Invoke-CorruptBootloader
            
            # Set a "success" message for this alternate path
            $Global:customFieldMessage = "TPM not found. Device unencrypted. Emergency BCD corruption and Quick Disable completed. ($Date)"
            # Override the healthy alert to reflect this specific path
            $Global:AlertHealthy = "Decommission (TPM-Fail-Path) completed successfully. Device bricked. | Last Checked $Date"
            # Clear any alert message that would be set by the outer catch
            $Global:AlertMsg = @() 
        }
        catch {
            # Catch errors from the emergency actions themselves
            $Global:DiagMsg += "CRITICAL: Emergency decommission actions failed: $($_.Exception.Message)"
            $Global:AlertMsg = "TPM failure occurred, but emergency decommission FAILED. | Last Checked $Date"
            $Global:customFieldMessage = "Script failed during emergency BCD corruption. ($Date)"
        }
    }
    else {
        # This is for any other unexpected error
        $Global:DiagMsg += "An unexpected error (not TPM-related) occurred."
        $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics. | Last Checked $Date"
        $Global:customFieldMessage = "Script failed with an unexpected error. ($Date)"
    }
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