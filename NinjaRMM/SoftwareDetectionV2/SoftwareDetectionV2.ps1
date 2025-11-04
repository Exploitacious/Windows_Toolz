# Script Title: Software Detection Monitor
# Description: Monitors for the presence or absence of specific software via the registry. Can optionally check service/process status and report extra registry data.

# Script Name and Type
$ScriptName = "Software Detection Monitor"
$ScriptType = "Monitoring"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$SoftwareRegPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\*'
)

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get' 
# None for this script.

## CONFIG RMM VARIABLES ## # Create the following variables in your NinjaRMM script configuration:
# alertActive (Checkbox): If checked, the script will trigger an alert. If unchecked, it will only update the custom field.
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# softwareName (Text): The DisplayName of the software to find. Supports wildcards (e.g., "*Chrome*").
# serviceOrProcessName (Text, Optional): The name or display name of the related service or process to check.
# detectionMethod (Dropdown): Select "Alert if Missing" or "Alert if Found".
# extraRegistryKeyLabel (Text, Optional): The friendly label for the extra data (e.g., "Version").
# extraRegistryKeyName (Text, Optional): The *name* of a registry property to report (e.g., DisplayVersion).



## Testing Purposes ##
$env:alertActive = "true" # (Checkbox): If checked, the script will trigger an alert. If unchecked, it will only update the custom field.
$env:customFieldName = "" # (Text): The name of the Text Custom Field to write the status to.
$env:softwareName = "CloudRadial Agent" # (Text): The DisplayName of the software to find. Supports wildcards (e.g., "*Chrome*").
$env:serviceOrProcessName = "CloudRadial" # (Text, Optional): The name or display name of the related service or process to check.
$env:detectionMethod = "Alert if Found" # (Dropdown): Select "Alert if Missing" or "Alert if Found".
$env:extraRegistryKeyLabel = "Version" # (Text, Optional): The friendly label for the extra data (e.g., "Version").
$env:extraRegistryKeyName = "DisplayVersion" # (Text, Optional): The *name* of a registry property to report (e.g., DisplayVersion).


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
# Helper Functions
##################################

function Find-SoftwareRegistryKey {
    param (
        [string]$Name
    )
    
    $Global:DiagMsg += "Searching for software matching '$Name' in registry paths..."
    $Global:DiagMsg += "Paths: $($SoftwareRegPaths -join ', ')"
    
    $found = $null
    foreach ($path in $SoftwareRegPaths) {
        $Global:DiagMsg += "Searching in path: $path"
        
        $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        
        if ($null -eq $items) {
            $Global:DiagMsg += "No items found in $path"
            continue
        }

        # We must check if the DisplayName property exists before trying to access it
        # We also check the key name itself (PSChildName)
        $found = $items | Where-Object { 
            ($_.PSObject.Properties.Name -contains 'DisplayName' -and $_.DisplayName -like $Name) -or 
            ($_.PSChildName -like $Name) 
        } | Select-Object -First 1
        
        if ($found) {
            $Global:DiagMsg += "Found match at: $($found.PSPath)"
            
            # --- Replacement for Format-Table ---
            $Global:DiagMsg += "" # Add blank line before
            $Global:DiagMsg += "--- Software Registry Details Start ---"
            
            # Get all property names, excluding the noisy PS* properties
            $properties = $found.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }
            foreach ($prop in $properties) {
                # Indent properties for readability
                $Global:DiagMsg += "    $($prop.Name) : $($prop.Value)"
            }
            
            $Global:DiagMsg += ""
            $Global:DiagMsg += "--- Software Registry Details End ---"
            $Global:DiagMsg += ""
            # --- End Replacement ---
            
            break # Exit the loop once found
        }
    }
    
    if (-not $found) {
        $Global:DiagMsg += "No software match found for '$Name'."
    }
    return $found
}


function Get-ServiceOrProcessStatus {
    param (
        [string]$NameList
    )
    
    if ([string]::IsNullOrWhiteSpace($NameList)) {
        return "N/A"
    }

    $Global:DiagMsg += "Checking status for services/processes: '$NameList'."
    $serviceNames = $NameList.Split(',') | ForEach-Object { $_.Trim() }
    $allStatuses = @()

    foreach ($name in $serviceNames) {
        $Global:DiagMsg += "Checking '$name'..."
        $statusString = "$name : Not Found" # Default
        
        # Try finding it as a service first (by name, then by display name)
        $service = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (!$service) {
            $service = Get-Service -DisplayName $name -ErrorAction SilentlyContinue
        }
        
        if ($service) {
            $Global:DiagMsg += "Found service: $($service.Name) (Display: $($service.DisplayName))"
            $serviceName = $service.Name
            $serviceStatus = $service.Status
            
            if ($serviceStatus -eq "Running") {
                try {
                    # Use a different variable name to avoid conflict with $PID
                    $processId = (Get-CimInstance -ClassName Win32_Service -Filter "Name = '$serviceName'").ProcessId
                    if ($processId -gt 0) {
                        $statusString = "$serviceName : Running PID $processId"
                    }
                    else {
                        $statusString = "$serviceName : Running (PID not found)"
                    }
                }
                catch {
                    $Global:DiagMsg += "Error getting PID for service '$serviceName': $($_.Exception.Message)"
                    $statusString = "$serviceName : Running (PID error)"
                }
            }
            else {
                $statusString = "$serviceName : $serviceStatus"
            }
        }
        else {
            # If not a service, try finding it as a process
            $process = Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
            
            if ($process) {
                $Global:DiagMsg += "Found process: $($process.Name) (PID: $($process.Id))"
                $statusString = "$($process.Name): Running PID $($process.Id)"
            }
            else {
                $Global:DiagMsg += "Could not find any service or process matching '$name'."
            }
        }
        $allStatuses += $statusString
    }
    
    return $allStatuses -join ", "
}


##################################
##################################
######## Start of Script #########

try {
    # Parameter Validation
    if (-not $env:softwareName) {
        $Global:DiagMsg += "Critical error: 'softwareName' RMM variable is not set."
        $Global:AlertMsg = "Script configuration error: 'softwareName' is required. | Last Checked $Date"
        $Global:customFieldMessage = "Script configuration error. ($Date)"
        # This will trigger the catch block, but we want to exit fast.
        # This will be handled by the final exit logic.
        throw "Configuration Error: softwareName is required."
    }
    
    if (-not $env:detectionMethod) {
        $Global:DiagMsg += "Warning: 'detectionMethod' not set. Defaulting to 'Alert if Missing'."
        $env:detectionMethod = "Alert if Missing"
    }

    $Global:DiagMsg += "Starting software check for '$($env:softwareName)'."
    $Global:DiagMsg += "Detection Method: $($env:detectionMethod)"

    # Initialize report variables
    $status = "Not Found"
    $serviceStatus = "N-A" # Use N-A to avoid confusion with the function's "N/A"
    $extraData = "N/A"
    
    # --- Main Logic ---
    
    $foundSoftware = Find-SoftwareRegistryKey -Name $env:softwareName
    
    if ($foundSoftware) {
        $status = "Installed"
        
        # Check for optional extra registry key
        if ($env:extraRegistryKeyName -and $env:extraRegistryKeyLabel) {
            $Global:DiagMsg += "Checking for extra registry key '$($env:extraRegistryKeyName)'."
            if ($foundSoftware.PSObject.Properties.Name -contains $env:extraRegistryKeyName) {
                $value = $foundSoftware.($env:extraRegistryKeyName)
                $extraData = "$($env:extraRegistryKeyLabel): $value"
                $Global:DiagMsg += "Found value: $value"
            }
            else {
                $extraData = "$($env:extraRegistryKeyLabel): <Not Found>"
                $Global:DiagMsg += "Property '$($env:extraRegistryKeyName)' not found on registry object."
            }
        }
        
        # Check for optional service/process
        if ($env:serviceOrProcessName) {
            $serviceStatus = Get-ServiceOrProcessStatus -NameList $env:serviceOrProcessName
        }
        
        # Set alert logic for "Alert if Found"
        if ($env:detectionMethod -eq "Alert if Found") {
            $Global:AlertMsg = "Detected software '$($env:softwareName)' which was set to 'Alert if Found'. | Last Checked $Date"
        }
        
    }
    else {
        # Software was not found
        $status = "Not Found"
        
        # Set alert logic for "Alert if Missing"
        if ($env:detectionMethod -eq "Alert if Missing") {
            $Global:AlertMsg = "Could not find software '$($env:softwareName)' which was set to 'Alert if Missing'. | Last Checked $Date"
        }
    }
    
    # --- Construct Custom Field Message ---
    $customFieldParts = @()
    
    if ($extraData -ne "N/A") {
        $customFieldParts += $extraData
    }
    
    $customFieldParts += "Status: $status"
    
    if ($serviceStatus -ne "N-A") {
        $customFieldParts += $serviceStatus
    }
    
    $customFieldParts += "Last Checked: $Date"
    
    $Global:customFieldMessage = $customFieldParts -join " | "
    $Global:DiagMsg += "Final status message: $($Global:customFieldMessage)"

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    # If AlertMsg isn't already set by our validation, set a generic one.
    if (-not $Global:AlertMsg) {
        $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
        $Global:customFieldMessage = "Script failed with an error. ($Date)"
    }
}

######## End of Script ###########
##################################
##################################

# Cast the checkbox variable to a boolean
[bool]$alertActive = $env:alertActive -eq 'true'

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

if ($Global:AlertMsg -and $alertActive) {
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