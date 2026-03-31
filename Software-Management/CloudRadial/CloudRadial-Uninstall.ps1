# Script Title: CloudRadial Agent Uninstallation
# Description: Silently uninstalls the CloudRadial agent from the target device.

# Script Name and Type
$ScriptName = "CloudRadial Agent Uninstallation"
$ScriptType = "Remediation" # Or "Monitoring", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$uninstallerPath = "C:\Program Files (x86)\CloudRadial Agent\unins000.exe"

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.

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
    $Global:DiagMsg += "Checking for uninstaller at: $uninstallerPath"
    
    if (Test-Path -Path $uninstallerPath -PathType Leaf) {
        $Global:DiagMsg += "Uninstaller found. Starting silent uninstallation..."
        $installArgs = "/SILENT"
        
        try {
            $process = Start-Process -FilePath $uninstallerPath -ArgumentList $installArgs -PassThru -ErrorAction Stop
            $Global:DiagMsg += "Waiting for uninstallation process (PID: $($process.Id)) to complete..."
            
            $process | Wait-Process -ErrorAction Stop
            
            $exitCode = $process.ExitCode
            $Global:DiagMsg += "Uninstallation process finished with exit code: $exitCode"
            
            if ($exitCode -ne 0) {
                # Note: Some uninstallers exit non-zero even on success. We'll report it but not fail the script.
                $Global:DiagMsg += "Warning: Uninstaller finished with a non-zero exit code: $exitCode."
            }
            
            $Global:customFieldMessage = "CloudRadial Agent uninstallation command executed successfully. ($Date)"
            $Global:AlertHealthy = "CloudRadial Agent uninstalled successfully. | Last Checked $Date"
            
        }
        catch {
            throw "Failed to start or monitor the uninstallation process. Error: $($_.Exception.Message)"
        }
        
    }
    else {
        $Global:DiagMsg += "Uninstaller not found at path. Agent is likely already uninstalled."
        $Global:customFieldMessage = "CloudRadial Agent not found (or already uninstalled). ($Date)"
        $Global:AlertHealthy = "CloudRadial Agent not found. | Last Checked $Date"
    }
}
catch {
    # Format the error message for the Custom Field
    $errorMessage = $_.Exception.Message.Split([Environment]::NewLine)[0] # Get first line of error
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "CloudRadial Agent uninstallation FAILED. See diagnostics. | Last Checked $Date"
    $Global:customFieldMessage = "CloudRadial Agent uninstallation FAILED. Error: $errorMessage ($Date)"
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