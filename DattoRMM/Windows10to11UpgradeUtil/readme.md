# Windows 10 to 11 In-Place Upgrade

This script automates the in-place upgrade from Windows 10 to Windows 11. It performs system prerequisite checks, removes common upgrade blockers, and then silently runs the official Microsoft Installation Assistant.

## How to Use

1.  (Optional) Edit the script to adjust the hardware requirements in the `User-Modifiable Variables` section.
2.  Run the PowerShell script as an Administrator.
3.  The script will perform all checks and launch the upgrade in the background before exiting. The Windows 11 installer will continue running until the upgrade is complete.

## Configuration Examples

You can modify the following variables to change the script's behavior, such as the minimum hardware requirements it checks for.

```powershell
# The URL for the official Microsoft Windows 11 Installation Assistant.
$Win11DownloadUrl = "[https://go.microsoft.com/fwlink/?linkid=2171764](https://go.microsoft.com/fwlink/?linkid=2171764)"

# A robust temporary location for the installer. The script will create C:\Temp if it doesn't exist.
$InstallerTempDir = "C:\Temp\Windows11Upgrade"

# Minimum system requirements for the prerequisite checks.
$MinimumRamGB = 4
$MinimumStorageGB = 64
$MinimumCpuCores = 2
$MinimumCpuSpeedGHz = 1.0