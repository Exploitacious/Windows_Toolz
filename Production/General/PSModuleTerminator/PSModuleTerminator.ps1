Write-Host
Write-Host " -= PowerShell Module Terminator =- " -ForegroundColor DarkMagenta
Write-Host


# Verify/Elevate Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit 
}

# Function to restore PowerShell to stock by removing all non-default modules
function Restore-DefaultModules {
    Write-Host "Restoring PowerShell to stock settings by removing all non-default modules..."
    
    $defaultModules = @(
        "AppBackgroundTask",
        "Appx",
        "AssignedAccess",
        "BitLocker",
        "BitsTransfer",
        "BranchCache",
        "CimCmdlets",
        "ClusterAwareUpdating",
        "Defender",
        "DeliveryOptimization",
        "DirectAccessClientComponents",
        "Dism",
        "DnsClient",
        "EventTracingManagement",
        "HgsClient",
        "HostComputeService",
        "Hyper-V",
        "International",
        "ISE",
        "Kds",
        "Microsoft.PowerShell.Diagnostics",
        "Microsoft.PowerShell.Host",
        "Microsoft.PowerShell.Management",
        "Microsoft.PowerShell.Security",
        "Microsoft.PowerShell.Utility",
        "Microsoft.WSMan.Management",
        "MMAgent",
        "MsDtc",
        "NetAdapter",
        "NetConnection",
        "NetEventPacketCapture",
        "NetLbfo",
        "NetNat",
        "NetQos",
        "NetSecurity",
        "NetSwitchTeam",
        "NetTCPIP",
        "NetWNV",
        "NetworkConnectivityStatus",
        "NetworkSwitchManager",
        "NetworkSwitchSubsystem",
        "PcsvDevice",
        "Pester",
        "PKI",
        "PnpDevice",
        "PrintManagement",
        "ProcessMitigations",
        "Provisioning",
        "PSDesiredStateConfiguration",
        "PSDiagnostics",
        "PSScheduledJob",
        "PSWorkflow",
        "PSWorkflowUtility",
        "ScheduledTasks",
        "SecureBoot",
        "SmbShare",
        "SmbWitness",
        "StartLayout",
        "Storage",
        "TLS",
        "TroubleshootingPack",
        "TrustedPlatformModule",
        "VpnClient",
        "Wdac",
        "WindowsDeveloperLicense",
        "WindowsErrorReporting",
        "WindowsSearch",
        "WindowsUpdate",
        "WindowsUpdateProvider"
    )

    $installedModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name | Sort-Object -Unique

    $modulesToRemove = $installedModules | Where-Object { $defaultModules -notcontains $_ }

    foreach ($module in $modulesToRemove) {
        Write-Host "Removing module: $module"
        Stop-ModuleProcesses -moduleName $module
        Remove-Module -Name $module -Force -ErrorAction SilentlyContinue
        $modulePath = "C:\Program Files\WindowsPowerShell\Modules\$module"
        EnsurePermissions -modulePath $modulePath
        Remove-ModuleFiles -moduleName $module
    }

    Write-Host "PowerShell has been restored to stock settings."
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

while ($true) {
    $input = Read-Host "Enter the name of the module to begin removal ; 'RESTORE' to reset PowerShell to stock settings ; or 'q' to quit and reset terminal"

    if ($input -eq "q") {
        Write-Host "Exiting script."
        break
    }

    if ($input -eq "RESTORE") {
        Restore-DefaultModules
        Write-Host "Restoration complete."
    }
    else {
        $moduleName = $input

        $availableVersions = Get-Module -ListAvailable -Name $moduleName | Select-Object -ExpandProperty Version

        if ($availableVersions.Count -eq 0) {
            Write-Host "No versions of the module '$moduleName' found."
        }
        else {
            Write-Host "Available versions of the module '$moduleName':"
            $availableVersions | ForEach-Object { Write-Host $_ }

            $versionInput = Read-Host "Enter the version to uninstall (or type 'ALL' to uninstall all versions)"

            if ($versionInput -eq "ALL") {
                foreach ($version in $availableVersions) {
                    Write-Host "Starting module removal process for $moduleName version $version..."
                    Stop-ModuleProcesses -moduleName $moduleName
                    Remove-Module -Name $moduleName -RequiredVersion $version -Force -ErrorAction SilentlyContinue
                    $modulePath = "C:\Program Files\WindowsPowerShell\Modules\$moduleName\$version"
                    EnsurePermissions -modulePath $modulePath
                    Remove-ModuleFiles -moduleName $moduleName
                    Write-Host "Module removal process completed for $moduleName version $version."
                }
            }
            else {
                Write-Host "Starting module removal process for $moduleName version $versionInput..."
                Stop-ModuleProcesses -moduleName $moduleName
                Remove-Module -Name $moduleName -RequiredVersion $versionInput -Force -ErrorAction SilentlyContinue
                $modulePath = "C:\Program Files\WindowsPowerShell\Modules\$moduleName\$versionInput"
                EnsurePermissions -modulePath $modulePath
                Remove-ModuleFiles -moduleName $moduleName
                Write-Host "Module removal process completed for $moduleName version $versionInput." -ForegroundColor DarkGreen
            }
        }
    }
}

Write-Host
Write-Host "Restarting Terminal in 5 seconds..."

Start-Sleep 5

# Restart terminal processes
Restart-TerminalProcesses