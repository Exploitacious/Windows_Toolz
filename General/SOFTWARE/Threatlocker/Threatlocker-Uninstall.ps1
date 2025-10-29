# Script Title: Uninstall ThreatLocker Agent
# Description: Downloads the ThreatLocker stub installer and uses it to perform an uninstallation. This script can optionally provide an uninstall password.

# Script Name and Type
$ScriptName = "Uninstall ThreatLocker Agent"
$ScriptType = "Remediation" # Or "Remediation", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$TempPath = "C:\Temp"
$StubInstallerName = "ThreatLockerStub.exe"
$LocalInstallerPath = Join-Path -Path $TempPath -ChildPath $StubInstallerName

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get' 
# None for this script.

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# uninstallPassword (Text): [Optional] The uninstall password, if one is required by your ThreatLocker policy. Leave blank if not needed.


# What to Write if Alert is Healthy
$Global:AlertHealthy = "ThreatLocker uninstallation process initiated successfully. | Last Checked $Date"

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
    # Force PowerShell to use TLS 1.2 for the web request.
    $Global:DiagMsg += "Setting security protocol to TLS 1.2."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    # Determine the correct download URL based on the OS architecture.
    if ([System.Environment]::Is64BitOperatingSystem) {
        $downloadURL = "https://api.threatlocker.com/installers/threatlockerstubx64.exe"
    }
    else {
        $downloadURL = "https://api.threatlocker.com/installers/threatlockerstubx86.exe"
    }
    $Global:DiagMsg += "OS is 64-bit: $([System.Environment]::Is64BitOperatingSystem). Download URL set to: $downloadURL"

    # Download the installer file with error handling.
    try {
        $Global:DiagMsg += "Downloading the ThreatLocker stub for uninstallation to $LocalInstallerPath..."
        Invoke-WebRequest -Uri $downloadURL -OutFile $LocalInstallerPath -ErrorAction Stop
        $Global:DiagMsg += "Download complete."
    }
    catch {
        # This is a critical failure.
        $Global:DiagMsg += "Failed to download the stub installer. Error: $($_.Exception.Message)"
        $Global:AlertMsg = "Failed to download the ThreatLocker stub installer. | Last Checked $Date"
        $Global:customFieldMessage = "Failed to download stub installer. ($Date)"
        # Throw to stop execution and be caught by the main catch block.
        throw "Failed to download stub installer."
    }

    # Set the argument for uninstallation, including password if provided.
    $arguments = "uninstall"
    if (-not [string]::IsNullOrEmpty($env:uninstallPassword)) {
        $Global:DiagMsg += "Uninstall password provided. Adding to arguments."
        # Add the password parameter, ensuring it's quoted correctly for Start-Process
        $arguments += " -p `"$($env:uninstallPassword)`""
    }
    else {
        $Global:DiagMsg += "No uninstall password provided. Proceeding without one."
    }
    
    $Global:DiagMsg += "Executing: $LocalInstallerPath $arguments"

    # Execute the stub installer with the uninstall argument and wait for it to complete.
    # We use a nested try/catch/finally to ensure cleanup (removing the stub) happens
    # even if the uninstallation fails.
    try {
        $Global:DiagMsg += "Running the ThreatLocker uninstaller..."
        Start-Process -FilePath $LocalInstallerPath -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
        
        $Global:DiagMsg += "The uninstallation process has completed."
        # Set success messages
        $Global:customFieldMessage = "ThreatLocker uninstallation process initiated successfully. ($Date)"
        # $Global:AlertHealthy is set by default, so we don't need to set $Global:AlertMsg
    }
    catch {
        # The uninstaller failed to run or threw an error.
        $Global:DiagMsg += "The uninstaller failed to run. Error: $($_.Exception.Message)"
        $Global:AlertMsg = "The ThreatLocker uninstaller failed to run. Check diagnostics for error. | Last Checked $Date"
        $Global:customFieldMessage = "Uninstaller failed to run. ($Date)"
        # Throw to stop execution and be caught by the main catch block.
        throw "Uninstaller failed to run."
    }
    finally {
        # Clean up by removing the downloaded installer file.
        if (Test-Path $LocalInstallerPath) {
            $Global:DiagMsg += "Cleaning up installer stub file: $LocalInstallerPath"
            Remove-Item $LocalInstallerPath -Force -ErrorAction SilentlyContinue
            $Global:DiagMsg += "Installer stub file has been removed."
        }
    }
}
catch {
    # This main catch block will capture 'throw' statements from inner blocks or any other unexpected error.
    $Global:DiagMsg += "An unexpected error occurred or an inner function failed: $($_.Exception.Message)"
    
    # If $Global:AlertMsg was NOT set by an inner block, set a generic failure message.
    if (-not $Global:AlertMsg) {
        $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
        $Global:customFieldMessage = "Script failed with an unexpected error. ($Date)"
    }
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