<#  bitlocker audit :: redux :: build 21/seagull, february 2025
    thanks to michael m., aaron m. (datto community)
    user vars: usrDisks/sel (SYS/All) :: usrAlert/bool :: usrUDF/sel (1-30) :: usrGetRecovery/bool

    this script, like all datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc.;
    it may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for 
    any reason. this includes on reddit, on discord, or as part of other RMM tools. PCSM and VSAX stand as exceptions to this rule.
    the moment you edit this script it becomes your own risk and support will not provide assistance with it.
    
    TPM bitmask legend:

    1   installed  | 0   absent
    2   enabled    | 1   installed; not enabled or activated
    4   activated  | 3   installed and enabled but not activated    (values not listed here are technically impossible)
    ---------------| 5   installed and activated but not enabled
                   | 7   installed, enabled and activated
#>

#region Functions & Variables -------------------------------------------------------------------------------------------------

function getRecovery ($context) {
    $varRecovery = $((get-bitlockervolume -mountpoint ($iteration).replace(':', '')).keyprotector | % { $_.recoverypassword } | where { !([string]::IsNullOrEmpty($_)) })
    if ($varRecovery) {
        if ($context -eq 'Intune') {
            write-host "  Recovery: $varRecovery (Intune)"
            $script:varDiskStatus += "/$varRecovery"
        }
        else {
            write-host "  Recovery: $varRecovery"
            $script:varDiskStatus += "/$varRecovery"
        }
    }
    else {
        if ($context -eq 'Intune') {
            $script:varDiskStatus += "/(No keys for automatic encryption)"
            write-host "  As this disk's encryption is automatic (eg, by Intune), no recovery key is supplied to audit."
        }
        else {
            $script:varDiskStatus += "/-------- NO RECOVERY KEY --------"
            write-host "! ERROR: No BitLocker recovery key could be found on the device."
            write-host "  This is an issue requiring immediate attention. BitLocker should be disabled"
            write-host "  and re-enabled with the resulting key being archived. As it it, the contents"
            write-host "  of this disk may not be recoverable after a locking operation."
        }
    }
}

if ($env:usrAlert -match 'true') {
    $varAlert = "Notice"
}
else {
    $varAlert = "Status"
}

#region Startup ---------------------------------------------------------------------------------------------------------------

write-host "BitLocker & TPM Audit Tool"
write-host "=========================================================================="

write-host "= TPM Check:"

#region TPM Check -------------------------------------------------------------------------------------------------------------

$varTPM = 0
if ((gwmi Win32_TPM -Namespace "root\CIMV2\Security\MicrosoftTpm").__SERVER) {
    # TPM installed
    $varTPM += 1
    if ((gwmi Win32_TPM -Namespace "root\CIMV2\Security\MicrosoftTpm").IsEnabled().isenabled -eq $true) {
        # TPM enabled
        $varTPM += 2
        if ((gwmi Win32_TPM -Namespace "root\CIMV2\Security\MicrosoftTpm").IsActivated().isactivated -eq $true) {
            # TPM activated
            $varTPM += 4
        }
    }
}

#add newest-supported TPM version :: https://learn.microsoft.com/en-us/windows/win32/secprov/win32-tpm
switch -Regex ((get-wmiobject -class win32_tpm -EnableAllPrivileges -Namespace "root\cimv2\security\microsofttpm").SpecVersion -split ',' -replace ' ' | select -first 1) {
    '^2' {
        $varTPMVer = "Modern: v2.x"
    } '^1.3' {
        $varTPMVer = "Legacy: v1.3x" #may be invalid
    } '^1.2' {
        $varTPMVer = "Legacy: v1.2x"
    } $null {
        $varTPMVer = "No version"
    } default {
        $varTPMVer = "No version"
    }
}

switch ($varTPM) {
    0 {
        $varTPMStatus = "Absent"
        write-host "- $varAlert`:   No TPM was detected on this system."
        break
    } 1 {
        $varTPMStatus = "Disabled [$varTPMVer]"
        write-host "- $varAlert`:   A TPM was detected ($varTPMVer), but it is not enabled or activated."
        break
    } 3 {
        $varTPMStatus = "Deactivated [$varTPMVer]"
        write-host "- $varAlert`:   A TPM was detected ($varTPMVer), but it is not activated."
        break
    } 5 {
        $varTPMStatus = "Disabled [$varTPMVer]"
        write-host "- $varAlert`:   An activated TPM was detected ($varTPMVer), but it is not enabled."
        break
    } 7 {
        $varTPMStatus = "Active [$varTPMVer]"
        write-host "- Status:   A TPM was detected ($varTPMVer) and is ready for use." 
        break
    } default {
        write-host "- Notice:   An error stopped the script working properly. Please report this issue."
        write-host "            Error: Unhandled exception (code $_)"
        exit 1
    }
}

#region Check to see if BitLocker is available as a Windows feature -----------------------------------------------------------

$varFeature = get-windowsoptionalFeature -online -FeatureName BitLocker

if ($varFeature) {
    if ($varFeature.state.value__ -eq 2 -or $varFeature.state.value__ -eq 5) {
        #feature is installed and enabled; import it
        write-host "- BitLocker module is installed and enabled. Importing."
        Import-Module -name BitLocker -DisableNameChecking
    }
    else {
        #feature is installed, but disabled
        write-host "! ERROR: The BitLocker feature is installed on this device, but it is disabled."
        write-host "  Please perform diagnostics on the device to ascertain why this might be."
        write-host "  The device has not been modified."
        $varBLError = "enabled"
    }
}
else {
    #feature is not installed
    write-host "! ERROR: The BitLocker feature is not installed on this device."
    write-host "  BitLocker will not be available on this device until it is installed."
    write-host "  The device has not been modified."
    $varBLError = "installed"
}

if ($varBLError) {
    if ($env:usrUDF -ge 1) {
        New-ItemProperty "HKLM:\Software\CentraStage" -Name "custom$env:usrUDF" -Value "ERROR: Cannot pull BitLocker info (not $varBLError on this device)" | out-null
    }
    exit 1
}

#region Disk check routine ----------------------------------------------------------------------------------------------------

write-host "- - - - - - - - - - - - - - - -"
write-host "= Disk Check:"

#all drives or just C:?
if ($env:usrDisks -match 'SYS') {
    write-host ": Checking $env:SystemDrive\..."
    $arrDisks = @("$env:SystemDrive")
}
else {
    write-host ": Enumerating fixed disks..."
    $arrDisks = Get-WMIObject -query "SELECT * from win32_logicaldisk where DriveType = '3'" | % { $_.DeviceID }
}

#disk analysis, for PS2.0 (where possible)
foreach ($iteration in $arrDisks) {
    $varEncStatus = Get-WmiObject -namespace "Root\cimv2\security\MicrosoftVolumeEncryption" -Class "Win32_Encryptablevolume" -Filter "DriveLetter='$iteration'"
    if ($varEncStatus.ProtectionStatus -eq 1) {
        write-host "- Status:   Disk $iteration is encrypted with BitLocker."
        $script:varDiskStatus += " $iteration`ENCPASS"
        if ($varEncStatus.EncryptionMethod -eq 5) {
            #alert on hardware enc
            write-host "- $varAlert`:   Disk $iteration is using hardware encryption."
            write-host "  More info: https://www.theregister.co.uk/2018/11/05/busted_ssd_encryption/"
            $script:varDiskStatus += "[HW!]"
        }
        if ($env:usrGetRecovery -match 'true') {
            getRecovery
        }
    }
    else {
        switch ((get-bitlockervolume | ? { $_.Mountpoint -eq "$iteration" }).volumestatus.value__) {

            <#
            use get-bitLockerVolume to catch devices following an inTune request to bitLock the device (since encryptableVolume omits it)
            DO NOT INCLUDE CODE ZERO. this is handled by 'default'. in a situation where a zero is returned OR the device cannot process
            inTune bitlocker requests (eg, pre-win10 1709), since the first check already failed to get to this point, assume the device
            is not encrypted and throw the default response. since we are polling an enum there shouldn't be any risk of friendly fire.
                - seagull, december 2023
            #>

            1 {
                #encrypted
                write-host "- Status:   Disk $iteration is encrypted with BitLocker (Automatic)."
                $script:varDiskStatus += " $iteration`ENCPASS"
                if ($env:usrGetRecovery -match 'true') {
                    getRecovery Intune
                }
            } 2 {
                #encryption in progress
                write-host "- Status:   Disk $iteration BitLocker (Automatic) encryption in progress."
                $script:varDiskStatus += " $iteration`ENCPASS"
                if ($env:usrGetRecovery -match 'true') {
                    getRecovery Intune
                }
            } 3 {
                #decryption in progress
                write-host "- Status:   Disk $iteration is being decrypted (Automatic)."
                $script:varDiskStatus += " $iteration`ENCFAIL"
                if ($env:usrGetRecovery -match 'true') {
                    getRecovery Intune
                }
            } 4 {
                #encryption suspended
                write-host "- Status:   Disk $iteration's (Automatic) encryption is suspended."
                $script:varDiskStatus += " $iteration`ENCFAIL"
                if ($env:usrGetRecovery -match 'true') {
                    getRecovery Intune
                }
            } 5 {
                #decryption suspended
                write-host "- Status:   Disk $iteration's (Automatic) decryption is suspended."
                $script:varDiskStatus += " $iteration`ENCFAIL"
                if ($env:usrGetRecovery -match 'true') {
                    getRecovery Intune
                }
            } 6 {
                #fully encrypted wipe in progress
                write-host "- Status:   Disk $iteration's is being encrypted-wiped (Automatic)."
                $script:varDiskStatus += " $iteration`ENCFAIL"
                if ($env:usrGetRecovery -match 'true') {
                    getRecovery Intune
                }
            } 7 {
                #fully encrypted wipe suspended
                write-host "- Status:   Disk $iteration's (Automatic) encrypted-wipe is suspended."
                $script:varDiskStatus += " $iteration`ENCFAIL"
                if ($env:usrGetRecovery -match 'true') {
                    getRecovery Intune
                }
            } default {
                write-host "- $varAlert`:   Disk $iteration is not encrypted with BitLocker."
                $script:varDiskStatus += " $iteration`ENCFAIL"
            }
        }
    }
}

#region Closeout: Write final values to UDF (if so configured) ----------------------------------------------------------------

$script:varDiskStatus = $script:varDiskStatus.Substring(1)
$varString = "TPM: $varTPMStatus | DISKS: $script:varDiskStatus"
if ($env:usrUDF -ge 1) {
    New-ItemProperty "HKLM:\Software\CentraStage" -Name "custom$env:usrUDF" -Value "$varString" | out-null
    write-host "==============================="
    if (($varString).length -gt 255) {
        write-host "! ALERT: Final output is longer than 255 characters and will be truncated in UDF form."
        write-host "  Consider re-running the script with `'usrGetRecovery`' set to False."
    }
    write-host "- Final output will be written to UDF $env:usrUDF."
    write-host "  It will look like this:"
    write-host "- - - - - - - - - - - - - - - -"
    write-host $varString
    write-host "==============================="
    write-host "To filter on this data:"
    write-host `r
    write-host "Criterion      Listed as       Description"
    write-host "--------------------------------------------------------------------------"
    write-host "TPM Status     Active          Ready for use/being used"
    write-host "               Deactivated     TPM must be activated first"
    write-host "               Disabled        TPM Must be enabled first"
    write-host "               Absent          Fit a TPM, enable an fTPM"
    write-host `r
    write-host "TPM Version    Modern          TPM specification v2.x"
    write-host "               Legacy          TPM specification v1.2/1.3"
    write-host "               (Unlisted)      No TPM fitted"
    write-host `r
    write-host "Disk Status    ENCPASS         Disk is encrypted with BitLocker"
    write-host "               ENCPASS[HW!]    Disk is hardware-encrypted with BitLocker"
    write-host "               ENCFAIL         Disk is not encrypted with BitLocker"
}

################
################
#Another bitlocker audit tool build 12/seagull
write-host "BitLocker Audit Tool"
write-host "=============================="
write-host "Enumerating fixed drives..."
write-host `r

[string]$varDriveList = "Bitlocker not enabled on Drives: "
[string]$varHardwareEnc = "Hardware encryption: "

#WORKING VERSION for POWERSHELL 2
foreach ($iteration in Get-WMIObject -query "SELECT * from win32_logicaldisk where DriveType = '3'" | select DeviceID) {
    $varEncStatus = Get-WmiObject -namespace "Root\cimv2\security\MicrosoftVolumeEncryption" -Class "Win32_Encryptablevolume" -Filter "DriveLetter='$($iteration.DeviceID)'"
    if ($varEncStatus.ProtectionStatus -eq 1) {
        write-host + Disk $iteration.deviceID is encrypted with BitLocker.
        if ($varEncStatus.EncryptionMethod -eq 5) {
            write-host : Disk $iteration.deviceID is using Hardware encryption.
            [string]$varHardwareEnc = $varHardwareEnc + $iteration.deviceID + ", "
            $varInsecureDrive = $true
        }
    }
    else {
        write-host - Disk $iteration.deviceID is not encrypted.
        $varInsecureDrive = $true
        [string]$varDriveList = $varDriveList + $iteration.deviceID + ", "
    }
}

write-host `r

#if we have hardware encryption, add it to the master list
if ($varHardwareEnc.Length -gt 21) {
    write-host "========================================="
    write-host "Advisory: Drives were discovered using Hardware-based BitLocker encryption."
    write-host "If the disk is an SSD, this may pose a security threat."
    write-host "More information: https://www.theregister.co.uk/2018/11/05/busted_ssd_encryption/"
    write-host "========================================="
    [string]$varDriveList = $varDriveList + ". " + $varHardwareEnc
}

#has the user opted to alert for insecure drives?
if ($env:usrAlert -match "true") {
    if ($varInsecureDrive) {
        write-host "Alert: $varDriveList"
        write-host `r
    }
}

#has the user put (only) a number in their usrUDF field?
if ([int]$env:usrUDF -and [int]$env:usrUDF -match '^\d+$') {
    #is it between 1 and 30?
    if ([int]$env:usrUDF -ge 1 -and [int]$env:usrUDF -le 30) {
        #are there any insecure drives?
        if ($varInsecureDrive) {
            #write the UDF
            New-ItemProperty -Path "HKLM:\SOFTWARE\CentraStage" -Name Custom$env:usrUDF -Value "$varDriveList" -Force | Out-Null
            write-host "Value written to User-defined Field $env:usrUDF`."
        }
        else {
            New-ItemProperty -Path "HKLM:\SOFTWARE\CentraStage" -Name Custom$env:usrUDF -Value "All fixed drives are encrypted." -Force | Out-Null
            write-host "Value written to User-defined Field $env:usrUDF`."
        }
    }
    else {
        write-host "User-defined Field value must be an integer between 1 and 30."
    }
}
else {
    write-host "User-defined field value invalid or not specified - not writing results to a User-defined field."
}