#
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Install Latest OneDrive for All Users" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:APIEndpoint = "https://prod-36.westus.logic.azure.com:443/workflows/6c032a1ca84045b9a7a1436864ecf696/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=c-dVa333HMzhWli_Fp_4IIAqaJOMwFjP2y5Zfv4j_zA"
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

<#
This script is designed to download and install the latest version of OneDrive for all users on a machine. It will create a temporary directory, 
download the installer, run it silently, and then clean up the installer file. All actions are logged to the Datto RMM diagnostic log.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message + ' `' }
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
# --- Variables ---
# Define the directory path and the full file path for the installer.
$downloadDir = "C:\Temp"
$installerPath = Join-Path -Path $downloadDir -ChildPath "OneDriveSetup.exe"
$oneDriveUrl = "https://go.microsoft.com/fwlink/?linkid=844652"

# Check if the destination directory exists. If not, create it.
if (-not (Test-Path -Path $downloadDir -PathType Container)) {
    $Global:DiagMsg += "Directory $downloadDir does not exist. Creating it now..."
    try {
        New-Item -ItemType Directory -Path $downloadDir -Force -ErrorAction Stop | Out-Null
        $Global:DiagMsg += "Directory $downloadDir created successfully."
    }
    catch {
        $Global:DiagMsg += "ERROR: Failed to create directory '$downloadDir'. Please check permissions."
    }
}
else {
    $Global:DiagMsg += "Directory $downloadDir already exists."
}

$Global:DiagMsg += "Starting the download of the latest OneDrive installer to $installerPath..."

try {
    # Download the latest OneDrive installer
    Invoke-WebRequest -Uri $oneDriveUrl -OutFile $installerPath -ErrorAction Stop
    $Global:DiagMsg += "Download complete."
}
catch {
    $Global:DiagMsg += "ERROR: Failed to download the OneDrive installer. Please check the internet connection and the URL: $oneDriveUrl"
}

if (Test-Path -Path $installerPath) {
    $Global:DiagMsg += "Installing OneDrive for all users. This will be a silent installation."
    try {
        # Start the installer in silent mode and for all users
        # The /allusers switch installs OneDrive to the Program Files directory
        # The /silent switch prevents any UI from showing during installation
        Start-Process -FilePath $installerPath -ArgumentList "/allusers /silent" -Wait -PassThru -ErrorAction Stop
        $Global:DiagMsg += "OneDrive installation is complete."
    }
    catch {
        $Global:DiagMsg += "ERROR: The OneDrive installation failed. Please check the installer logs if available."
    }
    finally {
        # Clean up the downloaded installer file
        if (Test-Path -Path $installerPath) {
            Remove-Item -Path $installerPath -Force
            $Global:DiagMsg += "Cleaned up the installer file from $installerPath."
        }
    }
}
else {
    $Global:DiagMsg += "Skipping installation because the installer failed to download."
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