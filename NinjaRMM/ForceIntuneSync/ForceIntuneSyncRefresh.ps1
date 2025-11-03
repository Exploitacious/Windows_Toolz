# Script Title: Force Intune Sync and App Refresh
# Description: This script forces a device to sync with Microsoft Intune to retrieve the latest policies. It can also force a re-evaluation and re-installation of specific or all deployed Win32 applications by clearing their registration status in the registry.

# Script Name and Type
$ScriptName = "Force Intune Sync and App Refresh"
$ScriptType = "Remediation" # Or "Monitoring", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ## Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# forceAppRefresh (Checkbox): If checked, the script will force a re-install of Win32 apps. Default is false.

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
        # On any failure, explicitly reset to a known-bad state.
        $output.IsIntuneManaged = $false
        $output.JoinState = "State Check Failed"
    }
    
    return $output
}

function Clear-ComplianceScriptsReports {
    # Clear Intune compliance script history to force re-run
    $Global:DiagMsg += "Clearing Intune script execution and report history..."
    $scriptExecPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies\Scripts\Execution"
    $scriptReportPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies\Scripts\Reports"

    # Clear Execution History
    try {
        if (Test-Path $scriptExecPath) {
            Get-ChildItem -Path $scriptExecPath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction Stop
            $Global:DiagMsg += "[SUCCESS] Cleared script execution history from $scriptExecPath"
        }
        else {
            $Global:DiagMsg += "[INFO] Script execution path $scriptExecPath not found. Skipping."
        }
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to clear script execution history: $($_.Exception.Message)"
    }

    # Clear Report History
    try {
        if (Test-Path $scriptReportPath) {
            Get-ChildItem -Path $scriptReportPath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction Stop
            $Global:DiagMsg += "[SUCCESS] Cleared script report history from $scriptReportPath"
        }
        else {
            $Global:DiagMsg += "[INFO] Script report path $scriptReportPath not found. Skipping."
        }
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to clear script report history: $($_.Exception.Message)"
    }   
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
    $Global:DiagMsg += "Refreshing ALL applications for user $userObjectID."
    
    try {
        Get-Item -Path $basePath | Remove-Item -Recurse -Force
        $Global:DiagMsg += "[SUCCESS] Removed entire user registry key: $basePath"
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to remove registry key. Error: $($_.Exception.Message)"
    }
}

function Restart-IntuneService {
    # Restart the Intune service to finalize the refresh
    $Global:DiagMsg += "Restarting Intune Management Extension service..."
    try {
        Get-Service -Name "IntuneManagementExtension" -ErrorAction Stop | Restart-Service -Force -WarningAction SilentlyContinue
        $Global:DiagMsg += "[SUCCESS] Intune Management Extension service restarted."
    }
    catch {
        $Global:DiagMsg += "[ERROR] Could not restart Intune Management Extension Service: $($_.Exception.Message)"
    }
    $Global:DiagMsg += "Policy refresh has been initiated."
}

function Run-IntuneServiceSync {
    # Force a full device sync to pull the latest policies from Intune 
    $Global:DiagMsg += "Forcing device sync with Intune Management Extension..."
    try {
        Start-Process -FilePath "C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe" -ArgumentList "intunemanagementextension://synccompliance"
        $Global:DiagMsg += "[SUCCESS] Device sync command executed."
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to run Intune Management Extension: $($_.Exception.Message)"
    }    
}

function Run-FullDeviceSync {
    # Force a full device sync to pull the latest policies from Intune
    $Global:DiagMsg += "Forcing device sync with Intune service..."
    try {
        Start-Process -FilePath "$env:windir\system32\deviceenroller.exe" -ArgumentList "/c /AutoEnrollMDM" -Wait -WindowStyle Hidden
        $Global:DiagMsg += "[SUCCESS] Device sync command executed."
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to run deviceenroller.exe: $($_.Exception.Message)"
    }
}

function Run-DeviceHealthAttestation {
    # Force the Device Health Attestation task to run
    $Global:DiagMsg += "Forcing Device Health Attestation (DHA) task to run..."
    try {
        $task = Get-ScheduledTask -TaskName "TPM-HASCertRetr" -TaskPath "\Microsoft\Windows\TPM\" -ErrorAction Stop
        if ($task.State -eq 'Running') {
            $Global:DiagMsg += "[INFO] DHA task 'TPM-HASCertRetr' is already running. Skipping."
        }
        else {
            Start-ScheduledTask -InputObject $task
            $Global:DiagMsg += "[SUCCESS] Triggered 'TPM-HASCertRetr' scheduled task."
        }
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to find or start 'TPM-HASCertRetr' task: $($_.Exception.Message)"
    }    
}


##################################
######## Start of Script #########

try {    
    # --- Process RMM Variables ---
    $runAppRefresh = if ($env:forceAppRefresh) { [bool]::Parse($env:forceAppRefresh) } else { $false }  
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
        $finalStatusInfo = "(State: $($deviceState.JoinState))"
        
        Clear-ComplianceScriptsReports
        $actionsTaken += "Scripts Cleared"

        # Win32 App Refresh
        if ($runAppRefresh) {
            Invoke-Win32AppRefresh -UserObjectID $deviceState.UserObjectID
            $actionsTaken += "Apps Cleared"
        }

        Restart-IntuneService
        $actionsTaken += "Svc Restart"

        Run-IntuneServiceSync
        $actionsTaken += "IME Sync"

        Run-FullDeviceSync
        $actionsTaken += "Device Sync"

        Run-DeviceHealthAttestation
        $actionsTaken += "DHA Run"

        # Finish Report on Actions Taken
        if ($actionsTaken.Count -eq 0) {
            $Global:customFieldMessage = "No actions were selected to run. $finalStatusInfo ($Date)"
            $Global:DiagMsg += "No actions selected in RMM variables. Script completed without changes."
        }
        else {
            $Global:customFieldMessage = "Actions initiated: $($actionsTaken -join ', '). $finalStatusInfo ($Date)"
        }
    }
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