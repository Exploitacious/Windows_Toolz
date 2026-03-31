<#
.SYNOPSIS
    This script performs a series of security actions on a local machine to render it virtually disabled.
    It retrieves and rotates BitLocker recovery keys, disables user accounts,
    and forces the machine into BitLocker recovery on the next boot.

.DESCRIPTION
    The script executes the following major steps:
    1.  Starts a detailed transcript of all actions.
    2.  Clears all cached credentials from the Windows Credential Manager.
    3.  Logs the current BitLocker recovery keys for all volumes.
    4.  Rotates the recovery key for the OS drive (C:).
    5.  Logs the new BitLocker recovery key.
    6.  Records computer identifying information (Manufacturer, Model, Serial Number).
    7.  Disables all local user accounts.
    8.  Forces the C: drive into recovery mode for the next restart.
    9.  Disables network adapters to prevent internet access.
    10. Immediately restarts the computer.

.NOTES
    Author:     Alex Ivantsov
    Version:    2.0
    Created:    2026-06-10
    Requires:   Administrator privileges and the BitLocker module.
#>

#==============================================================================
# SCRIPT INITIALIZATION AND CONFIGURATION
#==============================================================================

# Stop on any error for more predictable script execution within try/catch blocks.
$ErrorActionPreference = 'Stop'

# Define paths and sources for logging and transcripts.
$LogDirectory = "C:\Temp"
$LogFile = Join-Path -Path $LogDirectory -ChildPath "BitLocker-Rotation_$($env:computername).log"
$TranscriptFile = Join-Path -Path $LogDirectory -ChildPath "BitlockerBrick-Transcript_$($env:computername).txt"
$EventLogSource = "BitLockerRotation"

# Ensure the log directory exists before proceeding.
if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -Path $LogDirectory -ItemType Directory | Out-Null
}

# Stop any existing transcript and start a new one, appending if it already exists.
# Using 'SilentlyContinue' to prevent an error if no transcript is running.
Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
Start-Transcript -Path $TranscriptFile -Append

#==============================================================================
# LOGGING FUNCTION
#==============================================================================

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$LogString
    )
    
    # Prepend a timestamp to the log message.
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $LogString"
    
    # Write the message to the console and the log file.
    Write-Output $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

#==============================================================================
# PRE-FLIGHT OPERATIONS
#==============================================================================

# Clear any stored credentials from the Windows Credential Manager.
Write-Log "INFO: Clearing cached credentials from Credential Manager..."
cmdkey /list | ForEach-Object {
    # Find lines that contain a target and extract the target name.
    if ($_ -match '^\s*Target:\s*(.*)$') {
        $target = $Matches[1]
        cmdkey /delete:$target
    }
}

#==============================================================================
# BITLOCKER KEY ROTATION AND LOGGING
#==============================================================================

# Register an event log source for better system auditing.
if (-not ([System.Diagnostics.EventLog]::SourceExists($EventLogSource))) {
    New-EventLog -LogName 'Application' -Source $EventLogSource -ErrorAction SilentlyContinue
}

# Process all BitLocker-enabled volumes found on the system.
Get-BitLockerVolume | ForEach-Object {
    $Volume = $_
    $MountPoint = $Volume.MountPoint
    Write-Log "INFO: Processing volume '$MountPoint'."

    # Correctly identify and log the *current* recovery password.
    # A volume can have multiple key protectors; we need to find the recovery password specifically.
    $CurrentKey = ($Volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).RecoveryPassword
    
    if ($CurrentKey) {
        Write-Log "INFO: Current recovery key for '$MountPoint' is: $CurrentKey"
    }
    else {
        Write-Log "WARN: No existing recovery key found for '$MountPoint'."
    }

    # Rotate the recovery password only for the OS drive (typically C:).
    if ($Volume.VolumeType -eq 'OperatingSystem') {
        Write-Log "INFO: Rotating BitLocker recovery password for OS drive '$MountPoint'..."
        try {
            # Find the specific ID for the recovery password key protector.
            $RecoveryProtector = $Volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }

            if ($RecoveryProtector) {
                # Remove the old recovery key protector.
                Remove-BitLockerKeyProtector -MountPoint $MountPoint -KeyProtectorId $RecoveryProtector.KeyProtectorId
                Write-Log "SUCCESS: Removed old recovery key from '$MountPoint'."
            }

            # Add a new recovery password.
            # WARNING: This assumes AD backup is configured. The new key is not displayed for security.
            Add-BitLockerKeyProtector -MountPoint $MountPoint -RecoveryPasswordProtector | Out-Null
            Write-Log "SUCCESS: Added new recovery key protector to '$MountPoint'."

            # Log success to the Application Event Log for auditing purposes.
            $SuccessMessage = "BitLocker recovery password for $MountPoint was successfully rotated."
            Write-EventLog -LogName 'Application' -Source $EventLogSource -EntryType Information -EventId 1000 -Message $SuccessMessage
            Write-Host $SuccessMessage -ForegroundColor Green
            
            # Get and log the newly created recovery key.
            $NewKey = (Get-BitLockerVolume -MountPoint $MountPoint).KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -ExpandProperty RecoveryPassword
            if ($NewKey) {
                Write-Log "INFO: New recovery key for '$MountPoint' is: $NewKey"
            }

        }
        catch {
            # Catch and log any errors during the rotation process.
            $ErrorMessage = "ERROR: Failed to rotate BitLocker recovery password for '$MountPoint'. Details: $($_.Exception.Message)"
            Write-Log $ErrorMessage
            Write-EventLog -LogName 'Application' -Source $EventLogSource -EntryType Error -EventId 1001 -Message $ErrorMessage
        }
    }
}

#==============================================================================
# SYSTEM INFORMATION AND USER LOCKOUT
#==============================================================================

# Get computer information using the modern Get-CimInstance for better performance.
Write-Log "INFO: Retrieving system information..."
$ComputerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$BiosInfo = Get-CimInstance -ClassName Win32_BIOS

Write-Log "  - Manufacturer: $($ComputerInfo.Manufacturer)"
Write-Log "  - Model: $($ComputerInfo.Model)"
Write-Log "  - Serial Number: $($BiosInfo.SerialNumber)"

# Disable all local user accounts, including the default Administrator.
Write-Log "INFO: Disabling all local user accounts..."
Get-LocalUser | Disable-LocalUser -Confirm:$false
Write-Log "SUCCESS: All local user accounts have been disabled."

#==============================================================================
# FINAL LOCKDOWN AND RESTART
#==============================================================================

# Force the operating system drive into recovery mode on the next restart.
Write-Log "INFO: Forcing BitLocker recovery mode for C: on next boot."
manage-bde -ForceRecovery C:

# (Optional) Disable all physical network adapters to prevent network access.
Write-Log "INFO: Disabling all physical network adapters..."
Get-NetAdapter -Physical | Disable-NetAdapter -Confirm:$false
Write-Log "SUCCESS: Network adapters disabled."

# Stop the transcript before shutting down.
Write-Log "INFO: Script complete. System will now restart."
Stop-Transcript

# Force an immediate restart of the computer.
Restart-Computer -Force