# This script adds a "Run with PowerShell Core" option to the right-click context menu for PowerShell (.ps1) files.
# When selected, it will execute the .ps1 script using PowerShell 7 Preview.

# --- Configuration ---
$pwshPath = "c:\Program Files\PowerShell\7-preview\pwsh.exe" # Specify the path to the PowerShell 7 Preview executable.

# --- Registry Drive Setup ---
# Check if a PowerShell drive for HKEY_CLASSES_ROOT (HKCR) already exists.
# If not, create it to simplify registry path navigation.
if (-not (Get-PSDrive -PSProvider Registry | Where-Object Root -EQ "HKEY_CLASSES_ROOT")) {
    New-PSDrive -PSProvider Registry -Root "HKEY_CLASSES_ROOT" -Name "HKCR" | Out-Null
}

# --- Context Menu Entry Creation ---
# Create the main key for our new context menu option under the PowerShell script's ProgID.
# The '1' key is a common convention for custom context menu entries.
New-Item -Path "HKCR:\Microsoft.PowerShellScript.1\Shell" -Name "1" | Out-Null

# Set the text that will appear in the right-click context menu.
# The '&' before 'Core' creates an underlined access key for keyboard navigation.
New-ItemProperty -Path "HKCR:\Microsoft.PowerShellScript.1\Shell\1" `
    -PropertyType String `
    -Name "MUIVerb" `
    -Value "Run with PowerShell &Core" | Out-Null

# Set the icon for the context menu entry to match the PowerShell 7 Preview executable.
New-ItemProperty -Path "HKCR:\Microsoft.PowerShellScript.1\Shell\1" `
    -PropertyType String `
    -Name "Icon" `
    -Value $pwshPath | Out-Null

# --- Command Definition ---
# Create the 'Command' key, which tells Windows what command to execute.
New-Item -Path "HKCR:\Microsoft.PowerShellScript.1\Shell\1" -Name "Command" | Out-Null

# Set the default value of the 'Command' key. This is the command that gets executed.
# It uses string formatting to insert the PowerShell executable path and the script path (%1).
# The command ensures the execution policy is temporarily bypassed for the process
# if it's not already 'AllSigned', allowing the script to run without restrictions.
Set-ItemProperty -Path "HKCR:\Microsoft.PowerShellScript.1\Shell\1\Command" `
    -Name "(Default)" `
    -Value ('"{0}" "-Command" "if((Get-ExecutionPolicy ) -ne ''AllSigned'') {{ Set-ExecutionPolicy -Scope Process Bypass }}; & ''%1''"' -f $pwshPath) | Out-Null

Write-Host "Successfully added 'Run with PowerShell Core' to the context menu for .ps1 files."