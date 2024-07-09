Write-Host
Write-Host " -= PowerShell Module Terminator =- " -ForegroundColor DarkGreen
Write-Host


# Verify/Elevate Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit 
}

# Function to check for running processes using the module
function Stop-ModuleProcesses {
    param (
        [string]$moduleName
    )

    try {
        $processes = Get-Process | Where-Object { $_.Modules.ModuleName -like "*$moduleName*" } 2>$null
        if ($processes) {
            Write-Host "Stopping processes using the module..."
            $processes | ForEach-Object {
                try {
                    Stop-Process -Id $_.Id -Force -ErrorAction Stop
                    Write-Host "Stopped process $($_.Name) (ID: $($_.Id))"
                }
                catch {
                    Write-Host "Failed to stop process $($_.Name) (ID: $($_.Id)): $_"
                }
            }
        }
        else {
            Write-Host "No processes are using the module."
        }
    }
    catch {
        Write-Host "Error checking processes: $_"
    }
}

# Function to remove the module
function Remove-ModuleFiles {
    param (
        [string]$moduleName
    )

    try {
        $modulePath = Get-Module -ListAvailable -Name $moduleName | Select-Object -ExpandProperty Path
        if ($modulePath) {
            try {
                Write-Host "Removing module files..."
                Remove-Item -Recurse -Force $modulePath
                Write-Host "Module files removed successfully."
            }
            catch {
                Write-Host "Failed to remove module files: $_"
            }
        }
        else {
            Write-Host "Module not found in module path."
        }
    }
    catch {
        Write-Host "Error locating module path: $_"
    }
}

# Function to ensure permissions
function EnsurePermissions {
    param (
        [string]$modulePath
    )

    try {
        if (Test-Path $modulePath) {
            Write-Host "Ensuring permissions for the module path..."
            Takeown /F $modulePath /R /D Y
            icacls $modulePath /grant administrators:F /T
            Write-Host "Permissions ensured."
        }
        else {
            Write-Host "Module path not found."
        }
    }
    catch {
        Write-Host "Failed to ensure permissions: $_"
    }
}

# Function to restart PowerShell and Windows Terminal processes
function Restart-TerminalProcesses {
    try {
        $processNames = @("powershell", "pwsh", "WindowsTerminal")

        foreach ($processName in $processNames) {
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($processes) {
                Write-Host "Restarting $processName processes..."
                $processes | ForEach-Object {
                    try {
                        Stop-Process -Id $_.Id -Force -ErrorAction Stop
                        Write-Host "Stopped $processName process (ID: $($_.Id))"
                    }
                    catch {
                        Write-Host "Failed to stop $processName process (ID: $($_.Id)): $_"
                    }
                }
            }
            else {
                Write-Host "No $processName processes found."
            }
        }

        # Restart PowerShell and Windows Terminal if they were running
        Start-Process -FilePath "powershell" -NoNewWindow
        Start-Process -FilePath "wt" -NoNewWindow
    }
    catch {
        Write-Host "Failed to restart terminal processes: $_"
    }
}

#######################
# Main script execution
#######################

$moduleName = Read-Host "Enter the name of the module"
$moduleVersion = Read-Host "Enter the version of the module (leave blank for all versions)"

if ($moduleVersion) {
    $fullModuleName = "$moduleName -RequiredVersion $moduleVersion"
}
else {
    $fullModuleName = $moduleName
}

Write-Host "Starting module removal process for $fullModuleName..." -ForegroundColor Green
Stop-ModuleProcesses -moduleName $moduleName
Remove-Module -Name $moduleName -Verbose -Force -ErrorAction SilentlyContinue
$modulePath = "C:\Program Files\WindowsPowerShell\Modules\$moduleName"
EnsurePermissions -modulePath $modulePath
Remove-ModuleFiles -moduleName $moduleName
Write-Host
Write-Host "Module removal process completed for $fullModuleName." -ForegroundColor DarkGreen
Write-Host
Write-Host "Restarting Terminal in 5 seconds..."

Start-Sleep 5

# Restart terminal processes
Restart-TerminalProcesses