# Script Title: Install BlackPoint SNAP Agent
# Description: Checks for the presence of the BlackPoint SNAP Agent service. If the service is not found, it downloads and installs the agent using configuration data from Organization-level Custom Fields.

# Script Name and Type
$ScriptName = "Install BlackPoint SNAP Agent"
$ScriptType = "Remediation" # Or "Remediation", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$SnapServiceName = "Snap"
$TempDirectory = "C:\Temp"

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get'
# bpSnapUid (Text): The unique identifier (UID) for the BlackPoint SNAP installer download URL.
# bpSnapFile (Text): The specific filename of the SNAP installer for your organization (e.g., 'snap-2.6.5.msi').

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
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
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ012356789') {
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
$InstallerPath = $null # Initialize for cleanup block

try {
    # Retrieve required data from Organization Custom Fields
    $Global:DiagMsg += "Retrieving configuration from Organization Custom Fields 'bpSnapUid' and 'bpSnapFile'..."
    $SnapUID = Ninja-Property-Get -Name 'bpSnapUid'
    $InstallerName = Ninja-Property-Get -Name 'bpSnapFile'

    # Pre-flight Check for Org Custom Fields
    if (-not ($SnapUID -and $InstallerName)) {
        throw "FATAL: The Organization Custom Fields 'bpSnapUid' and 'bpSnapFile' must be configured and populated in NinjaRMM."
    }
    $Global:DiagMsg += "Successfully retrieved Org-level variables."

    # Define dynamic variables
    $InstallerPath = Join-Path $TempDirectory $InstallerName
    $DownloadURL = "https://portal.blackpointcyber.com/installer/$($SnapUID)/$($InstallerName)"

    # Main logic starts
    $Global:DiagMsg += "Checking for existing SNAP service ('$SnapServiceName')..."
    if (Get-Service -Name $SnapServiceName -ErrorAction SilentlyContinue) {
        $Global:DiagMsg += "SUCCESS: BlackPoint SNAP service is present. No action needed."
        $Global:customFieldMessage = "BlackPoint SNAP Agent installed. ($Date)"
    }
    else {
        $Global:DiagMsg += "SNAP service not found. Proceeding with installation."

        # 1. Check for required .NET Framework version
        $Global:DiagMsg += "Checking for .NET Framework 4.6.1 or higher..."
        $netVersionKey = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue
        if ($null -eq $netVersionKey -or $netVersionKey.Release -lt 394254) {
            throw ".NET Framework 4.6.1 or higher is required but not found. Current release key: '$($netVersionKey.Release)'"
        }
        $Global:DiagMsg += ".NET Framework check passed."

        # 2. Download the installer
        $Global:DiagMsg += "Checking for and removing pre-existing installer file at $InstallerPath..."
        if (Test-Path -Path $InstallerPath) {
            Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
            $Global:DiagMsg += "Removed existing file. Pausing for 5 seconds to allow file lock to be released..."
            Start-Sleep -Seconds 5
        }

        $Global:DiagMsg += "Downloading installer from $DownloadURL to $InstallerPath..."
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $DownloadURL -OutFile $InstallerPath -ErrorAction Stop
        }
        catch {
            throw "Failed to download the SNAP installer. Error: $($_.Exception.Message)"
        }

        # 3. Run the installer
        $Global:DiagMsg += "Executing installer with silent arguments..."
        
        Start-Process -FilePath $InstallerPath -ArgumentList "-y"
        
        $process = Start-Process -FilePath $InstallerPath -ArgumentList "-y" # -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -ne 0) {
            # This is not a fatal error, as the service might still install. We verify below.
            $Global:DiagMsg += "Installer process exited with a non-zero exit code: $($process.ExitCode)."
        }
        
        # Give the service a moment to register
        Start-Sleep -Seconds 20

        # 4. Verify installation
        $Global:DiagMsg += "Verifying SNAP service installation..."
        if (Get-Service -Name $SnapServiceName -ErrorAction SilentlyContinue) {
            $Global:DiagMsg += "SUCCESS: BlackPoint SNAP Agent service is now installed."
            $Global:customFieldMessage = "BlackPoint SNAP Agent installed successfully. ($Date)"
        }
        else {
            throw "Installation failed. The '$SnapServiceName' service was not found after running the installer."
        }
    }
}
catch {
    # Use the more specific error message from the script's logic
    $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { "An unknown error occurred." }
    $Global:DiagMsg += "An unexpected error occurred: $errorMessage"
    $Global:AlertMsg = "Script failed: $errorMessage | Last Checked $Date"
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