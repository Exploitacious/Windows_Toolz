# Script Title: Monitor Antivirus Health
# Description: Checks the health of the primary AV. If BitDefender, ensures its service is running. If Microsoft Defender, checks definitions, protection status, MDE (Sense) onboarding, and quarantine.

# Script Name and Type
$ScriptName = "Monitor Antivirus Health"
$ScriptType = "Monitoring" # Or "Remediation", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$BitDefenderServiceName = 'EPSecurityService'
$BitDefenderDisplayName = 'BitDefender'

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get' 
# (None required for this script)

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# maxDefinitionAgeDays (Text): The maximum age (in days) for AV definitions to be considered 'up to date'. Default: 3

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
        if (-not [string]::IsNullOrEmpty($env:maxDefinitionAgeDays)) {
            $maxDefinitionAgeDays = [int]$env:maxDefinitionAgeDays
            $Global:DiagMsg += "RMM Param: 'maxDefinitionAgeDays' set to '$maxDefinitionAgeDays'."
        }
        else {
            $maxDefinitionAgeDays = 3 # Default value
            $Global:DiagMsg += "RMM Param: 'maxDefinitionAgeDays' not set, using default: '$maxDefinitionAgeDays'."
        }
    }
    catch {
        $Global:DiagMsg += "Error casting 'maxDefinitionAgeDays' ('$($env:maxDefinitionAgeDays)'). Using default: 3."
        $maxDefinitionAgeDays = 3
    }
    
    # --- Supporting Functions ---

    function Check-BitDefender {
        Param(
            [string]$serviceName
        )
        $Global:DiagMsg += "BitDefender is the active AV. Checking its service status..."
        $bdService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        
        if ($bdService -and $bdService.Status -eq 'Running') {
            $Global:DiagMsg += "BitDefender service '$serviceName' is running."
            $Global:customFieldMessage = "BitDefender is active and its service ($serviceName) is running. ($Date)"
        }
        else {
            $Global:DiagMsg += "BitDefender is active, but its service '$serviceName' is not running or not found. Status: $($bdService.Status)"
            $Global:AlertMsg = "BitDefender is the active AV, but its service ($serviceName) is not running. | Last Checked $Date"
            $Global:customFieldMessage = "BitDefender service ($serviceName) is NOT running. ($Date)"
        }
    }

    function Check-MicrosoftDefender {
        Param(
            [PSObject]$avStatus,
            [int]$maxAge
        )
        $Global:DiagMsg += "Microsoft Defender is the active AV. Performing comprehensive check..."
        $issuesFound = @()

        # Check 1: Definition Age
        $definitionAge = (Get-Date) - $avStatus.AntivirusSignatureLastUpdated
        $Global:DiagMsg += "AV definitions last updated: $($avStatus.AntivirusSignatureLastUpdated) ($([math]::Round($definitionAge.TotalDays, 2)) days ago)."
        if ($definitionAge.TotalDays -gt $maxAge) {
            $issuesFound += "AV definitions are out of date (Last updated: $($avStatus.AntivirusSignatureLastUpdated), Threshold: $maxAge days)."
        }

        # Check 2: Protection Status
        if (-not $avStatus.RealTimeProtectionEnabled) { $issuesFound += "Real-Time Protection is disabled." }
        if (-not $avStatus.AntispywareEnabled) { $issuesFound += "Antispyware protection is disabled." }
        if (-not $avStatus.BehaviorMonitorEnabled) { $issuesFound += "Behavior Monitor is disabled." }
        if (-not $avStatus.IoavProtectionEnabled) { $issuesFound += "IOAV (download/attachment) protection is disabled." }
        if (-not $avStatus.OnAccessProtectionEnabled) { $issuesFound += "On-Access protection is disabled." }
        
        $Global:DiagMsg += "RealTimeProtectionEnabled: $($avStatus.RealTimeProtectionEnabled)"
        $Global:DiagMsg += "AntispywareEnabled: $($avStatus.AntispywareEnabled)"
        $Global:DiagMsg += "BehaviorMonitorEnabled: $($avStatus.BehaviorMonitorEnabled)"
        
        # Check 3: MDE (Sense) Onboarding
        $Global:DiagMsg += "Checking MDE (Sense) onboarding status..."
        if ($avStatus.SenseEnabled) {
            $Global:DiagMsg += "MDE Sense is enabled and running."
        }
        else {
            $issuesFound += "MDE (Sense) is not enabled. Device may not be onboarded to Defender for Endpoint correctly."
        }

        # Check 4: Quarantine
        $Global:DiagMsg += "Checking for quarantined items..."
        $quarantinedItems = Get-MpThreat -ThreatStatus Quarantine -ErrorAction SilentlyContinue
        if ($quarantinedItems) {
            $count = ($quarantinedItems | Measure-Object).Count
            $issuesFound += "$count items found in quarantine. Manual review may be required."
            $Global:DiagMsg += "Found $count quarantined items."
        }
        else {
            $Global:DiagMsg += "No items found in quarantine."
        }

        # Consolidate Findings
        if ($issuesFound.Count -gt 0) {
            $Global:DiagMsg += "One or more MDE issues were found:"
            $Global:DiagMsg += ($issuesFound | ForEach-Object { "- $_" })
            $alertString = ($issuesFound | Join-String -Separator ', ')
            $Global:AlertMsg = "MDE Health Check Failed: $alertString | Last Checked $Date"
            $Global:customFieldMessage = "MDE Health Check Failed: $($issuesFound.Count) issues found. ($Date)"
        }
        else {
            $Global:DiagMsg += "MDE health check passed. All components are healthy and up to date."
            $Global:customFieldMessage = "Microsoft Defender is active, healthy, and up-to-date. ($Date)"
        }
    }

    # --- Main Script Execution ---
    
    $Global:DiagMsg += "Checking AV status using Get-MpComputerStatus..."
    $avStatus = Get-MpComputerStatus
    
    if ($avStatus.AntivirusEnabled) {
        $Global:DiagMsg += "Active AV Product: $($avStatus.AntivirusProduct)"
        if ($avStatus.AntivirusProduct -like "*$BitDefenderDisplayName*") {
            Check-BitDefender -serviceName $BitDefenderServiceName
        }
        elseif ($avStatus.AntivirusProduct -like "*Windows Defender*") {
            Check-MicrosoftDefender -avStatus $avStatus -maxAge $maxDefinitionAgeDays
        }
        else {
            $Global:DiagMsg += "An unknown AV product is active: $($avStatus.AntivirusProduct). Cannot perform specific checks."
            $Global:AlertMsg = "Unknown AV product '$($avStatus.AntivirusProduct)' is active. No monitoring configured. | Last Checked $Date"
            $Global:customFieldMessage = "Unknown AV '$($avStatus.AntivirusProduct)' is active. ($Date)"
        }
    }
    else {
        $Global:DiagMsg += "No Antivirus product is enabled on this machine according to Get-MpComputerStatus."
        $Global:AlertMsg = "CRITICAL: No Antivirus product is enabled on this machine. | Last Checked $Date"
        $Global:customFieldMessage = "CRITICAL: No Antivirus product is enabled. ($Date)"
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