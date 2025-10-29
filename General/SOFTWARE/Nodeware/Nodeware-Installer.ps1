# Script Title: Nodeware Agent Deployment
# Description: Downloads and installs the Nodeware Windows agent using a customer ID stored in an Organization-Level Custom Field.

# Script Name and Type
$ScriptName = "Nodeware Agent Deployment"
$ScriptType = "Remediation" # This script installs software.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$downloadUrl = "https://downloads.nodeware.com/agent/windows/NodewareAgentSetup.msi"
$msiName = "NodewareAgentSetup.msi"
$workDir = "C:\Temp\"
$msiPath = Join-Path -Path $workDir -ChildPath $msiName

## ORG-LEVEL EXPECTED VARIABLES ##
# This script expects an Organization-Level Custom Field with the exact name 'nodewareCustomerID'.
$orgCustomFieldName = 'nodewareCustomerID'

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the final status to. (e.g., 'Nodeware Agent Status')


# What to Write if Alert is Healthy
$Global:AlertHealthy = "Nodeware agent installation script completed successfully. | Last Checked $Date"

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
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ01234156789') {
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
    # 1. Retrieve the Nodeware Customer ID from the Organization Custom Field
    $Global:DiagMsg += "Attempting to retrieve Nodeware Customer ID from Org Custom Field: '$orgCustomFieldName'"
    $nodewareCustomerID = (Ninja-Property-Get -Name $orgCustomFieldName).Value

    if (-not $nodewareCustomerID) {
        $Global:AlertMsg = "Error: Nodeware Customer ID is missing or empty in the Organization Custom Field '$orgCustomFieldName'. Cannot proceed with installation. | Last Checked $Date"
        $Global:customFieldMessage = "Failed: Org Custom Field '$orgCustomFieldName' is not set. ($Date)"
    }
    else {
        $Global:DiagMsg += "Successfully retrieved Customer ID: $nodewareCustomerID"

        # 2. Download the MSI installer
        $Global:DiagMsg += "Downloading Nodeware agent from $downloadUrl to $msiPath"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath
        $Global:DiagMsg += "Download command issued."

        # 3. Verify download and install
        if (Test-Path -Path $msiPath -PathType Leaf) {
            $Global:DiagMsg += "Installer downloaded successfully. Starting silent installation..."
            $ArgumentList = "/i `"$msiPath`" /q CUSTOMERID=$nodewareCustomerID"
            $Global:DiagMsg += "Executing: msiexec.exe $ArgumentList"
            
            Start-Process -FilePath "msiexec.exe" -ArgumentList $ArgumentList -Wait -PassThru
            
            $Global:DiagMsg += "Installation process finished."
            $Global:customFieldMessage = "Nodeware agent installed successfully. ($Date)"
        }
        else {
            $Global:AlertMsg = "Error: Failed to download the Nodeware agent MSI from the specified URL. | Last Checked $Date"
            $Global:customFieldMessage = "Failed: Could not download installer. ($Date)"
        }
    }
}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
    $Global:customFieldMessage = "Script failed with an unexpected error. ($Date)"
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