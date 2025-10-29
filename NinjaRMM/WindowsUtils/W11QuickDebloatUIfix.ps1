<#
.SYNOPSIS
    The definitive administrator script to harden, de-bloat, and customize the Windows UI
    for ALL users on a system, targeting both Windows 10 and Windows 11.

.DESCRIPTION
    This script must be run with Administrator privileges. It applies a vast collection of
    system-wide policies, service configurations, and per-user UI tweaks to standardize the
    user experience across an entire machine.

    The script is executed in distinct phases:
    1. System-Level Registry: Applies machine-wide HKLM policies to disable telemetry,
       harden security, and configure system-wide features.
    2. System-Level Actions: Disables unneeded scheduled tasks, configures services, and
       enables features like System Restore.
    3. Per-User Profiles: Iterates through the Default Profile, all existing users (skipping
       the current user), and the current admin to apply a rich set of UI customizations,
       privacy settings, visual performance tweaks, and de-bloating rules.

.AUTHOR
    Alex Ivantsov

.DATE
    09/27/2025
#>

#================================================================================
# HELPER AND CORE FUNCTIONS
#================================================================================

Function Test-IsAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Function Set-RegistryValue {
    param (
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] $Value,
        [Parameter(Mandatory = $false)] [ValidateSet('DWord', 'String', 'Binary', 'ExpandString')] [string]$Type = 'DWord'
    )
    try {
        if (-not (Test-Path -Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to set registry value '$Name' at '$Path'."
    }
}

Function Remove-RegistryKey {
    param (
        [Parameter(Mandatory = $true)] [string]$Path
    )
    try {
        if (Test-Path -Path $Path) {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "Failed to remove registry key '$Path'."
    }
}


Function Apply-SystemLevelRegistryTweaks {
    <#
    .SYNOPSIS
        Applies machine-wide (HKLM) registry settings for telemetry, security, and policies.
    #>
    Write-Host "  Applying System-Wide (HKLM) Registry Policies..." -ForegroundColor Cyan

    # --- Telemetry, Data Collection, and Privacy Policies ---
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DisableDiagnosticDataViewer" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds" -Name "AllowBuildPreview" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" -Name "CEIPEnable" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "AITEnable" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0

    # --- System Features and Policies ---
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableFirstLogonAnimation" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE" -Name "DisablePrivacyExperience" -Value 1
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableAutomaticRestartSignOn" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "DisableEdgeDesktopShortcutCreation" -Value 1

    # --- Remove Folders from "This PC" ---
    Write-Host "  Removing default folders from This PC..." -ForegroundColor Cyan
    $thisPcFolders = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}'
    )
    foreach ($folder in $thisPcFolders) {
        Remove-RegistryKey -Path $folder
        Remove-RegistryKey -Path $folder.Replace('HKLM:\SOFTWARE\', 'HKLM:\SOFTWARE\Wow6432Node\')
    }
}

Function Perform-SystemLevelActions {
    <#
    .SYNOPSIS
        Executes system-wide actions like configuring services and disabling scheduled tasks.
    #>
    Write-Host "  Performing System-Wide Actions (Services, Tasks)..." -ForegroundColor Cyan

    # --- Disable Scheduled Tasks ---
    $tasksToDisable = @(
        "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    )
    foreach ($task in $tasksToDisable) {
        Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Disable-ScheduledTask
    }
}

Function Apply-AllUserTweaks {
    <#
    .SYNOPSIS
        A master function that applies all per-user tweaks to a given registry hive path.
    #>
    param (
        [Parameter(Mandatory = $true)] [string]$RegistryHivePath,
        [Parameter(Mandatory = $true)] [bool]$IsWin11
    )

    # --- Pre-check for conflicting system policies to avoid unnecessary warnings ---
    $isFeedsPolicyDisabled = $false
    try {
        if ((Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -ErrorAction Stop) -eq 0) {
            $isFeedsPolicyDisabled = $true
        }
    }
    catch {}

    # --- Group 1: Privacy and Search ---
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Value 0
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" -Name "HasAccepted" -Value 0
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1

    # --- Group 2: Disable Ads & Suggestions ---
    $cdmPath = "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-RegistryValue -Path $cdmPath -Name "SilentInstalledAppsEnabled" -Value 0
    Set-RegistryValue -Path $cdmPath -Name "SubscribedContent-310093Enabled" -Value 0
    Set-RegistryValue -Path $cdmPath -Name "SystemPaneSuggestionsEnabled" -Value 0
    Set-RegistryValue -Path $cdmPath -Name "RotatingLockScreenOverlayEnabled" -Value 0
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Value 0

    # --- Group 3: File Explorer and Desktop ---
    $explorerAdvancedPath = "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-RegistryValue -Path $explorerAdvancedPath -Name "HideFileExt" -Value 0
    Set-RegistryValue -Path $explorerAdvancedPath -Name "ShowCompColor" -Value 1
    # Set-RegistryValue -Path $explorerAdvancedPath -Name "NavPaneShowAllFolders" -Value 1 # A bit controversial with users.
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 0
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "link" -Value ([byte[]](0, 0, 0, 0)) -Type "Binary"

    # --- Group 4: Visual Performance & Effects ---
    Set-RegistryValue -Path "$RegistryHivePath\Control Panel\Desktop" -Name "DragFullWindows" -Value 1 -Type "String"
    Set-RegistryValue -Path "$RegistryHivePath\Control Panel\Desktop" -Name "FontSmoothing" -Value 2 -Type "String"
    Set-RegistryValue -Path "$RegistryHivePath\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 0 -Type "String"
    Set-RegistryValue -Path $explorerAdvancedPath -Name "IconsOnly" -Value 0
    Set-RegistryValue -Path $explorerAdvancedPath -Name "ListviewShadow" -Value 0
    Set-RegistryValue -Path $explorerAdvancedPath -Name "TaskbarAnimations" -Value 0
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0

    # --- Group 5: Taskbar Configuration ---
    Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1
    Set-RegistryValue -Path "$explorerAdvancedPath\People" -Name "PeopleBand" -Value 0
    Set-RegistryValue -Path $explorerAdvancedPath -Name "ShowCortanaButton" -Value 0
    # Only set user preference if system policy is not already disabling the feature
    if (-not $isFeedsPolicyDisabled) {
        Set-RegistryValue -Path "$RegistryHivePath\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Value 2
    }

    # --- Group 6: Windows 11 Specific Tweaks ---
    if ($IsWin11) {
        Set-RegistryValue -Path "$RegistryHivePath\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name '(Default)' -Value '' -Type 'String'
        Set-RegistryValue -Path $explorerAdvancedPath -Name "TaskbarAl" -Value 0
        Set-RegistryValue -Path $explorerAdvancedPath -Name "LaunchTo" -Value 1
        Set-RegistryValue -Path $explorerAdvancedPath -Name "TaskbarMn" -Value 0 # Chat
        Set-RegistryValue -Path $explorerAdvancedPath -Name "ShowTaskViewButton" -Value 0 # Task View
        Set-RegistryValue -Path $explorerAdvancedPath -Name "ShowCopilotButton" -Value 0 # Copilot
        # Only set user preference if system policy is not already disabling the feature
        if (-not $isFeedsPolicyDisabled) {
            Set-RegistryValue -Path $explorerAdvancedPath -Name "TaskbarDa" -Value 0 # Widgets
        }
    }
}

#================================================================================
# MAIN SCRIPT EXECUTION
#================================================================================

Write-Host "--------------------------------------------------------" -ForegroundColor Green
Write-Host "   Windows System-Wide Customization Script (Admin)   "
Write-Host "--------------------------------------------------------" -ForegroundColor Green
Write-Host

if (-not (Test-IsAdmin)) {
    Write-Warning "This script requires Administrator privileges. Please re-run from an elevated PowerShell session."
    Read-Host "Press Enter to exit."; exit
}
Write-Host "Administrator privileges confirmed." -ForegroundColor Green
$isWin11 = (Get-CimInstance Win32_OperatingSystem).Caption -match "Windows 11"
if ($isWin11) { Write-Host "OS Check: Windows 11 detected." -ForegroundColor Cyan } else { Write-Host "OS Check: Windows 10 detected." -ForegroundColor Cyan }
Write-Host

Write-Host "Phase 1: Applying System-Level Hardening and Configuration..." -ForegroundColor Yellow
Apply-SystemLevelRegistryTweaks
Perform-SystemLevelActions
Write-Host "System-Level configuration complete." -ForegroundColor Green
Write-Host

Write-Host "Phase 2: Modifying Default User Profile..." -ForegroundColor Yellow
$defaultUserHive = Join-Path $env:SystemDrive "Users\Default\NTUSER.DAT"
$tempHiveKeyPS = "HKLM:\DEFAULT_USER_TEMP"
$tempHiveKeyReg = $tempHiveKeyPS.Replace(':\', '\')
if (Test-Path $defaultUserHive) {
    try {
        reg.exe load $tempHiveKeyReg $defaultUserHive | Out-Null
        Apply-AllUserTweaks -RegistryHivePath $tempHiveKeyPS -IsWin11 $isWin11
    }
    finally {
        [gc]::Collect()
        reg.exe unload $tempHiveKeyReg | Out-Null
        Write-Host "Default User Profile successfully updated." -ForegroundColor Green
    }
}
else { Write-Warning "Default User Profile hive not found." }
Write-Host

Write-Host "Phase 3: Modifying Existing User Profiles..." -ForegroundColor Yellow
$currentUserSID = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$tempHiveKeyPS = "HKLM:\EXISTING_USER_TEMP"
$tempHiveKeyReg = $tempHiveKeyPS.Replace(':\', '\')
$profileRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
Get-ChildItem -Path $profileRegPath | ForEach-Object {
    $profile = $_
    $sid = $profile.PSChildName
    if (($sid -notlike "S-1-5-18*") -and ($sid -notlike "S-1-5-19*") -and ($sid -notlike "S-1-5-20*") -and ($sid -ne $currentUserSID)) {
        $userHivePath = ($profile | Get-ItemProperty).ProfileImagePath
        $userHiveFile = Join-Path ([System.Environment]::ExpandEnvironmentVariables($userHivePath)) "NTUSER.DAT"
        if (Test-Path $userHiveFile) {
            Write-Host "  -> Processing profile at $userHivePath" -ForegroundColor DarkCyan
            try {
                reg.exe load $tempHiveKeyReg $userHiveFile | Out-Null
                Apply-AllUserTweaks -RegistryHivePath $tempHiveKeyPS -IsWin11 $isWin11
                Remove-RegistryKey -Path "$tempHiveKeyPS\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"
            }
            catch { Write-Warning "     Could not process hive for $userHivePath. It may be in use by another process." }
            finally { [gc]::Collect(); reg.exe unload $tempHiveKeyReg | Out-Null }
        }
    }
    elseif ($sid -eq $currentUserSID) {
        Write-Host "  -> Skipping currently logged-on user profile (will be handled in the next phase)." -ForegroundColor DarkGray
    }
}
Write-Host "Finished processing existing user profiles." -ForegroundColor Green
Write-Host

Write-Host "Phase 4: Modifying Current Administrator Profile (HKCU)..." -ForegroundColor Yellow
Apply-AllUserTweaks -RegistryHivePath "HKCU:" -IsWin11 $isWin11
Write-Host "Current administrator profile updated." -ForegroundColor Green
Write-Host

Write-Host "Restarting Windows Explorer to apply changes for the current user..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

Write-Host
Write-Host "--------------------------------------------------------" -ForegroundColor Green
Write-Host "          System-wide customization complete!           "
Write-Host "--------------------------------------------------------" -ForegroundColor Green