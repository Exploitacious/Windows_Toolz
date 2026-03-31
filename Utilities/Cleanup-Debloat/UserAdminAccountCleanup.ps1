<#
.SYNOPSIS
    This script performs security hardening and cleanup on a local machine. It ensures a specific
    account is the sole administrator, removes the built-in Administrator account, and deletes
    old, inactive user profiles.

.DESCRIPTION
    The script executes two main tasks:
    1. Administrator Security Hardening: It verifies a designated admin account exists. If so, it
       removes all other users from the local Administrators group and then deletes the built-in
       'Administrator' account.
    2. Inactive Profile Cleanup: It scans for and removes user profiles (and their associated accounts,
       if found) that have not been used within a specified number of days.

.NOTES
    Author: Your Name
    Date: 2025-06-10
    Version: 2.0

    WARNING: THIS SCRIPT MAKES SIGNIFICANT, DESTRUCTIVE CHANGES.
             - It modifies administrator privileges and can lock you out if the designated
               admin account ('UmbrellaLA') is not accessible.
             - It permanently deletes user profiles and data.
             - ALWAYS test in a non-production environment first.
             - Run this script with elevated (Administrator) privileges.
#>

#================================================================================
#      Configuration
#================================================================================

# The user account that MUST be the sole local administrator.
[string]$RequiredAdminAccount = "UmbrellaLA"

# Define the number of days of inactivity before a user profile is considered old.
[int]$InactiveDaysThreshold = 90

# List of local user account names to exclude from profile deletion.
# The built-in 'Administrator' is intentionally excluded from this list to ensure its profile is removed.
[string[]]$ExcludedUsers = @(
    "Default",
    "defaultuser0",
    "Public"
    # Note: 'UmbrellaLA' is implicitly protected because the script will not remove the sole admin.
)

#================================================================================
#      1. Administrator Security Hardening
#================================================================================

Write-Host "--- Starting Administrator Security Hardening ---" -ForegroundColor Cyan

try {
    # CRITICAL CHECK: Verify the required administrator account exists before making any changes.
    $TargetAdmin = Get-LocalUser -Name $RequiredAdminAccount -ErrorAction SilentlyContinue

    if (-not $TargetAdmin) {
        Write-Warning "The required administrator account '$RequiredAdminAccount' was NOT FOUND."
        Write-Warning "To prevent lockout, no changes will be made to administrator accounts."
    }
    else {
        Write-Host "Required account '$RequiredAdminAccount' found. Proceeding with hardening." -ForegroundColor Green

        # --- Set the sole administrator ---
        $AdminGroup = Get-LocalGroup -Name "Administrators"
        $AdminMembers = Get-LocalGroupMember -Group $AdminGroup

        # Remove any member that is not our required admin
        foreach ($Member in $AdminMembers) {
            if ($Member.Name -ne $TargetAdmin.Name) {
                Write-Host "  - Removing '$($Member.Name)' from the Administrators group."
                Remove-LocalGroupMember -Group $AdminGroup -Member $Member.Name -ErrorAction SilentlyContinue
            }
        }

        # Ensure the required admin is in the group (handles cases where the user exists but is not an admin)
        if (($AdminMembers | Where-Object { $_.Name -eq $TargetAdmin.Name }).Length -eq 0) {
            Write-Host "  - Adding '$($TargetAdmin.Name)' to the Administrators group."
            Add-LocalGroupMember -Group $AdminGroup -Member $TargetAdmin.Name
        }
        
        Write-Host "'$RequiredAdminAccount' is now configured as the sole administrator." -ForegroundColor Green

        # --- Disable and remove the built-in Administrator account ---
        $BuiltInAdmin = Get-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue
        if ($BuiltInAdmin) {
            Write-Host "  - Disabling and removing the built-in 'Administrator' account."
            $BuiltInAdmin | Disable-LocalUser -ErrorAction SilentlyContinue
            $BuiltInAdmin | Remove-LocalUser -ErrorAction Stop
            Write-Host "  - Successfully removed the 'Administrator' account." -ForegroundColor Green
        }
        else {
            Write-Host "  - Built-in 'Administrator' account not found. It may have been removed already."
        }
    }
}
catch {
    Write-Warning "An error occurred during Administrator Security Hardening."
    Write-Warning $_.Exception.Message
}

#================================================================================
#      2. Identify and Remove Inactive User Profiles
#================================================================================

Write-Host "`n--- Starting Inactive User Profile Cleanup ---" -ForegroundColor Cyan
Write-Host "Searching for profiles inactive for more than $InactiveDaysThreshold days..." -ForegroundColor Yellow

try {
    $ThresholdDate = (Get-Date).AddDays(-$InactiveDaysThreshold)
    $AllProfiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop

    # Exclude the required admin from the profile cleanup, in addition to the other exclusions
    $FinalExcludedUsers = $ExcludedUsers + $RequiredAdminAccount
    
    $InactiveProfiles = $AllProfiles | Where-Object {
        $_.LastUseTime -and
        $_.LastUseTime -lt $ThresholdDate -and
        -not $_.Special -and
        ($FinalExcludedUsers -notcontains ($_.LocalPath.Split('\')[-1]))
    }

    if ($InactiveProfiles) {
        Write-Host "Found the following inactive profiles for removal:" -ForegroundColor Green
        $InactiveProfiles | Select-Object @{Name = "Username"; Expression = { $_.LocalPath.Split('\')[-1] } }, LastUseTime | Format-Table

        foreach ($Profile in $InactiveProfiles) {
            $Username = $Profile.LocalPath.Split('\')[-1]
            Write-Host "Processing profile for user: $Username"

            # Attempt to remove the local user account if it still exists
            $LocalUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
            if ($LocalUser) {
                Write-Host "  - Removing local user account: $Username"
                try { Remove-LocalUser -SID $LocalUser.SID -ErrorAction Stop } catch {}
            }

            # Remove the profile directory and registry entries
            Write-Host "  - Removing profile data at $($Profile.LocalPath)"
            try {
                $Profile | Remove-CimInstance -ErrorAction Stop
                Write-Host "    - Successfully removed profile." -ForegroundColor Green
            }
            catch {
                Write-Warning "    - FAILED to remove profile for SID $($Profile.SID)."
                Write-Warning "      $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Host "No inactive user profiles found that match the criteria." -ForegroundColor Green
    }
}
catch {
    Write-Warning "An unexpected error occurred during profile cleanup."
    Write-Warning $_.Exception.Message
}

Write-Host "`nScript finished." -ForegroundColor Yellow