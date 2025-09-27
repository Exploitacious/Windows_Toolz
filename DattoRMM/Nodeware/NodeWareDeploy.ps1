# 
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Install Nodeware Agent" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:nodeWareCustomerID = "12345" # Which Customer ID to use for the Nodeware Agent installation.

<#
This Script is a Remediation compoenent, meaning it performs only one task with a log of granular detail. These task results can be added back ito tickets as time entries using the API. 

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "customerID" and here we use "$env:nodeWareCustomerID" to use that variable.

You can use as many of these as you like.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########

### Script Goes Here ###

# Check if the customerID variable is provided
if ([string]::IsNullOrEmpty($env:nodeWareCustomerID)) {
    $Global:DiagMsg += "Error: Customer ID is not defined. Please set the 'customerID' variable in the Datto RMM component."
    write-DRMMDiag $Global:DiagMsg
    Exit 1 # Exit with an error code
}

$Global:DiagMsg += "Using Customer ID: $env:nodeWareCustomerID"

# Script Variables
$url = "https://downloads.nodeware.com/agent/windows/NodewareAgentSetup.msi"
$msiName = "NodewareAgentSetup.msi"
$tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "NodewareInstallTemp")
$msiPath = [System.IO.Path]::Combine($tempDir, $msiName)

try {
    # Create temp directory if it doesn't exist
    if (-not (Test-Path -Path $tempDir -PathType Container)) {
        $Global:DiagMsg += "Creating temporary directory at $tempDir"
        New-Item -Path $tempDir -ItemType Directory | Out-Null
    }
    
    # Download the MSI installer
    $Global:DiagMsg += "Downloading Nodeware agent from $url to $msiPath"
    Invoke-WebRequest -Uri $url -OutFile $msiPath
    $Global:DiagMsg += "Download complete."

    # Verify download and install
    if (Test-Path -Path $msiPath -PathType Leaf) {
        $Global:DiagMsg += "Installer found. Starting installation..."
        $ArgumentList = "/i `"$msiPath`" /q CUSTOMERID=$env:nodeWareCustomerID"
        $Global:DiagMsg += "Executing: msiexec.exe $ArgumentList"
        Start-Process -FilePath "msiexec.exe" -ArgumentList $ArgumentList -Wait
        $Global:DiagMsg += "Installation process finished."
    }
    else {
        $Global:DiagMsg += "Error: Failed to download the NodewareAgentSetup MSI."
    }
}
catch {
    $Global:DiagMsg += "An error occurred during script execution: $_"
}
finally {
    # Clean up the temp directory and MSI file
    $Global:DiagMsg += "Performing cleanup..."
    if (Test-Path -Path $msiPath) {
        Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue
        $Global:DiagMsg += "Removed MSI file: $msiPath"
    }
    if (Test-Path -Path $tempDir) {
        Remove-Item -Path $tempDir -Force -Recurse -ErrorAction SilentlyContinue
        $Global:DiagMsg += "Removed temporary directory: $tempDir"
    }
    $Global:DiagMsg += "Cleanup complete."
}

######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {    
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Info to be sent to into JSON POST to API Endpoint (Optional)
$APIinfoHashTable = @{
    'CS_PROFILE_UID' = $env:CS_PROFILE_UID
    'Script_Diag'    = $Global:DiagMsg
    'Script_UID'     = $ScriptUID
}
#######################################################################
### Exit script with proper Datto diagnostic and API Results.
# Add Script Result and POST to API if an Endpoint is Provided
if ($null -ne $env:APIEndpoint) {
    $Global:DiagMsg += " - Sending Results to API"
    Invoke-WebRequest -Uri $env:APIEndpoint -Method POST -Body ($APIinfoHashTable | ConvertTo-Json) -ContentType "application/json"
}
# Exit with writing diagnostic back to the ticket / remediation component log
write-DRMMDiag $Global:DiagMsg
Exit 0