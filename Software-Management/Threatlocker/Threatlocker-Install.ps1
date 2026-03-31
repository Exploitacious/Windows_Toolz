# Script Title: ThreatLocker Deployment
# Description: Downloads and installs the ThreatLocker agent using a specified instance ID and installation key. It dynamically determines the organization name from a custom field or falls back to the NinjaRMM organization name.

# Script Name and Type
$ScriptName = "ThreatLocker Deployment"
$ScriptType = "Remediation" # Or "General"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# $env:threatlockerInstance = "" # (Text): The ThreatLocker instance identifier (e.g., "B").
# $env:threatlockerKey = "" # (Text): The unique ThreatLocker installation key (GUID).
# tempDirectory (Text): The directory to download the installer to. Default is C:\Temp.

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
    # Ensure TLS 1.2 is used for web requests
    [Net.ServicePointManager]::SecurityProtocol = "Tls12"

    # --- 1. Pre-computation and Validation ---
    $Global:DiagMsg += "--- Beginning Pre-computation and Validation ---"

    # Validate required RMM variables
    if ([string]::IsNullOrEmpty($env:threatlockerInstance) -or [string]::IsNullOrEmpty($env:threatlockerKey)) {
        throw "FATAL: RMM script variables 'threatlockerInstance' and 'threatlockerKey' must be configured."
    }
    $Global:DiagMsg += "RMM variables 'threatlockerInstance' and 'threatlockerKey' are present."

    # Set default temp directory if not provided
    $tempDir = if (-not [string]::IsNullOrEmpty($env:tempDirectory)) { $env:tempDirectory } else { "C:\Temp" }
    $localInstaller = Join-Path -Path $tempDir -ChildPath "ThreatLockerStub.exe"

    # --- 2. Check for Existing Installation ---
    $Global:DiagMsg += "--- Checking for existing installation ---"
    $service = Get-Service -Name ThreatLockerService -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        $Global:DiagMsg += "ThreatLockerService is already installed and running. No action needed."
        $Global:customFieldMessage = "ThreatLocker is already installed and running. ($Date)"
    }
    else {
        # --- 3. Determine Organization Name ---
        $Global:DiagMsg += "--- Determining Organization Name ---"
        $organizationName = ""
        try {
            # Directly query the hard-coded Organizational Custom Field name
            $orgNameFromField = Ninja-Property-Get -Organization -Name "threatlockerOrgName"
            if (-not [string]::IsNullOrEmpty($orgNameFromField)) {
                $organizationName = $orgNameFromField.Trim()
                $Global:DiagMsg += "Successfully retrieved organization name '$organizationName' from Org Custom Field 'threatlockerOrgName'."
            }
            else {
                $Global:DiagMsg += "Org Custom Field 'threatlockerOrgName' was found but is empty. Will use fallback."
            }
        }
        catch {
            $Global:DiagMsg += "Could not retrieve Org Custom Field 'threatlockerOrgName'. Error: $($_.Exception.Message). Will use fallback."
        }

        # If the custom field was empty or an error occurred, use the fallback
        if ([string]::IsNullOrEmpty($organizationName)) {
            $organizationName = $env:NINJA_ORGANIZATION_NAME
            $Global:DiagMsg += "Using fallback NinjaRMM organization name: '$organizationName'."
        }

        # Final check to ensure we have a name before proceeding
        if ([string]::IsNullOrEmpty($organizationName)) {
            throw "FATAL: Organization name could not be determined from 'threatlockerOrgName' Custom Field or the fallback Ninja variable. Cannot proceed."
        }
        
        # --- 4. Download Installer ---
        $Global:DiagMsg += "--- Downloading Installer ---"

        # Create temp directory if it doesn't exist
        if (-not (Test-Path -Path $tempDir -PathType Container)) {
            $Global:DiagMsg += "Directory '$tempDir' not found. Creating it."
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }

        # Determine correct installer for OS architecture
        $downloadURL = if ([Environment]::Is64BitOperatingSystem) {
            $Global:DiagMsg += "64-bit OS detected."
            "https://api.threatlocker.com/updates/installers/threatlockerstubx64.exe"
        }
        else {
            $Global:DiagMsg += "32-bit OS detected."
            "https://api.threatlocker.com/updates/installers/threatlockerstubx86.exe"
        }

        $Global:DiagMsg += "Downloading installer from $downloadURL to $localInstaller."
        Invoke-WebRequest -Uri $downloadURL -OutFile $localInstaller

        # --- 5. Install Application ---
        $Global:DiagMsg += "--- Installing Application ---"
        $installArgs = "Instance=`"$($env:threatlockerInstance)`" key=`"$($env:threatlockerKey)`" Company=`"$organizationName`""
        $Global:DiagMsg += "Executing: $localInstaller $installArgs"

        Start-Process -FilePath $localInstaller -ArgumentList $installArgs -Wait -NoNewWindow
        
        # Add a short delay to allow the service to start
        Start-Sleep -Seconds 15

        # --- 6. Verify Installation ---
        $Global:DiagMsg += "--- Verifying Installation ---"
        $serviceCheck = Get-Service -Name ThreatLockerService -ErrorAction SilentlyContinue
        if ($serviceCheck -and $serviceCheck.Status -eq 'Running') {
            $Global:DiagMsg += "Verification successful. ThreatLockerService is running."
            $Global:customFieldMessage = "ThreatLocker successfully installed and service is running. ($Date)"
        }
        else {
            $Global:DiagMsg += "Verification FAILED. ThreatLockerService is not running or not found."
            $Global:AlertMsg = "ThreatLocker installation failed. Service is not running. | Last Checked $Date"
            $Global:customFieldMessage = "ThreatLocker installation failed. ($Date)"
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