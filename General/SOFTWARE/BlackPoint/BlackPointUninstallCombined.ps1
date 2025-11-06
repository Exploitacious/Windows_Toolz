# Script Title: Comprehensive BlackPoint Uninstaller (SNAP & ZTAC)
# Description: Provides a comprehensive, multi-step removal of ZTAC and optionally, BlackPoint SNAP Agent software, including services, processes, files, and registry keys.

# Script Name and Type
$ScriptName = "Comprehensive BlackPoint Uninstaller (SNAP & ZTAC)"
$ScriptType = "Remediation"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the final status to.
# uninstallOnlyZTAC (Checkbox): If 'true', only ZTAC will be uninstalled. If 'false', both SNAP and ZTAC will be uninstalled.
# enableLocalLogging (Checkbox): If 'true', create a local log file in C:\Temp\BPUninstall.log.

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$localLogDirectory = "C:\Temp"
$localLogFile = "C:\Temp\BPUninstall.log"
$snapAgentAppName = "SnapAgent"
$ztacAppName = "ZTAC"
$ztacDriverName = "ZtacFltr"
$bpInstallPath = "C:\Program Files (x86)\Blackpoint"
$bpProgramDataPath = "C:\ProgramData\Blackpoint"
$ztacProgramDataPath = "C:\ProgramData\Blackpoint\ZTAC"
$ztacDriverPath = "C:\Windows\System32\drivers\ZtacFltr.sys"

# Comprehensive list of registry keys for cleanup, derived from provided scripts
$Global:RegistryKeysToRemove = @(
    "HKLM:\SOFTWARE\Classes\Installer\Features\0E1D3F0C2B974FA4AA0418F12B055384",
    "HKLM:\SOFTWARE\Classes\Installer\Products\0E1D3F0C2B974FA4AA0418F12B055384",
    "HKLM:\SOFTWARE\Classes\Installer\Products\0E1D3F0C2B974FA4AA0418F12B055384\SourceList",
    "HKLM:\SOFTWARE\Classes\Installer\Products\0E1D3F0C2B974FA4AA0418F12B055384\SourceList\Media",
    "HKLM:\SOFTWARE\Classes\Installer\Products\0E1D3F0C2B974FA4AA0418F12B055384\SourceList\Net",
    "HKLM:\SOFTWARE\Classes\Installer\UpgradeCodes\7CF0653F8B24F2647B3A70510A96BEE6",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes\7CF0653F8B24F2647B3A70510A96BEE6",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\08C8C87010175A141912F6695F06EB95",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\5E3D36BBC4ADCA749AC6CC3774478B04",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\74A044CACC826754BB48542EA5681E4C",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\A3129D8FE202CCF47B233E82C70367D2",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\A73F059633BC8314597EE7F81A662796",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\C0016A60CBED93E41900FCBD4BC10AB4",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\DB4ABEA1DA4832048BCCF78860ADA944",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\F1AB931B4E8A02A4F8E5F828409E4DD1",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\F81ECEA5C9A7CA3409D05D38A602B11C",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\0E1D3F0C2B974FA4AA0418F12B055384",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\0E1D3F0C2B974FA4AA0418F12B055384\Features",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\0E1D3F0C2B974FA4AA0418F12B055384\InstallProperties",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\0E1D3F0C2B974FA4AA0418F12B055384\Patches",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\0E1D3F0C2B974FA4AA0418F12B055384\Usage",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{C0F3D1E0-79B2-4AF4-AA40-811FB2503548}",
    "HKLM:\SYSTEM\CurrentControlSet\Services\ZTAC",
    "HKLM:\SYSTEM\CurrentControlSet\Services\ZtacFltr"
)

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Blackpoint removal process completed successfully. | Last Checked $Date"

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
########### Functions ############

function Write-Log {
    param ([string]$message)
        
    $Global:DiagMsg += $message
        
    if ($enableLocalLogging) {
        try {
            if (-not (Test-Path $localLogDirectory)) {
                New-Item -Path $localLogDirectory -ItemType Directory -Force | Out-Null
            }
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content -Path $localLogFile -Value "$timestamp - $message"
        }
        catch {
            $Global:DiagMsg += "Warning: Failed to write to local log file: $($_.Exception.Message)"
        }
    }
}

function Check-Software-Installed {
    param (
        [string]$appName,
        [string]$serviceName
    )
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Log "CHECK: Found $appName (Service: $serviceName, Status: $($service.Status))"
    }
    else {
        Write-Log "CHECK: Did not find $appName (Service: $serviceName)"
    }
}

function Get-ProductGUIDs {
    param ([string]$programName)
        
    $uninstallPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    return $uninstallPaths | ForEach-Object {
        Get-ItemProperty -Path $_ -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$programName*" } |
        ForEach-Object {
            [PSCustomObject]@{
                DisplayName = $_.DisplayName
                GUID        = Split-Path $_.PSPath -Leaf
                PSPath      = $_.PSPath
            }
        }
    }
}

function Stop-And-Remove-Service {
    param ([string]$serviceName)
        
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Log "Service '$serviceName' found. Stopping..."
        try {
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            Write-Log "Service '$serviceName' stopped."
            Start-Sleep -Seconds 3
        }
        catch {
            Write-Log "Warning: Could not stop service '$serviceName'. It may already be stopped. $($_.Exception.Message)"
        }
            
        Write-Log "Removing service '$serviceName'..."
        try {
            sc.exe delete $serviceName | Out-Null
            Write-Log "Service '$serviceName' removed successfully."
        }
        catch {
            Write-Log "Error: Failed to remove service '$serviceName'. $($_.Exception.Message)"
            $Global:errorsEncountered = $true
        }
    }
    else {
        Write-Log "Service '$serviceName' not found. Skipping stop/remove."
    }
}

function Kill-Process {
    param ([string]$processName)
        
    $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($process) {
        Write-Log "Process '$processName' found. Terminating..."
        try {
            Stop-Process -Name $processName -Force -ErrorAction Stop
            Write-Log "Process '$processName' terminated."
        }
        catch {
            Write-Log "Error: Failed to terminate process '$processName'. $($_.Exception.Message)"
            $Global:errorsEncountered = $true
        }
    }
    else {
        Write-Log "Process '$processName' not running."
    }
}

function Schedule-FileForDelete {
    param ([string]$FilePath)
        
    Write-Log "Scheduling locked file for deletion on next reboot: $FilePath"
    $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $valueName = "PendingFileRenameOperations"
    try {
        $currentValue = Get-ItemProperty -Path $regKey -Name $valueName -ErrorAction SilentlyContinue
        $newValue = if ($null -ne $currentValue) { $currentValue.PendingFileRenameOperations } else { @() }
            
        $formattedPath = "\??\$FilePath"
        $newValue += $formattedPath, ""
            
        Set-ItemProperty -Path $regKey -Name $valueName -Value $newValue -Type MultiString -Force -ErrorAction Stop
        Write-Log "Successfully scheduled file for deletion."
    }
    catch {
        Write-Log "ERROR: Could not schedule file for deletion via registry. $($_.Exception.Message)"
        $Global:errorsEncountered = $true
    }
}

function Remove-Registry-Key-List {
    param ([string[]]$keyList)
        
    Write-Log "Starting comprehensive registry cleanup..."
    foreach ($key in $keyList) {
        try {
            if (Test-Path $key) {
                Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
                Write-Log "Deleted registry key: $key"
            }
            else {
                #Write-Log "Registry key not found (already clean): $key"
            }
        }
        catch {
            Write-Log "Error deleting registry key '$key': $($_.Exception.Message)"
            # Non-fatal, just log it.
        }
    }
    Write-Log "Registry cleanup finished."
}

function Uninstall-ZTAC {
    Write-Log "--- Starting ZTAC Uninstallation ---"
        
    # 1. Stop and remove services
    Stop-And-Remove-Service -serviceName "ZTAC"
    Stop-And-Remove-Service -serviceName $ztacDriverName
        
    # 2. Unload filter driver
    Write-Log "Attempting to unload filter driver: $ztacDriverName"
    fltmc.exe unload $ztacDriverName | Out-Null
        
    # 3. Attempt MSI uninstall
    $guids = Get-ProductGUIDs -programName $ztacAppName
    if ($guids) {
        Write-Log "Found ZTAC installation entries. Attempting MSI uninstall..."
        foreach ($entry in $guids) {
            Write-Log "Attempting to uninstall package with GUID: $($entry.GUID)"
            $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x$($entry.GUID) /quiet /norestart" -Wait -PassThru
            Write-Log "MSI uninstall for $($entry.GUID) finished with exit code: $($proc.ExitCode)"
        }
    }
    else {
        Write-Log "No ZTAC installation GUIDs found in registry."
    }
        
    # 4. Forcefully remove driver file
    if (Test-Path $ztacDriverPath) {
        Write-Log "Attempting to delete driver file: $ztacDriverPath"
        try {
            Remove-Item -Path $ztacDriverPath -Force -ErrorAction Stop
            Write-Log "Driver file deleted successfully."
        }
        catch {
            Write-Log "Failed to delete driver file immediately (likely locked)."
            Schedule-FileForDelete -FilePath $ztacDriverPath
        }
    }
    else {
        Write-Log "Driver file not found at $ztacDriverPath."
    }
        
    # 5. Remove ZTAC ProgramData folder
    if (Test-Path $ztacProgramDataPath) {
        Write-Log "Removing ZTAC ProgramData folder: $ztacProgramDataPath"
        Remove-Item -Path $ztacProgramDataPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Log "ZTAC ProgramData folder not found."
    }
        
    Write-Log "--- ZTAC Uninstallation Attempt Finished ---"
    $Global:removalSummary += "ZTAC removal attempted."
}

function Uninstall-SNAP {
    Write-Log "--- Starting SNAP Agent Uninstallation ---"
        
    # 1. Kill watcher process
    Kill-Process -processName "snapw"
        
    # 2. Stop and remove main service
    Stop-And-Remove-Service -serviceName "snap"
        
    # 3. Attempt MSI uninstall
    $guids = Get-ProductGUIDs -programName $snapAgentAppName
    if ($guids) {
        Write-Log "Found SNAP Agent installation entries. Attempting MSI uninstall..."
        foreach ($entry in $guids) {
            Write-Log "Attempting to uninstall package with GUID: $($entry.GUID)"
            $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x$($entry.GUID) /quiet /norestart" -Wait -PassThru
            Write-Log "MSI uninstall for $($entry.GUID) finished with exit code: $($proc.ExitCode)"
        }
    }
    else {
        Write-Log "No SNAP Agent installation GUIDs found in registry."
    }
        
    Write-Log "--- SNAP Agent Uninstallation Attempt Finished ---"
    $Global:removalSummary += "SNAP removal attempted."
}

function Cleanup-Shared-Items {
    Write-Log "--- Starting Shared Item Cleanup ---"
        
    # 1. Remove main install directory
    if (Test-Path $bpInstallPath) {
        Write-Log "Removing main Blackpoint install folder: $bpInstallPath"
        try {
            Remove-Item -Path $bpInstallPath -Recurse -Force -ErrorAction Stop
            Write-Log "Successfully removed $bpInstallPath"
        }
        catch {
            Write-Log "Error removing $bpInstallPath. It may be locked. $($_.Exception.Message)"
            $Global:errorsEncountered = $true
        }
    }
    else {
        Write-Log "Main install folder not found: $bpInstallPath"
    }

    # 2. Remove main ProgramData directory (catches any leftovers)
    if (Test-Path $bpProgramDataPath) {
        Write-Log "Removing main Blackpoint ProgramData folder: $bpProgramDataPath"
        try {
            Remove-Item -Path $bpProgramDataPath -Recurse -Force -ErrorAction Stop
            Write-Log "Successfully removed $bpProgramDataPath"
        }
        catch {
            Write-Log "Error removing $bpProgramDataPath. It may be locked. $($_.Exception.Message)"
            $Global:errorsEncountered = $true
        }
    }
    else {
        Write-Log "Main ProgramData folder not found: $bpProgramDataPath"
    }
        
    # 3. Run comprehensive registry cleanup
    Remove-Registry-Key-List -keyList $Global:RegistryKeysToRemove
        
    Write-Log "--- Shared Item Cleanup Finished ---"
    $Global:removalSummary += "Shared item cleanup attempted."
}

##################################
######## Start of Script #########

try {
    ## PARAMETER CASTING ##
    [bool]$uninstallOnlyZTAC = $env:uninstallOnlyZTAC -eq 'true'
    [bool]$enableLocalLogging = $env:enableLocalLogging -eq 'true'
    $Global:errorsEncountered = $false
    $Global:removalSummary = @()
    
    ## MAIN SCRIPT EXECUTION ##
    if ($enableLocalLogging) {
        Write-Log "Local logging enabled. Log file at: $localLogFile"
        Remove-Item -Path $localLogFile -ErrorAction SilentlyContinue
    }

    Write-Log "--- Pre-removal Check ---"
    Check-Software-Installed -appName "ZTAC" -serviceName "ZTAC"
    Check-Software-Installed -appName "SNAP Agent" -serviceName "snap"
    Write-Log "---------------------------"
    Write-Log "Beginning removal process..."
    Write-Log "Uninstall ZTAC Only: $uninstallOnlyZTAC"

    # Always uninstall ZTAC
    try {
        Uninstall-ZTAC
    }
    catch {
        Write-Log "An unexpected error occurred during ZTAC uninstall: $($_.Exception.Message)"
        $Global:errorsEncountered = $true
    }
    
    # Uninstall SNAP and shared files ONLY if the checkbox is false
    if (-not $uninstallOnlyZTAC) {
        Write-Log "Full removal selected. Proceeding with SNAP and shared item cleanup."
        
        try {
            Uninstall-SNAP
        }
        catch {
            Write-Log "An unexpected error occurred during SNAP uninstall: $($_.Exception.Message)"
            $Global:errorsEncountered = $true
        }

        try {
            Cleanup-Shared-Items
        }
        catch {
            Write-Log "An unexpected error occurred during shared item cleanup: $($_.Exception.Message)"
            $Global:errorsEncountered = $true
        }
    }
    else {
        Write-Log "Uninstall Only ZTAC selected. Skipping SNAP and shared item cleanup."
    }

    Write-Log "Blackpoint removal process finished."
    
    # Set final status message
    $finalSummary = $Global:removalSummary -join " "
    if ($Global:errorsEncountered) {
        $Global:AlertMsg = "Blackpoint removal finished with one or more errors. See diagnostics. | $Date"
        $Global:customFieldMessage = "Removal finished with errors: $($finalSummary) ($Date)"
    }
    else {
        $Global:AlertHealthy = "Blackpoint removal process completed successfully. $finalSummary | $Date"
        $Global:customFieldMessage = "Removal successful: $($finalSummary) ($Date)"
    }

}
catch {
    $Global:DiagMsg += "An unexpected script-level error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
    $Global:customFieldMessage = "Script failed with an unexpected error. ($Date)"
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