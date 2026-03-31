<#
.SYNOPSIS
    Downloads and installs the latest version of OneDrive as ALL USERS.

.DESCRIPTION
    This script creates a C:\Temp directory if it doesn't exist, downloads the 
    latest production release of the OneDrive installer to it, and then runs the 
    installer in silent mode with the /allusers switch to ensure it is installed 
    for all users on the machine. Administrator privileges are required.

#>

# Requires -RunAsAdministrator

# --- Variables ---
# Define the directory path and the full file path for the installer.
$downloadDir = "C:\Temp"
$installerPath = Join-Path -Path $downloadDir -ChildPath "OneDriveSetup.exe"
$oneDriveUrl = "https://go.microsoft.com/fwlink/?linkid=844652"


# --- Script Body ---

# Check if the destination directory exists. If not, create it.
if (-not (Test-Path -Path $downloadDir -PathType Container)) {
    Write-Host "Directory $downloadDir does not exist. Creating it now..." -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
        Write-Host "Directory $downloadDir created successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create directory '$downloadDir'. Please check permissions."
        # Stop the script if the directory cannot be created
        return
    }
}
else {
    Write-Host "Directory $downloadDir already exists." -ForegroundColor Cyan
}


Write-Host "Starting the download of the latest OneDrive installer to $installerPath..." -ForegroundColor Green

try {
    # Download the latest OneDrive installer
    Invoke-WebRequest -Uri $oneDriveUrl -OutFile $installerPath
    Write-Host "Download complete." -ForegroundColor Green
}
catch {
    Write-Error "Failed to download the OneDrive installer. Please check your internet connection and the URL: $oneDriveUrl"
    return
}


Write-Host "Installing OneDrive for all users. This will be a silent installation." -ForegroundColor Green

try {
    # Start the installer in silent mode and for all users
    # The /allusers switch installs OneDrive to the Program Files directory
    # The /silent switch prevents any UI from showing during installation
    Start-Process -FilePath $installerPath -ArgumentList "/allusers /silent" -Wait -PassThru

    Write-Host "OneDrive installation is complete." -ForegroundColor Green
}
catch {
    Write-Error "The OneDrive installation failed. Please check the installer logs if available."
}
finally {
    # Clean up the downloaded installer file
    if (Test-Path -Path $installerPath) {
        Remove-Item -Path $installerPath -Force
        Write-Host "Cleaned up the installer file from $installerPath." -ForegroundColor Yellow
    }
}