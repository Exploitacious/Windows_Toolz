# Script Title: CloudRadial Agent Deployment
# Description: Downloads and silently installs the CloudRadial agent, configuring it with an organization-specific Company ID.

# Script Name and Type
$ScriptName = "CloudRadial Agent Deployment"
$ScriptType = "Remediation" # Or "Monitoring", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$agentDownloadURL = 'https://github.com/Exploitacious/Windows_Toolz/raw/refs/heads/main/Helpers/CloudRadial/CloudRadialDataAgent.exe'
$tempInstallerPath = 'C:\Temp\CloudRadialAgent.exe'

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get'
$orgCustomFieldName = 'cloudRadialCompanyId' # Org custom field holding the CloudRadial Company ID

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to (e.g., softwareCloudRadialInfo).

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
    # --- [MODIFIED] Force TLS 1.2 for modern web requests ---
    $Global:DiagMsg += "Setting SecurityProtocol to Tls12."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # --- Get Organization Company ID ---
    $Global:DiagMsg += "Attempting to retrieve Organization Custom Field: $orgCustomFieldName"
    $companyId = $null
    try {
        # Using the direct-query method for organization-level fields
        $companyId = Ninja-Property-Get $orgCustomFieldName
    }
    catch {
        throw "Failed to query Organization Custom Field '$orgCustomFieldName'. Error: $($_.Exception.Message)"
    }

    if ([string]::IsNullOrEmpty($companyId)) {
        throw "Organization Custom Field '$orgCustomFieldName' is empty or not found. Cannot proceed with installation."
    }
    $Global:DiagMsg += "Successfully retrieved Company ID: $companyId"

    # --- [MODIFIED] Download Agent using Invoke-WebRequest ---
    $Global:DiagMsg += "Downloading CloudRadial agent from $agentDownloadURL to $tempInstallerPath using Invoke-WebRequest."
    try {
        # Switched from WebClient to Invoke-WebRequest
        Invoke-WebRequest -Uri $agentDownloadURL -OutFile $tempInstallerPath -UseBasicParsing -ErrorAction Stop
    }
    catch {
        # This will catch more specific WebRequest errors
        throw "Failed to download agent from $agentDownloadURL. Error: $($_.Exception.Message)"
    }
    $Global:DiagMsg += "Download successful."

    # --- Install Agent (Fire and Forget) ---
    $Global:DiagMsg += "Starting agent installation..."
    $installArgs = "/companyid=$companyId /verysilent"
    $Global:DiagMsg += "Installer Path: $tempInstallerPath"
    $Global:DiagMsg += "Arguments: $installArgs"
    
    try {
        Start-Process -FilePath $tempInstallerPath -ArgumentList $installArgs -ErrorAction Stop
        $Global:DiagMsg += "Installation process successfully launched."
    }
    catch {
        throw "Failed to *start* the installation process. Error: $($_.Exception.Message)"
    }

    # --- Success ---
    $Global:DiagMsg += "CloudRadial Agent installer was successfully launched."
    $Global:customFieldMessage = "CloudRadial Agent installer launched with Company ID $companyId. ($Date)"
    $Global:AlertHealthy = "CloudRadial Agent installer launched successfully. | Last Checked $Date"

}
catch {
    # --- [MODIFIED] Dig for the *real* error message (InnerException) ---
    $errorMessage = ""
    if ($_.Exception.InnerException) {
        # Get the real error from the inner exception
        $errorMessage = ($_.Exception.InnerException.Message.Split([Environment]::NewLine)[0]).Trim()
        $Global:DiagMsg += "An unexpected error occurred (Outer): $($_.Exception.Message)"
        $Global:DiagMsg += "INNER EXCEPTION (Real Error): $errorMessage"
    }
    else {
        # Fallback to the main exception message
        $errorMessage = ($_.Exception.Message.Split([Environment]::NewLine)[0]).Trim()
        $Global:DiagMsg += "An unexpected error occurred: $errorMessage"
    }
    
    # --- Truncate error message for Custom Field ---
    # Max length for the error portion
    $maxErrorLength = 130 
    
    if ($errorMessage.Length -gt $maxErrorLength) {
        $errorMessage = $errorMessage.Substring(0, $maxErrorLength) + "..."
    }
    
    $Global:AlertMsg = "CloudRadial Agent installation FAILED to launch. See diagnostics. | Last Checked $Date"
    $Global:customFieldMessage = "CloudRadial Agent launch FAILED. Error: $errorMessage ($Date)"
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