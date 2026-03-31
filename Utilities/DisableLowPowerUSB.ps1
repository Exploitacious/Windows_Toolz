<#
.SYNOPSIS
    Disables power saving ("Allow the computer to turn off this device...") for
    key device classes to prevent connectivity issues.

.DESCRIPTION
    This script iterates through all Network Adapters and USB Controllers found by the system.
    For each device, it modifies a specific registry property (PnPCapabilities) that
    governs whether the operating system is allowed to power down the device to save energy.
    This can resolve issues where devices fail to wake up properly, causing disconnects.

.NOTES
    Version: 1.0
    Author: Gemini
    Requires: PowerShell 5.1 running as an Administrator. A restart is required after execution.
#>

#==============================================================================
# SCRIPT BODY
#==============================================================================

# Step 1: Verify the script is running with Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires Administrator privileges. Please re-launch PowerShell as an Administrator."
    # Pause to allow the user to read the message before the window closes.
    if ($Host.Name -eq "ConsoleHost") {
        Write-Host "Press any key to continue..."
        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") | Out-Null
    }
    return
}

Write-Host "Running with Administrator privileges. Starting process..." -ForegroundColor Green

# Define a reusable function to disable power saving for a given device class
function Disable-DevicePowerSaving {
    param(
        [string]$DeviceClass
    )

    Write-Host "`nProcessing devices in class: '$($DeviceClass)'" -ForegroundColor Cyan
    
    # Get all Plug and Play devices belonging to the specified class
    $devices = Get-PnpDevice -Class $DeviceClass -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' }

    if (-not $devices) {
        Write-Warning "No devices found for class '$DeviceClass'."
        return
    }

    $devices | ForEach-Object {
        $deviceName = $_.FriendlyName
        Write-Host "  - Checking device: $deviceName"

        # Get the path to the device's specific driver key in the registry
        $regKeyPath = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_DriverRegKey' -ErrorAction SilentlyContinue).Data
        
        if ($regKeyPath) {
            $fullRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$regKeyPath"
            
            # The 'PnPCapabilities' value controls power management features.
            # Setting it to 24 (Hex 0x18) disables "Allow the computer to turn off..."
            # We use -ErrorAction SilentlyContinue because not all devices have this value.
            Set-ItemProperty -Path $fullRegPath -Name "PnPCapabilities" -Value 24 -ErrorAction SilentlyContinue
            
            # Check if the value was set successfully to provide feedback
            $currentValue = Get-ItemProperty -Path $fullRegPath -Name "PnPCapabilities" -ErrorAction SilentlyContinue
            if ($currentValue -and $currentValue.PnPCapabilities -eq 24) {
                Write-Host "    -> Power saving has been disabled." -ForegroundColor Green
            }
            else {
                Write-Host "    -> This device does not support this power setting, or it could not be changed." -ForegroundColor Yellow
            }
        }
    }
}

# Step 2: Call the function for Network Adapters and USB Controllers
try {
    Disable-DevicePowerSaving -DeviceClass 'Net'
    Disable-DevicePowerSaving -DeviceClass 'USB'
    # 'USBDevice' can sometimes contain other relevant devices like hubs on complex docks
    Disable-DevicePowerSaving -DeviceClass 'USBDevice'

    Write-Host "`n============================================================" -ForegroundColor Green
    Write-Host "Script finished. A restart is required to apply all changes." -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
}
catch {
    Write-Error "An unexpected error occurred: $_"
}