# Script Title: Software Detection Monitor
# Description: This monitor checks for the installation status of a specified piece of software by searching the Windows Registry. It can be configured to trigger an alert if the software is found or if it is missing.

# Script Name and Type
$ScriptName = "Software Detection Monitor"
$ScriptType = "Monitoring" # Or "Remediation", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get' 

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
$env:softwareName = "Threatlocker" # (Text): The name of the software to search for (can be a partial match). Example: 'Google Chrome'
$env:method = "MISSING" # (Text): Use 'MISSING' to alert if the software is NOT found, or 'FOUND' to alert if the software IS found.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "System state is nominal. | Last Checked $Date"

# Log/Diagnostic Messaging
function write-RMMDiag ($messages) {
    Write-Host "`n<-Start Diagnostic->"
    foreach ($Message in $messages) { $Message + ' `' }
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
    # This function searches the registry for installed software.
    function Check-SoftwareInstalled {
        param(
            [string]$SoftwareName
        )

        $detectedSoftware = @()
        # Registry paths where installed software information is commonly stored
        $regPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\*'
        )

        $Global:DiagMsg += "Searching for software matching '$SoftwareName'..."

        foreach ($regPath in $regPaths) {
            # Using Get-ItemProperty is more direct and efficient
            $installedApps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            
            # Filter the results for a display name that matches the search term
            $foundItems = $installedApps | Where-Object { $_.DisplayName -match $SoftwareName }

            if ($foundItems) {
                foreach ($item in $foundItems) {
                    # Add found item details to our results array
                    $detectedSoftware += [PSCustomObject]@{
                        DisplayName = $item.DisplayName
                        Version     = $item.DisplayVersion
                        Publisher   = $item.Publisher
                        SourcePath  = $item.PSPath
                    }
                }
            }
        }

        # Return a result object containing detection status and details
        if ($detectedSoftware.Count -gt 0) {
            return [PSCustomObject]@{
                Detected = $true
                Details  = $detectedSoftware
            }
        }
        else {
            return [PSCustomObject]@{
                Detected = $false
                Details  = $null
            }
        }
    }

    # --- Main Logic ---

    # 1. Validate Input Variables from NinjaRMM
    if (-not $env:softwareName -or -not $env:method) {
        $Global:AlertMsg = "Configuration Error: 'softwareName' and 'method' variables must be defined. | Last Checked $Date"
        $Global:customFieldMessage = "Script failed due to missing parameters. ($Date)"
        $Global:DiagMsg += "CRITICAL: Script cannot run. Define 'softwareName' and 'method' script variables."
    }
    else {
        # Sanitize method input to ensure consistent logic
        $method = $env:method.ToUpper().Trim()
        $softwareName = $env:softwareName

        if ($method -notin @('MISSING', 'FOUND')) {
            $Global:AlertMsg = "Configuration Error: The 'method' variable must be either 'MISSING' or 'FOUND'. | Last Checked $Date"
            $Global:customFieldMessage = "Script failed due to invalid 'method' parameter. ($Date)"
            $Global:DiagMsg += "CRITICAL: Invalid value for 'method': '$($env:method)'. Must be 'MISSING' or 'FOUND'."
        }
        else {
            $Global:DiagMsg += "Starting check for '$softwareName' with method '$method'."

            # 2. Run the detection function
            $result = Check-SoftwareInstalled -SoftwareName $softwareName

            # 3. Process the results and populate diagnostic messages
            if ($result.Detected) {
                $Global:DiagMsg += "SUCCESS: Found $($result.Details.Count) matching installation(s)."
                # Use the first detected item for the summary message
                $firstHit = $result.Details[0]
                $Global:customFieldMessage = "Detected: $($firstHit.DisplayName) v$($firstHit.Version) ($Date)"
                
                foreach ($detail in $result.Details) {
                    $Global:DiagMsg += "  - DisplayName: $($detail.DisplayName)"
                    $Global:DiagMsg += "    Version: $($detail.Version)"
                    $Global:DiagMsg += "    Publisher: $($detail.Publisher)"
                    $Global:DiagMsg += "    Registry Key: $($detail.SourcePath | Split-Path -Leaf)"
                }
            }
            else {
                $Global:DiagMsg += "INFO: No software installed matching '$softwareName'."
                $Global:customFieldMessage = "Not Detected: $softwareName ($Date)"
            }

            # 4. Determine alert status based on the configured method
            if ($method -eq 'FOUND' -and $result.Detected) {
                # Alert Condition: Software SHOULD NOT be installed, but it WAS found.
                $Global:AlertMsg = "Detected Forbidden Software: $($result.Details[0].DisplayName) | Last Checked $Date"
                $Global:DiagMsg += "ALERT: Software should not be present but was detected."
            }
            elseif ($method -eq 'MISSING' -and -not $result.Detected) {
                # Alert Condition: Software SHOULD be installed, but it was NOT found.
                $Global:AlertMsg = "Missing Required Software: $softwareName | Last Checked $Date"
                $Global:DiagMsg += "ALERT: Software is required but was not detected."
            }
            else {
                # Healthy Condition: The state matches the desired state.
                $Global:DiagMsg += "HEALTHY: Software installation status is as expected."
                # Create a more descriptive healthy message.
                $Global:AlertHealthy = "Status OK for '$softwareName'. Installation status is as expected. | Last Checked $Date"
            }
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