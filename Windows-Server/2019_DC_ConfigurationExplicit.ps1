<#
.SYNOPSIS
    This script hardens a Windows Server 2019 Domain Controller based on a combination of
    CIS Benchmarks, Azure Security Center recommendations, and other best practices.

.DESCRIPTION
    This script provides an explicit PowerShell 5.1 implementation of a Desired State Configuration (DSC)
    security baseline. It modifies numerous system settings to enhance security. All operations are performed
    using base PowerShell cmdlets and built-in Windows command-line tools, requiring no external modules.

    The script performs the following actions:
    - Removes non-essential Windows Features (Telnet Client, SMBv1).
    - Configures an extensive set of security-related registry values.
    - Sets advanced audit policies using auditpol.exe.
    - Configures local security policies, including User Rights Assignments, using secedit.exe.
    - Hardens Windows Firewall profiles and logging.

    WARNING: This script makes significant and extensive changes to the system's security configuration.
    It is designed for a Windows Server 2019 Domain Controller environment.
    REVIEW THE SCRIPT THOROUGHLY and TEST IT IN A NON-PRODUCTION ENVIRONMENT before deploying to live systems.

.NOTES
    Author: Alex Ivantsov
    Date:   10/06/2025
    Version: 1.0
    PowerShell Version: 5.1
#>

#----------------------------------------------------------------------------------------------------------
# --- Script Configuration ---
# This section contains variables that you may want to customize for your environment.
#----------------------------------------------------------------------------------------------------------

#region User-Modifiable Variables

# [Logon Banner] Configure the legal text and title for the interactive logon banner.
$LegalNoticeText = "This system is restricted to authorized users. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information."
$LegalNoticeCaption = "Logon Warning"

# [Firewall Log Settings] Configure paths and sizes for the Windows Firewall logs.
$FirewallLogSettings = @{
    DomainProfileLog  = @{
        Path = "%SystemRoot%\System32\logfiles\firewall\domainfw.log"
        Size = 16384 # KB
    }
    PrivateProfileLog = @{
        Path = "%SystemRoot%\System32\logfiles\firewall\privatefw.log"
        Size = 16384 # KB
    }
    PublicProfileLog  = @{
        Path = "%SystemRoot%\System32\logfiles\firewall\publicfw.log"
        Size = 16384 # KB
    }
}

# [Event Log Sizes] Configure the maximum size in KB for primary event logs.
$EventLogSizes = @{
    Application = 32768   # KB
    Security    = 5000000 # KB
    Setup       = 32768   # KB
    System      = 32768   # KB
}

#endregion

#----------------------------------------------------------------------------------------------------------
# --- Helper Functions ---
# These functions are used to organize and apply the configuration settings.
#----------------------------------------------------------------------------------------------------------

#region Helper Functions

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $ColorMap = @{
        INFO    = "White"
        WARN    = "Yellow"
        ERROR   = "Red"
        SUCCESS = "Green"
    }
    $Color = $ColorMap[$Level]
    Write-Host "[$Level] $Message" -ForegroundColor $Color
}

function Set-RegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        $Value,
        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryValueKind]$Type,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter]$Delete
    )
    
    try {
        if ($Delete.IsPresent) {
            if (Get-ItemProperty -Path $Key -Name $Name -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $Key -Name $Name -Force -ErrorAction Stop
                # Write-Log "Successfully deleted registry value '$Name' from '$Key'." -Level "SUCCESS"
            }
            else {
                # Write-Log "Registry value '$Name' does not exist in '$Key'. No action taken." -Level "INFO"
            }
        }
        else {
            # Ensure the registry key path exists.
            if (-not (Test-Path $Key)) {
                Write-Log "Creating registry key: $Key" -Level "INFO"
                New-Item -Path $Key -Force | Out-Null
            }

            # Set the registry value.
            Set-ItemProperty -Path $Key -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            # Write-Log "Successfully set registry value '$Name' in '$Key'." -Level "SUCCESS"
        }
    }
    catch {
        $action = if ($Delete.IsPresent) { "delete" } else { "set" }
        Write-Log "Failed to $action registry value '$Name' in '$Key'. Error: $_" -Level "ERROR"
    }
}


function Remove-OptionalFeatures {
    <#
    .SYNOPSIS
        Removes specified Windows Features.
    #>
    Write-Log "--- Removing Optional Windows Features ---"
    
    $featuresToRemove = @(
        'Telnet-Client',
        'FS-SMB1'
    )

    foreach ($feature in $featuresToRemove) {
        Write-Log "Ensuring feature '$feature' is absent."
        try {
            $winFeature = Get-WindowsFeature -Name $feature -ErrorAction Stop
            if ($winFeature.Installed) {
                Write-Log "Feature '$feature' is installed. Removing..." -Level "WARN"
                Remove-WindowsFeature -Name $feature -ErrorAction Stop | Out-Null
                Write-Log "Successfully removed feature '$feature'." -Level "SUCCESS"
            }
            else {
                Write-Log "Feature '$feature' is already absent." -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Could not process feature '$feature'. It may not be applicable to this OS version. Error: $_" -Level "ERROR"
        }
    }
}

function Apply-SecurityAccountPolicies {
    <#
    .SYNOPSIS
        Applies account policies for password and lockout settings.
    .DESCRIPTION
        These settings were commented out in the source DSC, likely because they are
        best managed by Domain GPO. This function provides the equivalent PowerShell
        commands for a local policy configuration.
    #>
    Write-Log "--- Applying Account Security Policies (from comments) ---"
    Write-Log "NOTE: These settings are typically managed via Group Policy in a domain environment." -Level "WARN"

    # In a domain, password and lockout policies are controlled by the "Default Domain Policy" GPO.
    # The commands below show how to set them locally, which is generally only effective on non-domain joined machines.
    # We are including this function to fully represent the source DSC, but these commands will be ineffective on a DC.

    # 1.1.1 Enforce password history: 24
    # net accounts /uniquepw:24

    # 1.1.2 Maximum password age: 60
    # net accounts /maxpwage:60

    # 1.1.3 Minimum password age: 1
    # net accounts /minpwage:1

    # 1.1.4 Minimum password length: 14
    # net accounts /minpwlen:14

    # 1.1.5 Password must meet complexity requirements: Enabled
    # This is handled by GPO, but local equivalent would be in secedit configuration.

    # 1.1.6 Store passwords using reversible encryption: Disabled
    # This is handled by GPO, but local equivalent would be in secedit configuration.

    # 1.2.1 Account lockout duration: 15
    # net accounts /lockoutduration:15

    # 1.2.2 Account lockout threshold: 10
    # net accounts /lockoutthreshold:10

    # 1.2.3 Reset account lockout counter after: 15
    # net accounts /lockoutwindow:15
    
    Write-Log "Skipping application of account policies as they should be controlled by GPO on a Domain Controller." -Level "INFO"
}

function Apply-UserRightsAssignments {
    <#
    .SYNOPSIS
        Configures User Rights Assignments using a temporary security policy file.
    #>
    Write-Log "--- Applying User Rights Assignments ---"

    # Define the mapping from DSC Policy Name to secedit.exe internal name
    $userRightsMapping = @{
        'Bypass_traverse_checking'                      = 'SeChangeNotifyPrivilege'
        'Increase_a_process_working_set'                = 'SeIncreaseWorkingSetPrivilege'
        'Access_Credential_Manager_as_a_trusted_caller' = 'SeTrustedCredManAccessPrivilege'
        'Access_this_computer_from_the_network'         = 'SeNetworkLogonRight'
        'Act_as_part_of_the_operating_system'           = 'SeTcbPrivilege'
        'Adjust_memory_quotas_for_a_process'            = 'SeIncreaseQuotaPrivilege'
        'Allow_log_on_locally'                          = 'SeInteractiveLogonRight'
        'Allow_log_on_through_Remote_Desktop_Services'  = 'SeRemoteInteractiveLogonRight'
        'Back_up_files_and_directories'                 = 'SeBackupPrivilege'
        'Change_the_system_time'                        = 'SeSystemtimePrivilege'
        'Change_the_time_zone'                          = 'SeTimeZonePrivilege'
        'Create_a_pagefile'                             = 'SeCreatePagefilePrivilege'
        'Create_a_token_object'                         = 'SeCreateTokenPrivilege'
        'Create_global_objects'                         = 'SeCreateGlobalPrivilege'
        'Create_permanent_shared_objects'               = 'SeCreatePermanentPrivilege'
        'Create_symbolic_links'                         = 'SeCreateSymbolicLinkPrivilege'
        'Debug_programs'                                = 'SeDebugPrivilege'
        'Deny_access_to_this_computer_from_the_network' = 'SeDenyNetworkLogonRight'
        'Deny_log_on_as_a_batch_job'                    = 'SeDenyBatchLogonRight'
        'Deny_log_on_as_a_service'                      = 'SeDenyServiceLogonRight'
        'Deny_log_on_locally'                           = 'SeDenyInteractiveLogonRight'
        'Deny_log_on_through_Remote_Desktop_Services'   = 'SeDenyRemoteInteractiveLogonRight'
        'Force_shutdown_from_a_remote_system'           = 'SeRemoteShutdownPrivilege'