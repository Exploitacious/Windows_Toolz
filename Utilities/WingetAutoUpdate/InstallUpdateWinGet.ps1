<#
.SYNOPSIS
    Installs or updates the Windows Package Manager (WinGet) for the current user.

.DESCRIPTION
    This script provides a fully automated method for installing the latest version of the
    Windows Package Manager (WinGet) on PowerShell 5.1. It is designed to run without
    any parameters and handles all necessary prerequisite checks, dependency resolution,
    and installation steps.

    The script performs the following actions:
    1. Checks for a compatible Windows version (Windows 10 build 17763 or newer).
    2. Verifies internet connectivity.
    3. Handles administrative elevation gracefully to query and install system-wide packages.
    4. Detects if a functional version of WinGet is already installed.
    5. If WinGet is missing, outdated, or a forced update is requested, it downloads the latest version.
    6. Automatically identifies, downloads, and prepares required dependencies (like UI.Xaml and VCLibs).
    7. Installs WinGet along with its dependencies.
    8. Cleans up all temporary files upon completion.

.NOTES
    Author: Alex Ivantsov
    Date:   October 2, 2025
    Version: 1.0
    PowerShell Version: 5.1 (No external modules required)

.LINK
    Original script concept from: https://github.com/Andrew-J-Larson/OS-Scripts
#>

#------------------------------------------------------------------------------------
# --- USER CONFIGURABLE VARIABLES ---
#------------------------------------------------------------------------------------

# Set to $true to reinstall WinGet even if it's already present and up to date.
# Set to $false to skip installation if a working version of WinGet is detected.
$Global:ForceUpdate = $false

#------------------------------------------------------------------------------------
# --- HELPER FUNCTIONS ---
#------------------------------------------------------------------------------------

function Get-SystemInfo {
    <#
    .SYNOPSIS
        Gathers essential information about the operating system and environment.
    .DESCRIPTION
        This function collects OS version, architecture, and PowerShell session details.
        It returns a custom object containing these properties for use by other functions.
    .OUTPUTS
        [PSCustomObject] An object with system information.
    #>
    Write-Host "Gathering system information..."

    # Determine if the OS is 64-bit. This is a reliable method in PowerShell 5.1.
    $is64BitOS = [System.Environment]::Is64BitOperatingSystem

    # Determine the processor architecture string (x86, x64, arm, arm64).
    $architecture = switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { "x64"; break }
        "x86" { "x86"; break }
        "ARM64" { "arm64"; break }
        "ARM" { "arm"; break }
        default { if ($is64BitOS) { "x64" } else { "x86" } }
    }

    # Create and return a custom object with all the gathered information.
    return [PSCustomObject]@{
        OSVersion    = [System.Environment]::OSVersion.Version
        IsWindows    = $PSVersionTable.PSVersion.Major -ge 3 # A simple check for Windows PowerShell
        Architecture = $architecture
        IsElevated   = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        TempPath     = $env:TEMP
    }
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Checks if the system meets all requirements for installing WinGet.
    .DESCRIPTION
        Validates the OS version and internet connectivity. Halts the script if
        requirements are not met.
    .PARAMETER SystemInfo
        The system information object from Get-SystemInfo.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SystemInfo
    )

    Write-Host "Verifying system prerequisites..."

    # Define the minimum supported Windows 10 version for WinGet (1809).
    $supportedWindowsVersion = [System.Version]'10.0.17763.0'

    # Check 1: Ensure the script is running on a supported Windows version.
    if (-not $SystemInfo.IsWindows -or $SystemInfo.OSVersion -lt $supportedWindowsVersion) {
        Write-Error "SCRIPT HALTED: WinGet requires Windows 10 version 1809 (build 17763) or newer."
        return $false
    }

    # Check 2: Verify that there is an active internet connection.
    try {
        # Test-Connection is a reliable way to check for general internet access.
        if (-not (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction Stop)) {
            Write-Error "SCRIPT HALTED: An active internet connection is required."
            return $false
        }
    }
    catch {
        Write-Error "SCRIPT HALTED: An active internet connection is required. Could not reach 8.8.8.8."
        return $false
    }

    Write-Host "Prerequisites met." -ForegroundColor Green
    return $true
}

function Get-AllUserAppxPackages {
    <#
    .SYNOPSIS
        Retrieves a list of all AppX packages installed for all users on the system.
    .DESCRIPTION
        This function requires administrative privileges. If the current session is not
        elevated, it spawns a temporary elevated PowerShell process to get the data,
        exports it to a temp file, and then imports it back into the current session.
        This avoids forcing the user to run the entire script as an administrator.
    .OUTPUTS
        [Array] An array of AppX package objects.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SystemInfo
    )

    if ($SystemInfo.IsElevated) {
        # If already running as admin, just get the packages directly.
        return @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
    }
    else {
        # If not elevated, use a common technique to get elevated data without
        # re-running the whole script as admin.
        Write-Warning "Elevation is required to check system-wide packages. A UAC prompt will appear."
        
        $tempFile = Join-Path $SystemInfo.TempPath ([System.Guid]::NewGuid().ToString() + ".clixml")
        
        # Command to be executed in the new elevated process.
        $command = "Get-AppxPackage -AllUsers | Export-Clixml -Path '$tempFile' -Force"
        
        # Start a new PowerShell process with administrative rights (-Verb RunAs).
        # It runs hidden (-WindowStyle Hidden) and waits for completion (-Wait).
        $processInfo = @{
            FilePath     = "powershell.exe"
            ArgumentList = "-NoProfile -Command `"$command`""
            Verb         = "RunAs"
            WindowStyle  = "Hidden"
            Wait         = $true
        }
        Start-Process @processInfo

        # Import the data from the temporary file.
        if (Test-Path $tempFile) {
            $packages = Import-Clixml -Path $tempFile
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            return @($packages)
        }
        else {
            Write-Error "Failed to retrieve AppX package information from the elevated process."
            return @()
        }
    }
}

function Find-WinGetExecutable {
    <#
    .SYNOPSIS
        Locates the full path to the winget.exe executable.
    .DESCRIPTION
        WinGet can be installed in different locations. This function checks the standard
        user and system paths to find the most recent version of winget.exe.
    .OUTPUTS
        [String] The full path to winget.exe, or $null if not found.
    #>
    
    # Define potential paths for winget.exe.
    $userPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe"
    $systemPath = "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe\winget.exe"

    # Prefer the system-wide installation if it exists, as it's often more stable.
    if (Test-Path $systemPath) {
        try {
            # If multiple versions exist, find the latest one based on its file version.
            return (Get-Item $systemPath | Sort-Object -Property FileVersionRaw | Select-Object -Last 1).FullName
        }
        catch {
            # Fallback if sorting fails.
        }
    }
    
    # Check the user-specific path if the system path check fails.
    if (Test-Path $userPath) {
        return $userPath
    }

    # Return null if not found in any standard location.
    return $null
}

function Test-WinGetInstallation {
    <#
    .SYNOPSIS
        Checks if WinGet is installed, functional, and up to date.
    .DESCRIPTION
        This function first tries to locate winget.exe. If found, it checks its version
        to see if it is a retired version that must be updated. It also attempts to
        re-register the AppX package, which can fix common issues where the .exe exists
        but is not properly linked.
    .PARAMETER AllUserPackages
        An array of all user AppX packages from Get-AllUserAppxPackages.
    .OUTPUTS
        [String] Returns 'OK', 'Retired', or 'NotFound'.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [Array]$AllUserPackages
    )

    Write-Host "Checking for existing WinGet installation..."
    
    # Attempt to fix a common issue where WinGet is installed but not registered for the current user.
    $desktopAppInstaller = $AllUserPackages | Where-Object { $_.Name -eq "Microsoft.DesktopAppInstaller" }
    if ($desktopAppInstaller) {
        try {
            Add-AppxPackage -DisableDevelopmentMode -Register ($desktopAppInstaller.InstallLocation + "\AppxManifest.xml") -ErrorAction Stop | Out-Null
            Start-Sleep -Seconds 2 # Allow time for registration.
        }
        catch {
            Write-Warning "Could not re-register the existing Microsoft Desktop App Installer package."
        }
    }

    # Now, check if the executable can be found.
    $wingetPath = Find-WinGetExecutable
    if (-not $wingetPath) {
        Write-Host "WinGet is not installed."
        return 'NotFound'
    }

    # If the executable exists, check its version. Versions 1.2 and older used retired CDNs and must be updated.
    try {
        $versionString = (& $wingetPath --version).Replace("v", "")
        $currentVersion = [System.Version]$versionString
        $retiredVersion = [System.Version]'1.3.0.0' # Versions older than 1.3 are considered retired.

        if ($currentVersion -lt $retiredVersion) {
            Write-Warning "Found a retired version of WinGet ($currentVersion). An update is required."
            return 'Retired'
        }
        
        Write-Host "Found a functional and up-to-date version of WinGet ($currentVersion)." -ForegroundColor Green
        return 'OK'
    }
    catch {
        Write-Warning "Found winget.exe, but could not verify its version. Assuming it's broken."
        return 'NotFound'
    }
}

function Download-FileWithRetry {
    <#
    .SYNOPSIS
        Downloads a file from a URL with retry logic.
    .DESCRIPTION
        A robust wrapper for Invoke-WebRequest that handles transient network errors by retrying.
    .PARAMETER Uri
        The URL of the file to download.
    .PARAMETER OutFile
        The local path to save the file.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [string]$OutFile
    )

    $maxRetries = 3
    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            # PowerShell 5.1 can be slow without -UseBasicParsing.
            # -ErrorAction Stop ensures that failures are caught by the catch block.
            $webRequestParams = @{
                Uri             = $Uri
                OutFile         = $OutFile
                UseBasicParsing = $true
                ErrorAction     = 'Stop'
            }
            Invoke-WebRequest @webRequestParams
            
            # If download succeeds, exit the loop.
            return $true
        }
        catch {
            Write-Warning "Download from '$Uri' failed on attempt $i. Retrying in 5 seconds..."
            Start-Sleep -Seconds 5
        }
    }
    
    Write-Error "Failed to download file from '$Uri' after $maxRetries attempts."
    return $false
}

function Resolve-And-Install-WinGet {
    <#
    .SYNOPSIS
        The core function that handles the entire download, dependency resolution, and installation process.
    .DESCRIPTION
        This function downloads the WinGet .msixbundle, inspects its manifest to find dependencies,
        downloads any missing dependencies, and then orchestrates the final installation.
    .PARAMETER SystemInfo
        The system information object.
    .PARAMETER AllUserPackages
        An array of all user AppX packages.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SystemInfo,
        [Parameter(Mandatory = $true)]
        [Array]$AllUserPackages
    )

    # 1. Download the latest WinGet package
    #-----------------------------------------
    Write-Host "Downloading the latest WinGet package..."
    $wingetUrl = "https://aka.ms/getwinget"
    $tempWingetBundle = Join-Path $SystemInfo.TempPath "winget.msixbundle"
    
    if (-not (Download-FileWithRetry -Uri $wingetUrl -OutFile $tempWingetBundle)) {
        return $false
    }
    Write-Host "WinGet package downloaded successfully." -ForegroundColor Green

    # 2. Extract the manifest from the package to find dependencies
    #-----------------------------------------
    Write-Host "Resolving WinGet dependencies..."
    $dependenciesToInstall = [System.Collections.Generic.List[string]]::new()
    $tempExtractionDir = Join-Path $SystemInfo.TempPath ([System.Guid]::NewGuid().ToString())
    New-Item -Path $tempExtractionDir -ItemType Directory -Force | Out-Null
    
    try {
        # Load the assembly required to work with .zip files (which .msixbundle is).
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # Unzip the bundle to get the main .msix file for the correct architecture.
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempWingetBundle, $tempExtractionDir)
        $msixFile = Get-ChildItem -Path $tempExtractionDir -Filter "*.msix" | Where-Object { $_.Name -like "*$($SystemInfo.Architecture)*" } | Select-Object -First 1
        
        if (-not $msixFile) {
            throw "Could not find a matching .msix file for architecture '$($SystemInfo.Architecture)' in the bundle."
        }

        # Unzip the .msix file to read its manifest.
        $msixExtractionDir = Join-Path $SystemInfo.TempPath ([System.Guid]::NewGuid().ToString())
        [System.IO.Compression.ZipFile]::ExtractToDirectory($msixFile.FullName, $msixExtractionDir)
        
        # Load the AppxManifest.xml file.
        [xml]$manifest = Get-Content -Path (Join-Path $msixExtractionDir "AppxManifest.xml")

        # Loop through each dependency declared in the manifest.
        foreach ($dependency in $manifest.Package.Dependencies.PackageDependency) {
            $depName = $dependency.Name
            $depMinVersion = [System.Version]$dependency.MinVersion

            Write-Host "Checking dependency: $depName (version $depMinVersion or newer)"

            # Check if a suitable version of the dependency is already installed for any user.
            $installedDep = $AllUserPackages | Where-Object { $_.Name -eq $depName -and [System.Version]$_.Version -ge $depMinVersion }
            
            if ($installedDep) {
                Write-Host " -> Dependency '$depName' is already satisfied." -ForegroundColor Green
                continue # Move to the next dependency.
            }

            # If dependency is not met, download it.
            Write-Warning " -> Dependency '$depName' is missing. Attempting to download."
            
            $depFile = ""
            if ($depName -like "Microsoft.UI.Xaml*") {
                # UI.Xaml is distributed as a NuGet package (.nupkg).
                $nupkgUrl = "https://www.nuget.org/api/v2/package/$depName/$($depMinVersion.ToString())"
                $nupkgFile = Join-Path $SystemInfo.TempPath "$depName.nupkg"
                if (Download-FileWithRetry -Uri $nupkgUrl -OutFile $nupkgFile) {
                    # Extract the .appx from the .nupkg (which is a zip file).
                    $nupkgExtractionDir = Join-Path $SystemInfo.TempPath "$depName-nupkg"
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($nupkgFile, $nupkgExtractionDir)
                    $appxInNupkg = Get-ChildItem -Path $nupkgExtractionDir -Recurse -Filter "*.appx" | Select-Object -First 1
                    if ($appxInNupkg) {
                        $depFile = Join-Path $SystemInfo.TempPath $appxInNupkg.Name
                        Move-Item -Path $appxInNupkg.FullName -Destination $depFile -Force
                    }
                }
            }
            elseif ($depName -like "Microsoft.VCLibs*") {
                # VCLibs are distributed directly as .appx files from a Microsoft URL.
                $vcLibsVersion = "$($depMinVersion.Major).00"
                $vcLibsFileName = "Microsoft.VCLibs.$($SystemInfo.Architecture).$vcLibsVersion.Desktop.appx"
                $vcLibsUrl = "https://aka.ms/$vcLibsFileName"
                $depFile = Join-Path $SystemInfo.TempPath $vcLibsFileName
                if (-not (Download-FileWithRetry -Uri $vcLibsUrl -OutFile $depFile)) {
                    $depFile = "" # Clear on failure
                }
            }

            if ([string]::IsNullOrEmpty($depFile)) {
                throw "Failed to download and prepare dependency: $depName"
            }
            
            Write-Host " -> Successfully downloaded dependency: $(Split-Path $depFile -Leaf)" -ForegroundColor Green
            $dependenciesToInstall.Add($depFile)
        }
    }
    catch {
        Write-Error "An error occurred during dependency resolution: $($_.Exception.Message)"
        return $false
    }
    finally {
        # Clean up temporary extraction folders.
        Remove-Item -Path $tempExtractionDir -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $msixExtractionDir) {
            Remove-Item -Path $msixExtractionDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # 3. Install WinGet with all required dependencies
    #-----------------------------------------
    Write-Host "Starting WinGet installation..."
    try {
        $installParams = @{
            Path                           = $tempWingetBundle
            ForceTargetApplicationShutdown = $true # Closes related apps if necessary.
            ErrorAction                    = 'Stop'
        }
        # Add the -DependencyPath parameter only if we have dependencies to install.
        if ($dependenciesToInstall.Count -gt 0) {
            $installParams.Add("DependencyPath", $dependenciesToInstall)
        }
        
        Add-AppxPackage @installParams
        
        Write-Host "WinGet installation command executed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "WinGet installation failed. Error: $($_.Exception.Message)"
        return $false
    }
    finally {
        # Clean up all downloaded package files.
        Remove-Item -Path $tempWingetBundle -Force -ErrorAction SilentlyContinue
        foreach ($dep in $dependenciesToInstall) {
            Remove-Item -Path $dep -Force -ErrorAction SilentlyContinue
        }
    }

    return $true
}

#------------------------------------------------------------------------------------
# --- SCRIPT EXECUTION ---
#------------------------------------------------------------------------------------

# Clear the screen for better readability of the output.
Clear-Host

Write-Host "========================================"
Write-Host "  Automated WinGet Installer"
Write-Host "  Author: Alex Ivantsov"
Write-Host "========================================"
Write-Host

# Step 1: Gather system information.
$systemInfo = Get-SystemInfo

# Step 2: Check prerequisites. If they fail, the script stops.
if (-not (Test-Prerequisites -SystemInfo $systemInfo)) {
    Exit 1
}

# Step 3: Get a list of all installed AppX packages. This may trigger a UAC prompt.
$allUserPackages = Get-AllUserAppxPackages -SystemInfo $systemInfo
if ($allUserPackages.Count -eq 0) {
    Write-Error "Could not retrieve the list of installed AppX packages. Cannot continue."
    Exit 1
}

# Step 4: Check the current state of the WinGet installation.
$wingetStatus = Test-WinGetInstallation -AllUserPackages $allUserPackages

# Step 5: Decide whether to proceed with installation.
$needsInstall = $false
if ($wingetStatus -eq 'NotFound' -or $wingetStatus -eq 'Retired') {
    $needsInstall = $true
}
elseif ($Global:ForceUpdate) {
    Write-Host "ForceUpdate is set to true. Proceeding with reinstallation."
    $needsInstall = $true
}
else {
    Write-Host "WinGet is already installed and up to date. No action needed."
}

# Step 6: Run the installation process if needed.
if ($needsInstall) {
    $installSuccess = Resolve-And-Install-WinGet -SystemInfo $systemInfo -AllUserPackages $allUserPackages
    
    # Final verification
    if ($installSuccess) {
        Write-Host "Verifying installation..."
        Start-Sleep -Seconds 3 # Give Windows a moment to finalize the installation.
        if ((Test-WinGetInstallation -AllUserPackages (Get-AllUserAppxPackages -SystemInfo $systemInfo)) -eq 'OK') {
            Write-Host "`nSCRIPT COMPLETE: WinGet has been successfully installed." -ForegroundColor Green
        }
        else {
            Write-Error "`nSCRIPT FAILED: Installation command was sent, but WinGet is still not functional."
        }
    }
    else {
        Write-Error "`nSCRIPT FAILED: The installation process encountered an unrecoverable error."
    }
}

Write-Host "`n========================================"