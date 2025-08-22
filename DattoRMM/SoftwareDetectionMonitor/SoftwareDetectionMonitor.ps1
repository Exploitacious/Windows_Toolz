#
## Software Detection Monitor for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious
# Improved by Datto RMM Component Creator (Gemini)

# Script Name and Type
$ScriptName = "Software Detection Monitor" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation
$Date = Get-Date -Format "MM/dd/yyy hh:mm tt"

# What to Write if Alert is Healthy - This is constructed dynamically later
$Global:AlertHealthy = "" 

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables.
# These variables MUST be defined in the Datto RMM component.
$env:softwareName = "DNS" # The name of the software to search for (can be a partial match).
$env:method = 'NE' # Use 'EQ' to alert if MISSING, or 'NE' to alert if FOUND.
#$env:usrUDF = 14 # Optional: Which UDF to write the result to. Leave blank to Skip UDF writing.

<#
DESCRIPTION:
This monitor checks for the installation status of a specified piece of software by searching the Windows Registry.
It can be configured to trigger an alert if the software is found or if it is missing.

DATTO RMM VARIABLES:
- softwareName (string): The name of the software to find. The script uses a partial match, so "Google" will find "Google Chrome". Be as specific as needed.
- method (string): The logic to apply.
    - 'EQ': (Equal) - The software MUST exist. An alert is raised if it is NOT found.
    - 'NE': (Not Equal) - The software must NOT exist. An alert is raised if it IS found.
#>

# DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host "`n<-Start Diagnostic->"
    foreach ($Message in $messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
function write-DRMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:AlertMsg = @() # Combined Alert message. If left blank, will not trigger Alert status. Use " $Global:AlertMsg += " to append messages to be alerted on in Datto.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date
##################################
##################################
######## Start of Script #########

function Check-SoftwareInstalled {
    param(
        [string]$SoftwareName
    )

    $detectedSoftware = @()
    # Registry paths where installed software information is commonly stored
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $Global:DiagMsg += "Searching for software matching '$SoftwareName'..."

    foreach ($regPath in $regPaths) {
        # Using Get-ItemProperty is more direct than Get-ChildItem | ForEach-Object
        $installedApps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        
        # Filter the results
        $foundItems = $installedApps | Where-Object { $_.DisplayName -match $SoftwareName -or $_.PSChildName -match $SoftwareName }

        if ($foundItems) {
            foreach ($item in $foundItems) {
                # Add found item details to our results array
                $detectedSoftware += [PSCustomObject]@{
                    DisplayName = $item.DisplayName
                    Version     = $item.DisplayVersion
                    Publisher   = $item.Publisher
                    InstallDate = $item.InstallDate
                    SourcePath  = $item.PSPath
                }
            }
        }
    }

    # Return a result object
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

# 1. Validate Input Variables from Datto RMM
if (-not $env:softwareName -or -not $env:method) {
    $Global:AlertMsg = "Component Error: 'softwareName' and 'method' variables must be defined."
    $Global:DiagMsg += "CRITICAL: Component cannot run. Define 'softwareName' and 'method' variables."
}
else {
    # Sanitize method input
    $method = $env:method.ToUpper()
    $softwareName = $env:softwareName

    $Global:DiagMsg += "Starting check for '$softwareName' with method '$method'."

    # 2. Run the detection function
    $result = Check-SoftwareInstalled -SoftwareName $softwareName

    # 3. Process the results and populate diagnostic messages
    if ($result.Detected) {
        $Global:DiagMsg += "SUCCESS: Found $($result.Details.Count) matching installation(s)."
        $Global:varUDFString = "Detected: $($result.Details[0].DisplayName)" # Write first detected name to UDF
        foreach ($detail in $result.Details) {
            $Global:DiagMsg += "  - DisplayName: $($detail.DisplayName)"
            $Global:DiagMsg += "    Version: $($detail.Version)"
            $Global:DiagMsg += "    Publisher: $($detail.Publisher)"
            $Global:DiagMsg += "    Registry Key: $($detail.SourcePath | Split-Path -Leaf)"
        }
    }
    else {
        $Global:DiagMsg += "INFO: No software installed matching '$softwareName'."
        $Global:varUDFString = "Not Detected"
    }

    # 4. Determine alert status based on the method
    if ($method -eq 'NE' -and $result.Detected) {
        # Alert Condition: Software SHOULD NOT be installed, but it WAS found.
        $Global:AlertMsg = "Detected Forbidden Software: $($result.Details[0].DisplayName) | Last Checked $Date"
        $Global:DiagMsg += "ALERT: Software should not be present but was detected."
    }
    elseif ($method -eq 'EQ' -and -not $result.Detected) {
        # Alert Condition: Software SHOULD be installed, but it was NOT found.
        $Global:AlertMsg = "Missing Required Software: $softwareName | Last Checked $Date"
        $Global:DiagMsg += "ALERT: Software is required but was not detected."
    }
    else {
        # Healthy Condition: The state matches the desired state (e.g., method EQ and found, or method NE and not found).
        $Global:DiagMsg += "HEALTHY: Software installation status is as expected."
        $Global:AlertHealthy = "Status OK for '$softwareName' | Last Checked $Date"
    }
}

######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) { 
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Exit script with proper Datto alerting, diagnostic and API Results.
#######################################################################
if ($Global:AlertMsg) {
    # If your AlertMsg has value, this is how it will get reported.
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-DRMMAlert $Global:AlertMsg
    write-DRMMDiag $Global:DiagMsg

    # Exit 1 means DISPLAY ALERT
    Exit 1
}
else {
    # If the AlertMsg variable is blank (nothing was added), the script will report healthy status.
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"

    ##### You may alter the NO ALERT Exit Message #####
    write-DRMMAlert $Global:AlertHealthy
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}