<#
.SYNOPSIS
    Automates the installation and updating of specified PowerShell modules and then runs Windows Updates.

.DESCRIPTION
    This script performs the following actions:
    1. Ensures it is running with Administrator privileges.
    2. Configures the environment for reliable interaction with the PowerShell Gallery (TLS 1.2, trusted repository, NuGet provider).
    3. Iterates through a user-defined list of PowerShell modules. For each module, it:
        - Installs the module if it's not present.
        - Updates the module if a newer version is available.
        - Cleans up any old, duplicate versions of the module.
    4. Installs the 'PSWindowsUpdate' module if not already present.
    5. Uses 'PSWindowsUpdate' to check for, download, and install all available Windows Updates automatically.
    
    The script is designed to run without user interaction by automatically accepting prompts.

.AUTHOR
    Alex Ivantsov

.DATE
    28 August 2025
#>

# --- USER-CONFIGURABLE VARIABLES ---
# Add or remove the names of the PowerShell modules you want to keep installed and up-to-date in the list below.
$TargetModules = @(
    "PSWindowsUpdate",
    "PSReadline" # Example: Add other modules you use here
)

# --- FUNCTION DEFINITIONS ---

Function Initialize-Environment {
    <#
    .SYNOPSIS
        Prepares the PowerShell environment for the script's operations.
    .DESCRIPTION
        This function performs three key setup tasks:
        1. Verifies that the script is running in an elevated (Administrator) session. If not, it attempts to relaunch itself with admin rights.
        2. Sets the security protocol to TLS 1.2, which is required for secure communication with modern web services like the PowerShell Gallery.
        3. Configures the PowerShell Gallery as a trusted source and ensures the necessary NuGet package provider is installed. This prevents security prompts during module installation.
    #>
    Write-Host "--- Initializing Environment ---" -ForegroundColor Yellow

    # 1. Verify/Elevate Admin Session
    Write-Host "Checking for Administrator privileges..."
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Administrator rights required. Attempting to relaunch the script as an Administrator."
        # Relaunch the script with Admin rights and exit the current, non-elevated session.
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
    else {
        Write-Host "Administrator privileges confirmed." -ForegroundColor Green
    }

    # 2. Define and use TLS1.2 for modern web compatibility
    Write-Host "Setting network security protocol to TLS 1.2..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "TLS 1.2 set successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to set TLS 1.2. Network operations may fail. Error: $_"
        # Exit if we can't set this critical protocol
        exit
    }
    
    # 3. Register PSGallery, set it as Trusted, and Verify NuGet provider
    # These steps are crucial for avoiding interactive prompts when installing modules.
    Write-Host "Configuring PowerShell Gallery repository..."
    try {
        # Silently try to register the default repository if it doesn't exist.
        if (-NOT (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
            Register-PSRepository -Default -ErrorAction Stop
            Write-Host "PSGallery repository has been registered."
        }

        # Set the repository to 'Trusted' to avoid security prompts on module installation.
        if ((Get-PSRepository -Name 'PSGallery').InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop
            Write-Host "PSGallery repository has been set to 'Trusted'."
        }

        # Ensure the NuGet package provider, which PowerShellGet depends on, is installed.
        # -Force ensures it installs even if a version is already present.
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -ErrorAction Stop
        
        # Ensure the PowerShellGet module itself is up-to-date for best performance and security.
        Install-Module -Name PowerShellGet -MinimumVersion 2.2.4 -Scope AllUsers -Force -AllowClobber -ErrorAction Stop

        Write-Host "PowerShell Gallery and NuGet provider are configured." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to configure PowerShell providers. Cannot proceed with module management. Error: $_"
        # Exit if the fundamental providers can't be set up
        exit
    }
    Write-Host "-----------------------------" -ForegroundColor Yellow
    Write-Host
}

Function Manage-PowerShellModules {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ModuleList
    )
    <#
    .SYNOPSIS
        Installs, updates, and cleans specified PowerShell modules.
    .DESCRIPTION
        Takes an array of module names as input. For each module, it checks the local installation status against the latest version in the PowerShell Gallery.
        - If the module is not installed, it installs the latest version.
        - If the module is installed but outdated, it updates it.
        - If multiple versions of a module are installed, it removes all old versions and ensures the latest is installed.
        - If the module is already up-to-date, it confirms the status and moves on.
        The function uses parameters like -Force, -AcceptLicense, and -AllowClobber to ensure a non-interactive execution.
    #>
    Write-Host "--- Managing PowerShell Modules ---" -ForegroundColor Yellow

    # Loop through each module specified in the user-configurable list
    foreach ($ModuleName in $ModuleList) {
        Write-Host "Processing module: '$ModuleName'..." -ForegroundColor Cyan
        try {
            # Find the latest version of the module available in the PSGallery
            $GalleryModule = Find-Module -Name $ModuleName -ErrorAction Stop
            $LatestVersion = $GalleryModule.Version

            # Get all locally installed versions of the module
            $InstalledModules = Get-InstalledModule -Name $ModuleName -AllVersions -ErrorAction SilentlyContinue

            if (-not $InstalledModules) {
                # CASE 1: The module is not installed at all.
                Write-Host "  '$ModuleName' is not installed. Installing version $LatestVersion..."
                Install-Module -Name $ModuleName -Force -AcceptLicense -AllowClobber -Scope AllUsers -ErrorAction Stop
                Write-Host "  Successfully installed '$ModuleName'." -ForegroundColor Green
            }
            else {
                # The module is installed. Now check versions.
                $InstalledVersions = $InstalledModules.Version

                if ($InstalledVersions.Count -gt 1) {
                    # CASE 2: Multiple versions are installed. Time to clean up.
                    Write-Host "  Multiple versions of '$ModuleName' found: $($InstalledVersions -join ', ')"
                    
                    # Uninstall all old versions
                    foreach ($Version in $InstalledVersions) {
                        if ($Version -ne $LatestVersion) {
                            Write-Host "  Uninstalling old version $Version..."
                            Uninstall-Module -Name $ModuleName -RequiredVersion $Version -Force -ErrorAction Stop
                        }
                    }
                }

                # Get the current state again after potential cleanup
                $CurrentInstalled = Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue
                
                # CASE 3: A single version is installed, check if it's the latest.
                if ($CurrentInstalled.Version -lt $LatestVersion) {
                    Write-Host "  Updating '$ModuleName' from version $($CurrentInstalled.Version) to $LatestVersion..."
                    # Using Install-Module with -Force is often more reliable than Update-Module for overwriting.
                    Install-Module -Name $ModuleName -Force -AcceptLicense -AllowClobber -Scope AllUsers -ErrorAction Stop
                    Write-Host "  Successfully updated '$ModuleName'." -ForegroundColor Green
                }
                else {
                    # CASE 4: The latest version is already installed.
                    Write-Host "  '$ModuleName' is already up-to-date (Version: $($CurrentInstalled.Version))." -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Warning "An error occurred while managing '$ModuleName'. Error: $($_.Exception.Message)"
        }
        Write-Host
    }
    Write-Host "---------------------------------" -ForegroundColor Yellow
    Write-Host
}

Function Invoke-WindowsUpdate {
    <#
    .SYNOPSIS
        Checks for and installs all available Windows Updates using the PSWindowsUpdate module.
    .DESCRIPTION
        This function handles the entire Windows Update process:
        1. Imports the PSWindowsUpdate module.
        2. Checks if the Microsoft Update service is registered, which allows updates for other Microsoft products (like Office). If not, it registers the service non-interactively.
        3. Verifies the service registration.
        4. Scans for, downloads, and installs all pending updates automatically. It accepts all updates and will not force a reboot.
    #>
    Write-Host "--- Starting Windows Update Process ---" -ForegroundColor Yellow

    try {
        # Forcefully import the module to ensure we're using the latest version
        Import-Module PSWindowsUpdate -Force
        Write-Host "Successfully imported 'PSWindowsUpdate' module."
    }
    catch {
        Write-Error "Failed to import the 'PSWindowsUpdate' module. Cannot proceed with Windows Updates. Error: $_"
        return # Exit the function if the module can't be loaded
    }

    # The Service ID for Microsoft Update (to get updates for Office, etc.)
    $MicrosoftUpdateServiceId = "7971f918-a847-4430-9279-4a52d1efe18d"

    Write-Host "Checking for Microsoft Update Service registration..."
    # Check if the Microsoft Update service is registered
    if (-not (Get-WUServiceManager -ServiceID $MicrosoftUpdateServiceId -ErrorAction SilentlyContinue)) {
        Write-Host "Microsoft Update Service is not registered. Attempting to register..."
        # Add the service manager, -Confirm:$false prevents the interactive prompt.
        Add-WUServiceManager -ServiceID $MicrosoftUpdateServiceId -Confirm:$false
        if (Get-WUServiceManager -ServiceID $MicrosoftUpdateServiceId -ErrorAction SilentlyContinue) {
            Write-Host "Microsoft Update Service registered successfully." -ForegroundColor Green
        }
        else {
            Write-Error "Failed to register the Microsoft Update Service. Updates may be limited to Windows only."
            # We can continue without this, but it's worth noting.
        }
    }
    else {
        Write-Host "Microsoft Update Service is already registered." -ForegroundColor Green
    }
    
    # Run the update installation process
    Write-Host "Searching for, downloading, and installing all available updates..."
    Write-Host "(This process can take a significant amount of time. Please be patient.)"
    try {
        # Install-WindowsUpdate combines the check, download, and install steps.
        # -AcceptAll: Agrees to all EULAs
        # -IgnoreReboot: Prevents the script from forcing a system restart.
        # -ForceInstall: Forces installation even if an update is already downloaded.
        Install-WindowsUpdate -AcceptAll -ForceInstall -IgnoreReboot -Verbose -ErrorAction Stop
        Write-Host "Windows Update installation process complete." -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred during the Windows Update process. Error: $($_.Exception.Message)"
    }
    Write-Host "-------------------------------------" -ForegroundColor Yellow
    Write-Host
}


# --- SCRIPT EXECUTION ---

# Clear the screen for a clean start
Clear-Host

# Step 1: Set up the environment (Admin check, TLS, PSGallery config)
Initialize-Environment

# Step 2: Ensure all required PowerShell modules are installed and up-to-date
Manage-PowerShellModules -ModuleList $TargetModules

# Step 3: Run the Windows Update process
Invoke-WindowsUpdate

# Final message to the user
Write-Host "Script has finished all tasks." -ForegroundColor Green
Read-Host -Prompt "Press Enter to exit"