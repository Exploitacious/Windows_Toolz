# 
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "In-Place Upgrade W10 to W11 (Asynchronous Launch)" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:APIEndpoint = "https://prod-36.westus.logic.azure.com:443/workflows/6c032a1ca84045b9a7a1436864ecf696/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=c-dVa333HMzhWli_Fp_4IIAqaJOMwFjP2y5Zfv4j_zA"
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

<#
This Script is a Remediation compoenent, meaning it performs only one task with a log of granular detail. These task results can be added back ito tickets as time entries using the API. 

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message + ' `' }
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

#<#
#.SYNOPSIS
#    A PowerShell script to prepare a Windows 10 system for and initiate an in-place upgrade to Windows 11.
#    This script is designed to be resilient and run via RMM tools (as SYSTEM), requiring no user interaction.
#
#.NOTES
#    Author: Alex Ivantsov
#    Date:   June 27, 2025
#    Version: 1.3 - Changed to fire-and-forget model; script exits after launching the upgrade assistant.
#
#    DISCLAIMER: This script performs significant system modifications. It is highly recommended to test this script
#    in a controlled lab environment before deploying to production systems. The author is not responsible for any
#    data loss or system instability.
##>

#--------------------------------------------------------------------------------
# --- User-Modifiable Variables ---
#--------------------------------------------------------------------------------

# The URL for the official Microsoft Windows 11 Installation Assistant.
$Win11DownloadUrl = "https://go.microsoft.com/fwlink/?linkid=2171764"

# A robust temporary location for the installer. The script will create C:\Temp if it doesn't exist.
$InstallerTempDir = "C:\Temp\RMM_Upgrade_Temp"
$InstallerTempPath = Join-Path -Path $InstallerTempDir -ChildPath "Windows11InstallationAssistant.exe"

# Minimum system requirements for the prerequisite checks.
$MinimumRamGB = 4
$MinimumStorageGB = 64
$MinimumCpuCores = 2
$MinimumCpuSpeedGHz = 1.0

#--------------------------------------------------------------------------------
# --- Function Definitions ---
#--------------------------------------------------------------------------------

Function Remove-UpgradeBlockers {
    <#
    .SYNOPSIS
        Removes common software-based blockers that can prevent the Windows 11 upgrade.
    #>
    $Global:DiagMsg += "INFO: Stage 1 of 3: Removing potential upgrade blockers..."

    # --- 1.1: Registry Key Remediation ---
    $WindowsUpdatePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (Test-Path -Path $WindowsUpdatePolicyPath) {
        $Global:DiagMsg += "INFO: Found Windows Update policy key. Checking for release version locks..."
        $propertiesToRemove = @("TargetReleaseVersion", "TargetReleaseVersionInfo", "ProductVersion")
        foreach ($property in $propertiesToRemove) {
            if (Get-ItemProperty -Path $WindowsUpdatePolicyPath -Name $property -ErrorAction SilentlyContinue) {
                $Global:DiagMsg += "  - Removing registry value '$property'..."
                try { Remove-ItemProperty -Path $WindowsUpdatePolicyPath -Name $property -Force -ErrorAction Stop }
                catch { $Global:DiagMsg += "  - WARNING: Could not remove registry value '$property'. This may be due to permissions." }
            }
        }
    }
    else {
        $Global:DiagMsg += "INFO: Windows Update policy key not found."
    }

    # --- 1.2: Local Group Policy Reset ---
    $Global:DiagMsg += "INFO: Resetting local Group Policy objects for Windows Update..."
    try {
        $gpPathSystem = Join-Path -Path $env:SystemRoot -ChildPath "System32\GroupPolicy"
        $gpPathUsers = Join-Path -Path $env:SystemRoot -ChildPath "System32\GroupPolicyUsers"
        if (Test-Path $gpPathSystem) {
            $Global:DiagMsg += "  - Removing policy files from '$gpPathSystem'..."
            Remove-Item -Path "$gpPathSystem\*" -Recurse -Force -ErrorAction Stop
        }
        if (Test-Path $gpPathUsers) {
            $Global:DiagMsg += "  - Removing policy files from '$gpPathUsers'..."
            Remove-Item -Path "$gpPathUsers\*" -Recurse -Force -ErrorAction Stop
        }
        gpupdate /force
        $Global:DiagMsg += "INFO: Local Group Policy reset and refresh complete."
    }
    catch {
        $Global:DiagMsg += "WARN: Failed to reset local Group Policy. This might not be critical."
    }

    # --- 1.3: Windows Update Service and Component Reset ---
    $Global:DiagMsg += "INFO: Resetting Windows Update components..."
    $services = @("wuauserv", "bits")
    foreach ($service in $services) {
        $Global:DiagMsg += "  - Stopping service '$service'..."
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
    }

    try {
        $softwareDistPath = Join-Path -Path $env:SystemRoot -ChildPath "SoftwareDistribution"
        $catroot2Path = Join-Path -Path $env:SystemRoot -ChildPath "System32\catroot2"
        if (Test-Path $softwareDistPath) {
            $Global:DiagMsg += "  - Renaming '$softwareDistPath'..."
            Rename-Item -Path $softwareDistPath -NewName "SoftwareDistribution.old" -Force -ErrorAction Stop
        }
        if (Test-Path $catroot2Path) {
            $Global:DiagMsg += "  - Renaming '$catroot2Path'..."
            Rename-Item -Path $catroot2Path -NewName "catroot2.old" -Force -ErrorAction Stop
        }
        $Global:DiagMsg += "INFO: Windows Update cache folders successfully renamed."
    }
    catch {
        $Global:DiagMsg += "WARN: Could not rename Windows Update folders. They may be in use."
    }

    foreach ($service in $services) {
        $Global:DiagMsg += "  - Starting service '$service'..."
        Start-Service -Name $service
    }
}

Function Test-SystemPrerequisites {
    <#
    .SYNOPSIS
        Checks if the system meets the minimum requirements for Windows 11.
    #>
    $Global:DiagMsg += "INFO: Stage 2 of 3: Performing pre-flight readiness checks..."
    $allChecksPassed = $true

    # --- 2.1: TPM Check ---
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        if ($tpm.TpmPresent -and $tpm.TpmReady) { $Global:DiagMsg += "  - PASSED: TPM is present and ready." }
        else { $Global:DiagMsg += "  - FAILED: TPM not ready. (Present: $($tpm.TpmPresent), Ready: $($tpm.TpmReady))"; $allChecksPassed = $false }
    }
    catch { $Global:DiagMsg += "  - FAILED: Could not retrieve TPM status."; $allChecksPassed = $false }
    
    # --- 2.2: Secure Boot Check ---
    try {
        if ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -Name "UEFISecureBootEnabled").UEFISecureBootEnabled -eq 1) { $Global:DiagMsg += "  - PASSED: Secure Boot is enabled." }
        else { $Global:DiagMsg += "  - FAILED: Secure Boot is disabled."; $allChecksPassed = $false }
    }
    catch { $Global:DiagMsg += "  - FAILED: Could not verify Secure Boot status."; $allChecksPassed = $false }
    
    # --- 2.3: RAM Check ---
    $totalRamGB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    if ($totalRamGB -ge $MinimumRamGB) { $Global:DiagMsg += "  - PASSED: System has $totalRamGB GB RAM (Minimum: $MinimumRamGB GB)." }
    else { $Global:DiagMsg += "  - FAILED: System has $totalRamGB GB RAM (Minimum: $MinimumRamGB GB)."; $allChecksPassed = $false }

    # --- 2.4: Storage Check ---
    $freeSpaceGB = [math]::Round((Get-PSDrive -Name $env:SystemDrive.Substring(0, 1)).Free / 1GB, 2)
    if ($freeSpaceGB -ge $MinimumStorageGB) { $Global:DiagMsg += "  - PASSED: System drive has $freeSpaceGB GB free space (Minimum: $MinimumStorageGB GB)." }
    else { $Global:DiagMsg += "  - FAILED: System drive has $freeSpaceGB GB free space (Minimum: $MinimumStorageGB GB)."; $allChecksPassed = $false }

    # --- 2.5: CPU Check ---
    $processor = Get-CimInstance -ClassName Win32_Processor
    $coreCount = $processor.NumberOfCores
    $cpuSpeed = $processor.MaxClockSpeed / 1000
    if (($coreCount -ge $MinimumCpuCores) -and ($cpuSpeed -ge $MinimumCpuSpeedGHz)) { $Global:DiagMsg += "  - PASSED: CPU has $coreCount cores @ $cpuSpeed GHz." }
    else { $Global:DiagMsg += "  - FAILED: CPU does not meet requirements (Cores: $coreCount, Speed: $cpuSpeed GHz)."; $allChecksPassed = $false }

    return $allChecksPassed
}

Function Start-WindowsUpgrade {
    <#
    .SYNOPSIS
        Downloads and executes the Windows 11 Installation Assistant, then exits.
    #>
    $Global:DiagMsg += "INFO: Stage 3 of 3: Initiating Windows 11 upgrade..."

    # --- 3.1: Download Installation Assistant ---
    try {
        # Ensure the parent C:\Temp directory exists
        if (-not (Test-Path -Path "C:\Temp" -PathType Container)) {
            $Global:DiagMsg += "INFO: C:\Temp not found. Creating it now..."
            New-Item -Path "C:\" -Name "Temp" -ItemType Directory -Force -ErrorAction Stop
        }
        
        $Global:DiagMsg += "INFO: Preparing temporary directory at '$InstallerTempDir'..."
        if (-not (Test-Path -Path $InstallerTempDir)) {
            New-Item -Path $InstallerTempDir -ItemType Directory -Force -ErrorAction Stop
        }
        
        $Global:DiagMsg += "INFO: Downloading Windows 11 Installation Assistant from '$Win11DownloadUrl'..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Win11DownloadUrl -OutFile $InstallerTempPath -ErrorAction Stop
        $Global:DiagMsg += "INFO: Download complete. Installer saved to '$InstallerTempPath'."
    }
    catch {
        $Global:DiagMsg += "FATAL: Failed to create directory or download the Installation Assistant. Error: $_"
        return # Exit the function
    }

    # --- 3.2: Execute Silent Upgrade (Fire and Forget) ---
    $arguments = "/QuietInstall /SkipEULA /NoRestartUI"
    $Global:DiagMsg += "INFO: Launching the silent upgrade process with arguments: '$arguments'."
    try {
        # Launch the process without -Wait, so the script can continue and exit.
        Start-Process -FilePath $InstallerTempPath -ArgumentList $arguments -NoNewWindow -ErrorAction Stop
        
        # If we get here, the process was launched successfully.
        $Global:DiagMsg += "SUCCESS: The upgrade assistant has been launched. The script will now exit and the upgrade will continue in the background."
    }
    catch {
        $Global:DiagMsg += "FATAL: An error occurred while trying to launch the Installation Assistant: $_"
    }
    finally {
        # Clean up the downloaded installer and temporary directory.
        # This is safe because the installer is copied to another location by the OS to run.
        if (Test-Path -Path $InstallerTempDir) {
            $Global:DiagMsg += "INFO: Cleaning up temporary directory..."
            Remove-Item -Path $InstallerTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

#--------------------------------------------------------------------------------
# --- Main Script Execution ---
#--------------------------------------------------------------------------------

# Execute Stage 1: Remove Blockers
Remove-UpgradeBlockers

# Execute Stage 2: Prerequisite Checks
if (-not (Test-SystemPrerequisites)) {
    $Global:DiagMsg += "FATAL: System prerequisites not met. Aborting upgrade process."
}
else {
    $Global:DiagMsg += "SUCCESS: All system prerequisites passed."
    # Execute Stage 3: Start the Upgrade
    Start-WindowsUpgrade
}

$Global:DiagMsg += "------------------------------------------------------------------"
$Global:DiagMsg += "Script execution finished."
$Global:DiagMsg += "------------------------------------------------------------------"

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