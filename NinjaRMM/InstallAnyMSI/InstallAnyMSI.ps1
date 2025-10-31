# Script Title: Download and Install MSI
# Description: Downloads an MSI from a specified URL and installs it silently.
# Script Name and Type
$ScriptName = "Download and Install MSI"
$ScriptType = "Remediation"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$Global:tempDirectory = "C:\Temp"
$env:msiFileName = "Installer.msi" # (Text): The name for the downloaded MSI file (e.g., Installer.msi).
$env:logFileName = "MSI-Installer.log" # (Text): The name for the installation log file (e.g., Msi-Install-Log.log).


## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# msiUrl (Text): The direct download URL for the MSI installer.
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
    # --- Start of Converted Functions ---

    Function Download-MsiFile {
        <#
        .SYNOPSIS
            Downloads the MSI file from the specified URL.
        #>
        param (
            [Parameter(Mandatory = $true)]
            [string]$Url,

            [Parameter(Mandatory = $true)]
            [string]$DestinationPath
        )

        # Define a User Agent string that mimics a standard web browser.
        $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36"

        $Global:DiagMsg += "Starting download of MSI from '$Url'..."
        try {
            # Using Invoke-WebRequest to download the file.
            Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UserAgent $userAgent -UseBasicParsing
            $Global:DiagMsg += "Successfully downloaded MSI to '$DestinationPath'."
            return $true
        }
        catch {
            # Provide a more detailed error message for 403 errors.
            if ($_.Exception.Response.StatusCode.Value__ -eq 403) {
                $Global:DiagMsg += "Failed to download MSI. The server returned a '403 Forbidden' error. This link may be expired or require authentication."
            }
            else {
                $Global:DiagMsg += "Failed to download MSI. Error: $($_.Exception.Message)"
            }
            return $false
        }
    }

    Function Install-MsiPackage {
        <#
        .SYNOPSIS
            Installs the MSI package silently.
        #>
        param (
            [Parameter(Mandatory = $true)]
            [string]$MsiPath,

            [Parameter(Mandatory = $true)]
            [string]$LogPath
        )

        $Global:DiagMsg += "Starting installation of MSI package from '$MsiPath'..."
        $Global:DiagMsg += "A detailed log will be created at '$LogPath'."

        # Arguments for msiexec.exe:
        $msiArgs = "/i `"$MsiPath`" /qn /L*v `"$LogPath`""

        try {
            # Start the msiexec process and wait for it to complete.
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

            # Check the exit code of the process. 0 usually means success.
            if ($process.ExitCode -eq 0) {
                $Global:DiagMsg += "MSI installation completed successfully."
                return $true
            }
            else {
                $Global:DiagMsg += "MSI installation completed with a non-zero exit code: $($process.ExitCode)."
                $Global:DiagMsg += "This may indicate an error. Check the log file for details: $LogPath"
                return $false
            }
        }
        catch {
            $Global:DiagMsg += "An error occurred while trying to run the MSI installer. Error: $($_.Exception.Message)"
            return $false
        }
    }

    # --- End of Converted Functions ---

    # --- Start of Main Execution Logic ---

    $Global:DiagMsg += "--- Starting MSI Installer Script ---"

    # 1. Validate RMM Variables
    if ([string]::IsNullOrWhiteSpace($env:msiUrl)) { throw "RMM variable 'msiUrl' is not set." }
    if ([string]::IsNullOrWhiteSpace($env:msiFileName)) { throw "RMM variable 'msiFileName' is not set." }
    if ([string]::IsNullOrWhiteSpace($env:logFileName)) { throw "RMM variable 'logFileName' is not set." }

    # 2. Construct paths using the hard-coded temp directory
    $msiFullPath = Join-Path -Path $Global:tempDirectory -ChildPath $env:msiFileName
    $logFullPath = Join-Path -Path $Global:tempDirectory -ChildPath $env:logFileName
    $Global:DiagMsg += "Installer path set to: $msiFullPath"
    $Global:DiagMsg += "Log path set to: $logFullPath"

    # 3. Step 1: Download the MSI file.
    if (Download-MsiFile -Url $env:msiUrl -DestinationPath $msiFullPath) {

        # 4. Step 2: If download was successful, proceed with installation.
        if (Install-MsiPackage -MsiPath $msiFullPath -LogPath $logFullPath) {
            # Successful installation
            $Global:DiagMsg += "Installation of '$($env:msiFileName)' successful."
            $Global:customFieldMessage = "Successfully downloaded and installed '$($env:msiFileName)'. | Last Checked $Date"
        }
        else {
            # Failed installation
            $Global:DiagMsg += "Installation failed. See diagnostic messages."
            $Global:AlertMsg = "MSI installation failed with a non-zero exit code. Check log: $logFullPath | Last Checked $Date"
            $Global:customFieldMessage = "MSI installation failed. See log. ($Date)"
        }
    }
    else {
        # Failed download
        $Global:DiagMsg += "Skipping installation due to download failure."
        $Global:AlertMsg = "Failed to download MSI from '$($env:msiUrl)'. See diagnostics. | Last Checked $Date"
        $Global:customFieldMessage = "MSI download failed. ($Date)"
    }

    $Global:DiagMsg += "--- Script Execution Finished ---"
    # Note: MSI cleanup logic from original script is intentionally removed per RMM directive.

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