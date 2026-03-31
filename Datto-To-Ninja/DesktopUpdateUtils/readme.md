# Datto RMM - Manufacturer Update Utility Monitor & Installer

This component includes a monitoring script to check for manufacturer-specific update utilities (Dell, HP, Lenovo, Microsoft) and a remediation script to automatically install them if they are missing.

## How to Use

1.  **Deploy the Monitor:** In your Datto RMM policy, add the `Manufacturer Update Utility Monitor` script as a monitoring component. It will automatically check if the correct utility is installed.
2.  **Set Up Remediation:** Configure the monitor so that if it fails (i.e., the utility is missing), it automatically runs the `Install Manufacturer Update Utility` remediation script.
3.  **No Configuration Needed:** The scripts are pre-configured to work for Dell, HP, Lenovo, and Microsoft devices. No editing of the scripts is required for them to function.

## Configuration Examples

While not required, you can change the script name and the "Healthy" status message that appears in Datto RMM by editing the variables at the top of the **monitoring script**.

```powershell
# Script Name and Type
$ScriptName = "Manufacturer Update Utility Monitor"

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Healthy: Update Utility Installed"