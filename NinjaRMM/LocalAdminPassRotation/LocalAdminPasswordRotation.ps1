# Script Title: Local Admin Password Rotation (LAPS)
# Description: This script creates/updates a specified local admin account, generates a new complex password, removes unauthorized members from the local Administrators group, disables default accounts, and reports the new credentials back to NinjaRMM custom fields.

# Script Name and Type
$ScriptName = "Local Admin Password Rotation (LAPS)"
$ScriptType = "Remediation"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# These values are integral to the script's function and are consistently applied across all devices.
$LocalAdminUsername = 'UmbrellaLA'
$AccountsToDisable = @('Administrator', 'Guest')
$MSPDomain = 'umbrellaitgroup.com', 'AAD DC Administrators'          # The Azure AD domain whose users should be exempt from removal.
$MSPNETBIOSDomain = 'Umbrella'              # The NetBIOS/local domain name to also exempt.
$AdminNameCustomField = 'umbrellaLocalAdminName' # Text Field: Stores username and password set date.
$AdminPassCustomField = 'umbrellaLocalAdmin'     # Secure Field: Stores the new password.

## ORG-LEVEL EXPECTED VARIABLES ##
# This script expects the following Organization-level Custom Field to be present.
# azureADExclusionDomain (Text): The Azure AD domain name (e.g., 'myclient.com') whose users should be exempt from removal from the local Administrators group.
$OrgAzureDomain = 'umbrellaitgroup.com' # Will be populated within the 'try' block.

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# passwordLength (Integer): The desired length of the generated password. Default: 30
# passwordCharSet (Text): The character sets to include: U=Uppercase, L=Lowercase, N=Numbers, S=Symbols. Default: 'ULNS'

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Local Admin '$($LocalAdminUsername)' password rotated successfully. | Last Checked $Date"

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
$Global:customFieldMessage = @() # Not used in this script, but kept for boilerplate consistency.

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

function Test-IsDomainController {
    # Get the computer system information
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem

    # A DomainRole of 4 or 5 indicates a Backup or Primary Domain Controller
    if ($computerSystem.DomainRole -eq 4 -or $computerSystem.DomainRole -eq 5) {
        return $true
    }
    else {
        return $false
    }
}

function New-LAPPassword {
    [CmdletBinding()]
    param (
        [int]$Length = 30,
        [string]$CharSets = 'ULNS'
    )
    
    $charGroups = @{
        U = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        L = [char[]]'abcdefghijklmnopqrstuvwxyz'
        N = [char[]]'0123456789'
        S = [char[]]'!%&()*+,-./:;<=>?@[]^_{}~' # Excluded problematic chars like " ' # $ \ `
    }

    $passwordChars = [System.Collections.Generic.List[char]]@()
    $allAvailableChars = [System.Collections.Generic.List[char]]@()

    # Ensure at least one character from each specified set is included
    foreach ($set in $CharSets.ToCharArray()) {
        $key = $set.ToString().ToUpper()
        if ($charGroups.ContainsKey($key)) {
            $passwordChars.Add(($charGroups[$key] | Get-Random))
            $allAvailableChars.AddRange($charGroups[$key])
        }
    }

    # Fill the rest of the password length with random characters from all allowed sets
    $remainingLength = $Length - $passwordChars.Count
    if ($remainingLength -gt 0) {
        for ($i = 0; $i -lt $remainingLength; $i++) {
            $passwordChars.Add(($allAvailableChars | Get-Random))
        }
    }

    # Shuffle the characters and join them into a final string
    return -join ($passwordChars | Get-Random -Count $passwordChars.Count)
}

## Script Logic

if (-not (Test-IsDomainController)) {
    try {
        # Validate and cast RMM script parameters with sensible defaults.
        $PasswordLength = if ($env:passwordLength) { [int]$env:passwordLength } else { 30 }
        $PasswordCharSet = if ($env:passwordCharSet) { $env:passwordCharSet } else { 'ULNS' }
        $Global:DiagMsg += "Password parameters: Length '$($PasswordLength)', CharSet '$($PasswordCharSet)'."
        $Global:DiagMsg += "Hard-coded Azure AD exclusion domain: '$($MSPDomain)'."

        # --- 1. Generate New Password ---
        $Global:DiagMsg += "Generating new password for user '$($LocalAdminUsername)'."
        $newPassword = New-LAPPassword -Length $PasswordLength -CharSet $PasswordCharSet
        $newPasswordSecure = ConvertTo-SecureString -String $newPassword -AsPlainText -Force
        $Global:DiagMsg += "Password generated successfully."

        # --- 2. Create or Update the Local Admin User ---
        $Global:DiagMsg += "Checking for local user '$($LocalAdminUsername)'."
        try {
            $localUser = Get-LocalUser -Name $LocalAdminUsername -ErrorAction Stop
            $Global:DiagMsg += "User '$($LocalAdminUsername)' exists. Updating password."
            Set-LocalUser -InputObject $localUser -Password $newPasswordSecure -PasswordNeverExpires $true
            if (-not $localUser.Enabled) {
                $Global:DiagMsg += "User '$($LocalAdminUsername)' is disabled. Enabling."
                Enable-LocalUser -InputObject $localUser
            }
        }
        catch [Microsoft.PowerShell.Commands.UserNotFoundException] {
            $Global:DiagMsg += "User '$($LocalAdminUsername)' not found. Creating new user."
            New-LocalUser -Name $LocalAdminUsername -Password $newPasswordSecure -FullName "Umbrella Local Admin" -Description "Managed local administrator account." -PasswordNeverExpires $true -ErrorAction Stop
        }
    
        # --- 3. Ensure User is in Administrators Group ---
        $Global:DiagMsg += "Ensuring '$($LocalAdminUsername)' is a member of the 'Administrators' group."
        Add-LocalGroupMember -Group 'Administrators' -Member $LocalAdminUsername -ErrorAction SilentlyContinue

        # --- 4. Clean Up Administrators Group ---
        $Global:DiagMsg += "Auditing 'Administrators' group membership."
        $adminGroupMembers = Get-LocalGroupMember -Group 'Administrators'
        foreach ($member in $adminGroupMembers) {
            $memberName = $member.Name
            # Define conditions to KEEP a user
            $isProtectedUser = ($memberName -eq "BUILTIN\Administrators") -or ($memberName -eq "*\AAD DC Administrators") -or ($memberName -like "*\$($LocalAdminUsername)")
            $isMSPNETBIOSUser = ($memberName -like "$($MSPNETBIOSDomain)\*")
            $isAzureADUser = ($memberName -like "AzureAD\*") -and ($memberName.Split('\')[1] -like "*@$($MSPDomain)")
            $isUnresolvedSID = ($memberName -match '^S-\d-\d+-(\d+-){1,14}\d+$') # Regex to detect a SID

            if ($isProtectedUser) {
                $Global:DiagMsg += "Keeping protected user: '$($memberName)'."
                continue
            }
            if ($isMSPNETBIOSUser) {
                $Global:DiagMsg += "Keeping MSP NetBIOS domain user: '$($memberName)'."
                continue
            }
            if ($isAzureADUser) {
                $Global:DiagMsg += "Keeping Azure AD user from specified domain: '$($memberName)'."
                continue
            }
            if ($isUnresolvedSID) {
                $Global:DiagMsg += "Keeping unresolved SID (likely an Azure AD Principal): '$($memberName)'."
                continue
            }

            # If not protected by any rule, remove the user
            $Global:DiagMsg += "Removing unauthorized user from Administrators group: '$($memberName)'."
            try {
                Remove-LocalGroupMember -Group 'Administrators' -Member $memberName -ErrorAction Stop
            }
            catch {
                $Global:DiagMsg += "Warning: Could not remove '$($memberName)'. Manual review may be needed. Error: $($_.Exception.Message)"
            }
        }

        # --- 5. Disable Default Accounts ---
        $Global:DiagMsg += "Ensuring default accounts are disabled: $($AccountsToDisable -join ', ')."
        foreach ($account in $AccountsToDisable) {
            try {
                # Added -ErrorAction Stop to Get-LocalUser to properly trigger the catch block if the user doesn't exist.
                Get-LocalUser -Name $account -ErrorAction Stop | Disable-LocalUser
                $Global:DiagMsg += "Account '$($account)' confirmed disabled."
            }
            catch {
                $Global:DiagMsg += "Info: Could not disable account '$($account)' as it was not found."
            }
        }
        # --- 7. Prepare Custom Field Data ---
        $statusMessage = "$($LocalAdminUsername) | $Date"
        $Global:DiagMsg += "Data prepared for NinjaRMM Custom Fields."
    
        # --- 8. Set Ninja RMM Custom Fields ---
        $Global:DiagMsg += "Updating NinjaRMM Custom Fields..."
        Ninja-Property-Set -Name $AdminPassCustomField -Value $newPassword
        Ninja-Property-Set -Name $AdminNameCustomField -Value $statusMessage
        $Global:DiagMsg += "Successfully set Custom Fields '$($AdminNameCustomField)' and '$($AdminPassCustomField)'."
    }
    catch {
        $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
        $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
    }
}
else {
    # If the result is TRUE (it is a DC), write a message and move on.
    $Global:DiagMsg += "This computer is a domain controller. Skipping password rotation."
    $Global:AlertHealthy = "This computer is a domain controller. Password rotation has been skipped. | Last Checked $Date"
}

######## End of Script ###########
##################################
##################################

# This script uses hard-coded custom field names, so the generic boilerplate reporting block is not needed.

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