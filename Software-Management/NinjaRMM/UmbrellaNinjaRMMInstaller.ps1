<#
.SYNOPSIS
    Downloads and installs an MSI package from a given URL.

.DESCRIPTION
    This script downloads an MSI installer from a specified URL to a temporary directory,
    then runs the installer silently with verbose logging. The script is designed for
    PowerShell 5.1 and does not require any external modules. All user-configurable
    variables are located at the beginning of the script.

.AUTHOR
    Alex Ivantsov

.DATE
    2025-10-09
#>

#--------------------------------------------------------------------------------
# --- User-Configurable Variables ---
#--------------------------------------------------------------------------------

# The direct download URL for the MSI installer.
$msiUrl = ""

# The directory where the MSI and log files will be saved.
# Using the user's temporary folder by default.
$tempDirectory = $env:TEMP

# The name for the downloaded MSI file.
$msiFileName = "Installer.msi"

# The name for the installation log file.
$logFileName = "Msi-Install-Log.log"


#--------------------------------------------------------------------------------
# --- Functions ---
#--------------------------------------------------------------------------------

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

    # --- CHANGE ---
    # Define a User Agent string that mimics a standard web browser.
    $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36"

    Write-Verbose "Starting download of MSI from '$Url'..."
    try {
        # Using Invoke-WebRequest to download the file.
        # Added the -UserAgent parameter to mimic a browser request.
        Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UserAgent $userAgent -UseBasicParsing -Verbose
        Write-Host "Successfully downloaded MSI to '$DestinationPath'."
        return $true
    }
    catch {
        # Provide a more detailed error message for 403 errors.
        if ($_.Exception.Response.StatusCode.Value__ -eq 403) {
            Write-Error "Failed to download MSI. The server returned a '403 Forbidden' error. This link may be expired or require authentication."
        }
        else {
            Write-Error "Failed to download MSI. Error: $_"
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

    Write-Verbose "Starting installation of MSI package from '$MsiPath'..."
    Write-Verbose "A detailed log will be created at '$LogPath'."

    # Arguments for msiexec.exe:
    # /i - Specifies the installation of a package.
    # /qn - Specifies a quiet, no-UI installation.
    # /L*v - Creates a verbose log file at the specified path.
    $msiArgs = "/i `"$MsiPath`" /qn /L*v `"$LogPath`""

    try {
        # Start the msiexec process and wait for it to complete.
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -Verbose

        # Check the exit code of the process. 0 usually means success.
        if ($process.ExitCode -eq 0) {
            Write-Host "MSI installation completed successfully."
            return $true
        }
        else {
            Write-Warning "MSI installation completed with a non-zero exit code: $($process.ExitCode)."
            Write-Warning "This may indicate an error. Check the log file for details: $LogPath"
            return $false
        }
    }
    catch {
        Write-Error "An error occurred while trying to run the MSI installer. Error: $_"
        return $false
    }
}


#--------------------------------------------------------------------------------
# --- Main Execution ---
#--------------------------------------------------------------------------------

# Set the VerbosePreference to 'Continue' to ensure verbose messages are displayed.
$VerbosePreference = 'Continue'

# Construct the full paths for the MSI and log files.
$msiFullPath = Join-Path -Path $tempDirectory -ChildPath $msiFileName
$logFullPath = Join-Path -Path $tempDirectory -ChildPath $logFileName

Write-Host "--- Starting MSI Installer Script ---"

# Step 1: Download the MSI file.
if (Download-MsiFile -Url $msiUrl -DestinationPath $msiFullPath) {

    # Step 2: If the download was successful, proceed with the installation.
    Install-MsiPackage -MsiPath $msiFullPath -LogPath $logFullPath
}
else {
    Write-Error "Skipping installation due to download failure."
}

# Clean up the downloaded MSI file.
if (Test-Path -Path $msiFullPath) {
    Write-Verbose "Removing temporary MSI file: '$msiFullPath'"
    Remove-Item -Path $msiFullPath -Force -ErrorAction SilentlyContinue
}

Write-Host "--- Script Execution Finished ---"