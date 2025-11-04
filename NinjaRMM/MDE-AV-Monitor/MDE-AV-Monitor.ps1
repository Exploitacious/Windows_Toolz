# Script Title: Monitor MDE and AV Status
# Description: Checks Microsoft Defender for Endpoint (MDE) configuration, service status, and detected threats. Verifies BitDefender status if MDE is not in a normal running mode.

# Script Name and Type
$ScriptName = "Monitor MDE and AV Status"
$ScriptType = "Monitoring"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ### This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$BitDefenderServiceName = 'EPSecurityService'
$BitDefenderDisplayName = 'BitDefender'

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the summary status to.
# detectedThreatDetailsFieldName (Text): The name of the Multi-line Text Custom Field for threat details.
# threatRetentionDays (Number): Days to retain a threat in the log. Default: 30

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

function Check-BitDefender {
    <#
        .SYNOPSIS
        Checks if the BitDefender service is running.
        .DESCRIPTION
        Uses the hard-coded service name to check the status of BitDefender.
        .RETURNS
        [bool] $true if the service is running, $false otherwise.
        #>
    $Global:DiagMsg += "Checking BitDefender service status..."
    $bdService = Get-Service -Name $BitDefenderServiceName -ErrorAction SilentlyContinue
        
    if ($bdService -and $bdService.Status -eq 'Running') {
        $Global:DiagMsg += "BitDefender service '$BitDefenderServiceName' is running."
        return $true
    }
    else {
        $Global:DiagMsg += "BitDefender service '$BitDefenderServiceName' is not running or not found. Status: $($bdService.Status)"
        return $false
    }
}

function Check-MDEConfiguration {
    <#
        .SYNOPSIS
        Checks the Get-MpComputerStatus output against a "golden" configuration.
        .DESCRIPTION
        If AMRunningMode is not 'Normal', it checks for BitDefender as an acceptable alternative.
        If AMRunningMode is 'Normal', it validates all key MDE properties.
        .RETURNS
        [bool] $true if compliant, $false if non-compliant.
        #>
    $Global:DiagMsg += ""
    $Global:DiagMsg += "--- Starting MDE Configuration Check ---"
    $avStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue

    if (-not $avStatus) {
        $Global:DiagMsg += "[CRITICAL] Failed to execute Get-MpComputerStatus. Checking for BitDefender..."
        # If MDE is gone, BitDefender *must* be running
        return (Check-BitDefender)
    }

    # 1. Check AMRunningMode
    if ($avStatus.AMRunningMode -ne 'Normal') {
        $Global:DiagMsg += "AMRunningMode is '$($avStatus.AMRunningMode)'. Checking for BitDefender fallback."
        $bdRunning = Check-BitDefender
        if (-not $bdRunning) {
            $Global:DiagMsg += "[CRITICAL] BitDefender is also not running."
            return $false
        }
        else {
            $Global:DiagMsg += "BitDefender is fully operational."
            return $true
        }
    }

    # 2. If AMRunningMode is 'Normal', check the golden configuration
    $Global:DiagMsg += "Microsoft Defender is operational. Validating MDE Desired State..."
    $goldenConfig = @{
        AMServiceEnabled          = $true
        AntispywareEnabled        = $true
        AntivirusEnabled          = $true
        BehaviorMonitorEnabled    = $true
        IoavProtectionEnabled     = $true
        IsTamperProtected         = $true
        NISEnabled                = $true
        OnAccessProtectionEnabled = $true
        RealTimeProtectionEnabled = $true
    }

    $mismatchedProps = @()
    foreach ($key in $goldenConfig.Keys) {
        try {
            if ($avStatus.$key -ne $goldenConfig[$key]) {
                $mismatchedProps += "$key is '$($avStatus.$key)', expected '$($goldenConfig[$key])'"
            }
        }
        catch {
            $mismatchedProps += "Property '$key' could not be read from Get-MpComputerStatus."
        }
    }

    if ($mismatchedProps.Count -gt 0) {
        $Global:DiagMsg += "MDE configuration mismatch: $($mismatchedProps -join '; ')"
        return $false
    }
    else {
        $Global:DiagMsg += "[SUCCESS] MDE matches desired configuration state."
        return $true
    }
}

function Check-MDEService {
    <#
        .SYNOPSIS
        Checks the MDE 'Sense' service and onboarding registry keys.
        .RETURNS
        [bool] $true if compliant, $false if non-compliant.
        #>
    $Global:DiagMsg += ""
    $Global:DiagMsg += "--- Starting MDE Service Check ---"
    $isCompliant = $true
        
    # 1. Check Sense Service
    $senseService = Get-Service -Name "Sense" -ErrorAction SilentlyContinue
    if (-not $senseService -or $senseService.Status -ne 'Running') {
        $Global:DiagMsg += "[CRITICAL] MDE Sense service is not running or not found. Status: $($senseService.Status)"
        $isCompliant = $false
    }
    else {
        $Global:DiagMsg += "MDE Sense service is running."
    }

    # 2. Check Registry
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status\"
    $regStatus = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue

    if (-not $regStatus) {
        $Global:DiagMsg += "[CRITICAL] Could not read MDE registry status from $regPath."
        return $false # This is a hard failure
    }

    try {
        $lastConnectedDate = [datetime]::FromFileTime($regStatus.LastConnected)
        $Global:MDELastConnected = $lastConnectedDate.ToString('yyyy-MM-dd HH:mm:ss')
        $Global:DiagMsg += "Last Connected for update: $Global:MDELastConnected"
    }
    catch {
        $Global:DiagMsg += "Could not parse MDE Last Connected FileTime: $($regStatus.LastConnected)"
    }
        
    if ($regStatus.OnboardingState -ne 1) {
        $Global:DiagMsg += "MDE OnboardingState is '$($regStatus.OnboardingState)', expected '1'."
        $isCompliant = $false
    }
    else {
        $Global:DiagMsg += "[SUCCESS] MDE is Onboarded with OrgID: $($regStatus.OrgId)"
    }

    return $isCompliant
}

function Check-MDEThreats {
    <#
        .SYNOPSIS
        Checks for new MDE threats and writes details to a multi-line custom field.
        .DESCRIPTION
        Compares current detections against a persistent list in a custom field.
        Alerts only on new, previously unlogged ThreatIDs.
        .RETURNS
        [bool] $true if a *new* threat is found, $false otherwise.
        #>
    $Global:DiagMsg += ""
    $Global:DiagMsg += "--- Starting MDE Threat Check ---"
        
    # Get RMM Variables
    $threatField = $env:detectedThreatDetailsFieldName
    if (-not $threatField) {
        $Global:DiagMsg += "RMM variable 'detectedThreatDetailsFieldName' is not set. Skipping threat check."
        return $false
    }

    # Get existing data from Custom Field
    $existingThreatData = $null
    $propertyObject = $null
    try {
        $propertyObject = Ninja-Property-Get -Name $threatField -ErrorAction SilentlyContinue
            
        $targetObject = $null
        if ($null -ne $propertyObject) {
            if ($propertyObject -is [array]) {
                if ($propertyObject.Count -gt 0) { $targetObject = $propertyObject[0] }
            }
            else {
                $targetObject = $propertyObject
            }

            if ($null -ne $targetObject) {
                if ($targetObject -is [string]) {
                    $existingThreatData = $targetObject
                }
                elseif ($targetObject.GetType().GetProperty('Value')) {
                    $existingThreatData = $targetObject.Value
                    $Global:DiagMsg += "Successfully read 'Value' property from custom field object."
                }
                else {
                    $Global:DiagMsg += "Retrieved object is not a string and has no 'Value' property. Object Type: $($targetObject.GetType().FullName)"
                }
            }
        }
        else {
            $Global:DiagMsg += "Ninja-Property-Get returned $null. Field is likely empty."
        }
    }
    catch {
        $Global:DiagMsg += "Error reading threat data from '$threatField': $($_.Exception.Message). Assuming no previous detections."
    }

    $Global:DiagMsg += "Data read from custom field: '$($existingThreatData.Substring(0, [System.Math]::Min($existingThreatData.Length, 250)))'"

    $previousThreatIDs = @{}
    if ([string]::IsNullOrWhiteSpace($existingThreatData)) {
        $Global:DiagMsg += "Custom field value is empty or null. Assuming no previous detections."
    }
    elseif ($existingThreatData -match "Previously Detected: ([\d,]+)") {
        # Use regex to find the line, no matter where it is
        $matches[1].Split(',') | ForEach-Object { $previousThreatIDs[$_] = $true }
        $Global:DiagMsg += "Found $($previousThreatIDs.Count) previously detected threat IDs."
    }
    else {
        $Global:DiagMsg += "Could not find 'Previously Detected:' line in custom field. Assuming no previous detections."
    }


    # Get current threats from MDE (no expiration check)
    $currentDetections = Get-MpThreatDetection -ErrorAction SilentlyContinue
    $newThreatDetails = @()
    $currentThreatIDs = @{} # Use a hashtable for a unique list of IDs
    $newThreatFound = $false

    if (-not $currentDetections) {
        $Global:DiagMsg += "No current MDE threats found."
    }
    else {
        foreach ($threat in $currentDetections) {
            $threatIDString = $threat.ThreatID.ToString()
            $currentThreatIDs[$threatIDString] = $true
                
            # Check if this ID is new
            if (-not $previousThreatIDs.ContainsKey($threatIDString)) {
                $newThreatFound = $true
                $Global:DiagMsg += " !!! New Threat detected !!! ID: $threatIDString"
            }

            # New Threats Data Format
            $resources = $threat.Resources -join '; '
            $newThreatDetails += "-----"
            $newThreatDetails += "Time: $($threat.InitialDetectionTime.ToString('yyyy-MM-dd HH:mm:ss'))"
            $newThreatDetails += "ThreatID: $($threat.ThreatID)"
            $newThreatDetails += "$resources"
        }
    }

    if (-not $newThreatFound -and $currentThreatIDs.Keys.Count -gt 0) {
        $Global:DiagMsg += "All current threat IDs have been previously detected."
    }
        
    # --- Build and write new custom field value ---
        
    # 1. Combine all known IDs (old and new) to create the new "memory".
    $allKnownThreatIDs = $previousThreatIDs
    $currentThreatIDs.Keys | ForEach-Object { $allKnownThreatIDs[$_] = $true }

    # 2. Build the "Previously Detected" string from this complete list.
    $idListArray = $allKnownThreatIDs.keys | Select-Object -Unique | Sort-Object
    $idListString = $idListArray -join ','

    # 3. Initialize the new custom field value.
    $newCustomFieldValue = ""
    if ($allKnownThreatIDs.Count -gt 0) {
        # This line is now built from the complete, combined list.
        $newCustomFieldValue = "Previously Detected: $idListString"
    }

    # 4. Append the details of *currently active* threats.
    if ($newThreatDetails.Count -gt 0) {
        $threatDetailsString = $newThreatDetails -join [Environment]::NewLine
        
        # Add a newline to separate from the "Previously Detected" line (if it exists)
        if ([string]::IsNullOrEmpty($newCustomFieldValue)) {
            $newCustomFieldValue = $threatDetailsString
        }
        else {
            # Combine the "Previously Detected" line and the new details
            $newCustomFieldValue = ($newCustomFieldValue, $threatDetailsString) -join [Environment]::NewLine
        }
    }
    # 5. Handle the "No threats" case.
    elseif ($allKnownThreatIDs.Count -eq 0) {
        # This only runs if *no current threats* were found AND *no previous threats* were logged.
        # Note: $Date was not defined; replaced with (Get-Date).
        $newCustomFieldValue = "No active threats detected. Last Checked: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }
    # If $newThreatDetails.Count is 0 but $allKnownThreatIDs.Count > 0,
    # the field will just contain the "Previously Detected: 1,2,3" line, preserving the memory.
        
    try {
        # Use .Trim() to remove any potential leading/trailing whitespace
        Ninja-Property-Set -Name $threatField -Value $newCustomFieldValue.Trim()
        $Global:DiagMsg += "Successfully updated threat details field '$threatField'."
    }
    catch {
        $Global:DiagMsg += "Failed to write to threat detail field '$threatField': $($_.Exception.Message)"
    }

    return $newThreatFound
}
    
##################################
######## Start of Script #########

try {
    $Global:DiagMsg += "Verifying AV Presence..."
    
    [bool]$mdeConfigOK = $true
    [bool]$mdeServiceOK = $true
    [bool]$newThreatFound = $false

    # Execute checks
    $mdeConfigOK = Check-MDEConfiguration
    $mdeServiceOK = Check-MDEService
    $newThreatFound = Check-MDEThreats
    
    $Global:DiagMsg += ""
    $Global:DiagMsg += "--- AV Summary ---"
    $Global:DiagMsg += "MDE Service OK: $mdeServiceOK"
    $Global:DiagMsg += "MDE Config OK: $mdeConfigOK"
    $Global:DiagMsg += "New Threats Found: $newThreatFound"
    $Global:DiagMsg += "------------------"
    $Global:DiagMsg += ""


    # Aggregate results for alerting
    $mdeStatusString = if ($mdeConfigOK -and $mdeServiceOK) { "Compliant" } else { "Non-Compliant" }
    $customFieldSummary = "MDE Status: $mdeStatusString | Last Connected: $Global:MDELastConnected"
    
    $summaryMessages = @()
    if (-not $mdeConfigOK) { $summaryMessages += "MDE/AV Configuration is non-compliant" }
    if (-not $mdeServiceOK) { $summaryMessages += "MDE Service (Sense) is not running or onboarded" }
    if ($newThreatFound) { $summaryMessages += "New MDE threats detected" }

    if ($summaryMessages.Count -gt 0) {
        $alertString = $summaryMessages -join ', '
        $Global:AlertMsg = "MDE Status Alert: $alertString. | Last Checked $Date"
        $Global:customFieldMessage = "Alert: $alertString. | $customFieldSummary "
    }
    else {
        $Global:customFieldMessage = " $customFieldSummary. ($Date)"
        # $Global:AlertMsg remains empty, $Global:AlertHealthy will be used
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