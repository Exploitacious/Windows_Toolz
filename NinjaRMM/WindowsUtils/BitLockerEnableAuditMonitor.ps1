# Script Title: BitLocker Management and TPM Audit
# Description: Audits BitLocker status on all fixed drives, enables encryption if specified, and backs up recovery keys and TPM information to NinjaRMM custom fields.

# Script Name and Type
$ScriptName = "BitLocker Management and TPM Audit"
$ScriptType = "Remediation" # This script can both monitor and remediate
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
$KeySeparator = ",,,"
$TempPath = "C:\Temp\"

## ORG-LEVEL EXPECTED VARIABLES ##
# None for this script

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# enableBitlockerIfDisabled (Checkbox): If checked, the script will enable BitLocker on unencrypted drives. Default: False
# bitlockerKeyField (Text): The name of the Device Custom Field to store BitLocker recovery key(s). Example: 'bitlockerDecryptionKey'
# bitlockerVolumeInfoField (Text): The name of the Device Custom Field to store BitLocker volume information. Example: 'bitlockerVolumeInfo'
# tpmInfoField (Text): The name of the Device Custom Field to store TPM audit information. Example: 'trustedPlatformModuleInfo'


# What to Write if Alert is Healthy
$Global:AlertHealthy = "BitLocker compliance checks passed. | Last Checked $Date"

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

# RMM Custom Field - This global is not used for writing, but the boilerplate expects it.
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

### Helper Functions ###

# Function to get TPM information and format it
function Get-TpmAuditInfo {
    try {
        $tpm = Get-Tpm
        $tpmInfo = @(
            "TPM Present: $($tpm.TpmPresent)",
            "TPM Ready: $($tpm.TpmReady)",
            "TPM Enabled: $($tpm.TpmEnabled)",
            "TPM Activated: $($tpm.TpmActivated)",
            "TPM Owned: $($tpm.TpmOwned)",
            "Manufacturer: $($tpm.ManufacturerIdTxt)",
            "Manufacturer Version: $($tpm.ManufacturerVersion)",
            "Specification Version: $($tpm.SpecificationVersion)"
        )
        return $tpmInfo -join "`n"
    }
    catch {
        $Global:DiagMsg += "Failed to get TPM information: $($_.Exception.Message)"
        return "TPM information could not be retrieved. The Get-Tpm command may have failed or a TPM is not present."
    }
}

# Function to update a specific NinjaRMM Custom Field
function Update-RmmCustomField {
    param(
        [string]$FieldName,
        [string]$Value
    )
    if (-not $FieldName) {
        $Global:DiagMsg += "Custom Field name not provided to Update-RmmCustomField function. Skipping."
        return
    }
    
    $Global:DiagMsg += "Attempting to write to Custom Field '$FieldName'."
    try {
        # Clear the field first to avoid character limits on repeated runs
        Ninja-Property-Clear -Name $FieldName
        if ($Value) {
            Ninja-Property-Set -Name $FieldName -Value $Value
        }
        $Global:DiagMsg += "Successfully updated Custom Field '$FieldName'."
    }
    catch {
        $Global:DiagMsg += "Error writing to Custom Field '$FieldName': $($_.Exception.Message)"
    }
}

try {
    # 1. Audit TPM and store information
    $tpmInfoString = Get-TpmAuditInfo
    $Global:DiagMsg += "TPM audit completed."

    # 2. Initialize collectors for script-wide data
    $allVolumeInfo = @()
    $alertsToGenerate = @()
    $remediatedActions = @()
    $allKeys = @{} # Using a hashtable for [DriveLetter] = [Key]

    # 3. Get currently stored keys from NinjaRMM
    $storedKeysString = ""
    if ($env:bitlockerKeyField) {
        try {
            $storedKeysString = (Ninja-Property-Get -Name $env:bitlockerKeyField).Value
            if ($storedKeysString) {
                $Global:DiagMsg += "Retrieved existing keys from Custom Field '$($env:bitlockerKeyField)'."
                $storedKeysString.Split($KeySeparator) | ForEach-Object {
                    if ($_ -like "*:*") {
                        $drive, $key = $_.Split(':', 2)
                        $allKeys[$drive] = $key
                    }
                }
            }
            else {
                $Global:DiagMsg += "Custom Field '$($env:bitlockerKeyField)' was empty."
            }
        }
        catch {
            $Global:DiagMsg += "Could not read Custom Field '$($env:bitlockerKeyField)'. It may not exist on this device. Assuming no keys are stored."
        }
    }
    
    # 4. Get all eligible volumes (Fixed disks with NTFS filesystem AND an assigned Drive Letter)
    $volumes = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.FileSystemType -eq 'NTFS' -and $_.DriveLetter }
    if (-not $volumes) {
        $Global:DiagMsg += "No BitLocker-eligible (Fixed, NTFS, Mounted) volumes found on this device."
        $allVolumeInfo += "No BitLocker-eligible volumes found."
    }

    # 5. Process each volume
    foreach ($volume in $volumes) {
        $driveLetter = $volume.DriveLetter
        $mountPoint = "$($driveLetter):"
        $Global:DiagMsg += "Processing volume: $mountPoint"

        try {
            $bitlockerVolume = Get-BitLockerVolume -MountPoint $mountPoint
            
            # --- CASE A: BitLocker is ON ---
            if ($bitlockerVolume.ProtectionStatus -eq 'On') {
                $currentVolumeInfo = "Volume: $mountPoint | Status: Encrypted | Protection: ON"
                $keyProtector = $bitlockerVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
                
                if ($keyProtector) {
                    $recoveryKey = $keyProtector.RecoveryPassword
                    $currentVolumeInfo += " | Key ID: $($keyProtector.KeyProtectorId)"
                    
                    if ($allKeys.ContainsKey($driveLetter) -and $allKeys[$driveLetter] -eq $recoveryKey) {
                        $Global:DiagMsg += "Key for $mountPoint matches stored key."
                    }
                    else {
                        $remediatedActions += "Recovery key for $mountPoint was successfully backed up."
                        $Global:DiagMsg += "Key for $mountPoint is new or mismatched. Staging for update."
                        $allKeys[$driveLetter] = $recoveryKey
                    }
                }
                else {
                    $currentVolumeInfo += " | WARNING: No recovery key protector found!"
                    $alertsToGenerate += "Volume $mountPoint is encrypted but has NO recovery key."
                }
                $allVolumeInfo += $currentVolumeInfo

                # --- CASE B: BitLocker is OFF ---
            }
            else {
                $Global:DiagMsg += "BitLocker is OFF for volume $mountPoint."
                
                if ([bool]$env:enableBitlockerIfDisabled) {
                    $Global:DiagMsg += "Remediation is enabled. Attempting to encrypt $mountPoint."
                    try {
                        Enable-BitLocker -MountPoint $mountPoint -TpmProtector -EncryptionMethod XtsAes256
                        Start-Sleep -Seconds 15
                        $newBlVolume = Get-BitLockerVolume -MountPoint $mountPoint
                        $newProtector = $newBlVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }

                        if ($newProtector.RecoveryPassword) {
                            $allKeys[$driveLetter] = $newProtector.RecoveryPassword
                            # MODIFIED: Changed this from an alert to a remediation action
                            $remediatedActions += "Enabled BitLocker on $mountPoint and backed up new key."
                            $allVolumeInfo += "Volume: $mountPoint | Status: Encryption Enabled | Protection: ON | Key ID: $($newProtector.KeyProtectorId)"
                            $Global:DiagMsg += "Successfully enabled BitLocker on $mountPoint."
                        }
                        else {
                            throw "Failed to retrieve recovery key after enabling BitLocker."
                        }
                    }
                    catch {
                        $alertsToGenerate += "FAILED to enable BitLocker on $mountPoint. Error: $($_.Exception.Message)"
                        $allVolumeInfo += "Volume: $mountPoint | Status: FAILED ENCRYPTION"
                    }
                }
                else {
                    $alertsToGenerate += "Volume $mountPoint is NOT encrypted."
                    $allVolumeInfo += "Volume: $mountPoint | Status: Unencrypted | Protection: OFF"
                }
            }
        }
        catch {
            $alertsToGenerate += "Could not process BitLocker status for $mountPoint. Error: $($_.Exception.Message)"
            $allVolumeInfo += "Volume: $mountPoint | Status: ERROR processing volume."
        }
    }

    # 6. Finalize data for custom fields
    $finalKeysString = ($allKeys.GetEnumerator() | ForEach-Object { "$($_.Key):$($_.Value)" }) -join $KeySeparator
    $finalVolumeInfoString = $allVolumeInfo -join "`n"

    # 7. Update all Custom Fields in NinjaRMM
    Update-RmmCustomField -FieldName $env:tpmInfoField -Value $tpmInfoString
    Update-RmmCustomField -FieldName $env:bitlockerVolumeInfoField -Value $finalVolumeInfoString
    Update-RmmCustomField -FieldName $env:bitlockerKeyField -Value $finalKeysString

    # 8. Consolidate alert and remediation messages
    # MODIFIED: This logic now separates remediation actions from critical alerts.
    # Remediation actions are logged to diagnostics but do not trigger a FAILURE.
    if ($remediatedActions) {
        $Global:DiagMsg += "Remediation actions taken: $($remediatedActions -join '; ')"
    }
    # Only critical issues will now set the Alert message and cause an Exit Code 1.
    if ($alertsToGenerate) {
        $Global:AlertMsg = ($alertsToGenerate -join "; ") + " | Last Checked $Date"
    }
}
catch {
    $Global:DiagMsg += "An unexpected error occurred in the main script block: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
}

######## End of Script ###########
##################################
##################################

# This section is modified from the boilerplate to reflect that specific custom fields were updated within the script body.
$Global:DiagMsg += "Script execution finished. Preparing to exit."

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