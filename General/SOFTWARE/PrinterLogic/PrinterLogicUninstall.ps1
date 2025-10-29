[CmdletBinding()]
param (
    $name, $code
)
# ----- FUNCTION DEFINITIONS
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
# ----- END FUNCTION DEFINITIONS


# ----- MAIN SCRIPT STARTS HERE

# Make sure we are elevated
if (!(Test-IsAdmin)) {
    $params = @(
        "-NoLogo"
        "-NoProfile"
        "-ExecutionPolicy RemoteSigned"
        "-File `"$PSCommandPath`""
    )

    Start-Process "$($(Get-Process -id $pid | Get-Item).FullName)" -Verb RunAs -ArgumentList $params
    exit
}

$regKeys = @(
    "HKLM:\SOFTWARE\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}"
    "HKLM:\SOFTWARE\Classes\Installer\Products\8580ED9ADDD9B1E40B142CAA09CDFB47"
    "HKLM:\SOFTWARE\Classes\PPPiPrinterfile"
    "HKLM:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin"
    "HKLM:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin.1"
    "HKLM:\SOFTWARE\Classes\printerlogicidp"
    "HKLM:\SOFTWARE\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}"
    "HKLM:\SOFTWARE\Classes\WOW6432Node\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}"
    "HKLM:\SOFTWARE\Classes\WOW6432Node\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}"
    "HKLM:\SOFTWARE\WOW6432Node\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKLM:\SOFTWARE\WOW6432Node\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKLM:\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKLM:\SOFTWARE\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKLM:\SOFTWARE\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKLM:\SOFTWARE\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKLM:\SOFTWARE\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin_x86_64"
    "HKLM:\SOFTWARE\WOW6432Node\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}"
    "HKLM:\SOFTWARE\WOW6432Node\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}"
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A9DE0858-9DDD-4E1B-B041-C2AA90DCBF74}"
    "HKLM:\SOFTWARE\WOW6432Node\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKLM:\SOFTWARE\WOW6432Node\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin"
    "HKLM:\SOFTWARE\WOW6432Node\PPP"
    "HKLM:\SYSTEM\CurrentControlSet\Services\PrinterInstallerLauncher"
    "HKLM:\SOFTWARE\PrinterLogic"
    "HKLM:\SOFTWARE\PPP"
    "HKCU:\SOFTWARE\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}"
    "HKCU:\SOFTWARE\Classes\Installer\Products\8580ED9ADDD9B1E40B142CAA09CDFB47"
    "HKCU:\SOFTWARE\Classes\PPPiPrinterfile"
    "HKCU:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin"
    "HKCU:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin.1"
    "HKCU:\SOFTWARE\Classes\printerlogicidp"
    "HKCU:\SOFTWARE\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}"
    "HKCU:\SOFTWARE\Classes\WOW6432Node\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}"
    "HKCU:\SOFTWARE\Classes\WOW6432Node\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}"
    "HKCU:\SOFTWARE\WOW6432Node\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKCU:\SOFTWARE\WOW6432Node\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKCU:\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKCU:\SOFTWARE\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKCU:\SOFTWARE\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKCU:\SOFTWARE\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKCU:\SOFTWARE\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin_x86_64"
    "HKCU:\SOFTWARE\WOW6432Node\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}"
    "HKCU:\SOFTWARE\WOW6432Node\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}"
    "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A9DE0858-9DDD-4E1B-B041-C2AA90DCBF74}"
    "HKCU:\SOFTWARE\WOW6432Node\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client"
    "HKCU:\SOFTWARE\WOW6432Node\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin"
    "HKCU:\SOFTWARE\WOW6432Node\PPP"
    "HKCU:\SYSTEM\CurrentControlSet\Services\PrinterInstallerLauncher"
    "HKCU:\SOFTWARE\PrinterLogic"
    "HKCU:\SOFTWARE\PPP"
)

$processPrefixes = @(
    "PrinterInstaller"
    "PrinterLogic"
)

Write-Output "Stopping PrinterLogic processes..."
foreach ($processPrefix in $processPrefixes) {
    Get-Process "${processPrefix}*" | Stop-Process -Force
}

Write-Output "Removing PrinterLogic services..."
$launcherService = Get-WmiObject -Class Win32_Service -Filter "Name='PrinterInstallerLauncher'"
if ($null -ne $launcherService) {
    $launcherService.delete()
}

Write-Output "Deleting PrinterLogic installation from disk..."
if (Test-Path "C:\Program Files (x86)\Printer Properties Pro") {
    Remove-Item "C:\Program Files (x86)\Printer Properties Pro" -Recurse -Force
}

Write-Output "Cleaning registry keys..."
foreach ($key in $regKeys) {
    Write-Output "Removing $key..."
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force
    }
}
