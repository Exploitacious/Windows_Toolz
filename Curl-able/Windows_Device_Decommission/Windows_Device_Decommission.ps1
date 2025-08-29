# This actually doesn't do anything except install our Datto RMM Agent for the Device Decommission Site
# Once the device is in the site, it will process the decommissioning tasks.

# The direct download URL for the new Datto RMM agent installer.
$InstallerUrl = "https://concord.rmm.datto.com/download-agent/windows/5a1e8979-8afc-47ac-9a6b-81ba15765b29"

# The location to temporarily store the downloaded installer.
$InstallerTempPath = "$env:TEMP\AgentInstall.exe"

#--------------------------------------------------------------------------------
# --- SCRIPT INITIALIZATION AND CHECKS ---
#--------------------------------------------------------------------------------

# Function to check if the script is running with elevated (Administrator) privileges.
function Test-IsAdmin {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Warning "Failed to determine administrator status. Assuming non-admin."
        return $false
    }
}

# Exit the script if not running as an Administrator.
if (-not (Test-IsAdmin)) {
    Write-Error "This script must be run with Administrator privileges. Please right-click and 'Run as Administrator'."
    # Pause to allow the user to read the error before the window closes.
    if ($Host.Name -eq 'ConsoleHost') {
        Read-Host -Prompt "Press Enter to exit"
    }
    exit 1
}

#--------------------------------------------------------------------------------
# --- REMOVAL FUNCTION ---
#--------------------------------------------------------------------------------

# This function handles the complete and forceful removal of Datto RMM / CentraStage.
function Remove-DattoRMM {

    Write-Host "--- Starting Datto RMM Removal Process ---" -ForegroundColor Yellow

    # Define common names and paths associated with Datto RMM / CentraStage installations.
    $serviceNames = @("CagService", "RMM Agent Service", "Datto RMM Agent Service", "Uvnc_service")
    $processNames = @("CagService", "AEMAgent", "DattoRMMService")
    $filePaths = @(
        "$env:ProgramFiles\CentraStage",
        "$env:ProgramFiles(x86)\CentraStage",
        "$env:ProgramFiles\Datto RMM",
        "$env:ProgramFiles(x86)\Datto RMM"
    )
    $registryPaths = @(
        "HKLM:\SOFTWARE\CentraStage",
        "HKLM:\SOFTWARE\Datto RMM",
        "HKLM:\SOFTWARE\WOW6432Node\CentraStage",
        "HKLM:\SOFTWARE\WOW6432Node\Datto RMM"
    )

    # Step 1: Stop all related services.
    Write-Host "Step 1: Stopping Datto RMM services..." -ForegroundColor Cyan
    foreach ($service in $serviceNames) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc) {
            try {
                Write-Host "  -> Stopping service: $($svc.DisplayName)"
                Stop-Service -Name $svc.Name -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not stop service: $($svc.Name). It might already be stopped."
            }
        }
    }

    # Step 2: Terminate all related processes.
    Write-Host "Step 2: Terminating Datto RMM processes..." -ForegroundColor Cyan
    foreach ($process in $processNames) {
        $proc = Get-Process -Name $process -ErrorAction SilentlyContinue
        if ($proc) {
            try {
                Write-Host "  -> Terminating process: $($proc.Name)"
                Stop-Process -Name $proc.Name -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not terminate process: $($proc.Name)."
            }
        }
    }

    # Step 3: Run the official uninstaller silently.
    # We search the registry for the uninstall command, which is more reliable than using Win32_Product.
    Write-Host "Step 3: Attempting silent uninstallation..." -ForegroundColor Cyan
    $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $uninstallKey6432 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    $app = Get-ChildItem -Path $uninstallKey, $uninstallKey6432 | Get-ItemProperty | Where-Object {
        $_.DisplayName -like "Datto RMM Agent" -or $_.DisplayName -like "CentraStage*"
    } | Select-Object -First 1

    if ($app) {
        $uninstallString = $app.UninstallString
        if ($uninstallString) {
            Write-Host "  -> Found uninstaller: $uninstallString"
            # Modify the command for a silent execution.
            $uninstallArgs = ($uninstallString -split ' ')[1..($uninstallString.Split(' ').Length - 1)] -join ' '
            $uninstallArgs = $uninstallArgs.Replace("/I", "/X ") + " /qn"
            
            try {
                $process = Start-Process "msiexec.exe" -ArgumentList $uninstallArgs -Wait -PassThru -ErrorAction Stop
                if ($process.ExitCode -ne 0) {
                    Write-Warning "Uninstaller exited with code: $($process.ExitCode). It may not have completed successfully."
                }
                else {
                    Write-Host "  -> Uninstaller completed successfully." -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "Failed to run the uninstaller command automatically."
            }
        }
    }
    else {
        Write-Host "  -> No official uninstaller found in the registry. Proceeding with manual cleanup."
    }

    # Step 4: Delete leftover registry keys.
    Write-Host "Step 4: Cleaning up registry keys..." -ForegroundColor Cyan
    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            try {
                Write-Host "  -> Removing registry key: $regPath"
                Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to remove registry key: $regPath"
            }
        }
    }

    # Step 5: Delete leftover directories.
    Write-Host "Step 5: Cleaning up file system..." -ForegroundColor Cyan
    foreach ($filePath in $filePaths) {
        if (Test-Path $filePath) {
            try {
                Write-Host "  -> Removing directory: $filePath"
                Remove-Item -Path $filePath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to remove directory: $filePath. A reboot may be required."
            }
        }
    }

    Write-Host "--- Datto RMM Removal Process Complete ---" -ForegroundColor Green
    Write-Host "" # Add a blank line for readability
}

#--------------------------------------------------------------------------------
# --- INSTALLATION FUNCTION ---
#--------------------------------------------------------------------------------

# This function handles the download and installation of the new Datto RMM agent.
function Install-DattoRMM {
    Write-Host "--- Starting Datto RMM Installation Process ---" -ForegroundColor Yellow

    # Step 1: Download the new agent installer.
    Write-Host "Step 1: Downloading new agent from $InstallerUrl..." -ForegroundColor Cyan
    try {
        # Create a new WebClient object to handle the download.
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($InstallerUrl, $InstallerTempPath)
        Write-Host "  -> Download complete." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download the agent installer. Please check the URL and your internet connection."
        exit 1
    }

    # Step 2: Run the installer.
    Write-Host "Step 2: Starting the installer..." -ForegroundColor Cyan
    try {
        # The agent provided typically handles silent installation by default.
        Start-Process -FilePath $InstallerTempPath -Wait -ErrorAction Stop
        Write-Host "  -> Installation process has finished." -ForegroundColor Green
        Write-Host
        Write-Host "Datto RMM has been installed with the DECOMISSION SITE set." -ForegroundColor Magenta
        Write-Host "This will automatically trigger the device decommissioning process." -ForegroundColor Magenta
    }
    catch {
        Write-Error "Failed to start the installer process."
        exit 1
    }

    # Step 3: Clean up the downloaded installer file.
    Write-Host "Step 3: Cleaning up temporary installer file..." -ForegroundColor Cyan
    if (Test-Path $InstallerTempPath) {
        Remove-Item -Path $InstallerTempPath -Force
        Write-Host "  -> Temporary file removed."
    }
    
    Write-Host "--- Datto RMM Installation Process Complete ---" -ForegroundColor Green
    Write-Host "" # Add a blank line for readability
}


#--------------------------------------------------------------------------------
# --- MAIN SCRIPT EXECUTION ---
#--------------------------------------------------------------------------------

# Call the functions in the correct order.
Remove-DattoRMM
Install-DattoRMM

Write-Host "Script has finished. Please review for any errors." -ForegroundColor
if ($Host.Name -eq 'ConsoleHost') {
    Read-Host -Prompt "Press Enter to exit"
}
