# 
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Advanced Secure Decommission Device" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:usrUDF = 14 # Which UDF to write to.
#$env:usrCorruptBCD = "Yes" # Set to "Yes" to corrupt the BCD.
#$env:usrRebootDelaySeconds = 300 # Reboot delay in seconds.

<#
This script performs a multi-stage decommissioning:
1. Enables BitLocker in the fastest mode (-UsedSpaceOnly).
2. Immediately captures the recovery key and stores it in the specified UDF.
3. Aggressively removes the TPM protector to force recovery mode post-encryption.
4. Optionally corrupts the Boot Configuration Data (BCD) for an immediate boot failure.
5. Schedules a reboot after a configurable delay.
#>
# DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########

#region Configuration and Logging
$LogPath = "$env:TEMP\decommission-log-$ScriptUID.txt"
function Write-Log {
    param(
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Add-Content -Path $LogPath -Value $LogMessage
    $Global:DiagMsg += $LogMessage
}
if (Test-Path $LogPath) { Remove-Item $LogPath }
Write-Log "Advanced decommissioning script started."
#endregion

try {
    # GUID for the standard High Performance plan
    $HighPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        
    # Set the High Performance plan as active to ensure a consistent base
    powercfg /setactive $HighPerfGuid
    Write-Log "  - Activated 'High Performance' power plan."
        
    # Configure the active plan to never turn off components or sleep when on AC power
    powercfg /change monitor-timeout-ac 0
    Write-Log "  - Set monitor timeout to 'Never'."
    powercfg /change disk-timeout-ac 0
    Write-Log "  - Set disk timeout to 'Never'."
    powercfg /change standby-timeout-ac 0
    Write-Log "  - Set sleep timeout to 'Never'."
    powercfg /change hibernate-timeout-ac 0
    Write-Log "  - Set hibernate timeout to 'Never'."
        
    Write-Log "SUCCESS: Power settings configured for 'Always On'."
}
catch {
    Write-Log "WARN: Failed to configure all power settings. The upgrade will continue, but the device may sleep. Error: $_"
}

#region Set Script Variables from Datto
# Set default values if Datto variables are not defined
if ($null -eq $env:usrCorruptBCD) { $env:usrCorruptBCD = "No" }
if ($null -eq $env:usrRebootDelaySeconds) { $env:usrRebootDelaySeconds = 900 }
Write-Log "Parameter - Corrupt BCD: $($env:usrCorruptBCD)"
Write-Log "Parameter - Reboot Delay: $($env:usrRebootDelaySeconds) seconds"
#endregion

#region Pre-flight Checks
if (-not $env:usrUDF -or $env:usrUDF -lt 1) {
    Write-Log "FATAL ERROR: The usrUDF variable is not set. Cannot store the recovery key. Aborting."
    $FATAL = $true
}

if (-not $FATAL) {
    try {
        $OSVolume = Get-BitLockerVolume -MountPoint $env:SystemDrive
        Write-Log "Successfully identified OS Volume: $($OSVolume.MountPoint)."
    }
    catch {
        Write-Log "ERROR: Could not get BitLocker volume for $env:SystemDrive. Aborting."
        $FATAL = $true
    }
}
#endregion

if (-not $FATAL) {
    #region BitLocker Management
    $RecoveryKey = ""
    if ($OSVolume.ProtectionStatus -eq 'On') {
        Write-Log "BitLocker is already ON. Capturing existing recovery key."
        $KeyProtector = Get-BitLockerVolume -MountPoint $env:SystemDrive | Select-Object -ExpandProperty KeyProtector
        $RecoveryKey = ($KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).RecoveryPassword
    }
    else {
        Write-Log "BitLocker is OFF. Enabling in Fast (used space only) Mode..."
        try {
            Enable-BitLocker -MountPoint $env:SystemDrive -EncryptionMethod Aes256 -UsedSpaceOnly -SkipHardwareTest -RecoveryPasswordProtector
            Write-Log "BitLocker encryption initiated. Waiting 15 seconds for key generation..."
            Start-Sleep -Seconds 15
            $KeyProtector = Get-BitLockerVolume -MountPoint $env:SystemDrive | Select-Object -ExpandProperty KeyProtector
            $RecoveryKey = ($KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).RecoveryPassword
            Write-Log "Bitlocker will continue to encrypt the drive while the device is online..."
        }
        catch {
            Write-Log "ERROR: Failed to enable BitLocker. $_"
            $FATAL = $true
        }
    }

    if ([string]::IsNullOrEmpty($RecoveryKey)) {
        Write-Log "FATAL ERROR: Could not retrieve a valid BitLocker recovery key. Aborting."
        $FATAL = $true
    }
    else {
        Write-Log "Successfully captured recovery key."
        $Global:varUDFString = $RecoveryKey
    }
    #endregion
}

if (-not $FATAL) {
    #region Aggressive Key Protector Removal
    Write-Log "Aggressively removing non-recovery key protectors."
    try {
        $AllProtectors = (Get-BitLockerVolume -MountPoint $env:SystemDrive).KeyProtector
        foreach ($Protector in $AllProtectors) {
            if ($Protector.KeyProtectorType -ne "RecoveryPassword") {
                Write-Log "Removing protector ID $($Protector.KeyProtectorId) of type $($Protector.KeyProtectorType)..."
                Remove-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $Protector.KeyProtectorId
            }
        }
        Write-Log "Successfully removed all non-recovery key protectors."
    }
    catch {
        Write-Log "WARNING: An error occurred while removing key protectors. $_"
    }

    Write-Log "Attempting to clear the TPM..."
    try {
        Clear-Tpm
        Write-Log "TPM clear command issued successfully."
    }
    catch {
        Write-Log "WARNING: Could not issue Clear-Tpm command. Device may not have a TPM."
    }
    #endregion

    #region BCD Corruption (Optional)
    Write-Log "Checking if BCD corruption is enabled..."
    if ($env:usrCorruptBCD -eq 'Yes') {
        Write-Log "BCD corruption is ENABLED. Attempting to delete the default bootloader entry..."
        try {
            # This is the direct, standard command to delete the current OS boot entry.
            # It's more robust than trying to parse the specific identifier.
            bcdedit /delete { current } /f

            # We check the exit code to confirm the command was accepted.
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Successfully issued command to delete the default BCD entry '{current}'."
            }
            else {
                Write-Log "WARNING: The bcdedit command failed with exit code $LASTEXITCODE."
            }
        }
        catch {
            Write-Log "WARNING: A critical error occurred during BCD corruption. $_"
        }
    }
    else {
        Write-Log "BCD corruption is DISABLED. Skipping."
    }
    #endregion

    #region Initiate Delayed Reboot
    $RebootDelay = $env:usrRebootDelaySeconds
    Write-Log "Scheduling a forced reboot in $RebootDelay seconds to finalize decommissioning."
    $RebootMessage = "This computer has been decommissioned by your IT provider and will restart shortly. It will require a recovery key for future use."
    shutdown.exe /r /t $RebootDelay /c "$RebootMessage"
    #endregion
    
    Write-Log "Decommissioning script completed."
}


######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {    
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF: " + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF: " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Info to be sent into JSON POST to API Endpoint (Optional)
$APIinfoHashTable = @{
    'CS_PROFILE_UID' = $env:CS_PROFILE_UID
    'Script_Diag'    = $Global:DiagMsg
    'Script_UID'     = $ScriptUID
}
#######################################################################
### Exit script with proper Datto diagnostic and API Results.
# Add Script Result and POST to API if an Endpoint is Provided
if ($null -ne $env:APIEndpoint) {
    $Global:DiagMsg += " - Sending Results to API"
    Invoke-WebRequest -Uri $env:APIEndpoint -Method POST -Body ($APIinfoHashTable | ConvertTo-Json) -ContentType "application/json"
}
# Exit with writing diagnostic back to the ticket / remediation component log
write-DRMMDiag $Global:DiagMsg
Exit 0