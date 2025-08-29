<#
.SYNOPSIS
    Automated debloating script for Windows 10, Windows 11, and Windows Server.

.DESCRIPTION
    This script removes pre-installed bloatware (AppX packages) and specified MSI packages.
    It dynamically adjusts its behavior based on the detected operating system:
    - Windows 10: Performs standard AppX and MSI removal.
    - Windows 11: Includes all Windows 10 tasks plus Windows 11-specific removals, like disabling Copilot.
    - Server / Multi-Session: Performs the most aggressive cleaning, including all tasks from other versions plus a VM-specific bloat list.

#>

#---------------------------------------------------------------------------------------------
# Section 1: Prerequisites and Setup
#---------------------------------------------------------------------------------------------

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "== Automated OS-Aware Debloating Script ==" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Start-Sleep 2

# Verify/Elevate Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Script not running as Administrator. Attempting to elevate..."
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Determine OS architecture for MSI uninstalls
$SoftwareList = @("SOFTWARE")
if ((Get-CimInstance Win32_OperatingSystem).OSArchitecture -eq "64-bit") {
    $SoftwareList += "SOFTWARE\Wow6432Node"
}

#---------------------------------------------------------------------------------------------
# Section 2: Bloatware Lists and OS Detection
#---------------------------------------------------------------------------------------------

# --- Base Appx Bloat List (Common to all OS versions) ---
$AppxBloatList = @(
    "*562882FEEB491*" # Code Writer from Actipro Software LLC
    "*549981C3F5F10*" # Microsoft Cortana
    "*Client.Photon*" # Photon Client for AI / Recall
    "*Client.CoreAI*" # Core AI Client / Recall
    "*OutlookForWindows*" # New Outlook for Windows Appx
    "*PeopleExperienceHost*" # People Experience Host
    "*PowerAutomateDesktop*" # Power Automate Desktop
    "*Todos*" # Todos
    "*YourPhone*" # Your Phone
    "*CrossDevice*" # Cross Device
    "*ZuneMusic*" # Zune Music
    "*Clipchamp*" # Clipchamp
    "*QuickAssist*" # Quick Assist
    "*OfficePushNotificationUtility*" # Office Push Notification Utility
    "*Office.ActionsServer*" # Office Actions Server
    "*MicrosoftOfficeHub*" # Microsoft Office Hub
    "*ParentalControls*" # Parental Controls
    "*Windows.DevHome*" # Windows Dev Home
    "*WindowsFeedbackHub*" # Windows Feedback Hub
    "*Microsoft.OneDriveSync*" # OneDrive Appx (Use the Per-User / use System Install instead after this script)
    "*MicrosoftTeams*" # Microsoft Teams (other versions)
    "*MSTeams*" # Microsoft Teams (other versions)
    "*ActiproSoftware*"
    "*Alexa*"
    "*AIMeetingManager*"
    "*AdobePhotoshopExpress*"
    "*Advertising*"
    "*ArmouryCrate*"
    "*Asphalt*"
    "*ASUSPCAssistant*"
    "*AutodeskSketchBook*"
    "*Bing*"
    "*BingNews*"
    "*BingSports*"
    "*BingTranslator*"
    "*BingWeather*"
    "*BubbleWitch3Saga*"
    "*CandyCrush*"
    "*Casino*"
    "*COOKINGFEVER*"
    "*CyberLink*"
    "*Disney*"
    "*Dolby*"
    "*DrawboardPDF*"
    "*Duolingo*"
    "*ElevocTechnology*"
    "*EclipseManager*"
    "*Facebook*"
    "*FarmVille*"
    "*Fitbit*"
    "*flaregames*"
    "*GameAssist*"
    "*GameBar*"
    "*GamingOverlay*"
    "*Game*"
    "*xbox*"
    "*Flipboard*"
    "*GamingApp*"
    "*GamingServices*"
    "*GetHelp*"
    "*Getstarted*"
    "*HPPrinter*"
    "*iHeartRadio*"
    "*Instagram*"
    "*Keeper*"
    "*king.com*"
    "*Lenovo*"
    "*Lens*"
    "*LinkedInforWindows*"
    "*MarchofEmpires*"
    "*McAfee*"
    "*Messaging*"
    "*MirametrixInc*"
    "*Microsoft3DViewer*"
    "*MicrosoftOfficeHub*"
    "*SolitaireCollection*"
    "*Minecraft*"
    "*MixedReality*"
    "*MSPaint*" # This is Paint 3D, NOT the old-school MSPaint
    "*Netflix*"
    "*NetworkSpeedTest*"
    "*News*"
    "*OneConnect*"
    "*PandoraMediaInc*"
    "*People*"
    "*PhototasticCollage*"
    "*PicsArt-PhotoStudio*"
    "*Plex*"
    "*PolarrPhotoEditor*"
    "*PPIProjection*"
    "*Print3D*"
    "*Royal Revolt*"
    "*ScreenSketch*"
    "*Shazam*"
    "*SkypeApp*"
    "*SlingTV*"
    "*Spotify*"
    "*StickyNotes*"
    "*Sway*"
    "*MicrosoftTeams*"
    "*TheNewYorkTimes*"
    "*TuneIn*"
    "*Twitter*"
    "*Wallet*"
    "*WebExperience*" # This is the Windows 11 Widgets BS Microsof thas thrown in to the new OS. Remove Widgets entirely.
    "*Whiteboard*"
    "*WindowsAlarms*"
    "*windowscommunicationsapps*"
    "*Feedback*"
    "*WindowsMaps*"
    "*WindowsSoundRecorder*"
    "*WinZip*"
    "*Wunderlist*"
    "*Xbox.TCUI*"
    "*XboxApp*"
    "*XboxGameOverlay*"
    "*XboxGamingOverlay*"
    "*XboxIdentityProvider*"
    "*XboxSpeechToTextOverlay*"
    "*XboxGameCallableUI*"
    "*XING*"
    "*YourPhone*"
    "*ZuneMusic*"
    "*ZuneVideo*"
    "*TikTok*"
    "*ESPN*"
    "*Messenger*"
    "*Clipchamp*"
    "*whatsApp*"
    "*Prime*"
    "*Family*"
    "*copilot*"
    "*Mahjong*"
    "*viber*"
    "*Sidia*"
)

# --- VM / Server Specific Bloat List ---
$VMBasedBloatlist = @(
    "Microsoft.BioEnrollment",
    "WindowsCamera"
)

# --- MSI Based Classic Bloat List ---
$MsiBloatList = @(
    "*mcafee*",
    "*livesafe*",
    "*Passportal*"
)

# --- OS Detection Logic ---
$OSInfo = Get-CimInstance Win32_OperatingSystem
$OSVersion = $OSInfo.Caption
$OSProductType = $OSInfo.ProductType # 1 = Workstation, 2 = Domain Controller, 3 = Server

Write-Host "OS Detected: $OSVersion" -ForegroundColor White

if ($OSVersion -like "*Server*" -or $OSProductType -ne 1 -or $OSVersion -like "*Multi-Session*") {
    Write-Host "Server or Multi-Session environment detected. Applying most aggressive debloating." -ForegroundColor Yellow
    # Add VM-based bloat to the main list
    $AppxBloatList += $VMBasedBloatlist
    $disableCopilot = $true
}
elseif ($OSVersion -like "*Windows 11*") {
    Write-Host "Windows 11 detected. Applying standard and Windows 11-specific debloating." -ForegroundColor Yellow
    $disableCopilot = $true
}
else {
    Write-Host "Non-Windows 11 detected. Applying standard debloating." -ForegroundColor Yellow
}

# Make the final AppX list unique to avoid redundant operations
$AppxBloatList = $AppxBloatList | Select-Object -Unique

#---------------------------------------------------------------------------------------------
# Section 3: Functions for Debloating
#---------------------------------------------------------------------------------------------

function Disable-Copilot {
    Write-Host "`n------------------------------------------------------------" -ForegroundColor Green
    Write-Host "Disabling Windows Copilot via Registry..." -ForegroundColor Green
    Write-Host "------------------------------------------------------------"
    $RegPath = "HKCU:\Software\Policies\Microsoft\Windows"
    $KeyName = "WindowsCopilot"
    # Ensure the parent path exists
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }
    # Create the key if it doesn't exist
    if (-not (Test-Path "$RegPath\$KeyName")) {
        New-Item -Path $RegPath -Name $KeyName -Force | Out-Null
    }
    # Set the property to disable Copilot
    Set-ItemProperty -Path "$RegPath\$KeyName" -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
    Write-Host "Copilot has been disabled. A restart is required for it to fully disappear." -ForegroundColor White
}

function Remove-ClassicTeams {
    Write-Host "`n------------------------------------------------------------" -ForegroundColor Green
    Write-Host "Searching for and removing Classic Teams (Win32)..." -ForegroundColor Green
    Write-Host "------------------------------------------------------------"
    
    $foundAndRemoved = $false

    # Define all potential uninstaller paths and their specific arguments
    $potentialPaths = @(
        @{ # 32-bit System-wide Installer
            Path = Join-Path ${env:ProgramFiles(x86)} "Teams Installer\Teams.exe"
            Args = "--uninstall -s"
        },
        @{ # 64-bit System-wide Installer
            Path = Join-Path $env:ProgramFiles "Teams Installer\Teams.exe"
            Args = "--uninstall -s"
        },
        @{ # Per-User Installation
            Path = Join-Path $env:LOCALAPPDATA "Microsoft\Teams\Update.exe"
            Args = "--uninstall -s"
        }
    )

    # Loop through each potential path and execute the first one found
    foreach ($item in $potentialPaths) {
        if (Test-Path $item.Path) {
            Write-Host "Found Teams uninstaller at: $($item.Path)" -ForegroundColor Cyan
            Write-Host "Executing uninstall command..." -ForegroundColor White
            
            Start-Process -FilePath $item.Path -ArgumentList $item.Args -Wait
            
            Write-Host "Classic Teams uninstall command has been executed." -ForegroundColor Green
            $foundAndRemoved = $true
            break # Exit the loop since we found and removed it
        }
    }

    if (-not $foundAndRemoved) {
        Write-Host "Classic Teams (Win32) was not found in any common locations." -ForegroundColor Gray
    }
}

function Remove-AppxPackages {
    param([array]$PackageList)

    Write-Host "`n------------------------------------------------------------" -ForegroundColor Green
    Write-Host "Starting AppX Package Removal..." -ForegroundColor Green
    Write-Host "------------------------------------------------------------"
    Start-Sleep 2

    foreach ($AppxBloat in $PackageList) {
        Write-Host "`n--> Processing package pattern: $AppxBloat" -ForegroundColor Cyan
        
        $Packages = Get-AppxPackage -Name $AppxBloat -AllUsers -ErrorAction SilentlyContinue
        if ($Packages) {
            Write-Host "Found and removing AppxPackage(s) for all users..."
            $Packages | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }

        $ProvisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $AppxBloat
        if ($ProvisionedPackage) {
            Write-Host "Found and removing Appx Provisioned Package..."
            $ProvisionedPackage | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        }
    }
    Write-Host "`nAppX removal process completed. Waiting 10 seconds for jobs to finish..." -ForegroundColor Green
    Start-Sleep 10
}

function Remove-MsiPackages {
    param([array]$PackageList)

    Write-Host "`n------------------------------------------------------------" -ForegroundColor Green
    Write-Host "Starting MSI Package Removal..." -ForegroundColor Green
    Write-Host "------------------------------------------------------------"
    Start-Sleep 2

    foreach ($MsiBloat in $PackageList) {
        $entryFound = $false
        foreach ($Software in $SoftwareList) {
            $RegistryPath = "HKLM:\$Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
            $UninstallRegistryObjects = Get-ItemProperty "$RegistryPath" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $MsiBloat }
            
            if ($UninstallRegistryObjects) {
                $entryFound = $true
                foreach ($Object in $UninstallRegistryObjects) {
                    $DisplayName = $Object.DisplayName
                    $GUID = $Object.PSChildName
                    Write-Host "Found MSI package: $DisplayName" -ForegroundColor Cyan
                    Write-Host "Uninstalling via GUID: $GUID" -ForegroundColor White
                    
                    Start-Process -Wait -FilePath "MsiExec.exe" -ArgumentList "/X $GUID /qn /norestart"
                    Write-Host "$DisplayName has been uninstalled." -ForegroundColor Green
                    Start-Sleep 5 # Brief pause after each uninstall
                }
            }
        }
        if (-not $entryFound) {
            Write-Host "No MSI match found for pattern '$MsiBloat'" -ForegroundColor Gray
        }
    }
}

#---------------------------------------------------------------------------------------------
# Section 4: Execution
#---------------------------------------------------------------------------------------------

# Execute Copilot disable if flagged
if ($disableCopilot) {
    Disable-Copilot
}

Remove-ClassicTeams

# Execute AppX Removal
Remove-AppxPackages -PackageList $AppxBloatList

# Execute MSI Removal
Remove-MsiPackages -PackageList $MsiBloatList


Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "== Debloating Script Finished! ==" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Read-Host -Prompt "Press Enter to exit"