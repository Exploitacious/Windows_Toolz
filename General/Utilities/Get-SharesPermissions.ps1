<#
.SYNOPSIS
    Retrieves and displays the security permissions for all shares on specified computers.

.DESCRIPTION
    This script queries Windows Management Instrumentation (WMI) to enumerate all network shares on one or more target computers.
    For each share, it retrieves the Discretionary Access Control List (DACL) and displays the permissions granted or denied to each user or group.
    The script is designed to run on PowerShell 5.1 without any external modules.

.NOTES
    Author: Alex Ivantsov
    Date:   06/07/2025
    Version: 4.0
#>

#================================================================================
#                            USER-CONFIGURABLE VARIABLES
#================================================================================

# Define the target computers to scan.
# To scan the local computer, use '.'. For remote computers, use their hostname or IP address.
# Example for multiple computers: $TargetComputers = @('.', 'SERVER01', '192.168.1.100')
[string[]]$TargetComputers = @(
    '.'
)

#================================================================================
#                                  FUNCTIONS
#================================================================================

Function Convert-AccessMaskToPermission {
    <#
.SYNOPSIS
    Converts a numeric Win32_Ace AccessMask to a human-readable share permission string.
.PARAMETER AccessMask
    The integer value of the AccessMask property from a Win32_Ace object.
.RETURNS
    A string representing the share permission (e.g., "Full Control", "Change", "Read").
#>
    param (
        [Parameter(Mandatory = $true)]
        [int]$AccessMask
    )

    # The AccessMask is a bitmask. We use a switch statement to match the most common permission sets.
    switch ($AccessMask) {
        2032127 { return "Full Control" } # Corresponds to GENERIC_ALL
        1245631 { return "Change" }       # Corresponds to GENERIC_WRITE + GENERIC_READ + GENERIC_EXECUTE
        1179817 { return "Read" }         # Corresponds to GENERIC_READ + GENERIC_EXECUTE
        default { return "Custom ($AccessMask)" } # Return the raw mask if it's not a standard one.
    }
}

Function Get-FormattedSharePermissions {
    <#
.SYNOPSIS
    Connects to a computer, enumerates its shares, and retrieves the permissions for each.
.PARAMETER ComputerName
    The name or IP address of the target computer.
.RETURNS
    An array of custom PowerShell objects, each representing a specific permission entry for a share.
#>
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    # Announce which computer is being processed.
    Write-Host "--- Processing Computer: $ComputerName ---" -ForegroundColor Cyan

    # Retrieve all shares from the target computer using WMI.
    # We use a try/catch block to handle cases where the computer is offline or inaccessible.
    try {
        $Shares = Get-WmiObject -Class Win32_Share -ComputerName $ComputerName -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not connect to or retrieve shares from '$ComputerName'. Please ensure it is online and you have the necessary permissions."
        # Exit the function for this computer if we can't get the shares.
        return
    }

    # If no shares are found, print a message and exit the function.
    if (-not $Shares) {
        Write-Host "No shares found on '$ComputerName'."
        return
    }

    # Iterate through each share found on the computer.
    foreach ($Share in $Shares) {
        $ShareName = $Share.Name
        Write-Host "`n--> Share: $ShareName" -ForegroundColor Green

        # Get the security settings for the current share.
        $SecuritySetting = Get-WmiObject -Class Win32_LogicalShareSecuritySetting -Filter "Name='$ShareName'" -ComputerName $ComputerName

        try {
            # Retrieve the Security Descriptor for the share.
            # The .Descriptor property contains the Access Control List (DACL).
            $SecurityDescriptor = $SecuritySetting.GetSecurityDescriptor().Descriptor

            # If the DACL is empty, it means there are no explicit permissions set.
            if (-not $SecurityDescriptor.DACL) {
                Write-Host "    No explicit permissions found for this share."
                continue # Skip to the next share.
            }

            # Iterate through each Access Control Entry (ACE) in the DACL.
            foreach ($Ace in $SecurityDescriptor.DACL) {
                # Determine the user or group name associated with the permission.
                $Trustee = $Ace.Trustee
                if ($Trustee.Domain) {
                    $AccountName = "$($Trustee.Domain)\$($Trustee.Name)"
                }
                elseif ($Trustee.Name) {
                    $AccountName = $Trustee.Name
                }
                else {
                    # If the name is not available, fall back to the SID.
                    $AccountName = $Trustee.SIDString
                }

                # Determine if the permission is an "Allow" or "Deny" type.
                # AceType 0 corresponds to "Allow" and 1 corresponds to "Deny".
                $PermissionType = switch ($Ace.AceType) {
                    0 { "Allow" }
                    1 { "Deny" }
                }

                # Convert the numeric access mask to a readable format.
                $Permissions = Convert-AccessMaskToPermission -AccessMask $Ace.AccessMask

                # Create a custom object to hold the collected information for clean output.
                [PSCustomObject]@{
                    ComputerName   = $ComputerName
                    ShareName      = $ShareName
                    Account        = $AccountName
                    PermissionType = $PermissionType
                    Permissions    = $Permissions
                }
            }
        }
        catch {
            # Catch any errors during the security descriptor retrieval process.
            Write-Warning "    Unable to obtain permissions for share '$ShareName' on '$ComputerName'."
        }
    }
}

#================================================================================
#                                  MAIN EXECUTION
#================================================================================

# Create an empty array to store all the results.
$AllPermissions = @()

# Loop through each computer defined in the $TargetComputers variable.
foreach ($Computer in $TargetComputers) {
    # Call the function to get permissions and add the results to our collection.
    # The '+' operator on an array creates a new array, which is fine for a small number of computers.
    $AllPermissions += Get-FormattedSharePermissions -ComputerName $Computer
}

# Display the final, collected results in a formatted table.
# If no permissions were gathered, this will not produce any output.
if ($AllPermissions) {
    Write-Host "`n"
    Write-Host "===============================================" -ForegroundColor Yellow
    Write-Host "          SHARE PERMISSIONS SUMMARY" -ForegroundColor Yellow
    Write-Host "===============================================" -ForegroundColor Yellow
    $AllPermissions | Format-Table -AutoSize
}

Write-Host "`nScript execution complete." -ForegroundColor Green