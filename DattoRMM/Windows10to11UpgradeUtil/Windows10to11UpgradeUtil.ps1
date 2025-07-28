#
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "In-Place Upgrade to Windows 11" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:APIEndpoint = "https://prod-36.westus.logic.azure.com:443/workflows/6c032a1ca84045b9a7a1436864ecf696/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=c-dVa333HMzhWli_Fp_4IIAqaJOMwFjP2y5Zfv4j_zA"
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrOverrideChecks = $false # Datto User Input variable "usrOverrideChecks"

<#
This Script is a Remediation compoenent, meaning it performs only one task with a log of granular detail. These task results can be added back ito tickets as time entries using the API. 

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
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
    A script to automate the in-place upgrade of a Windows 10 device to the latest version of Windows 11.

.DESCRIPTION
    This script modifies the system power plan to prevent sleep/hibernation, performs pre-flight checks,
    clears upgrade blockers, and starts the Windows 11 upgrade. It creates a RunOnce task to restore
    the original power settings after the first reboot.
    
.AUTHOR
    Alex Ivantsov

.DATE
    July 18, 2025
#>

# =================================================================================================
#                                       USER-CONFIGURABLE VARIABLES
# =================================================================================================

# Set this to $true in the Datto RMM Component variables to allow the script to continue even if a blocking error is encountered.
# WARNING: Overriding checks is not recommended and can lead to unpredictable results.
if (-not ($env:usrOverrideChecks)) {
    [boolean]$env:usrOverrideChecks = $false
}


# =================================================================================================
#                                       FUNCTION DEFINITIONS
# =================================================================================================

Function Handle-BlockingError {
    <#
    .SYNOPSIS
        Handles blocking errors by either exiting the script or allowing it to continue if the override flag is set.
    #>
    param (
        [string]$ErrorMessage
    )

    Write-Host "`n! ERROR: $ErrorMessage" -ForegroundColor Red

    if ([System.Convert]::ToBoolean($env:usrOverrideChecks)) {
        Write-Host "! A blocking error was encountered, but the 'usrOverrideChecks' flag is enabled." -ForegroundColor Yellow
        Write-Host "  The script will proceed. Support cannot assist with issues arising from this override." -ForegroundColor Yellow
    }
    else {
        Write-Host "! This is a blocking error, and the operation has been aborted." -ForegroundColor Red
        Write-Host "  To ignore this error, set the `$usrOverrideChecks` variable to `$true` and re-run the script."
        Write-Host "  Stopping any existing setup processes..."
        
        Stop-Process -Name 'setupHost', 'mediaTool', 'Windows10UpgraderApp', 'installAssistant' -ErrorAction SilentlyContinue -Force
        
        # Stop script and report failure back to Datto RMM
        $Global:DiagMsg += "! SCRIPT FAILED: $ErrorMessage"
        write-DRMMDiag $Global:DiagMsg
        exit 1
    }
}

Function Set-PowerPlanForUpgrade {
    <#
    .SYNOPSIS
        Gets current power settings, sets them to 'Never' to prevent sleep/hibernate,
        and creates a RunOnce scheduled task to revert the settings after reboot.
    #>
    $Global:DiagMsg += "`n- Configuring power plan to prevent sleep during upgrade..."

    try {
        # Function to get current setting value in minutes by parsing powercfg output
        function Get-PowerSettingMinutes($SettingAlias) {
            $acValue = (powercfg -q | Select-String "($($SettingAlias))" -Context 0, 2 | Select-String "Current AC" | Out-String -Stream).Trim().Split(' ')[-1]
            $dcValue = (powercfg -q | Select-String "($($SettingAlias))" -Context 0, 2 | Select-String "Current DC" | Out-String -Stream).Trim().Split(' ')[-1]
            
            # Convert hex seconds to decimal minutes
            $acMinutes = ([System.Convert]::ToInt32($acValue, 16)) / 60
            $dcMinutes = ([System.Convert]::ToInt32($dcValue, 16)) / 60
            
            return @{ AC = $acMinutes; DC = $dcMinutes }
        }

        # Get original values using their well-known GUID aliases
        $originalStandby = Get-PowerSettingMinutes -SettingAlias "STANDBYIDLE"
        $originalHibernate = Get-PowerSettingMinutes -SettingAlias "HIBERNATEIDLE"

        $Global:DiagMsg += "  Original Standby Timeout (Minutes) - AC: $($originalStandby.AC), DC: $($originalStandby.DC)"
        $Global:DiagMsg += "  Original Hibernate Timeout (Minutes) - AC: $($originalHibernate.AC), DC: $($originalHibernate.DC)"
        
        # Set new values to Never (0 minutes)
        $Global:DiagMsg += "  Setting Standby and Hibernate timeouts to 'Never'..."
        powercfg /change -standby-timeout-ac 0
        powercfg /change -standby-timeout-dc 0
        powercfg /change -hibernate-timeout-ac 0
        powercfg /change -hibernate-timeout-dc 0

        # Create the cleanup script that will be run once after reboot
        $cleanupScriptPath = "C:\Windows\Temp\ResetPowerPlan.ps1"
        $cleanupScriptContent = @"
# This script is run once automatically after reboot to restore original power settings.

Write-Host "Restoring original power settings..."
powercfg /change -standby-timeout-ac $($originalStandby.AC)
powercfg /change -standby-timeout-dc $($originalStandby.DC)
powercfg /change -hibernate-timeout-ac $($originalHibernate.AC)
powercfg /change -hibernate-timeout-dc $($originalHibernate.DC)
Write-Host "Power settings restored."

# Self-destruct the script file
Remove-Item -Path "`$($MyInvocation.MyCommand.Definition)" -Force
"@

        $cleanupScriptContent | Out-File -FilePath $cleanupScriptPath -Encoding ascii -Force
        $runOnceCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$cleanupScriptPath`""
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "ResetWinUpgradePowerPlan" -Value $runOnceCommand -Force
        $Global:DiagMsg += "  SUCCESS: Created RunOnce task to restore power settings on next boot."
    }
    catch {
        $Global:DiagMsg += "  ERROR: Failed to configure power settings. The upgrade will continue, but the device may sleep. Error: $($_.Exception.Message)"
        # This is not a blocking error.
    }
}

Function Invoke-DownloadWithRedirect {
    <#
    .SYNOPSIS
        Downloads a file from a URL that may use a shortlink or redirect.
    #>
    param (
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$DestinationFile,
        [string]$WhitelistDomain
    )

    $Global:DiagMsg += "`n- Attempting to download file from '$Url'..."

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Method = "HEAD"
        $response = $request.GetResponse()
        
        $finalUrl = $response.ResponseURI.AbsoluteURI
        $response.Close()

        $Global:DiagMsg += "  Redirected to: $finalUrl"

        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($finalUrl, $DestinationFile)

        if (Test-Path $DestinationFile) {
            $fileName = Split-Path -Path $DestinationFile -Leaf
            $Global:DiagMsg += "  SUCCESS: Downloaded '$fileName' successfully."
        }
        else {
            $errorMessage = "File could not be downloaded."
            if ($WhitelistDomain) { $errorMessage += " Please ensure '$WhitelistDomain' is whitelisted in your firewall." }
            Handle-BlockingError -ErrorMessage $errorMessage
        }
    }
    catch {
        $errorMessage = "An error occurred during download: $($_.Exception.Message)"
        if ($WhitelistDomain) { $errorMessage += " Please ensure '$WhitelistDomain' is whitelisted." }
        Handle-BlockingError -ErrorMessage $errorMessage
    }
}

Function Test-AuthenticodeSignature {
    <#
    .SYNOPSIS
        Verifies the Authenticode digital signature of a file against a known certificate thumbprint.
    #>
    param (
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$ExpectedCertSubject,
        [Parameter(Mandatory = $true)][string]$ExpectedThumbprint,
        [Parameter(Mandatory = $true)][string]$AppName
    )

    $Global:DiagMsg += "`n- Verifying digital signature for '$AppName'..."

    if (!(Test-Path -Path $FilePath)) {
        Handle-BlockingError -ErrorMessage "File '$FilePath' not found for signature verification."
        return
    }

    try {
        $signature = Get-AuthenticodeSignature -FilePath $FilePath
        
        $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
        $chain.Build($signature.SignerCertificate) | Out-Null
        
        $intermediateCert = $chain.ChainElements | ForEach-Object { $_.Certificate } | Where-Object { $_.Subject -like "*$ExpectedCertSubject*" }
        
        if ($intermediateCert.Thumbprint -eq $ExpectedThumbprint) {
            $Global:DiagMsg += "  SUCCESS: Digital signature verification passed."
        }
        else {
            $errorMessage = "Digital signature thumbprint mismatch for '$AppName'."
            $Global:DiagMsg += "  Expected: $ExpectedThumbprint"
            $Global:DiagMsg += "  Received: $($intermediateCert.Thumbprint)"
            Handle-BlockingError -ErrorMessage $errorMessage
        }
    }
    catch {
        $errorMessage = "Failed to validate the certificate for '$AppName'. The file may be corrupt or untrusted. Error: $($_.Exception.Message)"
        Handle-BlockingError -ErrorMessage $errorMessage
    }
}

Function Clear-UpgradeBlockers {
    <#
    .SYNOPSIS
        Removes common software-based blockers that can prevent the Windows 11 upgrade.
    #>
    $Global:DiagMsg += "`n- Removing potential software and policy-based upgrade blockers..."

    # --- 1. Registry Key Remediation ---
    $windowsUpdatePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (Test-Path -Path $windowsUpdatePolicyPath) {
        $Global:DiagMsg += "  [1/3] Found Windows Update policy key. Checking for release version locks..."
        $propertiesToRemove = @("TargetReleaseVersion", "TargetReleaseVersionInfo", "ProductVersion")
        foreach ($property in $propertiesToRemove) {
            if (Get-ItemProperty -Path $windowsUpdatePolicyPath -Name $property -ErrorAction SilentlyContinue) {
                $Global:DiagMsg += "    - Removing registry value '$property'..."
                try { Remove-ItemProperty -Path $windowsUpdatePolicyPath -Name $property -Force -ErrorAction Stop } catch { $Global:DiagMsg += "    - WARN: Could not remove registry value '$property'." }
            }
        }
    }
    else { $Global:DiagMsg += "  [1/3] Windows Update policy key not found." }

    # --- 2. Windows Update Service and Component Reset ---
    $Global:DiagMsg += "  [2/3] Resetting Windows Update components..."
    $servicesToReset = @("wuauserv", "bits")
    $softwareDistPath = Join-Path -Path $env:SystemRoot -ChildPath "SoftwareDistribution"
    $catroot2Path = Join-Path -Path $env:SystemRoot -ChildPath "System32\catroot2"
    $servicesToReset | ForEach-Object { $Global:DiagMsg += "    - Stopping service '$_'..."; Stop-Service -Name $_ -Force -ErrorAction SilentlyContinue }
    try {
        if (Test-Path $softwareDistPath) { Rename-Item -Path $softwareDistPath -NewName "SoftwareDistribution.old" -Force -ErrorAction Stop }
        if (Test-Path $catroot2Path) { Rename-Item -Path $catroot2Path -NewName "catroot2.old" -Force -ErrorAction Stop }
        $Global:DiagMsg += "    - Successfully renamed Windows Update cache folders."
    }
    catch { $Global:DiagMsg += "    - WARN: Could not rename Windows Update folders." }
    $servicesToReset | ForEach-Object { $Global:DiagMsg += "    - Starting service '$_'..."; Start-Service -Name $_ }
    
    # --- 3. Local Group Policy Reset ---
    $Global:DiagMsg += "  [3/3] Resetting local Group Policy objects..."
    try {
        $gpPathSystem = Join-Path -Path $env:SystemRoot -ChildPath "System32\GroupPolicy"
        $gpPathUsers = Join-Path -Path $env:SystemRoot -ChildPath "System32\GroupPolicyUsers"
        if (Test-Path $gpPathSystem) { Remove-Item -Path "$gpPathSystem\*" -Recurse -Force -ErrorAction Stop }
        if (Test-Path $gpPathUsers) { Remove-Item -Path "$gpPathUsers\*" -Recurse -Force -ErrorAction Stop }
        gpupdate /force | Out-Null
        $Global:DiagMsg += "    - Local Group Policy reset and refresh complete."
    }
    catch { $Global:DiagMsg += "    - WARN: Failed to reset local Group Policy." }
}

Function Start-UpgradeProcess {
    <#
    .SYNOPSIS
        Starts the Windows 11 Installation Assistant with silent parameters.
    #>
    param ( [Parameter(Mandatory = $true)][string]$InstallerPath )
    
    $Global:DiagMsg += "`n- Starting the Windows 11 Installation Assistant..."
    $Global:DiagMsg += "  This process will run in the background. The script will wait for 2 minutes to confirm it has started."
    try {
        $arguments = "/quietinstall /skipeula /auto upgrade"
        Start-Process -FilePath $InstallerPath -ArgumentList $arguments
        $Global:DiagMsg += "  Installer launched successfully. Waiting to verify activity..."
        Start-Sleep -Seconds 120
    }
    catch { Handle-BlockingError -ErrorMessage "Failed to start the installer process. Error: $($_.Exception.Message)" }
}

Function Confirm-UpgradeIsRunning {
    <#
    .SYNOPSIS
        Confirms that the upgrade is running by checking for the installer's download files.
    #>
    $Global:DiagMsg += "`n- Confirming installer activity..."
    $configIniPath = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "WindowsInstallationAssistant\Configuration.ini"
    if (!(Test-Path $configIniPath)) { Handle-BlockingError -ErrorMessage "Installer 'Configuration.ini' not found."; return }
    $downloadFolderPath = (Select-String -Path $configIniPath -Pattern "DownloadESDFolder").Line.Split('=')[1]
    if ([string]::IsNullOrWhiteSpace($downloadFolderPath)) { Handle-BlockingError -ErrorMessage "Could not read ESD download folder path."; return }
    $esdFile = Get-ChildItem -Path "$downloadFolderPath*.esd" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$esdFile) { Handle-BlockingError -ErrorMessage "Could not find installer's ESD download file."; return }
    $tenMinutesAgo = (Get-Date).AddMinutes(-10)
    if ($esdFile.LastWriteTime -lt $tenMinutesAgo) { Handle-BlockingError -ErrorMessage "Installer download appears to have stalled." }
    else { $Global:DiagMsg += "  SUCCESS: Active ESD file found. The upgrade process is running." ; $Global:DiagMsg += "  ESD Location: $($esdFile.FullName)" }
}


# =================================================================================================
#                                       MAIN SCRIPT EXECUTION
# =================================================================================================

$Global:DiagMsg += "==============================================================================="
$Global:DiagMsg += "  Windows 11 Upgrade Tool"
$Global:DiagMsg += "==============================================================================="

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- Power Plan Configuration ---
Set-PowerPlanForUpgrade

# --- System Information Gathering ---
$Global:DiagMsg += "`n- Gathering system information..."
$winBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
$osInfo = Get-WmiObject -Class Win32_OperatingSystem
$processorInfo = Get-WmiObject -Class Win32_Processor
$tpmInfo = Get-WmiObject -Class Win32_TPM -Namespace "root\CIMV2\Security\MicrosoftTpm" -ErrorAction SilentlyContinue
$Global:DiagMsg += "  Hostname:          $($env:COMPUTERNAME)"
$Global:DiagMsg += "  Windows Version:   $($osInfo.Caption) (Build $winBuild)"
$Global:DiagMsg += "  Architecture:      $($processorInfo.Architecture | ForEach-Object { @{ 9 = '64-bit (x64)'; 0 = '32-bit (x86)' }[$_] })"
if ([System.Convert]::ToBoolean($env:usrOverrideChecks)) { $Global:DiagMsg += "  Override Mode:     Enabled" }

# --- Pre-Flight Eligibility Checks ---
$Global:DiagMsg += "`n- Starting device hardware and OS eligibility checks..."
$supportedSkus = @(4, 27, 48, 49, 98, 99, 100, 101, 161, 162) 
if ($osInfo.OperatingSystemSKU -in $supportedSkus) { $Global:DiagMsg += "  [PASS] Windows SKU is supported." } else { Handle-BlockingError -ErrorMessage "Windows SKU ($($osInfo.OperatingSystemSKU)) is not supported." }
if ($processorInfo.Architecture -ne 9) { Handle-BlockingError -ErrorMessage "A 64-bit (x64) processor is required." } else { $Global:DiagMsg += "  [PASS] 64-bit OS and processor detected." }
if ([int]$winBuild -lt 19041) { Handle-BlockingError -ErrorMessage "Windows 10 Version 2004 (Build 19041) or higher is required." } else { $Global:DiagMsg += "  [PASS] Windows build ($winBuild) meets minimum requirement." }
$licenseStatus = (Get-WmiObject SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -and $_.Name -like '*Windows(R)*' } | Select-Object -First 1).LicenseStatus
if ($licenseStatus -ne 1) { Handle-BlockingError -ErrorMessage "Windows is not properly licensed or activated." } else { $Global:DiagMsg += "  [PASS] Windows license is valid and activated." }
$systemDrive = Get-WmiObject -Class Win32_Volume | Where-Object { $_.DriveLetter -eq $env:SystemDrive }
$freeSpaceGB = [Math]::Round($systemDrive.FreeSpace / 1GB)
if ($freeSpaceGB -lt 20) { Handle-BlockingError -ErrorMessage "Insufficient disk space. 20 GB required, $freeSpaceGB GB available." } else { $Global:DiagMsg += "  [PASS] Sufficient disk space available ($freeSpaceGB GB)." }
$totalRamGB = (Get-WmiObject -Class "CIM_PhysicalMemory" | Measure-Object -Property Capacity -Sum).Sum / 1GB
if ($totalRamGB -lt 4) { Handle-BlockingError -ErrorMessage "Insufficient RAM. 4 GB required, $([Math]::Round($totalRamGB, 2)) GB detected." } else { $Global:DiagMsg += "  [PASS] Sufficient RAM installed ($([Math]::Round($totalRamGB, 2)) GB)." }
if (!$tpmInfo) { Handle-BlockingError -ErrorMessage "TPM not found or disabled in BIOS/UEFI." } elseif (!($tpmInfo.IsEnabled().IsEnabled)) { Handle-BlockingError -ErrorMessage "TPM is present but disabled in Windows." } elseif (!($tpmInfo.IsActivated().IsActivated)) { Handle-BlockingError -ErrorMessage "TPM is present and enabled, but not activated." } else { $Global:DiagMsg += "  [PASS] TPM is present, enabled, and activated." }
$staleInstallDir = Join-Path -Path $env:SystemDrive -ChildPath "\`$WINDOWS.~WS"
if (Test-Path $staleInstallDir) { Handle-BlockingError -ErrorMessage "Remains of a previous Windows installation found at '$staleInstallDir'." } else { $Global:DiagMsg += "  [PASS] No conflicting previous installation directories found." }
$Global:DiagMsg += "`n- Applying pre-flight configurations..."
try { Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "ServicesPipeTimeout" -Value 300000 -Type DWord -Force; $Global:DiagMsg += "  [OK] Service pipe timeout set to 5 minutes." } catch { $Global:DiagMsg += "  [WARN] Could not set service pipe timeout." }
$Global:DiagMsg += "`nSUCCESS: All eligibility checks passed."
$Global:DiagMsg += "==============================================================================="

# --- Clear Potential Blockers ---
Clear-UpgradeBlockers

# --- Download and Execution ---
$Global:DiagMsg += "`nSUCCESS: System prepared. Proceeding with upgrade."
$Global:DiagMsg += "==============================================================================="
$installerFile = Join-Path -Path $scriptDir -ChildPath "installAssistant.exe"
Invoke-DownloadWithRedirect -Url "https://go.microsoft.com/fwlink/?linkid=2171764" -DestinationFile $installerFile -WhitelistDomain "download.microsoft.com"
Test-AuthenticodeSignature -FilePath $installerFile -ExpectedCertSubject "Microsoft Code Signing PCA" -ExpectedThumbprint "F252E794FE438E35ACE6E53762C0A234A2C52135" -AppName "Windows 11 Installation Assistant"
Start-UpgradeProcess -InstallerPath $installerFile
Confirm-UpgradeIsRunning

# --- Final Message ---
$Global:DiagMsg += "==============================================================================="
$Global:DiagMsg += "`n- The Windows 11 upgrade has been successfully initiated."
$Global:DiagMsg += "  A cleanup task has been created to restore power settings after reboot."
$Global:DiagMsg += "  The device will reboot automatically to complete the installation."
$Global:DiagMsg += "  This script's task is now complete."
$Global:DiagMsg += "==============================================================================="

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