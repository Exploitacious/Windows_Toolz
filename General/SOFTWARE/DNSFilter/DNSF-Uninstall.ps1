# Script Title: DNSFilter Agent Uninstall and Cleanup
# Description: Uninstalls the DNSFilter agent, removes leftover registry keys, and resets network adapter DNS settings if they are pointed to a loopback address.

# Script Name and Type
$ScriptName = "DNSFilter Agent Uninstall and Cleanup"
$ScriptType = "Remediation"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get'

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# appNamesToUninstall (Text): Comma-separated list of application display names to uninstall. Default: "DNSFilter Agent,DNS Agent"

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
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123-9') {
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

# --- Functions from provided script, adapted for RMM ---

function Uninstall-Applications {
    <#
    .SYNOPSIS
        Finds an application by its display name in the registry and runs its uninstaller.
    .PARAMETER AppNames
        An array of strings containing the exact display names of the applications to uninstall.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$AppNames
    )

    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $installedPrograms = Get-ItemProperty $registryPaths -ErrorAction SilentlyContinue
    $anyAppUninstalled = $false

    foreach ($appName in $AppNames) {
        $Global:DiagMsg += "Searching for application: `"$appName`""
        $app = $installedPrograms | Where-Object { $_.DisplayName -eq $appName } | Select-Object -First 1

        if ($app) {
            $uninstallString = $app.UninstallString
            if ($uninstallString) {
                if ($uninstallString -match '\{([0-9a-fA-F\-]+)\}') {
                    $productCode = $matches[1]
                    $Global:DiagMsg += "  Found MSI product code: $productCode"
                    $Global:DiagMsg += "  Executing: msiexec.exe /X `{$productCode`} /qb /norestart"
                    $process = Start-Process "msiexec.exe" -ArgumentList "/X `{$productCode`} /qb /norestart" -Wait -PassThru
                    $Global:DiagMsg += "  Uninstaller for '$appName' finished with exit code: $($process.ExitCode)."
                    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
                        # 3010 is success, reboot required
                        throw "Uninstaller for '$appName' failed with exit code $($process.ExitCode)."
                    }
                    $anyAppUninstalled = $true
                }
                else {
                    $Global:DiagMsg += "  WARNING: '$appName' has a non-standard uninstall string that cannot be automated reliably: $uninstallString"
                }
            }
            else {
                $Global:DiagMsg += "  WARNING: Found '$appName' but it has no associated uninstall string."
            }
        }
        else {
            $Global:DiagMsg += "  Application '$appName' not found."
        }
    }
    return $anyAppUninstalled
}

function Remove-LeftoverRegistryKeys {
    <#
    .SYNOPSIS
        Removes specified registry keys that might be left behind after uninstallation.
    #>
    $Global:DiagMsg += "Removing leftover registry keys..."
    $registryKeysToRemove = @(
        "HKLM:\Software\DNSFilter",
        "HKLM:\Software\DNSAgent"
    )

    foreach ($keyPath in $registryKeysToRemove) {
        if (Test-Path $keyPath) {
            $Global:DiagMsg += "  Removing registry key: $keyPath"
            Remove-Item -Path $keyPath -Recurse -Force
            if (Test-Path $keyPath) {
                throw "Failed to remove registry key '$keyPath'."
            }
            $Global:DiagMsg += "  Successfully removed $keyPath."
        }
        else {
            $Global:DiagMsg += "  Registry key not found, skipping: $keyPath"
        }
    }
}

function Correct-NetworkAdapterDnsSettings {
    <#
    .SYNOPSIS
        Checks all active network adapters for invalid loopback DNS servers and corrects them.
    #>
    $Global:DiagMsg += "Checking network adapter DNS settings for invalid entries..."
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }

    if (-not $adapters) {
        $Global:DiagMsg += "No active physical network adapters found."
        return
    }

    foreach ($adapter in $adapters) {
        $Global:DiagMsg += "  Checking adapter: '$($adapter.Name)' (Index: $($adapter.InterfaceIndex))"
        $dnsSettings = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue

        $needsCorrection = $false
        if ($dnsSettings.ServerAddresses.Count -gt 0) {
            foreach ($dnsServer in $dnsSettings.ServerAddresses) {
                if ($dnsServer.StartsWith("127.")) {
                    $Global:DiagMsg += "  Found invalid loopback DNS server: $dnsServer. Flagging for correction."
                    $needsCorrection = $true
                    break
                }
            }
        }

        if ($needsCorrection) {
            $Global:DiagMsg += "  Correcting DNS settings for '$($adapter.Name)'."
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
            $Global:DiagMsg += "  Setting DNS to 'Automatic' (via DHCP)."
            
            $Global:DiagMsg += "  Renewing DHCP lease..."
            ipconfig /renew | Out-Null
            
            $newDnsSettings = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4
            $newServers = if ($newDnsSettings.ServerAddresses) { $newDnsSettings.ServerAddresses -join ', ' } else { "None (DHCP assigned)" }
            $Global:DiagMsg += "  Verification: New DNS Servers are now set to: $newServers"
        }
        else {
            $Global:DiagMsg += "  DNS settings for '$($adapter.Name)' appear correct. No action needed."
        }
    }
}


try {
    # --- Parameter Validation and Processing ---
    if (-not $env:appNamesToUninstall) {
        $Global:DiagMsg += "RMM variable 'appNamesToUninstall' is empty. Using default: 'DNSFilter Agent,DNS Agent'"
        $env:appNamesToUninstall = "DNSFilter Agent,DNS Agent"
    }
    # Convert comma-separated string from RMM variable into a string array
    $applicationsToUninstall = $env:appNamesToUninstall.Split(',') | ForEach-Object { $_.Trim() }
    $Global:DiagMsg += "Target applications for uninstallation: $($applicationsToUninstall -join ', ')"

    # --- Main Script Execution ---
    # Step 1: Uninstall the applications
    $uninstalled = Uninstall-Applications -AppNames $applicationsToUninstall

    # Step 2: Pause to allow system to process uninstallation
    if ($uninstalled) {
        $Global:DiagMsg += "Pausing for 5 seconds to allow system to settle..."
        Start-Sleep -Seconds 5
    }

    # Step 3: Remove leftover registry keys
    Remove-LeftoverRegistryKeys

    # Step 4: Correct network adapter DNS settings
    Correct-NetworkAdapterDnsSettings

    $Global:customFieldMessage = "DNSFilter uninstall and network cleanup completed successfully. ($Date)"

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed during cleanup. See diagnostics for details. | Last Checked $Date"
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