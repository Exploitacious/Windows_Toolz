<#
.SYNOPSIS
    Enables TLS 1.2 on the system by configuring .NET Framework and SCHANNEL registry settings.
    This script is designed to run on PowerShell 5.1 without any external modules.

.DESCRIPTION
    This script modifies the Windows Registry to enforce the use of TLS 1.2 for both client and server communications.
    It specifically targets the .NET Framework (both 32-bit and 64-bit) to use strong cryptography and system default TLS versions.
    It also explicitly enables the TLS 1.2 protocol for both client and server operations within the SCHANNEL security provider.
    A restart is required for the changes to take full effect.

.NOTES
    Author: Alex Ivantsov
    Date:   06/11/2025
    Version: 1.0
#>

#requires -Version 5.1

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#                                       *** SCRIPT CONFIGURATION ***
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# No variables need to be changed for the script to run.
# The script is designed to be executed without any parameters.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function Set-DotNetTlsConfiguration {
    <#
    .SYNOPSIS
        Configures the .NET Framework to use strong cryptography and the system's default TLS versions.
    .DESCRIPTION
        This function creates and sets specific registry keys for the .NET Framework (v4.0.30319) for both
        the 64-bit and 32-bit (WOW6432Node) hives. These settings ensure that applications relying on
        the .NET Framework will default to using the operating system's configured TLS protocols, including TLS 1.2.
    #>
    Write-Host "Configuring .NET Framework for strong cryptography..."

    # Define the registry paths for the .NET Framework
    $dotNetPaths = @(
        'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319'
    )

    foreach ($path in $dotNetPaths) {
        # Ensure the registry key path exists before attempting to set properties
        if (-not (Test-Path -Path $path)) {
            try {
                New-Item -Path $path -Force -ErrorAction Stop | Out-Null
                Write-Host "  Successfully created registry key: $path"
            }
            catch {
                Write-Error "Failed to create registry key: $path. Please run PowerShell as an Administrator."
                # Exit the function if a key cannot be created
                return
            }
        }

        # Set the 'SystemDefaultTlsVersions' property to 1 (DWORD)
        # This forces .NET to use the OS default TLS versions.
        try {
            New-ItemProperty -Path $path -Name 'SystemDefaultTlsVersions' -Value 1 -PropertyType 'DWord' -Force -ErrorAction Stop | Out-Null
            Write-Host "  Set 'SystemDefaultTlsVersions' at: $path"
        }
        catch {
            Write-Error "Failed to set 'SystemDefaultTlsVersions' at: $path."
        }


        # Set the 'SchUseStrongCrypto' property to 1 (DWORD)
        # This enables strong cryptography, which includes TLS 1.1 and TLS 1.2.
        try {
            New-ItemProperty -Path $path -Name 'SchUseStrongCrypto' -Value 1 -PropertyType 'DWord' -Force -ErrorAction Stop | Out-Null
            Write-Host "  Set 'SchUseStrongCrypto' at: $path"
        }
        catch {
            Write-Error "Failed to set 'SchUseStrongCrypto' at: $path."
        }
    }
    Write-Host ".NET Framework configuration complete." -ForegroundColor Green
}

function Set-SchannelTlsConfiguration {
    <#
    .SYNOPSIS
        Enables the TLS 1.2 protocol for SCHANNEL at the operating system level.
    .DESCRIPTION
        This function creates the necessary registry keys and values to enable TLS 1.2 for both client
        and server roles within the SCHANNEL security provider. This is a system-wide setting.
    #>
    Write-Host "Configuring SCHANNEL protocols for TLS 1.2..."

    # Define the registry paths for TLS 1.2 Client and Server protocols
    $schannelPaths = @(
        'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client',
        'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
    )

    foreach ($path in $schannelPaths) {
        # Ensure the registry key path exists
        if (-not (Test-Path -Path $path)) {
            try {
                New-Item -Path $path -Force -ErrorAction Stop | Out-Null
                Write-Host "  Successfully created registry key: $path"
            }
            catch {
                Write-Error "Failed to create registry key: $path. Please run PowerShell as an Administrator."
                # Exit the function if a key cannot be created
                return
            }
        }

        # Set the 'DisabledByDefault' property to 0 (DWORD)
        # This ensures the protocol is not disabled by default.
        try {
            New-ItemProperty -Path $path -Name 'DisabledByDefault' -Value 0 -PropertyType 'DWord' -Force -ErrorAction Stop | Out-Null
            Write-Host "  Set 'DisabledByDefault' to 0 at: $path"
        }
        catch {
            Write-Error "Failed to set 'DisabledByDefault' at: $path."
        }

        # Set the 'Enabled' property to 1 (DWORD)
        # This explicitly enables the protocol.
        try {
            New-ItemProperty -Path $path -Name 'Enabled' -Value 1 -PropertyType 'DWord' -Force -ErrorAction Stop | Out-Null
            Write-Host "  Set 'Enabled' to 1 at: $path"
        }
        catch {
            Write-Error "Failed to set 'Enabled' at: $path."
        }
    }
    Write-Host "SCHANNEL configuration for TLS 1.2 complete." -ForegroundColor Green
}

function Prompt-SystemRestart {
    <#
    .SYNOPSIS
        Prompts the user to restart the computer for changes to take effect.
    .DESCRIPTION
        After registry changes, a restart is required. This function asks the user if they want to
        restart now. It accepts 'y' or 'yes' as affirmative answers.
    #>
    Write-Host "`nTLS 1.2 has been enabled." -ForegroundColor Yellow
    Write-Host "A system restart is required for these changes to take effect." -ForegroundColor Yellow

    try {
        $response = Read-Host -Prompt "Would you like to restart now? (y/n)"
        if ($response -eq 'y' -or $response -eq 'yes') {
            Write-Host "Restarting the computer..." -ForegroundColor Magenta
            Shutdown.exe -r -t 0
        }
        else {
            Write-Host "Please remember to restart your computer later to apply the changes." -ForegroundColor Cyan
        }
    }
    catch {
        # This catch block handles cases where Read-Host might fail (e.g., non-interactive session)
        Write-Warning "Could not prompt for restart. Please restart the computer manually."
    }
}

# --- Main Execution ---
# The main part of the script that calls the functions in order.

# Check for Administrator privileges before running the script
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to modify the registry. Please run this script as an Administrator."
    # Pause the script to allow the user to read the error message before the window closes.
    if ($Host.Name -eq 'ConsoleHost') {
        Read-Host -Prompt "Press Enter to exit"
    }
    exit
}

# Execute the functions to configure TLS 1.2
Set-DotNetTlsConfiguration
Set-SchannelTlsConfiguration

# Prompt the user for a restart
Prompt-SystemRestart

# Pause the script if running in a console to see the final output before closing
if ($Host.Name -eq 'ConsoleHost') {
    Read-Host -Prompt "Script finished. Press Enter to exit"
}