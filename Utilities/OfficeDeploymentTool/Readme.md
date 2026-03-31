# Dynamic Microsoft 365 Installer

This PowerShell script automates the installation of Microsoft 365 Apps by dynamically building a configuration file based on simple variables you set.

---

## How to Use

1.  **Configure Script**: Open the `.ps1` file in an editor. Modify the variables in the `--- User Configuration ---` section to define your installation.
2.  **Run as Administrator**: Right-click the script and select **Run with PowerShell**.

The script will automatically download the necessary tools to `C:\Temp\Office` and begin the installation based on your choices.

---

## Configuration Examples

All settings are controlled at the top of the script.

### Selecting Apps

Set apps to `$true` to install them or `$false` to exclude them.

```powershell
$InstallWord = $true
$InstallExcel = $true
$InstallOutlook = $false
$InstallTeams = $true
$InstallProject = false