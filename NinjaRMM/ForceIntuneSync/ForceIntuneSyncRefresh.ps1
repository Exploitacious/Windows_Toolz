# Script Title: Force Intune Sync and App Refresh
# Description: This script forces a device to sync with Microsoft Intune to retrieve the latest policies. It can also force a re-evaluation and re-installation of specific or all deployed Win32 applications by clearing their registration status in the registry.

# Script Name and Type
$ScriptName = "Force Intune Sync and App Refresh"
$ScriptType = "Remediation" # Or "Monitoring", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ## Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# forcePolicyRefresh (Checkbox): If checked, the script will force a full Intune policy sync. Default is true.
# forceAppRefresh (Checkbox): If checked, the script will force a re-install of Win32 apps. Default is false.
# specificAppIDs (Text): A comma-separated list of App IDs (GUIDs) to refresh. Leave empty to refresh ALL apps if forceAppRefresh is checked.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Intune actions completed successfully. | Last Checked $Date"

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
$Global:customFieldMessage = ""

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
    #region --- Configuration & Helper Functions ---
    
    # --- Process RMM Variables ---
    $runPolicyRefresh = if ($env:forcePolicyRefresh) { [bool]::Parse($env:forcePolicyRefresh) } else { $true }
    $runAppRefresh = if ($env:forceAppRefresh) { [bool]::Parse($env:forceAppRefresh) } else { $false }
    $specificAppIDsToRefresh = @()
    if (-not [string]::IsNullOrWhiteSpace($env:specificAppIDs)) {
        $specificAppIDsToRefresh = $env:specificAppIDs -split ',' | ForEach-Object { $_.Trim() }
    }

    $Global:DiagMsg += "[CONFIG] Force Intune Policy Refresh: $runPolicyRefresh"
    $Global:DiagMsg += "[CONFIG] Force Win32 App Refresh: $runAppRefresh"
    $Global:DiagMsg += "[CONFIG] Specific App IDs to Refresh: $($specificAppIDsToRefresh -join ', ')"

    # --- Helper Functions ---
    function Get-DeviceAndUserState {
        <#
    .SYNOPSIS
        Checks the device's Azure AD join state and finds the Intune Management Extension user profile.
    .DESCRIPTION
        This function executes 'dsregcmd /status' to determine if the device is Azure AD Joined or Hybrid Joined.
        It also locates the most recently used user profile GUID from the Intune Management Extension registry path,
        which is required for Win32 app operations.
    .OUTPUTS
        A PSCustomObject with the following properties:
        - IsIntuneManaged (Boolean): $true if AzureAdJoined is YES.
        - JoinState (String): A descriptive string like "Hybrid Azure AD Joined", "Azure AD Joined", "Domain Joined", or "Workgroup".
        - TenantName (String): The name of the Azure tenant, if available.
        - UserObjectID (String): The GUID of the user profile from the IME registry, if found.
    #>
        $Global:DiagMsg += "Running device and user state analysis..."
        $output = [PSCustomObject]@{
            IsIntuneManaged = $false
            JoinState       = "Unknown"
            TenantName      = $null
            UserObjectID    = $null
        }

        try {
            # Part 1: Get Device Join State using dsregcmd
            $dsregOutput = (dsregcmd /status)
            if ([string]::IsNullOrWhiteSpace($dsregOutput)) {
                throw "dsregcmd /status returned no output. Cannot determine join state."
            }

            $isAzureAdJoined = $dsregOutput -match "AzureAdJoined\s+:\s+YES"
            $isDomainJoined = $dsregOutput -match "DomainJoined\s+:\s+YES"

            if ($isAzureAdJoined) {
                $output.IsIntuneManaged = $true
                $output.JoinState = if ($isDomainJoined) { "Hybrid Azure AD Joined" } else { "Azure AD Joined" }
            
                # Safely check for a TenantName match before trying to access the result.
                $tenantMatch = $dsregOutput | Select-String -Pattern "TenantName\s+:\s+(.*)"
                if ($tenantMatch) {
                    $output.TenantName = $tenantMatch.Matches.Groups[1].Value.Trim()
                }
            }
            elseif ($isDomainJoined) {
                $output.JoinState = "Domain Joined"
            }
            else {
                $output.JoinState = "Workgroup"
            }
            $Global:DiagMsg += "[INFO] Device Join State determined as: $($output.JoinState)."
            if ($output.TenantName) { $Global:DiagMsg += "[INFO] Tenant Name: $($output.TenantName)." }

            # Part 2: Get the IME User Object ID
            $win32AppsPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps"
            $userKey = Get-ChildItem -Path $win32AppsPath -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

            if ($userKey) {
                $output.UserObjectID = $userKey.PSChildName
                $Global:DiagMsg += "[INFO] Found Intune user profile: $($output.UserObjectID)."
            }
            else {
                $Global:DiagMsg += "[WARNING] No user profiles found under the Win32Apps registry key. App refresh may fail."
            }

        }
        catch {
            $Global:DiagMsg += "[ERROR] Failed to get device and user state: $($_.Exception.Message)"
            # CRITICAL FIX: On any failure, explicitly reset to a known-bad state.
            $output.IsIntuneManaged = $false
            $output.JoinState = "State Check Failed"
        }
    
        return $output
    }    
    #endregion --- Configuration & Helper Functions ---


    #region --- Core Action Functions ---

    function Invoke-IntunePolicyRefresh {
        $Global:DiagMsg += "[ACTION] Running Intune Policy Refresh..."
        
        # Force a full device sync to pull the latest policies from Intune
        $Global:DiagMsg += "Step 1 of 2: Forcing device sync with Intune service..."
        try {
            Start-Process -FilePath "$env:windir\system32\deviceenroller.exe" -ArgumentList "/c /AutoEnrollMDM" -Wait -WindowStyle Hidden
            $Global:DiagMsg += "[SUCCESS] Device sync command executed."
        }
        catch {
            $Global:DiagMsg += "[ERROR] Failed to run deviceenroller.exe: $($_.Exception.Message)"
        }
        
        # Restart the Intune service to finalize the refresh
        $Global:DiagMsg += "Step 2 of 2: Restarting Intune Management Extension service..."
        try {
            Get-Service -Name "IntuneManagementExtension" -ErrorAction Stop | Restart-Service -Force
            $Global:DiagMsg += "[SUCCESS] Intune Management Extension service restarted."
        }
        catch {
            $Global:DiagMsg += "[WARNING] The 'IntuneManagementExtension' service was not found. Win32 apps and some scripts may not apply."
        }
        $Global:DiagMsg += "Policy refresh has been initiated."
    }

    function Invoke-Win32AppRefresh {
        param(
            [string]$UserObjectID
        )

        $Global:DiagMsg += "[ACTION] Running Win32 App Refresh..."
        if (-not $UserObjectID) {
            $Global:DiagMsg += "[ERROR] User Object ID was not provided. Cannot proceed with app refresh."
            return
        }

        $basePath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps\$UserObjectID"
        
        # Logic for SPECIFIC apps
        if ($specificAppIDsToRefresh.Count -gt 0) {
            $Global:DiagMsg += "Refreshing specific applications."
            foreach ($appId in $specificAppIDsToRefresh) {
                if ($appId -notmatch '^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$') {
                    $Global:DiagMsg += "[WARNING] Skipping invalid GUID: $appId"
                    continue
                }
                $Global:DiagMsg += "--- Processing App ID: $appId ---"
                try {
                    $appKey = Get-ChildItem -Path $basePath | Where-Object { $_.PSChildName -match $appId }
                    if ($appKey) { 
                        $appKey | Remove-Item -Recurse -Force
                        $Global:DiagMsg += "[SUCCESS] Removed app tracking key: $($appKey.Name)"
                    }
                    else { 
                        $Global:DiagMsg += "[INFO] Could not find tracking key for App ID $appId. It may not be installed." 
                    }
                }
                catch {
                    $Global:DiagMsg += "[ERROR] An error occurred processing $appId : $($_.Exception.Message)"
                }
            }
        }
        # Logic for ALL apps
        else {
            $Global:DiagMsg += "Refreshing ALL applications for user $userObjectID."
            $Global:DiagMsg += "[WARNING] This will remove the installation history for ALL applications managed by Intune."
            try {
                Get-Item -Path $basePath | Remove-Item -Recurse -Force
                $Global:DiagMsg += "[SUCCESS] Removed entire user registry key: $basePath"
            }
            catch {
                $Global:DiagMsg += "[ERROR] Failed to remove registry key. Error: $($_.Exception.Message)"
            }
        }
        
        # Final step: Restart the service to apply changes
        $Global:DiagMsg += "Restarting the Intune Management Extension to process app changes..."
        try {
            Get-Service -Name "IntuneManagementExtension" | Restart-Service -Force -ErrorAction Stop
            $Global:DiagMsg += "[SUCCESS] Service restarted. App re-evaluation will begin shortly."
        }
        catch {
            $Global:DiagMsg += "[ERROR] Could not restart Intune Management Extension Service: $($_.Exception.Message)"
        }
    }
    
    #endregion --- Core Action Functions ---

    #region --- Script Entry Point ---

    $actionsTaken = @()
    $finalStatusInfo = ""

    # Pre-flight check for Intune Enrollment and User State
    $deviceState = Get-DeviceAndUserState

    if (-NOT $deviceState.IsIntuneManaged) {
        $alertMessage = "Device not managed by Intune (State: $($deviceState.JoinState)). No actions taken."
        $Global:AlertMsg = "$alertMessage | Last Checked $Date"
        $Global:customFieldMessage = "Failed: $alertMessage ($Date)"
    }
    else {
        $Global:DiagMsg += "[INFO] Device is Intune managed. Proceeding with actions."
        $finalStatusInfo = "(State: $($deviceState.JoinState)"
        if ($deviceState.TenantName) { $finalStatusInfo += ", Tenant: $($deviceState.TenantName)" }
        $finalStatusInfo += ")"

        if ($runPolicyRefresh) {
            Invoke-IntunePolicyRefresh
            $actionsTaken += "Policy Sync"
        }

        if ($runAppRefresh) {
            # Pass the discovered UserObjectID to the function
            Invoke-Win32AppRefresh -UserObjectID $deviceState.UserObjectID
            $action = if ($specificAppIDsToRefresh.Count -gt 0) { "App Refresh (Specific)" } else { "App Refresh (All)" }
            $actionsTaken += $action
        }

        if ($actionsTaken.Count -eq 0) {
            $Global:customFieldMessage = "No actions were selected to run. $finalStatusInfo ($Date)"
            $Global:DiagMsg += "No actions selected in RMM variables. Script completed without changes."
        }
        else {
            $Global:customFieldMessage = "Actions initiated: $($actionsTaken -join ', '). $finalStatusInfo ($Date)"
        }
    }
    
    #endregion --- Script Entry Point ---

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
    $Global:customFieldMessage = "Script failed with an error. ($Date)"
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