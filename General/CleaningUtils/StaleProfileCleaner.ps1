<#
.SYNOPSIS
    Cleans up old, inactive, and corrupted Windows user profiles from a local machine.

.DESCRIPTION
    This script identifies and removes user profiles that have been inactive for a specified number of days.
    It reliably determines inactivity by first checking the last modified date of the profile's NTUSER.DAT file.
    If NTUSER.DAT is unreadable, it uses the profile folder's last modification date as a robust fallback.
    It also detects and removes corrupted profiles (where NTUSER.DAT is missing).
    The script includes safeguards to prevent the deletion of system, administrative, or other specified user accounts.

.NOTES
    Author      : Alex Ivantsov
    Date        : 06/19/2025
    Version     : 1.5
    Requires    : PowerShell 5.1. This script is self-contained and does not require any external modules.
    Execution   : Run with administrative privileges to ensure permissions to delete profiles and registry keys.
#>

#------------------------------------------------------------------------------------
# --- USER CONFIGURATION ---
#------------------------------------------------------------------------------------

# Set the number of days a profile must be inactive before it is considered for deletion.
[int]$InactiveDays = 30

# Set the timeout in seconds for the confirmation prompt.
# If no input is received within this time, the script will automatically proceed with the deletion.
[int]$ConfirmationTimeoutSeconds = 15

# Set to $true to perform a "sanity check". This will list every user profile found
# and its last logon time before filtering, helping you diagnose why profiles are being kept or removed.
[boolean]$EnableVerboseSanityCheck = $true

# List of user account names to explicitly exclude from deletion.
# This is a safeguard to protect important accounts.
[string[]]$ExcludedUsers = @(
    'UmbrellaLA',
    'Administrator',
    'Public',
    'Default User',
    'DefaultAccount',
    'WDAGUtilityAccount'
)

#------------------------------------------------------------------------------------
# --- FUNCTIONS ---
#------------------------------------------------------------------------------------

Function Get-StaleUserProfiles {
    <#
    .SYNOPSIS
        Identifies user profiles that are stale, inactive, or corrupted using a fallback mechanism.
    .DESCRIPTION
        Queries WMI for user profiles. It determines inactivity based on the LastWriteTime of the NTUSER.DAT file.
        If that fails, it uses the profile folder's LastWriteTime as a fallback.
    .PARAMETER InactiveDays
        An integer representing the minimum number of days of inactivity.
    .PARAMETER ExcludedUsers
        A string array of usernames to protect from deletion.
    .PARAMETER VerboseCheck
        A boolean switch to enable detailed logging for every profile checked.
    .OUTPUT
        A custom object array. Each object contains the WMI Profile object and a reason for deletion.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [int]$InactiveDays,
        [Parameter(Mandatory = $true)]
        [string[]]$ExcludedUsers,
        [Parameter(Mandatory = $false)]
        [boolean]$VerboseCheck
    )

    Write-Host "Searching for user profiles inactive for more than $InactiveDays days..." -ForegroundColor Cyan
    if ($VerboseCheck) {
        Write-Host "Verbose Sanity Check is ENABLED. All found profiles will be listed below." -ForegroundColor Magenta
        Write-Host "---------------------------------------------------------------------------"
    }

    $CutoffDate = (Get-Date).AddDays(-$InactiveDays)
    $StaleProfiles = @()

    try {
        $AllProfiles = Get-WmiObject -Class Win32_UserProfile -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to query user profiles via WMI. Ensure you are running with Administrator privileges."
        Write-Error $_.Exception.Message
        exit 1
    }

    foreach ($Profile in $AllProfiles) {
        if (-not $Profile.LocalPath -or -not (Test-Path $Profile.LocalPath)) {
            continue
        }

        $Username = $Profile.LocalPath.Split('\')[-1]
        
        # --- PRE-FILTERING for excluded/special accounts ---
        if ($Profile.Special) {
            if ($VerboseCheck) { Write-Host "Checking Profile: $Username `t(Status: Special Profile)`n -> Skipping." -ForegroundColor DarkGray }
            continue
        }
        if ($ExcludedUsers -contains $Username) {
            if ($VerboseCheck) { Write-Host "Checking Profile: $Username `t(Status: Excluded by User)`n -> Skipping." -ForegroundColor DarkGray }
            continue
        }
        
        # --- CORE LOGIC with Fallback ---
        $LastLogonTime = $null
        $Method = ""
        $ntuserPath = Join-Path -Path $Profile.LocalPath -ChildPath "NTUSER.DAT"

        # Primary Method: Check NTUSER.DAT
        $ntuserItem = Get-Item -Path $ntuserPath -ErrorAction SilentlyContinue
        if ($ntuserItem) {
            $LastLogonTime = $ntuserItem.LastWriteTime
            $Method = "NTUSER.DAT"
        } 
        # Fallback Method: Check the parent folder date if NTUSER.DAT is missing or unreadable
        else {
            $folderItem = Get-Item -Path $Profile.LocalPath -ErrorAction SilentlyContinue
            if ($folderItem) {
                $LastLogonTime = $folderItem.LastWriteTime
                $Method = "Folder Date"
            }
        }

        # --- EVALUATION ---
        if ($LastLogonTime) {
            # We have a valid timestamp from one of the methods.
            if ($LastLogonTime -lt $CutoffDate) {
                # INACTIVE: Mark for deletion.
                if ($VerboseCheck) {
                    Write-Host "Checking Profile: $Username `t(Last Logon: $($LastLogonTime.ToString('yyyy-MM-dd'))) (Method: $Method)"
                    Write-Host " -> MARKED FOR DELETION (Reason: Inactive)." -ForegroundColor Red
                }
                $StaleProfiles += [PSCustomObject]@{
                    ProfileObject = $Profile
                    Reason        = "Inactive since $($LastLogonTime.ToString('yyyy-MM-dd')) (via $Method)"
                }
            }
            else {
                # ACTIVE: Skip.
                if ($VerboseCheck) {
                    Write-Host "Checking Profile: $Username `t(Last Logon: $($LastLogonTime.ToString('yyyy-MM-dd'))) (Method: $Method)"
                    Write-Host " -> Skipping: Used too recently." -ForegroundColor DarkGray
                }
            }
        }
        else {
            # Both methods failed. The profile is likely corrupted in a way we can still handle.
            # If NTUSER.DAT is confirmed missing, it's definitely corrupted.
            if (-not (Test-Path $ntuserPath)) {
                if ($VerboseCheck) {
                    Write-Host "Checking Profile: $Username `t(Status: CORRUPTED)"
                    Write-Host " -> MARKED FOR DELETION (Reason: Corrupted Profile)." -ForegroundColor Red
                }
                $StaleProfiles += [PSCustomObject]@{
                    ProfileObject = $Profile
                    Reason        = "Corrupted (NTUSER.DAT missing)"
                }
            }
            else {
                # Truly UNREADABLE.
                if ($VerboseCheck) {
                    Write-Host "Checking Profile: $Username `t(Status: UNREADABLE)"
                    Write-Host " -> Skipping: Cannot determine activity from NTUSER.DAT or folder." -ForegroundColor DarkGray
                }
            }
        }
    }

    if ($VerboseCheck) {
        Write-Host "---------------------------------------------------------------------------"
    }

    return $StaleProfiles
}

Function Confirm-ProfileRemoval {
    <#
    .SYNOPSIS
        Displays the profiles marked for deletion and asks for user confirmation.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [array]$StaleProfiles,
        [Parameter(Mandatory = $true)]
        [int]$Timeout
    )

    Write-Host "`n------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "The following $($StaleProfiles.Count) user profiles will be PERMANENTLY DELETED:" -ForegroundColor Yellow

    $StaleProfiles | ForEach-Object {
        $Username = $_.ProfileObject.LocalPath.Split('\')[-1]
        Write-Host " - Username: $($Username) `t(Reason: $($_.Reason))" -ForegroundColor White
    }

    Write-Host "------------------------------------------------------------`n" -ForegroundColor Yellow
    Write-Warning "This action cannot be undone. All data in these profiles will be lost."

    for ($i = $Timeout; $i -gt 0; $i--) {
        Write-Host -NoNewline "`rProceed with deletion? (Y/N) [Auto-confirming in $i seconds...] "
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.Character -eq 'y') {
                Write-Host "`n`nUser confirmed. Proceeding with deletion." -ForegroundColor Green
                return $true
            }
            if ($key.Character -eq 'n') {
                Write-Host "`n`nUser cancelled the operation. No profiles will be deleted." -ForegroundColor Red
                return $false
            }
        }
        Start-Sleep -Seconds 1
    }

    Write-Host "`n`nTimeout reached. Proceeding automatically." -ForegroundColor Green
    return $true
}

Function Remove-UserProfiles {
    <#
    .SYNOPSIS
        Deletes the specified user profiles.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [array]$ProfilesToDelete
    )

    Write-Host "`nStarting profile deletion process..." -ForegroundColor Cyan
    $DeletionCount = 0

    foreach ($Entry in $ProfilesToDelete) {
        $Profile = $Entry.ProfileObject
        $Username = $Profile.LocalPath.Split('\')[-1]
        Write-Host "Attempting to delete profile for user: $Username..." -ForegroundColor White
        
        try {
            # The .Delete() method handles WMI, registry, and folder removal.
            $Profile.Delete()
            
            if (Test-Path -Path $Profile.LocalPath) {
                Write-Warning "WMI deletion left the profile folder. Attempting forceful removal of '$($Profile.LocalPath)'..."
                Remove-Item -Path $Profile.LocalPath -Recurse -Force -ErrorAction Stop
                Write-Host "Forceful removal of folder successful." -ForegroundColor Green
            }
            else {
                Write-Host "Successfully deleted profile for $Username." -ForegroundColor Green
            }
            $DeletionCount++
        }
        catch {
            Write-Error "Failed to delete profile for '$Username'. Path: $($Profile.LocalPath)"
            Write-Error "Error: $($_.Exception.Message)"
            Write-Error "This may be due to files being in use. A reboot may be required before re-running."
        }
        Write-Host "---"
    }

    Write-Host "`nProfile cleanup complete. Total profiles deleted: $DeletionCount" -ForegroundColor Cyan
}

#------------------------------------------------------------------------------------
# --- SCRIPT EXECUTION ---
#------------------------------------------------------------------------------------

Clear-Host
Write-Host "============================================================"
Write-Host "       Automated User Profile Cleanup Script"
Write-Host "============================================================"
Write-Host

$StaleProfiles = Get-StaleUserProfiles -InactiveDays $InactiveDays -ExcludedUsers $ExcludedUsers -VerboseCheck $EnableVerboseSanityCheck

if ($null -eq $StaleProfiles -or $StaleProfiles.Count -eq 0) {
    Write-Host "No stale or corrupted profiles found matching the criteria. System is clean." -ForegroundColor Green
    Write-Host "Script finished."
    exit 0
}

$Confirmation = Confirm-ProfileRemoval -StaleProfiles $StaleProfiles -Timeout $ConfirmationTimeoutSeconds

if ($Confirmation) {
    Remove-UserProfiles -ProfilesToDelete $StaleProfiles
}
else {
    Write-Host "Script execution cancelled by user."
}

Write-Host "`nScript finished."
