<#
.SYNOPSIS
    Uninstalls the DNSFilter agent and ensures network adapter DNS settings are corrected.
.DESCRIPTION
    This script performs a multi-step cleanup process for the DNSFilter agent. It first uninstalls the application by looking up its uninstall string in the registry.
    After uninstallation, it removes leftover registry keys. Finally, it checks all active physical network adapters. If any adapter is configured to use a loopback DNS server (e.g., 127.0.0.1, 127.0.0.2),
    it resets the adapter's DNS settings to be assigned automatically via DHCP and then forces a DHCP lease renewal to fetch the correct settings.
.AUTHOR
    Alex Ivantsov
.DATE
    July 11, 2025
#>

#------------------------------------------------------------------------------------
# --- User-configurable variables ---
#
# Specify the display names of the applications to uninstall. The script will search
# for these exact names in the list of installed programs.
#------------------------------------------------------------------------------------
$applicationsToUninstall = @(
    "DNSFilter Agent",
    "DNS Agent"
)

#====================================================================================
# --- Functions ---
#====================================================================================

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

    # Registry locations for installed programs (covering both 32-bit and 64-bit applications)
    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    # Get information for all installed programs from both registry locations
    # Using -ErrorAction SilentlyContinue to prevent errors if a path doesn't exist
    $installedPrograms = Get-ItemProperty $registryPaths -ErrorAction SilentlyContinue

    foreach ($appName in $AppNames) {
        Write-Host "Processing uninstallation for: `"$appName`""
        # Find the application that matches the current name
        $app = $installedPrograms | Where-Object { $_.DisplayName -eq $appName } | Select-Object -First 1

        if ($app) {
            $uninstallString = $app.UninstallString
            if ($uninstallString) {
                # Most MSI-based installers include a product code GUID in the uninstall string.
                # We extract this GUID to run the uninstaller directly and silently.
                if ($uninstallString -match '\{([0-9a-fA-F\-]+)\}') {
                    $productCode = $matches[1]
                    Write-Host "  Found MSI product code: $productCode"
                    Write-Host "  Executing: msiexec.exe /X `{$productCode`} /qb /norestart"
                    try {
                        # Start the uninstaller and wait for it to complete.
                        # /X = Uninstall, /qb = Quiet with basic UI, /norestart = Prevents automatic restart
                        $process = Start-Process "msiexec.exe" -ArgumentList "/X `{$productCode`} /qb /norestart" -Wait -PassThru -ErrorAction Stop
                        Write-Host "  Uninstaller for '$appName' finished with exit code: $($process.ExitCode)."
                    }
                    catch {
                        Write-Error "  Failed to start the uninstaller for '$appName'. Error: $_"
                    }
                }
                else {
                    Write-Warning "  '$appName' has a non-standard uninstall string that cannot be automated reliably: $uninstallString"
                }
            }
            else {
                Write-Warning "  Found '$appName' but it has no associated uninstall string."
            }
        }
        else {
            Write-Host "  Application '$appName' not found."
        }
    }
}

function Remove-LeftoverRegistryKeys {
    <#
.SYNOPSIS
    Removes specified registry keys that might be left behind after uninstallation.
#>
    Write-Host "Removing leftover registry keys..."

    $registryKeysToRemove = @(
        "HKLM:\Software\DNSFilter",
        "HKLM:\Software\DNSAgent"
    )

    foreach ($keyPath in $registryKeysToRemove) {
        if (Test-Path $keyPath) {
            Write-Host "  Removing registry key: $keyPath"
            try {
                Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
                Write-Host "  Successfully removed $keyPath."
            }
            catch {
                Write-Error "  Failed to remove registry key '$keyPath'. Error: $_"
            }
        }
        else {
            Write-Host "  Registry key not found, skipping: $keyPath"
        }
    }
}

function Correct-NetworkAdapterDnsSettings {
    <#
.SYNOPSIS
    Checks all active network adapters for invalid loopback DNS servers and corrects them.
.DESCRIPTION
    This function gets all physical, connected network adapters. For each one, it checks the configured IPv4 DNS servers.
    If a DNS server address starts with "127.", it resets the adapter to get DNS settings automatically from DHCP
    and then renews the DHCP lease.
#>
    Write-Host "Checking network adapter DNS settings for invalid entries..."

    try {
        # Get all physical network adapters that are currently connected ('Up')
        $adapters = Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' }

        if (-not $adapters) {
            Write-Host "No active physical network adapters found."
            return
        }

        foreach ($adapter in $adapters) {
            Write-Host "  Checking adapter: '$($adapter.Name)' (Index: $($adapter.InterfaceIndex))"
            $dnsSettings = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue

            $needsCorrection = $false
            if ($dnsSettings.ServerAddresses.Count -gt 0) {
                foreach ($dnsServer in $dnsSettings.ServerAddresses) {
                    # Check if the DNS server is a loopback address (e.g., 127.0.0.1, 127.0.0.2)
                    if ($dnsServer.StartsWith("127.")) {
                        Write-Host "    Found invalid loopback DNS server: $dnsServer. Flagging for correction." -ForegroundColor Yellow
                        $needsCorrection = $true
                        break # Found an invalid address, no need to check others on this adapter
                    }
                }
            }

            if ($needsCorrection) {
                Write-Host "    Correcting DNS settings for '$($adapter.Name)'."

                # Reset the DNS server addresses to be obtained automatically via DHCP
                Write-Host "    Setting DNS to 'Automatic' (via DHCP)."
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue

                # Renew the DHCP lease to acquire new, correct DNS settings from the DHCP server.
                # Using ipconfig is a highly reliable method for this.
                Write-Host "    Renewing DHCP lease..."
                ipconfig /renew | Out-Null # Pipe to Out-Null to hide the lengthy command output

                # Verify the new settings as a final check
                $newDnsSettings = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4
                $newServers = if ($newDnsSettings.ServerAddresses) { $newDnsSettings.ServerAddresses -join ', ' } else { "None (DHCP assigned)" }
                Write-Host "    Verification: New DNS Servers are now set to: $newServers" -ForegroundColor Cyan
            }
            else {
                Write-Host "    DNS settings for '$($adapter.Name)' appear correct. No action needed."
            }
        }
    }
    catch {
        Write-Error "An error occurred while managing network adapters. This script requires the 'NetTCPIP' PowerShell module, which is standard on modern Windows. Error details: $_"
    }
}

#====================================================================================
# --- Main Script Execution ---
#====================================================================================

Clear-Host
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  Starting DNSFilter Uninstallation and Cleanup Script"
Write-Host "========================================================" -ForegroundColor Green

# Step 1: Uninstall the applications listed in the configuration variable
Uninstall-Applications -AppNames $applicationsToUninstall

# Step 2: Give the system a moment to process the uninstallation before proceeding
Write-Host "`nPausing for 3 seconds to allow system to settle..."
Start-Sleep -Seconds 3

# Step 3: Remove any leftover registry keys from the software
Remove-LeftoverRegistryKeys

# Step 4: Check all network adapters and correct any invalid DNS settings
Correct-NetworkAdapterDnsSettings

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "  Script execution finished."
Write-Host "========================================================" -ForegroundColor Green