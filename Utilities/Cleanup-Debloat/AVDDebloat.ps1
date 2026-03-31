<#
.SYNOPSIS
    This script optimizes a Windows 10 system, primarily for Virtual Desktop Infrastructure (VDI) environments.
    It removes specified AppX packages, disables services, disables scheduled tasks, and applies various user
    and system settings to improve performance.

.DESCRIPTION
    The script automates the process of system "debloating" by leveraging the "Virtual-Desktop-Optimization-Tool"
    from GitHub. It first downloads the tool, then dynamically generates configuration files based on the
    variables defined in this script. Finally, it executes the optimization tool with the custom configurations
    and cleans up afterward.

    All configurations are meant to be edited in the "USER-CONFIGURABLE VARIABLES" section. No parameters are required to run the script.

.NOTES
    Author: Alex Ivantsov
    Date:   June 11, 2025
    Version: 1.0
    Requirements: PowerShell 5.1. Runs without any external modules.
#>

#------------------------------------------------------------------------------------------------------------------
# SCRIPT CONFIGURATION
#------------------------------------------------------------------------------------------------------------------

# Set strict mode to catch common scripting errors
Set-StrictMode -Version Latest

# Stop the script if any command fails
$ErrorActionPreference = 'Stop'

#------------------------------------------------------------------------------------------------------------------
# USER-CONFIGURABLE VARIABLES
#------------------------------------------------------------------------------------------------------------------
# Instructions:
# - To KEEP an item (App, Service, etc.), delete the entire line it is on.
# - To REMOVE an item, ensure it is listed below.

# --- Target Windows Version ---
# The version folder within the optimization tool to use. '2009' corresponds to Windows 10 20H2.
$TargetWindowsVersion = '2009'

# --- Appx Packages to Remove ---
# List each AppX package to be removed on a new line. The format should be "PackageName,URL".
# The URL is for reference and does not affect the script's execution.
$AppxPackagesToRemove = @"
Microsoft.BingWeather,"https://www.microsoft.com/en-us/p/msn-weather/9wzdncrfj3q2"
Microsoft.GetHelp,"https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/customize-get-help-app"
Microsoft.Getstarted,"https://www.microsoft.com/en-us/p/microsoft-tips/9wzdncrdtbjj"
Microsoft.Messaging,"https://www.microsoft.com/en-us/p/microsoft-messaging/9wzdncrfjbq6"
Microsoft.MicrosoftOfficeHub,"https://www.microsoft.com/en-us/p/office/9wzdncrd29v9"
Microsoft.MicrosoftSolitaireCollection,"https://www.microsoft.com/en-us/p/microsoft-solitaire-collection/9wzdncrfhwd2"
Microsoft.MicrosoftStickyNotes,"https://www.microsoft.com/en-us/p/microsoft-sticky-notes/9nblggh4qghw"
Microsoft.MixedReality.Portal,"https://www.microsoft.com/en-us/p/mixed-reality-portal/9ng1h8b3zc7m"
Microsoft.Office.OneNote,"https://www.microsoft.com/en-us/p/onenote/9wzdncrfhvjl"
Microsoft.People,"https://www.microsoft.com/en-us/p/microsoft-people/9nblggh10pg8"
Microsoft.Print3D,"https://www.microsoft.com/en-us/p/print-3d/9pbpch085s3s"
Microsoft.SkypeApp,"https://www.microsoft.com/en-us/p/skype/9wzdncrfj364"
Microsoft.Wallet,"https://www.microsoft.com/en-us/payments"
Microsoft.Windows.Photos,"https://www.microsoft.com/en-us/p/microsoft-photos/9wzdncrfjbh4"
Microsoft.Microsoft3DViewer,"https://www.microsoft.com/en-us/p/3d-viewer/9nblggh42ths"
Microsoft.WindowsAlarms,"https://www.microsoft.com/en-us/p/windows-alarms-clock/9wzdncrfj3pr"
Microsoft.WindowsCalculator,"https://www.microsoft.com/en-us/p/windows-calculator/9wzdncrfhvn5"
Microsoft.WindowsCamera,"https://www.microsoft.com/en-us/p/windows-camera/9wzdncrfjbbg"
microsoft.windowscommunicationsapps,"https://www.microsoft.com/en-us/p/mail-and-calendar/9wzdncrfhvqm"
Microsoft.WindowsFeedbackHub,"https://www.microsoft.com/en-us/p/feedback-hub/9nblggh4r32n"
Microsoft.WindowsMaps,"https://www.microsoft.com/en-us/p/windows-maps/9wzdncrdtbvb"
Microsoft.WindowsSoundRecorder,"https://www.microsoft.com/en-us/p/windows-voice-recorder/9wzdncrfhwkn"
Microsoft.Xbox.TCUI,"https://docs.microsoft.com/en-us/gaming/xbox-live/features/general/tcui/live-tcui-overview"
Microsoft.XboxApp,"https://www.microsoft.com/store/apps/9wzdncrfjbd8"
Microsoft.XboxGameOverlay,"https://www.microsoft.com/en-us/p/xbox-game-bar/9nzkpstsnw4p"
Microsoft.XboxGamingOverlay,"https://www.microsoft.com/en-us/p/xbox-game-bar/9nzkpstsnw4p"
Microsoft.XboxIdentityProvider,"https://www.microsoft.com/en-us/p/xbox-identity-provider/9wzdncrd1hkw"
Microsoft.XboxSpeechToTextOverlay,"https://support.xbox.com/help/account-profile/accessibility/use-game-chat-transcription"
Microsoft.YourPhone,"https://www.microsoft.com/en-us/p/Your-phone/9nmpj99vjbwv"
Microsoft.ZuneMusic, "https://www.microsoft.com/en-us/p/groove-music/9wzdncrfj3pt"
Microsoft.ZuneVideo,"https://www.microsoft.com/en-us/p/movies-tv/9wzdncrfj3p2"
Microsoft.ScreenSketch,"https://www.microsoft.com/en-us/p/snip-sketch/9mz95kl8mr0l"
"@

# --- Services to Disable ---
# List each service name to be disabled on a new line.
$ServicesToDisable = @"
autotimesvc
BcastDVRUserService
defragsvc
DiagSvc
DiagTrack
DPS
DusmSvc
icssvc
lfsvc
MapsBroker
MessagingService
OneSyncSvc
PimIndexMaintenanceSvc
Power
SEMgrSvc
SmsRouter
SysMain
TabletInputService
WdiSystemHost
WerSvc
XblAuthManager
XblGameSave
XboxGipSvc
XboxNetApiSvc
"@

# --- Autologgers to Disable ---
# List each autologger name to be disabled on a new line.
$AutoLoggersToDisable = @"
AppModel
CloudExperienceHostOOBE
DiagLog
ReadyBoot
WDIContextLog
WiFiDriverIHVSession
WiFiSession
WinPhoneCritical
"@

# --- Scheduled Tasks to Disable ---
# List each scheduled task name to be disabled on a new line. Wildcards (*) are supported.
$ScheduledTasksToDisable = @"
BgTaskRegistrationMaintenanceTask
Consolidator
Diagnostics
FamilySafetyMonitor
FamilySafetyRefreshTask
MapsToastTask
*Compatibility*
Microsoft-Windows-DiskDiagnosticDataCollector
*MNO*
NotificationTask
PerformRemediation
ProactiveScan
ProcessMemoryDiagnosticEvents
Proxy
QueueReporting
RecommendedTroubleshootingScanner
ReconcileLanguageResources
RegIdleBackup
RunFullMemoryDiagnostic
Scheduled
ScheduledDefrag
SilentCleanup
SpeechModelDownloadTask
Sqm-Tasks
SR
StartupAppTask
SyspartRepair
UpdateLibrary
WindowsActionDialog
WinSAT
XblGameSaveTask
"@

# --- Default User Registry Settings ---
# These settings will be applied to the default user profile, affecting all new users on the machine.
# The format is JSON. Be careful to maintain valid JSON syntax.
$DefaultUserSettingsJson = @"
[
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "KeyName": "HideFileExt",
        "PropertyType": "DWORD",
        "PropertyValue": 0,
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "KeyName": "IconsOnly",
        "PropertyType": "DWORD",
        "PropertyValue": 0,
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "KeyName": "ListviewAlphaSelect",
        "PropertyType": "DWORD",
        "PropertyValue": 0,
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "KeyName": "ShowCompColor",
        "PropertyType": "DWORD",
        "PropertyValue": 1,
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "KeyName": "TaskbarAnimations",
        "PropertyType": "DWORD",
        "PropertyValue": 0,
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\Windows\\DWM",
        "KeyName": "EnableAeroPeek",
        "PropertyType": "DWORD",
        "PropertyValue": 0,
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Control Panel\\Desktop",
        "KeyName": "DragFullWindows",
        "PropertyType": "STRING",
        "PropertyValue": "0",
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Control Panel\\Desktop",
        "KeyName": "FontSmoothing",
        "PropertyType": "STRING",
        "PropertyValue": "2",
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Control Panel\\Desktop\\WindowMetrics",
        "KeyName": "MinAnimate",
        "PropertyType": "STRING",
        "PropertyValue": "0",
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\Windows\\CurrentVersion\\StorageSense\\Parameters\\StoragePolicy",
        "KeyName": "01",
        "PropertyType": "DWORD",
        "PropertyValue": 0,
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "KeyName": "SystemPaneSuggestionsEnabled",
        "PropertyType": "DWORD",
        "PropertyValue": 0,
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\InputPersonalization",
        "KeyName": "RestrictImplicitInkCollection",
        "PropertyType": "DWORD",
        "PropertyValue": 1,
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\InputPersonalization",
        "KeyName": "RestrictImplicitTextCollection",
        "PropertyType": "DWORD",
        "PropertyValue": 1,
        "SetProperty": "True"
    },
    {
        "HivePath": "HKLM:\\VDOT_TEMP\\Software\\Microsoft\\Windows\\CurrentVersion\\SearchSettings",
        "KeyName": "IsDeviceSearchHistoryEnabled",
        "PropertyType": "DWORD",
        "PropertyValue": 0,
        "SetProperty": "True"
    }
]
"@

#------------------------------------------------------------------------------------------------------------------
# FUNCTIONS
#------------------------------------------------------------------------------------------------------------------

Function Start-ScriptLogging {
    <#
    .SYNOPSIS
        Sets up script logging by creating a log directory and starting a transcript.
    #>
    Write-Verbose "Starting script logging..."
    $LogDirectory = "C:\Windows\Temp\OptimizationLogs"
    $LogFile = Join-Path -Path $LogDirectory -ChildPath "Debloat_Log-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"

    # Create the log directory if it doesn't exist
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    # Start logging all commands and output to the specified file
    Start-Transcript -Path $LogFile -Append
    Write-Host "--- Script Execution Started: $(Get-Date) ---"
}

Function Stop-ScriptLogging {
    <#
    .SYNOPSIS
        Stops the active PowerShell transcript.
    #>
    Write-Host "--- Script Execution Finished: $(Get-Date) ---"
    Stop-Transcript
}

Function Get-OptimizationTool {
    <#
    .SYNOPSIS
        Downloads and extracts the Virtual Desktop Optimization Tool from GitHub.
    .PARAMETER TempDirectory
        The parent directory where the tool will be downloaded and extracted.
    .RETURNS
        The path to the extracted tool's main directory.
    #>
    param (
        [string]$TempDirectory
    )

    Write-Host "Downloading the Virtual Desktop Optimization Tool..."

    $ToolUrl = "https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip"
    $ZipPath = Join-Path -Path $TempDirectory -ChildPath "optimize.zip"
    $ExtractedPath = Join-Path -Path $TempDirectory -ChildPath "optimize"
    $ToolRootPath = Join-Path -Path $ExtractedPath -ChildPath "Virtual-Desktop-Optimization-Tool-main"

    try {
        # Create the temporary directory
        New-Item -Path $ExtractedPath -ItemType Directory -Force | Out-Null

        # Download the tool
        Invoke-WebRequest -Uri $ToolUrl -OutFile $ZipPath
        Write-Host "Download complete. Extracting files..."

        # Extract the archive
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractedPath -Force
        Write-Host "Extraction complete."

        # Return the path to the tool's root directory
        return $ToolRootPath
    }
    catch {
        Write-Error "Failed to download or extract the optimization tool. Error: $($_.Exception.Message)"
        throw
    }
}

Function Generate-ConfigurationFiles {
    <#
    .SYNOPSIS
        Generates the required JSON configuration files from the user-defined variables.
    .PARAMETER ConfigDirectory
        The directory where the JSON files will be created.
    #>
    param (
        [string]$ConfigDirectory
    )

    Write-Host "Generating custom configuration files..."

    try {
        # Ensure the configuration directory exists
        if (-not (Test-Path -Path $ConfigDirectory)) {
            Write-Error "Configuration directory does not exist: $ConfigDirectory"
            throw
        }

        # --- 1. AppX Packages JSON ---
        Write-Verbose "Generating AppxPackages.json..."
        $AppxObjects = ($AppxPackagesToRemove -split "`n").Trim() | ConvertFrom-Csv -Delimiter ',' -Header "PackageName", "HelpURL"
        $AppxJson = $AppxObjects | ForEach-Object {
            [PSCustomObject]@{
                'AppxPackage' = $_.PackageName
                'VDIState'    = 'Disabled'
                'Description' = $_.PackageName
                'URL'         = $_.HelpURL
            }
        } | ConvertTo-Json
        $AppxJson | Out-File (Join-Path -Path $ConfigDirectory -ChildPath "AppxPackages.json")

        # --- 2. Services JSON ---
        Write-Verbose "Generating Services.json..."
        $ServiceObjects = ($ServicesToDisable -split "`n").Trim()
        $ServiceJson = $ServiceObjects | ForEach-Object {
            $serviceName = $_
            $serviceDisplayName = (Get-Service $serviceName -ErrorAction SilentlyContinue).DisplayName
            [PSCustomObject]@{
                'Name'        = $serviceName
                'VDIState'    = 'Disabled'
                'Description' = $serviceDisplayName
            }
        } | ConvertTo-Json
        $ServiceJson | Out-File (Join-Path -Path $ConfigDirectory -ChildPath "Services.json")
        
        # --- 3. Autologgers JSON ---
        Write-Verbose "Generating Autologgers.json..."
        $AutologgerObjects = ($AutoLoggersToDisable -split "`n").Trim()
        $AutologgerJson = $AutologgerObjects | ForEach-Object {
            $loggerName = $_
            $logHash = @{
                KeyName  = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$loggerName\"
                Disabled = $true
            }
            # The original script contained extensive descriptions. This has been simplified for clarity.
            switch ($loggerName) {
                'ReadyBoot' {
                    $logHash.Description = "ReadyBoot boot acceleration technology."
                    $logHash.URL = "https://docs.microsoft.com/en-us/previous-versions/windows/desktop/xperf/readyboot-analysis"
                }
                default {
                    $logHash.Description = "System autologger session: $loggerName"
                    $logHash.URL = "N/A"
                }
            }
            [PSCustomObject]$logHash
        } | ConvertTo-Json
        $AutologgerJson | Out-File (Join-Path -Path $ConfigDirectory -ChildPath "Autologgers.Json")

        # --- 4. Scheduled Tasks JSON ---
        Write-Verbose "Generating ScheduledTasks.json..."
        $TaskObjects = ($ScheduledTasksToDisable -split "`n").Trim()
        $TaskJson = $TaskObjects | ForEach-Object {
            $taskName = $_
            $taskDescription = (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).Description
            [PSCustomObject]@{
                'ScheduledTask' = $taskName
                'VDIState'      = 'Disabled'
                'Description'   = $taskDescription
            }
        } | ConvertTo-Json
        $TaskJson | Out-File (Join-Path -Path $ConfigDirectory -ChildPath "ScheduledTasks.json")

        # --- 5. Default User Settings JSON ---
        Write-Verbose "Generating DefaultUserSettings.json..."
        $DefaultUserSettingsJson | Out-File (Join-Path -Path $ConfigDirectory -ChildPath "DefaultUserSettings.json")

        Write-Host "Successfully generated all configuration files."
    }
    catch {
        Write-Error "Failed to generate configuration files. Error: $($_.Exception.Message)"
        throw
    }
}

Function Run-Optimizations {
    <#
    .SYNOPSIS
        Executes the main optimization script from the downloaded tool.
    .PARAMETER ToolPath
        The full path to the Windows_VDOT.ps1 script.
    #>
    param (
        [string]$ToolPath
    )

    Write-Host "Running the main optimization script. This may take some time..."
    
    if (-not (Test-Path -Path $ToolPath)) {
        Write-Error "Optimization script not found at path: $ToolPath"
        throw
    }
    
    try {
        # Change directory to the script's location to ensure it finds its modules
        Push-Location (Split-Path -Path $ToolPath -Parent)

        # Execute the script
        & $ToolPath -Optimizations All -Verbose -AcceptEula
        
        # Return to the original directory
        Pop-Location

        Write-Host "Optimization script completed."
    }
    catch {
        # Restore original location in case of an error
        Pop-Location
        Write-Error "An error occurred while running the optimization script. Please check the log for details."
        throw
    }
}

Function Perform-Cleanup {
    <#
    .SYNOPSIS
        Removes temporary files and directories created by the script.
    .PARAMETER TempDirectory
        The temporary directory to remove.
    #>
    param (
        [string]$TempDirectory
    )

    Write-Host "Performing cleanup..."
    if (Test-Path -Path $TempDirectory) {
        Remove-Item -Path $TempDirectory -Recurse -Force
        Write-Host "Temporary directory '$TempDirectory' has been removed."
    }
    else {
        Write-Host "Temporary directory not found, skipping cleanup."
    }
}


#------------------------------------------------------------------------------------------------------------------
# SCRIPT EXECUTION
#------------------------------------------------------------------------------------------------------------------

# Define a temporary working directory
$TempWorkDir = "C:\VDI_Optimize_Temp"

# Start logging for the entire script execution
Start-ScriptLogging

# Use a try/finally block to ensure cleanup happens even if the script fails
try {
    # 1. Download and extract the optimization tool
    $ToolRoot = Get-OptimizationTool -TempDirectory $TempWorkDir
    
    # 2. Define the path for the configuration files based on the target Windows version
    $ConfigPath = Join-Path -Path $ToolRoot -ChildPath "$TargetWindowsVersion\ConfigurationFiles"

    # 3. Generate the JSON configuration files
    Generate-ConfigurationFiles -ConfigDirectory $ConfigPath

    # 4. Define the path to the main script and run the optimizations
    $OptimizationScriptPath = Join-Path -Path $ToolRoot -ChildPath "Windows_VDOT.ps1"
    Run-Optimizations -ToolPath $OptimizationScriptPath
}
catch {
    # Any terminating error in the 'try' block will be caught here
    Write-Error "A critical error occurred. Script execution halted."
    Write-Error $_.Exception.Message
}
finally {
    # 5. Clean up the temporary directory regardless of success or failure
    Perform-Cleanup -TempDirectory $TempWorkDir
    
    # 6. Stop the transcript to finalize the log file
    Stop-ScriptLogging
}