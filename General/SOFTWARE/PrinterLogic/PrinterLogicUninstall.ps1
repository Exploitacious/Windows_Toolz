# Script Title: PrinterLogic Uninstaller
# Description: A comprehensive script to forcefully remove all traces of PrinterLogic, including processes, services, files, and registry keys.

# Script Name and Type
$ScriptName = "PrinterLogic Uninstaller"
$ScriptType = "Remediation"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "System state is nominal. | Last Checked $Date"

# Log/Diagnostic Messaging
function write-RMMDiag ($messages) {
    Write-Host "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
$Global:DiagMsg = @()

# Alert Messaging
function write-RMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
$Global:AlertMsg = @()

# RMM Custom Field.
$Global:customFieldMessage = @()

# Script UID and intro messaging
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
$ScriptUID = GenRANDString 20
$Global:DiagMsg += "Script Type: $ScriptType"
$Global:DiagMsg += "Script Name: $ScriptName"
$Global:DiagMsg += "Script UID: $ScriptUID"
$Global:DiagMsg += "Executed On: $Date"

##################################
##################################
######## Start of Script #########

try {
    # List of registry keys to remove
    $regKeys = @(
        "HKLM:\SOFTWARE\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKLM:\SOFTWARE\Classes\Installer\Products\8580ED9ADDD9B1E40B142CAA09CDFB47",
        "HKLM:\SOFTWARE\Classes\PPPiPrinterfile",
        "HKLM:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin",
        "HKLM:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin.1",
        "HKLM:\SOFTWARE\Classes\printerlogicidp",
        "HKLM:\SOFTWARE\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKLM:\SOFTWARE\Classes\WOW6432Node\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKLM:\SOFTWARE\Classes\WOW6432Node\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKLM:\SOFTWARE\WOW6432Node\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\WOW6432Node\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin_x86_64",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A9DE0858-9DDD-4E1B-B041-C2AA90DCBF74}",
        "HKLM:\SOFTWARE\WOW6432Node\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\WOW6432Node\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin",
        "HKLM:\SOFTWARE\WOW6432Node\PPP",
        "HKLM:\SYSTEM\CurrentControlSet\Services\PrinterInstallerLauncher",
        "HKLM:\SOFTWARE\PrinterLogic",
        "HKLM:\SOFTWARE\PPP",
        "HKCU:\SOFTWARE\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKCU:\SOFTWARE\Classes\Installer\Products\8580ED9ADDD9B1E40B142CAA09CDFB47",
        "HKCU:\SOFTWARE\Classes\PPPiPrinterfile",
        "HKCU:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin",
        "HKCU:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin.1",
        "HKCU:\SOFTWARE\Classes\printerlogicidp",
        "HKCU:\SOFTWARE\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKCU:\SOFTWARE\Classes\WOW6432Node\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKCU:\SOFTWARE\Classes\WOW6432Node\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKCU:\SOFTWARE\WOW6432Node\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\WOW6432Node\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin_x86_64",
        "HKCU:\SOFTWARE\WOW6432Node\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKCU:\SOFTWARE\WOW6432Node\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A9DE0858-9DDD-4E1B-B041-C2AA90DCBF74}",
        "HKCU:\SOFTWARE\WOW6432Node\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\WOW6432Node\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin",
        "HKCU:\SOFTWARE\WOW6432Node\PPP",
        "HKCU:\SYSTEM\CurrentControlSet\Services\PrinterInstallerLauncher",
        "HKCU:\SOFTWARE\PrinterLogic",
        "HKCU:\SOFTWARE\PPP"
    )

    # List of process prefixes to terminate
    $processPrefixes = @(
        "PrinterInstaller",
        "PrinterLogic"
    )
    
    # Known installation directory
    $InstallDir = "C:\Program Files (x86)\Printer Properties Pro"

    # --- Begin Remediation ---

    $Global:DiagMsg += "Stopping PrinterLogic processes..."
    foreach ($processPrefix in $processPrefixes) {
        $Global:DiagMsg += "Checking for processes starting with '$processPrefix'..."
        $processes = Get-Process "${processPrefix}*" -ErrorAction SilentlyContinue
        if ($processes) {
            $processes | Stop-Process -Force
            $Global:DiagMsg += "Stopped processes: $($processes.Name -join ', ')"
        }
        else {
            $Global:DiagMsg += "No running processes found for '$processPrefix'."
        }
    }

    $Global:DiagMsg += "Removing PrinterLogic services..."
    $launcherService = Get-WmiObject -Class Win32_Service -Filter "Name='PrinterInstallerLauncher'" -ErrorAction SilentlyContinue
    if ($null -ne $launcherService) {
        $Global:DiagMsg += "Found 'PrinterInstallerLauncher' service. Attempting to delete."
        $launcherService.delete()
        $Global:DiagMsg += "Service deleted."
    }
    else {
        $Global:DiagMsg += "Service 'PrinterInstallerLauncher' not found."
    }

    $Global:DiagMsg += "Deleting PrinterLogic installation from disk..."
    if (Test-Path $InstallDir) {
        $Global:DiagMsg += "Found installation directory: '$InstallDir'. Removing..."
        Remove-Item $InstallDir -Recurse -Force
        $Global:DiagMsg += "Directory removed."
    }
    else {
        $Global:DiagMsg += "Installation directory '$InstallDir' not found."
    }

    $Global:DiagMsg += "Cleaning registry keys..."
    $regKeysRemoved = 0
    foreach ($key in $regKeys) {
        if (Test-Path $key) {
            $Global:DiagMsg += "Removing registry key: $key"
            try {
                Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
                $regKeysRemoved++
            }
            catch {
                $Global:DiagMsg += "Failed to remove key $key : $($_.Exception.Message)"
            }
        }
    }
    $Global:DiagMsg += "Registry cleanup complete. Removed $regKeysRemoved keys."
    
    # --- Set Final Status ---
    # As a remediation script, success is assumed if the script runs to completion.
    # The 'catch' block will handle any script-terminating errors.
    $Global:customFieldMessage = "PrinterLogic remediation complete. ($Date)"

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
    $Global:customFieldMessage = "Script failed with an error. ($Date)"
}


######## End of Script ###########
##################################
##################################

# Write the collected information to the specified Custom Field before exiting.
if ($env:customFieldName) {
    $Global:DiagMsg += "Attempting to write '$($Global:customFieldMessage)' to Custom Field '$($env:customFieldName)'."
    try {
        Ninja-Property-Set -Name $env:customFieldName -Value $Global:customFieldMessage
        $Global:DiagMsg += "Successfully updated Custom Field."
    }
    catch {
        $Global:DiagMsg += "Error writing to Custom Field '$($env:customFieldName)': $($_.Exception.Message)"
    }
}
else {
    $Global:DiagMsg += "Custom Field name not provided in RMM variable 'customFieldName'. Skipping update."
}

if ($Global:AlertMsg) {
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-RMMAlert $Global:AlertMsg
    write-RMMDiag $Global:DiagMsg
    Exit 1
}
else {
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"
    write-RMMAlert $Global:AlertHealthy
    write-RMMDiag $Global:DiagMsg
    Exit 0
}