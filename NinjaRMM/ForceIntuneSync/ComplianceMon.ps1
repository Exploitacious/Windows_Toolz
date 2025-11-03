# Script Title: Monitor Intune Compliance and Sync Health
# Description: Checks device compliance and verifies last MDM sync status from event logs (Event 813/814). Alerts if not compliant, sync is stale, or a recent failure is detected.

# Script Name and Type
$ScriptName = "Monitor Intune Compliance and Sync Health"
$ScriptType = "Monitoring" # Or "Remediation", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
$logProvider = "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider"

## ORG-LEVEL EXPECTED VARIABLES ##
# None for this script

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# lastSyncThresholdHours (Text): The maximum age (in hours) of the last successful sync before an alert is triggered. Default is 24.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Device is Intune compliant and sync is healthy. | Last Checked $Date"

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

function Get-RegistrySyncStatus {
    $Global:DiagMsg += "Checking MDM enrollment registry for sync status..."
    try {
        $enrollmentKeyPath = "HKLM:\Software\Microsoft\Enrollments"
        $mdmProviderId = "MS DM Server" # Identifies the Intune/MDM enrollment

        $enrollmentGuid = Get-ChildItem -Path $enrollmentKeyPath |
        Where-Object { (Get-ItemProperty -Path $_.PSPath -ErrorAction Stop).ProviderID -eq $mdmProviderId } |
        Select-Object -First 1 |
        Select-Object -ExpandProperty PSChildName

        if (-not $enrollmentGuid) {
            $Global:DiagMsg += "[WARNING] No MDM enrollment key found."
            return $null
        }

        $connInfoPath = "HKLM:\Software\Microsoft\Provisioning\OMADM\Accounts\$enrollmentGuid\Protected\ConnInfo"
        if (Test-Path $connInfoPath) {
            $connInfo = Get-ItemProperty -Path $connInfoPath
            $lastSuccessString = $connInfo.ServerLastSuccessTime
            $Global:DiagMsg += "[INFO] Registry reports last successful sync (raw string): $lastSuccessString"
            
            # --- START FIX ---
            # Convert the registry string to a DateTime object
            try {
                # The format is 'yyyyMMddTHHmmssZ'
                $format = "yyyyMMddTHHmmssZ"
                $dateTimeObj = [DateTime]::ParseExact($lastSuccessString, $format, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
                $Global:DiagMsg += "[INFO] Converted registry sync time to DateTime: $dateTimeObj"
                return $dateTimeObj
            }
            catch {
                $Global:DiagMsg += "[ERROR] Failed to parse registry datetime string '$lastSuccessString': $($_.Exception.Message)"
                return $null
            }
            # --- END FIX ---
        }
        else {
            $Global:DiagMsg += "[WARNING] Could not find registry ConnInfo path."
            return $null
        }
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to query registry for sync status: $($_.Exception.Message)"
        return $null
    }
}

function Get-DeviceRegistrationInfo {
    $Global:DiagMsg += "Checking 'dsregcmd /status' for device state..."
    $output = [PSCustomObject]@{
        JoinType   = "N/A"
        TenantName = "N/A"
        TenantId   = "N/A"
        AzureAdPrt = "No"
        NgcSet     = "No"
    }

    try {
        $dsregOutput = (dsregcmd /status)
        if ([string]::IsNullOrWhiteSpace($dsregOutput)) {
            throw "dsregcmd /status returned no output."
        }

        # Convert the output to a reliable key-value dictionary
        $deviceState = @{}
        foreach ($line in $dsregOutput) {
            if ($line -match "^\s*([a-zA-Z0-9_]+)\s*:\s*(.+?)\s*$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $deviceState[$key] = $value
            }
        }

        # --- Parse Device State (FIXED) ---
        $isAzureAdJoined = if ($deviceState.ContainsKey('AzureAdJoined')) { $deviceState['AzureAdJoined'] -eq 'YES' } else { $false }
        $isDomainJoined = if ($deviceState.ContainsKey('DomainJoined')) { $deviceState['DomainJoined'] -eq 'YES' } else { $false }

        if ($isAzureAdJoined -and $isDomainJoined) {
            $output.JoinType = "Hybrid"
        }
        elseif ($isAzureAdJoined) {
            $output.JoinType = "Entra"
        }
        elseif ($isDomainJoined) {
            $output.JoinType = "Domain"
        }

        # --- Parse Tenant & SSO State (FIXED) ---
        $output.TenantName = if ($deviceState.ContainsKey('TenantName')) { $deviceState['TenantName'] } else { 'N/A' }
        $output.TenantId = if ($deviceState.ContainsKey('TenantId')) { $deviceState['TenantId'] } else { 'N/A' }
        $output.AzureAdPrt = if ($deviceState.ContainsKey('AzureAdPrt')) { $deviceState['AzureAdPrt'] } else { 'NO' }
        $output.NgcSet = if ($deviceState.ContainsKey('NgcSet')) { $deviceState['NgcSet'] } else { 'NO' } # (Windows Hello / WHfB)

        $Global:DiagMsg += "[INFO] Join: $($output.JoinType), Tenant: $($output.TenantName), PRT: $($output.AzureAdPrt), WHfB: $($output.NgcSet)"
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to get device registration info: $($_.Exception.Message)"
    }
    
    return $output
}

##################################
##################################
######## Start of Script #########

try {
    # --- Process RMM Variables ---
    $thresholdHours = 24
    if (-not [string]::IsNullOrWhiteSpace($env:lastSyncThresholdHours)) {
        if (-not ([int]::TryParse($env:lastSyncThresholdHours, [ref]$thresholdHours))) {
            $Global:DiagMsg += "[WARNING] Invalid 'lastSyncThresholdHours' value '$($env:lastSyncThresholdHours)'. Using default 24."
            $thresholdHours = 24
        }
    }
    $Global:DiagMsg += "[CONFIG] Alert threshold for last sync: $thresholdHours hours."
    $thresholdTime = (Get-Date).AddHours(-$thresholdHours)
    
    # --- Define Failure Reasons ---
    $failureReasons = @()
    
    # --- Data Points ---
    $regLastSuccess = $null
    $eventLastSuccess = $null
    $eventLastFailure = $null

    # --- Check 1: Device Registration Info ---
    $deviceInfo = Get-DeviceRegistrationInfo
    
    # --- Check 2: Registry Sync Status ---
    $regLastSuccess = Get-RegistrySyncStatus
    
    # --- Check 3: Event Log Sync Health ---
    $Global:DiagMsg += "Checking Event Logs for last sync times..."
    try {
        $lastSuccessEvent = Get-WinEvent -FilterHashtable @{ProviderName = $logProvider; Id = 813 } -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($lastSuccessEvent) {
            $eventLastSuccess = $lastSuccessEvent.TimeCreated
            $Global:DiagMsg += "[INFO] Last Successful Sync (Event 813) at: $eventLastSuccess"
        }
        else {
            $Global:DiagMsg += "[INFO] No successful sync (Event 813) found in logs."
        }

        $lastFailureEvent = Get-WinEvent -FilterHashtable @{ProviderName = $logProvider; Id = 814 } -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($lastFailureEvent) {
            $eventLastFailure = $lastFailureEvent.TimeCreated
            $Global:DiagMsg += "[INFO] Last Failed Sync (Event 814) at: $eventLastFailure"
        }
        else {
            $Global:DiagMsg += "[INFO] No failed sync (Event 814) found in logs."
        }
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to query sync event logs: $($_.Exception.Message)"
        $failureReasons += "Event Log Check Failed"
    }

    # --- Evaluate Sync Health ---
    
    # Find the most recent success time from ANY source
    $mostRecentSuccess = $null
    if ($regLastSuccess) { $mostRecentSuccess = $regLastSuccess }
    if ($eventLastSuccess -and $eventLastSuccess -gt $mostRecentSuccess) {
        $mostRecentSuccess = $eventLastSuccess
    }

    $syncStatus = "N/A"
    if (-not $mostRecentSuccess) {
        $Global:DiagMsg += "[FAIL] No successful sync time found in registry or event logs."
        $failureReasons += "No successful sync"
        $syncStatus = "Fail (None)"
    }
    elseif ($mostRecentSuccess -lt $thresholdTime) {
        $syncTimeShort = $mostRecentSuccess.ToString('MM/dd hh:mm tt')
        $Global:DiagMsg += "[FAIL] Last successful sync ($syncTimeShort) is older than threshold."
        $failureReasons += "Sync stale"
        $syncStatus = "Fail (Stale: $syncTimeShort)"
    }
    else {
        $syncStatus = "OK ($($mostRecentSuccess.ToString('MM/dd hh:mm tt')))"
    }
    
    if ($eventLastFailure -and $mostRecentSuccess -and ($eventLastFailure -gt $mostRecentSuccess)) {
        $Global:DiagMsg += "[FAIL] A sync failure ($eventLastFailure) has occurred *after* the last successful sync ($mostRecentSuccess)."
        $failureReasons += "Recent failure"
        $syncStatus = "Fail (Recent)"
    }

    # --- Build Concise Custom Field Message ---
    $tenantShort = $deviceInfo.TenantName.Split('.')[0] # Get 'umbrellait' from 'umbrellaitgroup.com'
    $statusMsg = ""
    $prtMsg = "PRT: $($deviceInfo.AzureAdPrt)"
    $whfbMsg = "WHfB: $($deviceInfo.NgcSet)"
    $joinMsg = "Join: $($deviceInfo.JoinType)"
    $tenantMsg = "Tenant: $tenantShort"

    if ($failureReasons.Count -gt 0) {
        $alertString = $failureReasons -join ', '
        $Global:AlertMsg = "Intune Health Check Failed: $alertString. | Last Checked $Date"
        $statusMsg = "Failed: $alertString."
    }
    else {
        $Global:DiagMsg += "[SUCCESS] All Intune health checks passed."
        $statusMsg = "OK. Sync: $($mostRecentSuccess.ToString('MM/dd hh:mm tt'))."
    }

    # Combine for custom field, respecting 200 char limit
    # FIX: Changed $Date.ToString('MM/dd') to (Get-Date -Format 'MM/dd')
    $Global:customFieldMessage = "$statusMsg $joinMsg. $prtMsg. $whfbMsg. $tenantMsg. ($(Get-Date -Format 'MM/dd'))"

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