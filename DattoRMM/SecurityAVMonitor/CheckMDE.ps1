# Script Title: Comprehensive Microsoft Defender Health & Configuration Monitor
# Description: Checks Defender's management source (GPO, MDM) for conflicts, verifies service status, and reports on resultant protection settings (RTP, Sense, Signatures).

# Script Name and Type
$ScriptName = "Comprehensive Microsoft Defender Health & Configuration Monitor"
$ScriptType = "Monitoring" # Or "Remediation", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$PolicyRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
$MdmRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager'
$LocalRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows Defender'

# Key services: WinDefend (Antivirus), WdNisSvc (Network Inspection), Sense (MDE)
$DefenderServices = @('WinDefend', 'WdNisSvc', 'Sense')

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get' 
# (None required for this script)

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# maxSignatureAgeDays (Text): The maximum age (in days) for AV definitions to be considered 'up to date'. Default: 3

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
    # --- RMM Variable Casting & Defaults ---
    $Global:DiagMsg += "Processing RMM script parameters..."
    try {
        if (-not [string]::IsNullOrEmpty($env:maxSignatureAgeDays)) {
            $maxSignatureAgeDays = [int]$env:maxSignatureAgeDays
            $Global:DiagMsg += "RMM Param: 'maxSignatureAgeDays' set to '$maxSignatureAgeDays'."
        }
        else {
            $maxSignatureAgeDays = 3 # Default value
            $Global:DiagMsg += "RMM Param: 'maxSignatureAgeDays' not set, using default: '$maxSignatureAgeDays'."
        }
    }
    catch {
        $Global:DiagMsg += "Error casting 'maxSignatureAgeDays' ('$($env:maxSignatureAgeDays)'). Using default: 3."
        $maxSignatureAgeDays = 3
    }
    
    # --- Script-Specific Variables ---
    $reportEntries = @() # For building the custom field string
    $issueEntries = @()  # For building the alert message

    # Define the "Golden State" for Get-MpPreference
    # We will alert if the current settings do NOT match these.
    # Note: For settings with multiple "good" values (like PUA=1 or PUA=2), we check them with specific logic.
    $DesiredState = @{
        'DisableRealtimeMonitoring' = $false
        'DisableBehaviorMonitoring' = $false
        'DisableIOAVProtection'     = $false
        'DisableScriptScanning'     = $false
        'DisableTamperProtection'   = $false
        'EnableNetworkProtection'   = 1       # 1 = Enabled
        'MAPSReporting'             = 2       # 2 = Advanced
    }

    # --- Main Script ---
    $Global:DiagMsg += "Starting Defender health and configuration check..."

    # 1. Check for 'DisableAntispyware' Policy Conflict
    $Global:DiagMsg += "Checking registry for 'DisableAntispyware' conflict..."
    $disablePolicy = Get-ItemProperty -Path $PolicyRegPath -Name 'DisableAntispyware' -ErrorAction SilentlyContinue
    $disableLocal = Get-ItemProperty -Path $LocalRegPath -Name 'DisableAntispyware' -ErrorAction SilentlyContinue
    
    if (($disablePolicy -and $disablePolicy.DisableAntispyware -eq 1) -or ($disableLocal -and $disableLocal.DisableAntispyware -eq 1)) {
        $issueEntries += "CRITICAL: 'DisableAntispyware' is set to 1 in registry."
        $reportEntries += "PolicyConflict:Disabled[ALERT]"
    }

    # 2. Check Defender Service Status
    $Global:DiagMsg += "Checking Defender service status..."
    foreach ($serviceName in $DefenderServices) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if (-not ($service -and $service.Status -eq 'Running')) {
            # 'Sense' service is only critical if MDE is expected
            if ($serviceName -eq 'WinDefend') {
                $issueEntries += "CRITICAL: Service '$serviceName' is not running (Status: $($service.Status))."
            }
            $Global:DiagMsg += "Service '$serviceName' is not running. Status: $($service.Status)"
            $reportEntries += "Service:$serviceName-Down[ALERT]"
        }
    }

    # 3. Check Management Source
    $Global:DiagMsg += "Checking management source policies..."
    $gpoKey = Get-Item -Path $PolicyRegPath -ErrorAction SilentlyContinue
    $mdmKey = Get-Item -Path $MdmRegPath -ErrorAction SilentlyContinue
    $gpoActive = ($gpoKey -and (($gpoKey.ValueCount -gt 0) -or ($gpoKey.SubKeyCount -gt 0)))
    $mdmActive = ($mdmKey -and (($mdmKey.ValueCount -gt 0) -or ($mdmKey.SubKeyCount -gt 0)))

    if ($gpoActive) { $reportEntries += "Mgmt:GPO" }
    if ($mdmActive) { $reportEntries += "Mgmt:MDM" }
    $Global:DiagMsg += "GPO/ConfigMgr Settings Detected: $gpoActive"
    $Global:DiagMsg += "Intune/MDM Settings Detected: $mdmActive"

    if ($gpoActive -and $mdmActive) {
        $issueEntries += "Potential Conflict: Both GPO and MDM policies are applied."
        $reportEntries += "MgmtConflict:Yes[ALERT]"
    }

    # 4. Check Resultant Settings via Get-MpPreference
    $Global:DiagMsg += "Checking resultant settings against 'Desired State'..."
    try {
        $prefs = Get-MpPreference -ErrorAction Stop
        
        # Check simple $true/$false or single-value settings
        foreach ($setting in $DesiredState.GetEnumerator()) {
            $key = $setting.Name
            $expectedValue = $setting.Value
            $currentValue = $prefs.$key
            
            if ($currentValue -ne $expectedValue) {
                $issueEntries += "$key is '$currentValue' (Expected: '$expectedValue')"
                $reportEntries += "$key : $currentValue[ALERT]"
            }
        }

        # Check settings with multiple "good" values
        if ($prefs.PUAProtection -eq 0) {
            # 0 = Disabled
            $issueEntries += "PUAProtection is 'Disabled' (Expected: 1 or 2)"
            $reportEntries += "PUA:Disabled[ALERT]"
        }
        if ($prefs.SubmitSamplesConsent -eq 0) {
            # 0 = Disabled
            $issueEntries += "SubmitSamplesConsent is 'Disabled' (Expected: 1 or 3)"
            $reportEntries += "Samples:Disabled[ALERT]"
        }
        if ($prefs.CloudBlockLevel -lt 2) {
            # 0 = Disabled, 1 = Default
            $issueEntries += "CloudBlockLevel is '$($prefs.CloudBlockLevel)' (Expected: 2 or higher)"
            $reportEntries += "CloudBlock:$($prefs.CloudBlockLevel)[ALERT]"
        }
        if ($prefs.EnableControlledFolderAccess -eq 0) {
            # 0 = Disabled
            $issueEntries += "ControlledFolderAccess is 'Disabled' (Expected: 1 or 2)"
            $reportEntries += "CFA:Disabled[ALERT]"
        }

        # Check Signatures
        $sigAge = (New-TimeSpan -Start $prefs.SignatureLastUpdated -End (Get-Date)).TotalDays
        $reportEntries += "SigAge:$([math]::Round($sigAge, 1))d"
        if ($sigAge -gt $maxSignatureAgeDays) {
            $issueEntries += "Signatures are outdated (Age: $([math]::Round($sigAge, 1)) days)"
            $reportEntries += "Sigs:Outdated[ALERT]"
        }

        # Report on Exclusions (Informational, not an alert)
        $exPaths = ($prefs.ExclusionPath | Measure-Object).Count
        $exProcs = ($prefs.ExclusionProcess | Measure-Object).Count
        $exExts = ($prefs.ExclusionExtension | Measure-Object).Count
        $exCount = $exPaths + $exProcs + $exExts
        if ($exCount -gt 0) {
            $reportEntries += "Exclusions:$exCount"
            $Global:DiagMsg += "Found $exCount exclusions (Paths: $exPaths, Procs: $exProcs, Exts: $exExts)."
        }

    }
    catch {
        $Global:DiagMsg += "Get-MpPreference command failed. Defender is likely disabled or not installed. Error: $($_.Exception.Message)"
        $issueEntries += "Get-MpPreference FAILED. Defender is likely disabled by policy or 3rd party AV."
        $reportEntries += "MpPreference:FAILED[ALERT]"
    }
    
    # --- Consolidate Findings ---
    if ($issueEntries.Count -gt 0) {
        $Global:AlertMsg = ($issueEntries | Join-String -Separator ', ') + " | Last Checked $Date"
        $Global:customFieldMessage = "Defender Issues: " + ($reportEntries | Join-String -Separator ' | ') + " ($Date)"
    }
    else {
        $Global:DiagMsg += "All Defender checks passed desired state."
        $Global:customFieldMessage = "Defender Healthy: " + ($reportEntries | Join-String -Separator ' | ') + " ($Date)"
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