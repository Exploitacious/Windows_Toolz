# Script Title: Get Intune Device ID
# Description: Executes 'dsregcmd /status' to extract the Azure AD/Intune Device ID and saves it to a specified Ninja RMM Custom Field.

# Script Name and Type
$ScriptName = "Get Intune Device ID"
$ScriptType = "General" 
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# MSP-wide standards
$ScriptExecutionInfoField = "Script_Execution_Info"

## ORG-LEVEL EXPECTED VARIABLES ##
# No specific Org-level fields required for this logic.

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to (e.g., intuneDeviceId).
# Defaulting to your request if not provided via environment variable
if (-not $env:customFieldName) { $env:customFieldName = "intuneDeviceId" }

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Device ID successfully retrieved and updated. | Last Checked $Date"

# Log/Diagnostic Messaging
function write-RMMDiag ($messages) {
    Write-Host "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message }
    Write-Host "<-End Diagnostic->"
    Write-Host
}
$Global:DiagMsg = @()

# Alert Messaging
function write-RMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host "<-End Result->"
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
    $Global:DiagMsg += "Executing 'dsregcmd /status'..."
    
    # Capture the output of dsregcmd
    $regStatus = dsregcmd /status
    
    # Use Regex to find the DeviceId line and extract the GUID
    # Looking for: DeviceId : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    if ($regStatus -match 'DeviceId\s*:\s*([a-fA-F0-0-9-]{36})') {
        $foundID = $matches[1]
        $Global:DiagMsg += "Found Device ID: $foundID"
        $Global:customFieldMessage = $foundID
    }
    else {
        $Global:DiagMsg += "Could not find a valid DeviceId in dsregcmd output. Is this device Entra/Azure AD joined?"
        $Global:AlertMsg = "Device ID not found. Verify Entra ID registration state. | Last Checked $Date"
        $Global:customFieldMessage = "Not Found"
    }

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
    $Global:customFieldMessage = "Error"
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
    $Global:DiagMsg += "Custom Field name not provided. Skipping update."
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