# 
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Reset Windows Update Components (Comprehensive)" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:APIEndpoint = "https://prod-36.westus.logic.azure.com:443/workflows/6c032a1ca84045b9a7a1436864ecf696/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=c-dVa333HMzhWli_Fp_4IIAqaJOMwFjP2y5Zfv4j_zA"
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

<#
This Script is a Remediation compoenent, meaning it performs only one task with a log of granular detail. These task results can be added back ito tickets as time entries using the API. 
#>
# DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########
<#
.SYNOPSIS
    Resets the Windows Update Components to fix common update issues using a comprehensive audit and cleanup.

.DESCRIPTION
    This script automates the process of stopping Windows Update services, performing a detailed audit and cleanup of registry policies,
    clearing caches, re-registering DLLs, resetting network components, and restarting services.
    It is designed to run without user interaction and requires administrative privileges.

.AUTHOR
    Alex Ivantsov

.DATE
    October 17, 2025
#>

#---------------------------------------------------------------------------------------------------
#--- SCRIPT CONFIGURATION - Variables you can modify
#---------------------------------------------------------------------------------------------------

# List of services to stop and start during the reset process.
$updateServices = @('bits', 'wuauserv', 'appidsvc', 'cryptsvc')

# List of DLL files to re-register.
$dllsToRegister = @(
    'atl.dll', 'urlmon.dll', 'mshtml.dll', 'shdocvw.dll', 'browseui.dll', 'jscript.dll', 'vbscript.dll', 'scrrun.dll', 'msxml.dll', 
    'msxml3.dll', 'msxml6.dll', 'actxprxy.dll', 'softpub.dll', 'wintrust.dll', 'dssenh.dll', 'rsaenh.dll', 'gpkcsp.dll', 'sccbase.dll', 
    'slbcsp.dll', 'cryptdlg.dll', 'oleaut32.dll', 'ole32.dll', 'shell32.dll', 'initpki.dll', 'wuapi.dll', 'wuaueng.dll', 'wuaueng1.dll', 
    'wucltui.dll', 'wups.dll', 'wups2.dll', 'wuweb.dll', 'qmgr.dll', 'qmgrprxy.dll', 'wucltux.dll', 'muweb.dll', 'wuwebv.dll'
)

# Define the registry paths to audit or clean.
$registryPathsToCheck = @{
    "WU GPO Policies (64-bit)"                                   = "Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    "Automatic Updates (AU) GPO Policies (64-bit)"               = "Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    "WU GPO Policies (32-bit / WOW6432Node)"                     = "Registry::HKLM\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows\WindowsUpdate"
    "Automatic Updates (AU) GPO Policies (32-bit / WOW6432Node)" = "Registry::HKLM\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows\WindowsUpdate\AU"
    "Automatic Updates (AU) Local Settings"                      = "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
}

# Define the policies to check for in the 'WindowsUpdate' keys.
$wuPolicies = @(
    "AcceptTrustedPublisherCerts", "BranchReadinessLevel", "DisableDualScan", "SetDisableUXWUAccess", 
    "SetProxyBehaviorForUpdateDetection", "TargetReleaseVersion", "TargetReleaseVersionInfo", "WUServer", "WUStatusServer"
)

# Define the policies to check for in the 'WindowsUpdate\AU' keys.
$auPolicies = @(
    "AlwaysAutoRebootAtScheduledTime", "AUOptions", "AutoInstallMinorUpdates", "DetectionFrequency", "DetectionFrequencyEnabled", 
    "NoAutoRebootWithLoggedOnUsers", "NoAutoUpdate", "RebootRelaunchTimeout", "RebootRelaunchTimeoutEnabled", "RebootWarningTimeout", 
    "RebootWarningTimeoutEnabled", "RescheduleWaitTime", "RescheduleWaitTimeEnabled", "ScheduledInstallDay", "ScheduledInstallTime", "UseWUServer"
)


#---------------------------------------------------------------------------------------------------
#--- FUNCTIONS
#---------------------------------------------------------------------------------------------------
function Get-RegistryPolicyState {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string[]]$PolicyNames,
        [Parameter(Mandatory = $true)] [string]$SectionTitle,
        [Parameter(Mandatory = $true)] [bool]$RestoreToDefaults
    )

    $Global:DiagMsg += "--------------------------------------------------"
    $Global:DiagMsg += "Auditing Section: $SectionTitle"
    $Global:DiagMsg += "Registry Path: $Path"

    if (-not (Test-Path -Path $Path)) {
        $Global:DiagMsg += "  -> Registry key not found. No policies configured in this section."
        return
    }

    $keyProperties = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue

    foreach ($policy in $PolicyNames) {
        if ($null -ne $keyProperties -and $keyProperties.PSObject.Properties.Name -contains $policy) {
            $value = $keyProperties.$($policy)
            if ($null -ne $value -and $value -ne "") {
                $Global:DiagMsg += "  -> Found Policy: $policy = $value"
                if ($RestoreToDefaults) {
                    try {
                        Remove-ItemProperty -Path $Path -Name $policy -Force -ErrorAction Stop
                        $Global:DiagMsg += "     REMOVED Registry Policy: '$policy'"
                    }
                    catch {
                        $Global:DiagMsg += "     FAILED to remove Registry Policy: '$policy'"
                    }
                }
            }
            else {
                $Global:DiagMsg += "  -> Found Policy: $policy [Exists but is NULL/Empty]"
                if ($RestoreToDefaults) {
                    try {
                        Remove-ItemProperty -Path $Path -Name $policy -Force -ErrorAction Stop
                        $Global:DiagMsg += "     REMOVED Empty Registry Policy: '$policy'"
                    }
                    catch {
                        $Global:DiagMsg += "     FAILED to remove Empty Registry Policy: '$policy'"
                    }
                }
            }
        }
    }
}

function Get-SystemComponentState {
    param([bool]$RestoreToDefaults)

    $Global:DiagMsg += "--------------------------------------------------"
    $Global:DiagMsg += "Auditing System Components"
    $Global:DiagMsg += "--------------------------------------------------"

    $agentPath = Join-Path -Path $env:windir -ChildPath "System32\wuaueng.dll"
    if (Test-Path $agentPath) {
        $versionInfo = (Get-Item $agentPath).VersionInfo.ProductVersion
        $Global:DiagMsg += "  -> Windows Update Agent Version: $versionInfo"
    }
    else {
        $Global:DiagMsg += "  -> Windows Update Agent Version: [File not found]"
    }

    $services = "wuauserv", "BITS"
    foreach ($serviceName in $services) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop
            $Global:DiagMsg += "  -> Service '$($service.DisplayName)': Status=$($service.Status), Startup=$($service.StartType)"
            if ($service.StartType -eq 'Disabled') {
                if ($RestoreToDefaults) {
                    try {
                        Set-Service -Name $service.Name -StartupType Manual -ErrorAction Stop
                        $Global:DiagMsg += "     RE-ENABLED Service (set to Manual startup)."
                    }
                    catch {
                        $Global:DiagMsg += "     FAILED to re-enable Service."
                    }
                }
            }
        }
        catch {
            $Global:DiagMsg += "  -> Service '$serviceName': [Service Not Found]"
        }
    }
}

function Stop-UpdateServices {
    param ([string[]]$Services)

    # Temporarily suppress the 'Waiting for service...' warnings
    $OriginalWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'

    try {
        $Global:DiagMsg += "Stopping Windows Update related services..."
        Stop-Process -Name "wuauclt" -Force -ErrorAction SilentlyContinue
        foreach ($serviceName in $Services) {
            $Global:DiagMsg += "  -> Stopping service: $serviceName"
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service -and $service.Status -ne 'Stopped') {
                try {
                    # Added a timeout of 120 seconds to prevent it from hanging indefinitely
                    $service | Stop-Service -Force -Timeout 120 -ErrorAction Stop
                    $Global:DiagMsg += "     Service stopped successfully."
                }
                catch {
                    $Global:DiagMsg += "     WARNING: Failed to stop service or it timed out."
                }
            }
            else {
                $Global:DiagMsg += "     Service is already stopped or does not exist."
            }
        }
    }
    finally {
        # IMPORTANT: Restore the original warning preference
        $WarningPreference = $OriginalWarningPreference
    }
}

function Clean-UpdateCacheAndBackups {
    $Global:DiagMsg += "Cleaning up old files and renaming cache folders..."
    $Global:DiagMsg += "  -> Deleting qmgr*.dat files..."
    Remove-Item -Path "$env:ALLUSERSPROFILE\Microsoft\Network\Downloader\qmgr*.dat" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -Force -ErrorAction SilentlyContinue

    $pathsToBackup = @{
        (Join-Path $env:SystemRoot "SoftwareDistribution") = "SoftwareDistribution.old";
        (Join-Path $env:SystemRoot "System32\catroot2")    = "catroot2.old"
    }
    $Global:DiagMsg += "  -> Removing previous backup folders..."
    foreach ($path in $pathsToBackup.Keys) {
        $oldPath = "$path.old"
        if (Test-Path $oldPath) { Remove-Item -Path $oldPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $Global:DiagMsg += "  -> Renaming current cache folders..."
    foreach ($item in $pathsToBackup.GetEnumerator()) {
        if (Test-Path $item.Name) {
            try {
                Rename-Item -Path $item.Name -NewName $item.Value -Force -ErrorAction Stop
                $Global:DiagMsg += "     Renamed '$($item.Name)'"
            }
            catch {
                $Global:DiagMsg += "     WARNING: Failed to rename '$($item.Name)'. It may be in use."
            }
        }
    }
}

function Reset-UpdateRegistryKeys {
    $Global:DiagMsg += "Starting comprehensive reset of Windows Update registry keys..."
    
    # --- Part 1: Granular Policy Audit and Removal ---
    Get-RegistryPolicyState -Path $registryPathsToCheck["WU GPO Policies (64-bit)"] -PolicyNames $wuPolicies -SectionTitle "WU GPO Policies (64-bit)" -RestoreToDefaults $true
    Get-RegistryPolicyState -Path $registryPathsToCheck["Automatic Updates (AU) GPO Policies (64-bit)"] -PolicyNames $auPolicies -SectionTitle "Automatic Updates (AU) GPO Policies (64-bit)" -RestoreToDefaults $true
    Get-RegistryPolicyState -Path $registryPathsToCheck["WU GPO Policies (32-bit / WOW6432Node)"] -PolicyNames $wuPolicies -SectionTitle "WU GPO Policies (32-bit / WOW6432Node)" -RestoreToDefaults $true
    Get-RegistryPolicyState -Path $registryPathsToCheck["Automatic Updates (AU) GPO Policies (32-bit / WOW6432Node)"] -PolicyNames $auPolicies -SectionTitle "Automatic Updates (AU) GPO Policies (32-bit / WOW6432Node)" -RestoreToDefaults $true
    Get-RegistryPolicyState -Path $registryPathsToCheck["Automatic Updates (AU) Local Settings"] -PolicyNames $auPolicies -SectionTitle "Automatic Updates (AU) Local Settings" -RestoreToDefaults $true

    # --- Part 2: Set Default Windows Update Values ---
    $Global:DiagMsg += "--------------------------------------------------"
    $Global:DiagMsg += "Setting default Windows Update registry values..."
    $regValuesToSet = @(
        [PSCustomObject]@{Path = 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DisableWindowsUpdateAccess'; Value = 0; Type = 'DWord' };
        [PSCustomObject]@{Path = 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'AUOptions'; Value = 3; Type = 'DWord' };
        [PSCustomObject]@{Path = 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate'; Value = 0; Type = 'DWord' };
        [PSCustomObject]@{Path = 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'UseWUServer'; Value = 0; Type = 'DWord' }
    )
    foreach ($regValue in $regValuesToSet) {
        if (-not (Test-Path $regValue.Path)) {
            New-Item -Path $regValue.Path -Force | Out-Null
        }
        New-ItemProperty -Path $regValue.Path -Name $regValue.Name -Value $regValue.Value -PropertyType $regValue.Type -Force -ErrorAction SilentlyContinue | Out-Null
    }
    $Global:DiagMsg += "  -> Default values have been set."
    $Global:DiagMsg += "Comprehensive registry reset complete."
}

function Reregister-UpdateDlls {
    param([string[]]$Dlls)
    $Global:DiagMsg += "Re-registering BITS and Windows Update DLL files..."
    $system32Path = Join-Path -Path $env:SystemRoot -ChildPath "System32"
    foreach ($dll in $Dlls) {
        $dllPath = Join-Path -Path $system32Path -ChildPath $dll
        if (Test-Path $dllPath) {
            regsvr32.exe /s $dllPath | Out-Null
        }
    }
    $Global:DiagMsg += "  -> DLL registration process completed."
}

function Reset-NetworkComponents {
    $Global:DiagMsg += "Resetting network components..."
    $Global:DiagMsg += "  -> Resetting Winsock..."
    netsh.exe winsock reset | Out-Null
    $Global:DiagMsg += "  -> Resetting WinHTTP Proxy..."
    netsh.exe winhttp reset proxy | Out-Null
    $Global:DiagMsg += "  -> Network component reset complete."
}

function Start-UpdateServices {
    param ([string[]]$Services)

    # Temporarily suppress the 'Waiting for service...' warnings
    $OriginalWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'

    try {
        $Global:DiagMsg += "Configuring and restarting Windows Update related services..."
        Set-Service -Name 'wuauserv' -StartupType Automatic -ErrorAction SilentlyContinue
        
        # FIXED: Set-Service doesn't support 'DelayedStart'. Use sc.exe instead for the BITS service.
        $Global:DiagMsg += "  -> Configuring BITS service for Automatic (Delayed Start)..."
        sc.exe config bits start= delayed-auto | Out-Null
        
        Set-Service -Name 'cryptsvc' -StartupType Automatic -ErrorAction SilentlyContinue

        foreach ($serviceName in $Services) {
            $Global:DiagMsg += "  -> Starting service: $serviceName"
            try {
                Start-Service -Name $serviceName -ErrorAction Stop
                $Global:DiagMsg += "     Service started successfully."
            }
            catch {
                $Global:DiagMsg += "     WARNING: Failed to start service."
            }
        }
    }
    finally {
        # IMPORTANT: Restore the original warning preference
        $WarningPreference = $OriginalWarningPreference
    }
}

function Run-SystemMaintenance {
    $Global:DiagMsg += "Running system component cleanup tasks..."
    $Global:DiagMsg += "  -> Running DISM to clean up the component store. This may take a while..."
    try {
        $dismProcess = Start-Process -FilePath "Dism.exe" -ArgumentList "/online /Cleanup-Image /StartComponentCleanup" -Wait -PassThru -NoNewWindow
        if ($dismProcess.ExitCode -eq 0) {
            $Global:DiagMsg += "     DISM cleanup completed successfully."
        }
        else {
            $Global:DiagMsg += "     WARNING: DISM process finished with exit code: $($dismProcess.ExitCode)."
        }
    }
    catch {
        $Global:DiagMsg += "     WARNING: An error occurred while running DISM."
    }
}


#---------------------------------------------------------------------------------------------------
#--- SCRIPT EXECUTION
#---------------------------------------------------------------------------------------------------

$Global:DiagMsg += "=================================================="
$Global:DiagMsg += "   Windows Update Reset Script (Comprehensive)"
$Global:DiagMsg += "=================================================="
$Global:DiagMsg += "This process will take several minutes to complete."

# 1. Initial State Audit
Get-SystemComponentState -RestoreToDefaults $true

# 2. Stop services
Stop-UpdateServices -Services $updateServices

# 3. Clean Caches and Backups
Clean-UpdateCacheAndBackups

# 4. Comprehensive Registry Reset
Reset-UpdateRegistryKeys

# 5. Re-register DLLs
Reregister-UpdateDlls -Dlls $dllsToRegister

# 6. Reset Network
Reset-NetworkComponents

# 7. Restart Services
Start-UpdateServices -Services $updateServices

# 8. Run Maintenance
Run-SystemMaintenance

# --- Completion Message ---
$Global:DiagMsg += "--------------------------------------------------"
$Global:DiagMsg += "Windows Update Reset process has completed."
$Global:DiagMsg += "Please review the output above for any warnings or errors."
$Global:DiagMsg += "A system reboot is recommended to ensure all changes take effect."

######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {    
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Info to be sent to into JSON POST to API Endpoint (Optional)
$APIinfoHashTable = @{
    'CS_PROFILE_UID' = $env:CS_PROFILE_UID
    'Script_Diag'    = $Global:DiagMsg
    'Script_UID'     = $ScriptUID
}
#######################################################################
### Exit script with proper Datto diagnostic and API Results.
# Add Script Result and POST to API if an Endpoint is Provided
if ($null -ne $env:APIEndpoint) {
    $Global:DiagMsg += " - Sending Results to API"
    Invoke-WebRequest -Uri $env:APIEndpoint -Method POST -Body ($APIinfoHashTable | ConvertTo-Json) -ContentType "application/json"
}
# Exit with writing diagnostic back to the ticket / remediation component log
write-DRMMDiag $Global:DiagMsg
Exit 0