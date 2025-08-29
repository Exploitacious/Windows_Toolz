<#
.SYNOPSIS
    Installs a predefined list of applications using the Windows Package Manager (Winget).
    This script is designed to be robust, automatically handling Winget's installation and
    using the package manager for all application deployments, including Winget-AutoUpdate.

.DESCRIPTION
    The script performs the following actions:
    1.  Verifies it is running with Administrator privileges.
    2.  Configures network settings (TLS 1.2, Proxy) for reliable downloads.
    3.  Checks for Winget. If not found, it downloads and installs the latest version.
    4.  Accurately checks the installation status of each app before installing.
    5.  Installs a list of required and optional applications directly through Winget.
    6.  A special override is used for 'Winget-AutoUpdate' to apply custom installer arguments.

.AUTHOR
    Alex Ivantsov

.DATE
    August 28, 2025
#>

#------------------------------------------------------------------------------------
# --- USER CONFIGURABLE VARIABLES ---
#------------------------------------------------------------------------------------

# Set this switch to $true to install the programs from the $OptionalPrograms list.
$InstallOptionalPrograms = $false

# A list of applications that will always be installed via Winget.
$RequiredPrograms = @(
    "Romanitho.Winget-AutoUpdate",      # Automatically updates Winget packages.
    "Microsoft.CompanyPortal",          # Company Portal
    "9N0DX20HK701",                     # Windows Terminal (from Microsoft Store)
    "Adobe.Acrobat.Reader.64-bit"       # Adobe Acrobat Reader DC (64-bit)
)

# A list of optional applications to be installed if the switch above is set to $true.
$OptionalPrograms = @(
    "Microsoft.VisualStudioCode",       # Visual Studio Code
    "Microsoft.PowerToys",              # Microsoft PowerToys
    "Zoom.Zoom",                        # Zoom Client
    "9NRX63209R7B",                     # Outlook (New) for Windows (from Microsoft Store)
    "Microsoft.Teams"                   # Microsoft Teams (New)
)

#------------------------------------------------------------------------------------
# --- SCRIPT INITIALIZATION ---
#------------------------------------------------------------------------------------

# Elevate to Administrator
Write-Host "Verifying administrator privileges..." -ForegroundColor Yellow
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Warning "Administrator privileges required. Re-launching script as an Administrator."
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

#------------------------------------------------------------------------------------
# --- FUNCTIONS ---
#------------------------------------------------------------------------------------

Function Invoke-ResilientWebRequest {
    param(
        [Parameter(Mandatory = $true)] [string]$Uri,
        [Parameter(Mandatory = $true)] [string]$OutFile
    )
    Write-Host "Downloading from $Uri"
    $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36" }
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -Headers $headers -ProxyUseDefaultCredentials -TimeoutSec 180 -UseBasicParsing
        Write-Host "Download successful." -ForegroundColor Green
    }
    catch {
        throw "Failed to download file. Error: $_"
    }
}

Function Test-Winget {
    Write-Host "Checking for Winget..." -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Winget is already installed." -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "Winget not found." -ForegroundColor Yellow
        return $false
    }
}

Function Install-Winget {
    Write-Host "Attempting to install Winget..." -ForegroundColor Cyan
    try {
        $wingetInstallerUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $downloadPath = Join-Path -Path $env:TEMP -ChildPath "Microsoft.DesktopAppInstaller.msixbundle"
        Invoke-ResilientWebRequest -Uri $wingetInstallerUrl -OutFile $downloadPath
        Write-Host "Installing Winget package..."
        Add-AppxPackage -Path $downloadPath
        Write-Host "Winget has been installed successfully." -ForegroundColor Green
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Error "Failed to download or install Winget. Error: $_"
        exit
    }
}

Function Install-Applications {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$AppList
    )

    foreach ($app in $AppList) {
        Write-Host "------------------------------------------------------------"
        Write-Host "Processing: $app" -ForegroundColor Cyan
        try {
            # Run the command to check for the installed package.
            $listResult = winget list --id $app --exact --accept-source-agreements -q
            
            # *** FIX IMPLEMENTED HERE ***
            # We now specifically check if the command's output contains the App ID.
            # The '-like' operator with wildcards ensures we find the ID anywhere in the output text.
            # This correctly handles the "No installed package found..." message.
            if ($listResult -like "*$app*") {
                Write-Host "'$app' is already installed. Skipping." -ForegroundColor Green
            } 
            else {
                Write-Host "Installing '$app'..." -ForegroundColor Yellow
                
                # Default command for most applications
                $wingetArgs = @("install", "--id", $app, "--exact", "--silent", "--accept-source-agreements", "--accept-package-agreements")
                
                # Special handling for Winget-AutoUpdate
                if ($app -eq "Romanitho.Winget-AutoUpdate") {
                    Write-Host "Applying custom installer arguments for Winget-AutoUpdate." -ForegroundColor Yellow
                    $overrideArgs = "/qn RUN_WAU=YES STARTMENUSHORTCUT=1 NOTIFICATIONLEVEL=None"
                    $wingetArgs += @("--override", "`"$overrideArgs`"")
                }
                
                # Execute the installation
                Start-Process winget -ArgumentList $wingetArgs -Wait -NoNewWindow
                Write-Host "Successfully installed '$app'." -ForegroundColor Green
            }
        }
        catch {
            Write-Error "An error occurred while processing '$app'. Error: $_"
        }
    }
}

#------------------------------------------------------------------------------------
# --- SCRIPT EXECUTION ---
#------------------------------------------------------------------------------------

Write-Host "`nStarting Application Installation Script..." -ForegroundColor Magenta

# Step 1: Configure .NET framework for modern web requests.
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebProxy]::GetDefaultProxy()
Write-Host "Network settings configured for this session." -ForegroundColor Cyan

# Step 2: Ensure Winget is available.
if (-not (Test-Winget)) {
    Install-Winget
    if (-not (Test-Winget)) {
        Write-Error "Winget is still not available after installation attempt. Terminating script."
        exit
    }
}

# Step 3: Install the required set of applications.
Write-Host "`n--- Installing Required Applications ---" -ForegroundColor Magenta
Install-Applications -AppList $RequiredPrograms

# Step 4: Install optional applications if requested.
if ($InstallOptionalPrograms) {
    Write-Host "`n--- Installing Optional Applications ---" -ForegroundColor Magenta
    Install-Applications -AppList $OptionalPrograms
}
else {
    Write-Host "`nSkipping optional applications as per the script configuration." -ForegroundColor Yellow
}

Write-Host "------------------------------------------------------------"
Write-Host "Script execution finished!" -ForegroundColor Magenta
Read-Host -Prompt "Press Enter to exit"