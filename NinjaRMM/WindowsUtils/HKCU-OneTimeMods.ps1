# Script Title: Set a Registry Key for All Users
# Description: Sets a specific registry value in the HKCU hive for the Default User, all existing users, and the current user. Ideal for applying a user-level tweak across an entire machine.

# Script Name and Type
$ScriptName = "Set Registry Key for All Users"
$ScriptType = "Remediation" # Or "Remediation", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get' 

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# regPathRelative (Text): The registry path *relative* to the user's hive (e.g., Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced).
# regName (Text): The name of the registry key to set (e.g., NavPaneShowAllFolders).
# regValue (Text): The value to set the key to. The script will attempt to cast this based on the regType.
# regType (Text): The key type. Valid options: String, ExpandString, Binary, DWord, MultiString, QWord. (Default: DWord)
# restartExplorer (Checkbox): If 'true', will force-restart 'explorer.exe' for the current user to apply UI changes.

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
    #--- Start Helper Functions ---#
    
    Function Set-RegistryValue {
        param (
            [Parameter(Mandatory = $true)] [string]$Path,
            [Parameter(Mandatory = $true)] [string]$Name,
            [Parameter(Mandatory = $true)] $Value,
            [Parameter(Mandatory = $false)] [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')] [string]$Type = 'DWord'
        )
        try {
            if (-not (Test-Path -Path $Path)) {
                $Global:DiagMsg += "Registry path '$Path' not found. Creating it."
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
            }
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            $Global:DiagMsg += "Successfully set '$Path\$Name' to '$Value' (Type: $Type)."
        }
        catch {
            $Global:DiagMsg += "Error: Failed to set registry value '$Name' at '$Path'. Message: $($_.Exception.Message)"
            # Re-throw to be caught by the main script's try/catch block
            throw "Failed to set registry key '$Path\$Name'."
        }
    }

    Function Apply-RegistryTweakToHive {
        param (
            [Parameter(Mandatory = $true)] [string]$RegistryHivePath,
            [Parameter(Mandatory = $true)] [string]$RelativePath,
            [Parameter(Mandatory = $true)] [string]$Name,
            [Parameter(Mandatory = $true)] $Value,
            [Parameter(Mandatory = $true)] [string]$Type
        )
    
        # Handle cases where the relative path might be empty (setting a key at the root of the hive)
        $fullRegPath = if ([string]::IsNullOrEmpty($RelativePath)) { $RegistryHivePath } else { Join-Path -Path $RegistryHivePath -ChildPath $RelativePath }
        
        Set-RegistryValue -Path $fullRegPath -Name $Name -Value $Value -Type $Type
    }
    
    #--- End Helper Functions ---#


    #--- Main Script Logic ---#
    
    # 1. Validate and cast RMM variables
    $Global:DiagMsg += "Validating and casting RMM variables."
    
    if ([string]::IsNullOrEmpty($env:regPathRelative)) {
        # This is a valid scenario if the user wants to set a key at the root of the hive.
        $Global:DiagMsg += "RMM Variable 'regPathRelative' is empty. Key will be set at the root of the hive path."
        $regPathRelative = ""
    }
    else {
        $regPathRelative = $env:regPathRelative
        $Global:DiagMsg += "RMM Variable 'regPathRelative' = '$regPathRelative'"
    }
    
    if ([string]::IsNullOrEmpty($env:regName)) { throw "RMM Variable 'regName' is not set." }
    $regName = $env:regName
    $Global:DiagMsg += "RMM Variable 'regName' = '$regName'"

    if ($null -eq $env:regValue) { throw "RMM Variable 'regValue' is not set." }
    
    $validTypes = @('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')
    $regType = if ($env:regType -and ($env:regType -in $validTypes)) { $env:regType } else { 'DWord' }
    $Global:DiagMsg += "Registry Type set to: $regType"

    [bool]$restartExplorer = $env:restartExplorer -eq 'true'
    $Global:DiagMsg += "Restart Explorer set to: $restartExplorer"

    # Cast the registry value from its string representation
    $regValue = $null
    try {
        switch ($regType) {
            'DWord' { $regValue = [int]$env:regValue }
            'QWord' { $regValue = [long]$env:regValue }
            'Binary' { $regValue = [byte[]]($env:regValue -split '[ ,]' | Where-Object { $_ } | ForEach-Object { "0x$_" }) }
            'MultiString' { $regValue = [string[]]($env:regValue -split ';') } # We'll use semicolon as a delimiter
            default { $regValue = [string]$env:regValue } # Covers String and ExpandString
        }
        $Global:DiagMsg += "Successfully cast registry value '$($env:regValue)' to type $regType."
    }
    catch {
        throw "Failed to cast RMM variable 'regValue' ('$($env:regValue)') to type $regType. Error: $($_.Exception.Message)"
    }

    # 2. Phase 1: Modify Default User Profile
    $Global:DiagMsg += "Phase 1: Modifying Default User Profile..."
    $defaultUserHive = Join-Path $env:SystemDrive "Users\Default\NTUSER.DAT"
    $tempHiveKeyPS = "HKLM:\DEFAULT_USER_TEMP"
    $tempHiveKeyReg = $tempHiveKeyPS.Replace(':\', '\')
    
    if (Test-Path $defaultUserHive) {
        try {
            reg.exe load $tempHiveKeyReg $defaultUserHive | Out-Null
            Apply-RegistryTweakToHive -RegistryHivePath $tempHiveKeyPS -RelativePath $regPathRelative -Name $regName -Value $regValue -Type $regType
        }
        finally {
            [gc]::Collect()
            reg.exe unload $tempHiveKeyReg | Out-Null
            $Global:DiagMsg += "Default User Profile successfully updated and unloaded."
        }
    }
    else { $Global:DiagMsg += "Warning: Default User Profile hive not found at '$defaultUserHive'. Skipping." }

    # 3. Phase 2: Modify Existing User Profiles
    $Global:DiagMsg += "Phase 2: Modifying Existing User Profiles..."
    $currentUserSID = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $tempHiveKeyPS = "HKLM:\EXISTING_USER_TEMP"
    $tempHiveKeyReg = $tempHiveKeyPS.Replace(':\', '\')
    $profileRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    
    Get-ChildItem -Path $profileRegPath | ForEach-Object {
        $profile = $_
        $sid = $profile.PSChildName
        
        # Skip System, Network, and LocalService accounts, AND the current user (handled next)
        if (($sid -notlike "S-1-5-18*") -and ($sid -notlike "S-1-5-19*") -and ($sid -notlike "S-1-5-20*") -and ($sid -ne $currentUserSID)) {
            try {
                $userHivePath = ($profile | Get-ItemProperty).ProfileImagePath
                $userHiveFile = Join-Path ([System.Environment]::ExpandEnvironmentVariables($userHivePath)) "NTUSER.DAT"
                
                if (Test-Path $userHiveFile) {
                    $Global:DiagMsg += "  -> Processing profile at $userHivePath"
                    try {
                        reg.exe load $tempHiveKeyReg $userHiveFile | Out-Null
                        Apply-RegistryTweakToHive -RegistryHivePath $tempHiveKeyPS -RelativePath $regPathRelative -Name $regName -Value $regValue -Type $regType
                    }
                    catch { $Global:DiagMsg += "     Warning: Could not process hive for $userHivePath. It may be in use. Error: $($_.Exception.Message)" }
                    finally { [gc]::Collect(); reg.exe unload $tempHiveKeyReg | Out-Null }
                }
                else { $Global:DiagMsg += "  -> Skipping profile for $sid. NTUSER.DAT not found at '$userHiveFile'." }
            }
            catch { $Global:DiagMsg += "  -> Error processing profile for $sid. Message: $($_.Exception.Message)" }
        }
        elseif ($sid -eq $currentUserSID) {
            $Global:DiagMsg += "  -> Skipping currently logged-on user profile (will be handled in next phase)."
        }
    }
    $Global:DiagMsg += "Finished processing existing user profiles."

    # 4. Phase 3: Modify Current User Profile (HKCU)
    # The script runs as SYSTEM, so HKCU is the SYSTEM profile. This is still valuable to set.
    $Global:DiagMsg += "Phase 3: Modifying Current SYSTEM Profile (HKCU)..."
    try {
        Apply-RegistryTweakToHive -RegistryHivePath "HKCU:" -RelativePath $regPathRelative -Name $regName -Value $regValue -Type $regType
        $Global:DiagMsg += "Current user (SYSTEM) profile updated."
    }
    catch {
        $Global:DiagMsg += "Warning: Could not modify current user (SYSTEM) hive. Error: $($_.Exception.Message)"
    }


    # 5. Restart Explorer (if requested)
    if ($restartExplorer) {
        $Global:DiagMsg += "Restarting Windows Explorer to apply changes for any logged-in users..."
        # Stop-Process is tricky for other users. This will only work for the user the process is running as (SYSTEM)
        # or potentially an interactively logged-on user if permissions allow.
        # A more robust method would be to find all explorer.exe processes.
        try {
            Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
            $Global:DiagMsg += "Attempted to restart explorer.exe."
        }
        catch {
            $Global:DiagMsg += "Could not restart explorer.exe. This is normal if no user is logged in. Error: $($_.Exception.Message)"
        }
    }
    
    # 6. Set Success Message
    $Global:customFieldMessage = "Successfully set '$regPathRelative\$regName' to '$($env:regValue)' for all user profiles. ($Date)"

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed to set registry key. See diagnostics for details. | Last Checked $Date"
    $Global:customFieldMessage = "Script failed with an error: $($_.Exception.Message) ($Date)"
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