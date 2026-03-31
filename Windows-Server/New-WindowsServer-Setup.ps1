<#
.SYNOPSIS
    Applies a comprehensive set of system modifications and security baseline settings to Windows Server 2022.
    Includes options for a first-time user logon script.

.DESCRIPTION
    This PowerShell script configures a Windows Server to enhance security and apply operational modifications.
    It merges TLS hardening, system tweaks, and a comprehensive security baseline.
    The script directly modifies registry values, security policies, and Windows features.

    Key actions include:
    - Disabling outdated protocols (TLS 1.0, 1.1, SMBv1).
    - Enabling modern security features (TLS 1.2, LSA Protection).
    - Configuring advanced audit policies and user rights assignments.
    - Hardening account policies, network settings, and remote access.
    - Applying settings to the Default User Profile for all new users.
    - Optionally deploying a first-time user logon script.

    The script should be run with elevated (Administrator) privileges.

.NOTES
    Author: Gemini (Merged and Refined)
    Version: 2.0
    PowerShell Version: 5.1
#>

#==============================================================================
# SCRIPT CONFIGURATION
#==============================================================================
#region Configuration

# Path for log files. A timestamped transcript will be created here.
$LogPath = "C:\Windows\Temp"

# --- First-Time Logon Script ---
# Set to $true to enable the creation of a script that runs when a new user logs on for the first time.
# This requires two files in the same directory as this main script:
#   - DebloatScript-HKCU.ps1 (The user-specific script to run)
#   - FirstLogon.bat (A batch file to trigger the PowerShell script)
$EnableUserLogonScript = $false

#endregion Configuration

#==============================================================================
# INITIALIZATION
#==============================================================================
#region Initialization

# Verify the script is running with Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires Administrator privileges. Please run it in an elevated PowerShell session."
    exit
}

# Start Logging
$LogPrefix = "System-Hardening-$Env:Computername-"
$LogDate = Get-Date -Format 'yyyy-MM-dd-HH-mm'
$LogName = "$LogPrefix$LogDate.txt"
if (-not (Test-Path -Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path (Join-Path -Path $LogPath -ChildPath $LogName)

Write-Host "Starting Windows Server hardening and configuration..." -ForegroundColor Cyan

# Helper function to simplify setting registry values
function Set-RegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        $Value,
        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryValueKind]$Type
    )

    try {
        if (-not (Test-Path -Path $Path)) {
            Write-Verbose "Registry path '$Path' not found. Creating it."
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        Write-Verbose "Setting registry value '$Name' at path '$Path'."
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        Write-Host " - Successfully set registry value '$Name' at '$Path'."
    }
    catch {
        Write-Error "Failed to set registry value '$Name' at path '$Path'. Error: $($_.Exception.Message)"
    }
}

#endregion Initialization

#==============================================================================
# 1. SECURITY PROTOCOL CONFIGURATION (TLS/SCHANNEL)
#==============================================================================
#region Security Protocols

Write-Host "Configuring Security Protocols (TLS/SCHANNEL)..." -ForegroundColor Green

# Disable TLS 1.0 and TLS 1.1
$tlsProtocols = @("TLS 1.0", "TLS 1.1")
$protocolRoles = @("Client", "Server")
foreach ($protocol in $tlsProtocols) {
    foreach ($role in $protocolRoles) {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\$role"
        Set-RegistryValue -Path $regPath -Name "Enabled" -Value 0 -Type DWord
        Set-RegistryValue -Path $regPath -Name "DisabledByDefault" -Value 1 -Type DWord
    }
}

# Enable TLS 1.2
$tls12Roles = @{
    "Server" = @{ "Enabled" = 1; "DisabledByDefault" = 0 };
    "Client" = @{ "Enabled" = 1; "DisabledByDefault" = 0 };
}
foreach ($role in $tls12Roles.Keys) {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\$role"
    foreach ($setting in $tls12Roles[$role].Keys) {
        Set-RegistryValue -Path $regPath -Name $setting -Value $tls12Roles[$role][$setting] -Type DWord
    }
}

# Configure .NET Framework to use strong cryptography
$netFrameworkPaths = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319',
    'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
)
foreach ($path in $netFrameworkPaths) {
    Set-RegistryValue -Path $path -Name 'SystemDefaultTlsVersions' -Value 1 -Type DWord
    Set-RegistryValue -Path $path -Name 'SchUseStrongCrypto' -Value 1 -Type DWord
}

#endregion Security Protocols

#==============================================================================
# 2. WINDOWS FEATURES
#==============================================================================
#region Windows Features

Write-Host "Configuring Windows Features..." -ForegroundColor Green

# CCE-37615-2: Ensure 'Telnet-Client' is set to 'Absent'
Write-Host " - Removing Telnet Client feature..."
Uninstall-WindowsFeature -Name Telnet-Client | Out-Null

# Ensure 'SMB1' is set to 'Absent'
Write-Host " - Removing SMBv1 feature..."
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null

#endregion Windows Features

#==============================================================================
# 3. ACCOUNT POLICIES & LSA (Local Security Authority)
#==============================================================================
#region Account Policies & LSA

Write-Host "Configuring Account Policies and LSA settings..." -ForegroundColor Green

# Set 'Account lockout threshold' to 5 invalid logon attempts
Write-Host " - Setting account lockout threshold to 5."
net accounts /lockoutthreshold:5 | Out-Null

# CCE-37615-2: Ensure 'Accounts: Limit local account use of blank passwords to console logon only' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'LimitBlankPasswordUse' -Value 1 -Type DWord

# CCE-37850-5: Ensure 'Audit: Force audit policy subcategory settings to override audit policy category settings' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'SCENoApplyLegacyAuditPolicy' -Value 1 -Type DWord

# CCE-35907-5: Ensure 'Audit: Shut down system immediately if unable to log security audits' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'CrashOnAuditFail' -Value 0 -Type DWord

# Enable 'Local Security Authority (LSA) protection' by forcing it to run as a Protected Process Light (PPL).
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -Type DWord

# Disable the local storage of passwords and credentials.
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "DisableDomainCreds" -Value 1 -Type DWord

# CCE-36077-6: Ensure 'Network access: Do not allow anonymous enumeration of SAM accounts and shares' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'RestrictAnonymous' -Value 1 -Type DWord

# CCE-36316-8: Ensure 'Network access: Do not allow anonymous enumeration of SAM accounts' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'RestrictAnonymousSAM' -Value 1 -Type DWord

# CCE-36148-5: Ensure 'Network access: Let Everyone permissions apply to anonymous users' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'EveryoneIncludesAnonymous' -Value 0 -Type DWord

# NOT_ASSIGNED: Ensure 'Network access: Restrict clients allowed to make remote calls to SAM' is set to 'Administrators: Remote Access: Allow'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'RestrictRemoteSAM' -Value 'O:BAG:BAD:(A;;RC;;;BA)' -Type String

# CCE-37623-6: Ensure 'Network access: Sharing and security model for local accounts' is set to 'Classic - local users authenticate as themselves'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'ForceGuest' -Value 0 -Type DWord

# CCE-38341-4: Ensure 'Network security: Allow Local System to use computer identity for NTLM' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'UseMachineId' -Value 1 -Type DWord

# CCE-37035-3: Ensure 'Network security: Allow LocalSystem NULL session fallback' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'AllowNullSessionFallback' -Value 0 -Type DWord

# CCE-38047-7: Ensure 'Network Security: Allow PKU2U authentication requests to this computer to use online identities' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa\pku2u' -Name 'AllowOnlineID' -Value 0 -Type DWord

# CCE-36326-7: Ensure 'Network security: Do not store LAN Manager hash value on next password change' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'NoLMHash' -Value 1 -Type DWord

# CCE-36173-3: Ensure 'Network security: LAN Manager authentication level' is set to 'Send NTLMv2 response only. Refuse LM & NTLM'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'LmCompatibilityLevel' -Value 5 -Type DWord

# CCE-37553-5: Ensure 'Network security: Minimum session security for NTLM SSP based clients' is set to 'Require NTLMv2, Require 128-bit encryption'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'NTLMMinClientSec' -Value 537395200 -Type DWord

# CCE-37835-6: Ensure 'Network security: Minimum session security for NTLM SSP based servers' is set to 'Require NTLMv2, Require 128-bit encryption'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa\MSV1_0' -Name 'NTLMMinServerSec' -Value 537395200 -Type DWord

#endregion Account Policies & LSA

#==============================================================================
# 4. NETWORK CONFIGURATION
#==============================================================================
#region Network Configuration

Write-Host "Configuring core network settings..." -ForegroundColor Green

# Disable IPv6 on all network adapters
Write-Host " - Disabling IPv6 stack on all adapters..."
Get-NetAdapterBinding -ComponentID "ms_tcpip6" | Disable-NetAdapterBinding -PassThru -ErrorAction SilentlyContinue | Out-Null

# Enable 'Require domain users to elevate when setting a network's location'
Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections" -Name "NC_StdDomainUserSetLocation" -Value 1 -Type DWord


#endregion Network Configuration

#==============================================================================
# 5. SCHEDULED TASKS
#==============================================================================
#region Scheduled Tasks

Write-Host "Disabling unneeded Scheduled Tasks..." -ForegroundColor Green
$tasksToDisable = @(
    "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
)
foreach ($task in $tasksToDisable) {
    Write-Host " - Disabling task: $task"
    Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
}

#endregion Scheduled Tasks

#==============================================================================
# 6. WINRM (WINDOWS REMOTE MANAGEMENT)
#==============================================================================
#region WinRM

Write-Host "Configuring WinRM settings..." -ForegroundColor Green

# CCE-36254-1: Ensure 'Allow Basic authentication' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WinRM\Client' -Name 'AllowBasic' -Value 0 -Type DWord

# CCE-38223-4: Ensure 'Allow unencrypted traffic' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WinRM\Client' -Name 'AllowUnencryptedTraffic' -Value 0 -Type DWord

# CCE-38318-2: Ensure 'Disallow Digest authentication' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WinRM\Client' -Name 'AllowDigest' -Value 0 -Type DWord

# CCE-36000-8: Ensure 'Disallow WinRM from storing RunAs credentials' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WinRM\Service' -Name 'DisableRunAs' -Value 1 -Type DWord

#endregion WinRM

#==============================================================================
# 7. CORTANA & SEARCH
#==============================================================================
#region Cortana & Search

Write-Host "Configuring Cortana and Search settings..." -ForegroundColor Green

# NOT_ASSIGNED: Ensure 'Allow Cortana above lock screen' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortanaAboveLock' -Value 0 -Type DWord

# NOT_ASSIGNED: Ensure 'Allow Cortana' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0 -Type DWord

# CCE-38277-0: Ensure 'Allow indexing of encrypted files' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Windows Search' -Name 'AllowIndexingEncryptedStoresOrItems' -Value 0 -Type DWord

# NOT_ASSIGNED: Ensure 'Allow search and Cortana to use location' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Windows Search' -Name 'AllowSearchToUseLocation' -Value 0 -Type DWord

# NOT_ASSIGNED: Disable Windows Search Service
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\Wsearch' -Name 'Start' -Value 4 -Type DWord

#endregion Cortana & Search

#==============================================================================
# 8. DATA COLLECTION & TELEMETRY
#==============================================================================
#region Data Collection & Telemetry

Write-Host "Configuring Data Collection and Telemetry settings..." -ForegroundColor Green

# AZ-WIN-00169: Ensure 'Allow Telemetry' is set to 'Enabled: 0 - Security [Enterprise Only]'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord

# NOT_ASSIGNED: Ensure 'Do not show feedback notifications' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\DataCollection' -Name 'DoNotShowFeedbackNotifications' -Value 1 -Type DWord

# NOT_ASSIGNED: Enable Windows Error Reporting
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 0 -Type DWord

#endregion Data Collection & Telemetry


#==============================================================================
# 9. SYSTEM - GENERAL, UAC, LOGON
#==============================================================================
#region System Settings

Write-Host "Configuring general System settings..." -ForegroundColor Green

# Enable Verbose Startup / Shutdown Messages
# This check handles cases where the script might be run on a client OS.
if ((Get-CimInstance -Class "Win32_OperatingSystem").ProductType -ne 1) {
    # 1 = Workstation, 2 = Domain Controller, 3 = Server
    Write-Host " - Enabling Verbose Status messages for startup/shutdown."
    Set-RegistryValue -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 1
}
else {
    Write-Host " - OS is not a workstation, ensuring VerboseStatus is not set."
    Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -ErrorAction SilentlyContinue
}

# CCE-38354-7: Ensure 'Allow Microsoft accounts to be optional' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'MSAOptional' -Value 1 -Type DWord

# CCE-36400-0: Ensure 'Allow user control over installs' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Installer' -Name 'EnableUserControl' -Value 0 -Type DWord

# CCE-37490-0: Ensure 'Always install with elevated privileges' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Installer' -Name 'AlwaysInstallElevated' -Value 0 -Type DWord

# NOT_ASSIGNED: Ensure 'Block user from showing account details on sign-in' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name 'BlockUserFromShowingAccountDetailsOnSignin' -Value 1 -Type DWord

# CCE-37912-3: Ensure 'Boot-Start Driver Initialization Policy' is set to 'Enabled: Good, unknown and bad but critical'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Policies\EarlyLaunch' -Name 'DriverLoadPolicy' -Value 3 -Type DWord

# CCE-35859-8: Ensure 'Configure Windows SmartScreen' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name 'EnableSmartScreen' -Value 1 -Type DWord

# NOT_ASSIGNED: Ensure 'Continue experiences on this device' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name 'EnableCdp' -Value 0 -Type DWord

# CCE-37701-0: Ensure 'Devices: Allowed to format and eject removable media' is set to 'Administrators'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AllocateDASD' -Value '0' -Type String

# CCE-37942-0: Ensure 'Devices: Prevent users from installing printer drivers' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Print\Providers\LanMan Print Services\Servers' -Name 'AddPrinterDrivers' -Value 1 -Type DWord

# CCE-37534-5: Ensure 'Do not display the password reveal button' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\CredUI' -Name 'DisablePasswordReveal' -Value 1 -Type DWord

# CCE-36512-2: Ensure 'Enumerate administrator accounts on elevation' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\CredUI' -Name 'EnumerateAdministrators' -Value 0 -Type DWord

# CCE-36056-0: Ensure 'Interactive logon: Do not display last user name' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'DontDisplayLastUserName' -Value 1 -Type DWord

# CCE-37637-6: Ensure 'Interactive logon: Do not require CTRL+ALT+DEL' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'DisableCAD' -Value 0 -Type DWord

# CCE-36788-8: Ensure 'Shutdown: Allow system to be shut down without having to log on' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ShutdownWithoutLogon' -Value 0 -Type DWord

# CCE-37712-7: Ensure 'Turn off background refresh of Group Policy' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'DisableBkGndGroupPolicy' -Value 0 -Type DWord

# CCE-37528-7: Ensure 'Turn on convenience PIN sign-in' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name 'AllowDomainPINLogon' -Value 0 -Type DWord

# CCE-36494-3: Ensure 'User Account Control: Admin Approval Mode for the Built-in Administrator account' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'FilterAdministratorToken' -Value 1 -Type DWord

# CCE-36863-9: Ensure 'User Account Control: Allow UIAccess applications to prompt for elevation without using the secure desktop' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableUIADesktopToggle' -Value 0 -Type DWord

# CCE-37029-6: Ensure 'UAC: Behavior of the elevation prompt for administrators' is set to 'Prompt for consent on the secure desktop'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin' -Value 2 -Type DWord

# CCE-36864-7: Ensure 'User Account Control: Behavior of the elevation prompt for standard users' is set to 'Automatically deny'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorUser' -Value 0 -Type DWord

# CCE-36533-8: Ensure 'User Account Control: Detect application installations and prompt for elevation' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableInstallerDetection' -Value 1 -Type DWord

# CCE-37057-7: Ensure 'User Account Control: Only elevate UIAccess applications that are installed in secure locations' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableSecureUIAPaths' -Value 1 -Type DWord

# CCE-36869-6: Ensure 'User Account Control: Run all administrators in Admin Approval Mode' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableLUA' -Value 1 -Type DWord

# CCE-36866-2: Ensure 'User Account Control: Switch to the secure desktop when prompting for elevation' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'PromptOnSecureDesktop' -Value 1 -Type DWord

# CCE-37064-3: Ensure 'User Account Control: Virtualize file and registry write failures to per-user locations' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableVirtualization' -Value 1 -Type DWord

# NOT_ASSIGNED: Shutdown: Clear virtual memory pagefile
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'ClearPageFileAtShutdown' -Value 1 -Type DWord

# NOT_ASSIGNED: System settings: Use Certificate Rules on Windows Executables for Software Restriction Policies
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers' -Name 'AuthenticodeEnabled' -Value 1 -Type DWord

#endregion System Settings

#==============================================================================
# 10. EXPLORER, SHELL, AND AUTOPLAY
#==============================================================================
#region Explorer & Shell Hardening

Write-Host "Configuring Explorer, Shell, and AutoPlay settings..." -ForegroundColor Green

# CCE-37636-8: Ensure 'Disallow Autoplay for non-volume devices' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Explorer' -Name 'NoAutoplayfornonVolume' -Value 1 -Type DWord

# CCE-38217-6: Ensure 'Set the default behavior for AutoRun' is set to 'Enabled: Do not execute any autorun commands'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoAutorun' -Value 1 -Type DWord

# CCE-36875-3: Ensure 'Turn off Autoplay' is set to 'Enabled: All drives'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDriveTypeAutoRun' -Value 255 -Type DWord

# CCE-37809-1: Ensure 'Turn off Data Execution Prevention for Explorer' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Explorer' -Name 'NoDataExecutionPrevention' -Value 0 -Type DWord

# CCE-36660-9: Ensure 'Turn off heap termination on corruption' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Explorer' -Name 'NoHeapTerminationOnCorruption' -Value 0 -Type DWord

# CCE-36809-2: Ensure 'Turn off shell protocol protected mode' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'PreXPSP2ShellProtocolBehavior' -Value 0 -Type DWord

#endregion Explorer & Shell Hardening

#==============================================================================
# 11. NETWORK SECURITY
#==============================================================================
#region Network Security

Write-Host "Configuring Network Security settings..." -ForegroundColor Green

# CCE-36142-8: Ensure 'Domain member: Digitally encrypt or sign secure channel data (always)' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\Netlogon\Parameters' -Name 'RequireSignOrSeal' -Value 1 -Type DWord

# CCE-37130-2: Ensure 'Domain member: Digitally encrypt secure channel data (when possible)' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\Netlogon\Parameters' -Name 'SealSecureChannel' -Value 1 -Type DWord

# CCE-37222-7: Ensure 'Domain member: Digitally sign secure channel data (when possible)' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\Netlogon\Parameters' -Name 'SignSecureChannel' -Value 1 -Type DWord

# CCE-37508-9: Ensure 'Domain member: Disable machine account password changes' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\Netlogon\Parameters' -Name 'DisablePasswordChange' -Value 0 -Type DWord

# CCE-37431-4: Ensure 'Domain member: Maximum machine account password age' is set to '30'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\Netlogon\Parameters' -Name 'MaximumPasswordAge' -Value 30 -Type DWord

# CCE-37614-5: Ensure 'Domain member: Require strong (Windows 2000 or later) session key' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\Netlogon\Parameters' -Name 'RequireStrongKey' -Value 1 -Type DWord

# NOT_ASSIGNED: Ensure 'Enable insecure guest logons' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\LanmanWorkstation' -Name 'AllowInsecureGuestAuth' -Value 0 -Type DWord

# CCE-36325-9: Ensure 'Microsoft network client: Digitally sign communications (always)' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'RequireSecuritySignature' -Value 1 -Type DWord

# CCE-36269-9: Ensure 'Microsoft network client: Digitally sign communications (if server agrees)' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'EnableSecuritySignature' -Value 1 -Type DWord

# CCE-37863-8: Ensure 'Microsoft network client: Send unencrypted password to third-party SMB servers' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'EnablePlainTextPassword' -Value 0 -Type DWord

# CCE-38046-9: Ensure 'Microsoft network server: Amount of idle time required before suspending session' is set to '15'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters' -Name 'AutoDisconnect' -Value 15 -Type DWord

# CCE-37864-6: Ensure 'Microsoft network server: Digitally sign communications (always)' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters' -Name 'RequireSecuritySignature' -Value 1 -Type DWord

# CCE-35988-5: Ensure 'Microsoft network server: Digitally sign communications (if client agrees)' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters' -Name 'EnableSecuritySignature' -Value 1 -Type DWord

# CCE-37972-7: Ensure 'Microsoft network server: Disconnect clients when logon hours expire' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters' -Name 'EnableForcedLogoff' -Value 1 -Type DWord

# CCE-36021-4: Ensure 'Network access: Restrict anonymous access to Named Pipes and Shares' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters' -Name 'RestrictNullSessAccess' -Value 1 -Type DWord

# CCE-36858-9: Ensure 'Network security: LDAP client signing requirements' is set to 'Negotiate signing' or higher
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Services\LDAP' -Name 'LDAPClientIntegrity' -Value 1 -Type DWord

# CCE-38002-2: Ensure 'Prohibit installation and configuration of Network Bridge on your DNS domain network' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Network Connections' -Name 'NC_AllowNetBridge_NLA' -Value 0 -Type DWord

# NOT_ASSIGNED: Ensure 'Turn off multicast name resolution' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -Value 0 -Type DWord

#endregion Network Security

#==============================================================================
# 12. TERMINAL SERVICES (REMOTE DESKTOP)
#==============================================================================
#region Terminal Services

Write-Host "Configuring Terminal Services (Remote Desktop) settings..." -ForegroundColor Green

# CCE-37929-7: Ensure 'Always prompt for password upon connection' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fPromptForPassword' -Value 1 -Type DWord

# CCE-36388-7: Ensure 'Configure Offer Remote Assistance' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fAllowUnsolicited' -Value 0 -Type DWord

# CCE-37281-3: Ensure 'Configure Solicited Remote Assistance' is set to 'Disabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fAllowToGetHelp' -Value 0 -Type DWord

# CCE-36223-6: Ensure 'Do not allow passwords to be saved' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services' -Name 'DisablePasswordSaving' -Value 1 -Type DWord

# CCE-37567-5: Ensure 'Require secure RPC communication' is set to 'Enabled'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fEncryptRPCTraffic' -Value 1 -Type DWord

# CCE-36627-8: Ensure 'Set client connection encryption level' is set to 'Enabled: High Level'
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services' -Name 'MinEncryptionLevel' -Value 3 -Type DWord

# NOT_ASSIGNED: Require user authentication for remote connections by using Network Level Authentication
Set-RegistryValue -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'UserAuthentication' -Value 1 -Type DWord

#endregion Terminal Services

#==============================================================================
# 13. EVENT & POWERSHELL LOGGING
#==============================================================================
#region Event & PowerShell Logging

Write-Host "Configuring Event Log and PowerShell Logging settings..." -ForegroundColor Green

# Enable PowerShell Script-Block Logging
Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -Type DWord
Set-RegistryValue -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -Type DWord


# Application Log
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\EventLog\Application' -Name 'Retention' -Value '0' -Type String
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\EventLog\Application' -Name 'MaxSize' -Value 32768 -Type DWord

# Security Log
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\EventLog\Security' -Name 'Retention' -Value '0' -Type String
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\EventLog\Security' -Name 'MaxSize' -Value 196608 -Type DWord

# Setup Log
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\EventLog\Setup' -Name 'Retention' -Value '0' -Type String
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\EventLog\Setup' -Name 'MaxSize' -Value 32768 -Type DWord

# System Log
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\EventLog\System' -Name 'Retention' -Value '0' -Type String
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\EventLog\System' -Name 'MaxSize' -Value 32768 -Type DWord

#endregion Event & PowerShell Logging

#==============================================================================
# 14. WINDOWS FIREWALL
#==============================================================================
#region Windows Firewall

Write-Host "Configuring Windows Firewall settings..." -ForegroundColor Green

# Domain Profile
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\DomainProfile' -Name 'EnableFirewall' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\DomainProfile' -Name 'DefaultInboundAction' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\DomainProfile' -Name 'DefaultOutboundAction' -Value 0 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\DomainProfile' -Name 'AllowLocalPolicyMerge' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\DomainProfile' -Name 'AllowLocalIPsecPolicyMerge' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\DomainProfile' -Name 'DisableNotifications' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging' -Name 'LogFileSize' -Value 16384 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging' -Name 'LogDroppedPackets' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging' -Name 'LogSuccessfulConnections' -Value 1 -Type DWord

# Private Profile
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile' -Name 'EnableFirewall' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile' -Name 'DefaultInboundAction' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile' -Name 'DefaultOutboundAction' -Value 0 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile' -Name 'AllowLocalPolicyMerge' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile' -Name 'AllowLocalIPsecPolicyMerge' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile' -Name 'DisableNotifications' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile\Logging' -Name 'LogFileSize' -Value 16384 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile\Logging' -Name 'LogDroppedPackets' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PrivateProfile\Logging' -Name 'LogSuccessfulConnections' -Value 1 -Type DWord

# Public Profile
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile' -Name 'EnableFirewall' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile' -Name 'DefaultInboundAction' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile' -Name 'DefaultOutboundAction' -Value 0 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile' -Name 'AllowLocalPolicyMerge' -Value 0 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile' -Name 'AllowLocalIPsecPolicyMerge' -Value 0 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile' -Name 'DisableNotifications' -Value 0 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile\Logging' -Name 'LogFileSize' -Value 16384 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile\Logging' -Name 'LogDroppedPackets' -Value 1 -Type DWord
Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\WindowsFirewall\PublicProfile\Logging' -Name 'LogSuccessfulConnections' -Value 1 -Type DWord

#endregion Windows Firewall

#==============================================================================
# 15. AUDIT POLICIES (ADVANCED)
#==============================================================================
#region Audit Policies

Write-Host "Configuring Advanced Audit Policies..." -ForegroundColor Green

# Using auditpol.exe to set advanced audit policy subcategories.
# Format: auditpol /set /subcategory:"<name>" /success:<enable|disable> /failure:<enable|disable>
$auditPolicies = @{
    "Logon"                           = @{s = "enable"; f = "enable" };
    "Logoff"                          = @{s = "enable"; f = "disable" };
    "Account Lockout"                 = @{s = "enable"; f = "enable" };
    "Special Logon"                   = @{s = "enable"; f = "disable" };
    "User Account Management"         = @{s = "enable"; f = "enable" };
    "Security Group Management"       = @{s = "enable"; f = "enable" };
    "Computer Account Management"     = @{s = "enable"; f = "enable" };
    "Process Creation"                = @{s = "enable"; f = "disable" };
    "Sensitive Privilege Use"         = @{s = "enable"; f = "enable" };
    "Removable Storage"               = @{s = "enable"; f = "enable" };
    "Other Logon/Logoff Events"       = @{s = "enable"; f = "enable" };
    "Other Account Management Events" = @{s = "enable"; f = "enable" };
    "Security System Extension"       = @{s = "enable"; f = "enable" };
    "System Integrity"                = @{s = "enable"; f = "enable" };
    "MPSSVC Rule-Level Policy Change" = @{s = "enable"; f = "enable" };
    "Other Object Access Events"      = @{s = "enable"; f = "enable" };
    "Plug and Play Events"            = @{s = "enable"; f = "disable" };
    "Application Group Management"    = @{s = "enable"; f = "enable" };
    "IPsec Driver"                    = @{s = "disable"; f = "disable" };
    "IPsec Main Mode"                 = @{s = "disable"; f = "disable" };
    "IPsec Quick Mode"                = @{s = "disable"; f = "disable" };
    "IPsec Extended Mode"             = @{s = "disable"; f = "disable" };
}
foreach ($policy in $auditPolicies.Keys) {
    auditpol /set /subcategory:"$policy" /success:$($auditPolicies[$policy].s) /failure:$($auditPolicies[$policy].f) | Out-Null
}

#endregion Audit Policies

#==============================================================================
# 16. USER RIGHTS ASSIGNMENTS
#==============================================================================
#region User Rights Assignments

Write-Host "Configuring User Rights Assignments... (This may take a moment)" -ForegroundColor Green

# This section generates a security template file (.inf) on the fly,
# imports it using secedit.exe to apply the settings, and then cleans up.
# This is the standard Microsoft-supported method for scripting user rights assignments.

# Well-known SIDs used in policies
$sids = @{
    Administrators                    = "*S-1-5-32-544"
    Users                             = "*S-1-5-32-545"
    Guests                            = "*S-1-5-32-546"
    "Backup Operators"                = "*S-1-5-32-551"
    "Remote Desktop Users"            = "*S-1-5-32-555"
    "Network Configuration Operators" = "*S-1-5-32-556"
    "Performance Monitor Users"       = "*S-1-5-32-558"
    "Performance Log Users"           = "*S-1-5-32-559"
    "Authenticated Users"             = "*S-1-5-11"
    "Local Service"                   = "*S-1-5-19"
    "Network Service"                 = "*S-1-5-20"
    Service                           = "*S-1-5-6"
    "WdiServiceHost"                  = "*S-1-5-80-3139157870-2983391045-3678747466-658725712-1809340420"
    "Local account"                   = "Local account" # Literal name
}

# Define user rights. Use comma-separated SID variables. Blank means no one assigned.
$userRights = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeNetworkLogonRight = $($sids.Administrators),$($sids.'Authenticated Users'),$($sids.'Remote Desktop Users')
SeRemoteInteractiveLogonRight = $($sids.Administrators),$($sids.'Remote Desktop Users')
SeInteractiveLogonRight = $($sids.Administrators),$($sids.'Remote Desktop Users')
SeCreateSymbolicLinkPrivilege = $($sids.Administrators)
SeDenyNetworkLogonRight = $($sids.Guests),$($sids.'Local account')
SeEnableDelegationPrivilege =
SeSecurityPrivilege = $($sids.Administrators)
SeTrustedCredManAccessPrivilege =
SeTcbPrivilege =
SeBackupPrivilege = $($sids.Administrators),$($sids.'Backup Operators')
SeSystemtimePrivilege = $($sids.Administrators),$($sids.'Local Service')
SeTimeZonePrivilege = $($sids.Administrators),$($sids.'Local Service')
SeCreatePagefilePrivilege = $($sids.Administrators)
SeCreateTokenPrivilege =
SeCreateGlobalPrivilege = $($sids.Administrators),$($sids.Service),$($sids.'Local Service'),$($sids.'Network Service')
SeCreatePermanentPrivilege =
SeDenyBatchLogonRight = $($sids.Guests)
SeDenyServiceLogonRight = $($sids.Guests)
SeDenyInteractiveLogonRight = $($sids.Guests)
SeDenyRemoteInteractiveLogonRight = $($sids.Guests),$($sids.'Local account')
SeRemoteShutdownPrivilege = $($sids.Administrators)
SeAuditPrivilege = $($sids.'Local Service'),$($sids.'Network Service')
SeIncreaseBasePriorityPrivilege = $($sids.Administrators)
SeLoadDriverPrivilege = $($sids.Administrators)
SeLockMemoryPrivilege =
SeRelabelObjectPrivilege =
SeSystemEnvironmentPrivilege = $($sids.Administrators)
SeManageVolumePrivilege = $($sids.Administrators)
SeProfileSingleProcessPrivilege = $($sids.Administrators)
SeSystemProfilePrivilege = $($sids.Administrators),$($sids.WdiServiceHost)
SeAssignPrimaryTokenPrivilege = $($sids.'Local Service'),$($sids.'Network Service')
SeRestorePrivilege = $($sids.Administrators),$($sids.'Backup Operators')
SeShutdownPrivilege = $($sids.Administrators)
SeTakeOwnershipPrivilege = $($sids.Administrators)
SeChangeNotifyPrivilege = $($sids.Administrators),$($sids.'Authenticated Users'),$($sids.'Backup Operators'),$($sids.'Local Service'),$($sids.'Network Service')
SeIncreaseWorkingSetPrivilege = $($sids.Users)
SeUndockPrivilege = $($sids.Administrators)
"@

$infFile = "$env:TEMP\secedit.inf"
$sdbFile = "$env:TEMP\secedit.sdb"
$logFile = "$env:TEMP\secedit.log"

try {
    $userRights | Out-File -FilePath $infFile -Encoding Unicode -Force
    secedit.exe /configure /db $sdbFile /cfg $infFile /log $logFile /quiet
    Write-Host " - User Rights Assignments applied successfully." -ForegroundColor DarkGreen
}
catch {
    Write-Error "Failed to apply User Rights Assignments. Error: $($_.Exception.Message)"
}
finally {
    if (Test-Path $infFile) { Remove-Item $infFile -Force }
    if (Test-Path $sdbFile) { Remove-Item $sdbFile -Force }
}

#endregion User Rights Assignments

#==============================================================================
# 17. DEFAULT USER PROFILE & FIRST LOGON SCRIPT
#==============================================================================
#region Default User Profile Settings

Write-Host "Applying settings to the Default User Profile..." -ForegroundColor Green
$defaultUserHive = "C:\Users\Default\NTUSER.DAT"
$hiveKeyName = "DefaultUser"

try {
    # Load the default user registry hive
    reg.exe load "HKEY_Users\$hiveKeyName" "$defaultUserHive" | Out-Null
    Write-Host " - Default User registry hive loaded successfully."

    # --- Disable Content Delivery Manager Features for all new users ---
    $cdmPath = "Registry::HKEY_USERS\$hiveKeyName\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $cdmKeys = @(
        "ContentDeliveryAllowed", "FeatureManagementEnabled", "OemPreInstalledAppsEnabled",
        "PreInstalledAppsEnabled", "PreInstalledAppsEverEnabled", "SilentInstalledAppsEnabled",
        "SubscribedContent-310093Enabled", "SubscribedContent-314559Enabled", "SubscribedContent-338387Enabled",
        "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled", "SubscribedContent-338393Enabled",
        "SubscribedContent-353694Enabled", "SubscribedContent-353696Enabled", "SubscribedContent-353698Enabled",
        "SubscribedContentEnabled", "SystemPaneSuggestionsEnabled"
    )
    foreach ($key in $cdmKeys) {
        Set-RegistryValue -Path $cdmPath -Name $key -Value 0 -Type DWord
    }

    # --- Implement User First-Time Logon Script (if enabled) ---
    if ( $EnableUserLogonScript ) {
        Write-Host "Configuring First-Time Logon script..." -ForegroundColor Yellow
        $scriptDir = "C:\Scripts"
        $sourceDebloatScript = Join-Path -Path $PSScriptRoot -ChildPath "DebloatScript-HKCU.ps1"
        $sourceBatchFile = Join-Path -Path $PSScriptRoot -ChildPath "FirstLogon.bat"

        if ((Test-Path $sourceDebloatScript) -and (Test-Path $sourceBatchFile)) {
            New-Item -Path $scriptDir -ItemType Directory -Force -ErrorAction SilentlyContinue
            Copy-Item -Path $sourceDebloatScript -Destination $scriptDir -Force
            Copy-Item -Path $sourceBatchFile -Destination $scriptDir -Force
            
            # Set the Run key for new users to trigger the script
            $runKeyPath = "Registry::HKEY_USERS\$hiveKeyName\Software\Microsoft\Windows\CurrentVersion\Run"
            $batchFilePath = Join-Path -Path $scriptDir -ChildPath "FirstLogon.bat"
            Set-RegistryValue -Path $runKeyPath -Name "FirstUserLogon" -Value $batchFilePath -Type String
            Write-Host " - First-Time Logon Script has been configured for all new users."
        }
        else {
            Write-Warning "EnableUserLogonScript is true, but required files (DebloatScript-HKCU.ps1, FirstLogon.bat) were not found in the script's directory."
        }
    }
}
catch {
    Write-Error "An error occurred while modifying the Default User hive. $($_.Exception.Message)"
}
finally {
    # Ensure the hive is always unloaded
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()
    reg.exe unload "HKEY_Users\$hiveKeyName" | Out-Null
    Write-Host " - Default User registry hive has been unloaded."
}

#endregion Default User Profile Settings

#==============================================================================
# SCRIPT COMPLETION
#==============================================================================

Write-Host "Security baseline and system configuration script has completed." -ForegroundColor Cyan
Write-Host "A reboot may be required for all settings to take effect." -ForegroundColor Yellow