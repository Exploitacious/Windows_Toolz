# De-Bloat and Optimize Windows 10 Before Deployment

<# 
 Powershell Script for running on the Local Machine - for ALL USERS
 This script should be ran as ADMIN and everything here will stick to ALL-USERS

 Download from GitHub and run the entire thing with one line: 

	curl -L cleanup.umbrellaitgroup.com -o cleanup.cmd && cleanup.cmd


Created By Alex Ivantsov - Umbrella IT Solutions
Github.com/exploitacious
Version 1.2
Tested on Powershell 5.0 +
Windows 10 2004 +

This powershell script accomplishes the follwoing objectives:

Registry Tweaks
	- Disables Telemetry by Microsoft / Windows
	- Disables Windows Preview Builds
	- Disables Wi-Fi Sense (https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwiy3qmx1MzyAhXURTABHVlSCUIQFnoECAcQAQ&url=https%3A%2F%2Fwww.lifewire.com%2Fwhat-is-wifi-sense-windows-10-4586925&usg=AOvVaw14UdBdVJlIKdrzTSu3c9LN)
	- Disables Bing Search in Start-Menu
	- Disables Suggested Applications
	- Disables Feedback
	- Disables Windows Defender System Tray Icon (Visual Only)
	- Disables entire IPv6 stavk
	- Enables Windows Update Auto-Downloads
	- Enabling Windows Search indexing service
	- Enabling Superfetch service
	- Enabling and Configuring System Restore for System Drive
	- Disable Fast-Startup
	- Hiding people icon
	- Showing Taskbar Search icon
	- Enabling NumLock after startup
	- Setting Control Panel view to small icons
	- Enabling Clipboard History
	- Disabling First Logon Animation
	- Disabling Xbox features
	- Enabling verbose startup/shutdown status messages
	- Showing all tray icons
	- Unpinning all Start Menu tiles
	- Removing Weather Taskbar Widget (Comment this out for any version previous to 20H2)
	- Removing Meet Now Feature

Windows Appx Bloatware Perma-Uninstall List

	- See "Bloatware" Variable for full list.
	- To add or remove bloatware apps from this list, simply add then in quotes with wildcard * symbols.
	- To make sure they'll be picked up and removed, test them on a machine by running:  get-appxpackage -name *appName*

Per-User first-time logon script to tweak user interface - Coming soon!
	- My goal is to deploy a mini script to run at first-time-logon for each user on the system to tweak the user interface into being nice and clean.
	- Will run as per-user context.
	
	Stay tuned!

#>

# Set Variables and Ensure Script is running as Admin.

	Write-Host
	Write-Host
	Write-Host
	$EnableUserLogonScript = Read-Host "Would you like this script to configure the first-time user logon experience script Y/N ? (Recommended)"

	$ErrorActionPreference = 'SilentlyContinue'
	$NotificationColor = 'Yellow'

	$Button = [System.Windows.MessageBoxButton]::YesNoCancel
	$ErrorIco = [System.Windows.MessageBoxImage]::Error
	$Ask = 'Do you want to run this as an Administrator?
			Select "Yes" to Run as an Administrator
			Select "No" to not run this as an Administrator
			
			Select "Cancel" to stop the script.'

	If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
		$Prompt = [System.Windows.MessageBox]::Show($Ask, "Run as an Administrator or not?", $Button, $ErrorIco) 
		Switch ($Prompt) {
			#This will debloat Windows 10
			Yes {
				Write-Host "You didn't run this script as an Administrator. This script will self elevate to run as an Administrator and continue."
				Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
				Exit
			}
			No {
				Break
			}
		}
	}


# Uninstalling Apps & Features

	$Bloatware = @(
		"*Advertising*"
		"*BingWeather*"
		"*BingSports*"
		"*BingTranslator*"
		"*PPIProjection*"
		"*BingNews*"
		"*GetHelp*"
		"*Getstarted*"
		"*Messaging*"
		"*Microsoft3DViewer*"
		"*MicrosoftOfficeHub*"
		"*MicrosoftSolitaireCollection*"
		"*NetworkSpeedTest*"
		"*News*"                                
		"*Lens*"                          
		"*OneConnect*"
		"*Sway*"
		"*People*"
		"*Print3D*"
		"*RemoteDesktop*"                        
		"*SkypeApp*"
		"*Whiteboard*"
		"*ScreenSketch*"                           
		"*WindowsAlarms*"
		"*windowscommunicationsapps*"
		"*WindowsFeedbackHub*"
		"*WindowsMaps*"
		"*WindowsSoundRecorder*"
		"*XboxApp*"
		"*GamingApp*"
		"*XboxGameOverlay*"
		"*XboxGamingOverlay*"
		"*XboxIdentityProvider*"
		"*XboxSpeechToTextOverlay*"
		"*ZuneMusic*"
		"*ZuneVideo*"
		"*YourPhone*"
		"*MixedReality*"
		"*StickyNotes*"
		"*Wallet*"
		"*EclipseManager*"
		"*ActiproSoftwareLLC*"
		"*AdobeSystemsIncorporated.AdobePhotoshopExpress*"
		"*Duolingo*"
		"*PandoraMediaInc*"
		"*CandyCrush*"
		"*BubbleWitch3Saga*"
		"*Wunderlist*"
		"*Flipboard*"
		"*Facebook*"
		"*Twitter*"
		"*Spotify*"
		"*Minecraft*"
		"*Royal Revolt*"
		"*Sway*"
		"*Dolby*"
		"*HPPrinter*"
		"*MSPaint*" # This is Paint 3D, NOT the old-school MSPaint
		"*LenovoCompanion*"
		"*Instagram*"
		"*WebExperience*" # This is the Windows 11 Widgets BS Microsof thas thrown in to the new OS. Remove Widgets entirely.
		"*McAfee*"
		"*ArmouryCrate*"
		"*ASUSPCAssistant*"
		"*GamingServices*"
		"*Xbox.TCUI*"
		"*PicsArt-PhotoStudio*"
		"*EclipseManager*"
		"*Netflix*"
		"*PolarrPhotoEditor*"
		"*Wunderlist*"
		"*LinkedInforWindows*"
		"*AutodeskSketchBook*"
		"*Twitter*"
		"*DisneyMagicKingdoms*"
		"*MarchofEmpires*"
		"*562882FEEB491*" # Code Writer from Actipro Software LLC
		"*Plex*"
		"*iHeartRadio*"
		"*FarmVille2CountryEscape*"
		"*CyberLinkMediaSuiteEssentials*"
		"*DolbyAccess*"
		"*DrawboardPDF*"
		"*FitbitCoach*"
		"*Flipboard*"
		"*Asphalt8Airborne*"
		"*Keeper*"
		"*COOKINGFEVER*"
		"*PandoraMediaInc*"
		"*Casino*"
		"*Shazam*"
		"*SlingTV*"
		"*SpotifyMusic*"
		"*TheNewYorkTimes*"
		"*PhototasticCollage*"
		"*TuneIn*"
		"*WinZipComputing*"
		"*XINGAG*"
		"*flaregames*"
		"*king.com*"
	)

	# This writes the output of each Bloatware Appx as it's removing.

	Start-Job -ScriptBlock {
			foreach ($App in $Bloatware) {
				Write-host ('Removing Package {0}' -f $App)
					
				Get-AppxPackage -Name $App | Remove-AppxPackage -ErrorAction SilentlyContinue -Verbose
				Get-AppxPackage -Name $App -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue -Verbose
				Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $App | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue -Verbose
		}
	}

	Wait-Job -Any


# Registry Tweaks

	# Telemetry
	Write-Host -ForegroundColor $NotificationColor Disabling Telemetry...

		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0

	# Preview Builds
	Write-Host -ForegroundColor $NotificationColor Disabling Windows Preview Builds...

		If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds")) {
			New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds" -Name "AllowBuildPreview" -Type DWord -Value 0

	# License Telemetry
	Write-Host -ForegroundColor $NotificationColor Disabling Windows License Telemetry...

		If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform")) {
			New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform" -Name "NoGenTicket" -Type DWord -Value 1

	# Customer Experience Imporvement
	Write-Host -ForegroundColor $NotificationColor Disabling Customer Experience Improvement...

		If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows")) {
			New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" -Name "CEIPEnable" -Type DWord -Value 0
		
	# App Telemetry
	Write-Host -ForegroundColor $NotificationColor Disabling App Telemetry...

		If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat")) {
			New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "AITEnable" -Type DWord -Value 0
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableInventory" -Type DWord -Value 1

		If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\AppV\CEIP")) {
			New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\AppV\CEIP" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\AppV\CEIP" -Name "CEIPEnable" -Type DWord -Value 0
		
	# Tablet PC Compatibility
	Write-Host -ForegroundColor $NotificationColor Disabling Tabled PC Features...

		If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC")) {
			New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Name "PreventHandwritingDataSharing" -Type DWord -Value 1
		If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput")) {
			New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput" -Force | Out-Null
		}

	# Scheduled Tasks
	Write-Host -ForegroundColor $NotificationColor Disabling Uneeded Scheduled Tasks...

		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput" -Name "AllowLinguisticDataCollection" -Type DWord -Value 0
		Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\ProgramDataUpdater" | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Windows\Autochk\Proxy" | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Windows\RemoteAssistance\RemoteAssistanceTask" | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Windows\RetailDemo\CleanupOfflineContent" -ErrorAction SilentlyContinue | Out-Null
		# Office 2016 / 2019
		Disable-ScheduledTask -TaskName "Microsoft\Office\Office ClickToRun Service Monitor" -ErrorAction SilentlyContinue | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Office\OfficeTelemetryAgentFallBack2016" -ErrorAction SilentlyContinue | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Office\OfficeTelemetryAgentLogOn2016" -ErrorAction SilentlyContinue | Out-Null



		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Experience\AllowCortana" -Name "Value" -Type DWord -Value 0
			If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) {
				New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
			}
			Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Type DWord -Value 0
			If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization")) {
				New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization" -Force | Out-Null
			}
			Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization" -Name "AllowInputPersonalization" -Type DWord -Value 0
			Get-AppxPackage "Microsoft.549981C3F5F10" | Remove-AppxPackage


	Write-Host -ForegroundColor $NotificationColor Disabling Wi-Fi Sense...

		If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting")) {
			New-Item -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name "Value" -Type DWord -Value 0
		If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots")) {
			New-Item -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Name "Value" -Type DWord -Value 0
		If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config")) {
			New-Item -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" -Name "WiFISenseAllowed" -Type DWord -Value 0
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" -Name "AutoConnectAllowedOEM" -Type DWord -Value 0


	Write-Host -ForegroundColor $NotificationColor Disabling Bing Search in Start Menu...

		If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) {
			New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Type DWord -Value 1


	Write-Host -ForegroundColor $NotificationColor Disabling Application suggestions...

		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "FeatureManagementEnabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "OemPreInstalledAppsEnabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEnabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEverEnabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-314559Enabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353696Enabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContentEnabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Type DWord -Value 0
		If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement")) {
			New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Type DWord -Value 0
		If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace")) {
			New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -Name "AllowSuggestedAppsInWindowsInkWorkspace" -Type DWord -Value 0
		# Empty placeholder tile collection in registry cache and restart Start Menu process to reload the cache
		If ([System.Environment]::OSVersion.Version.Build -ge 17134) {
			$key = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*windows.data.placeholdertilecollection\Current"
			Set-ItemProperty -Path $key.PSPath -Name "Data" -Type Binary -Value $key.Data[0..15]
			Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
		}


	Write-Host -ForegroundColor $NotificationColor Disabling Feedback...

		If (!(Test-Path "HKCU:\Software\Microsoft\Siuf\Rules")) {
			New-Item -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Type DWord -Value 0
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Type DWord -Value 1
		Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClient" -ErrorAction SilentlyContinue | Out-Null
		Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" -ErrorAction SilentlyContinue | Out-Null


	Write-Host -ForegroundColor $NotificationColor Hiding Windows Defender SysTray icon...

		If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray")) {
			New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" -Name "HideSystray" -Type DWord -Value 1
		If ([System.Environment]::OSVersion.Version.Build -eq 14393) {
			Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsDefender" -ErrorAction SilentlyContinue
		} ElseIf ([System.Environment]::OSVersion.Version.Build -ge 15063) {
			Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SecurityHealth" -ErrorAction SilentlyContinue
		}

	Write-Host -ForegroundColor $NotificationColor Disabling IPv6 stack...
		Disable-NetAdapterBinding -Name "*" -ComponentID "ms_tcpip6"


	Write-Host -ForegroundColor $NotificationColor Enabling Windows Update automatic downloads...
		Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -ErrorAction SilentlyContinue


	Write-Host -ForegroundColor $NotificationColor Enabling System Restore for system drive...
		vssadmin Resize ShadowStorage /On=$env:SYSTEMDRIVE /For=$env:SYSTEMDRIVE /MaxSize=10GB
		Enable-ComputerRestore -Drive "$env:SYSTEMDRIVE"


	Write-Host -ForegroundColor $NotificationColor Starting and enabling Superfetch service...
		Set-Service "SysMain" -StartupType Automatic
		Start-Service "SysMain" -WarningAction SilentlyContinue


	Write-Host -ForegroundColor $NotificationColor Starting and enabling Windows Search indexing service...
		Set-Service "WSearch" -StartupType Automatic
		Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch" -Name "DelayedAutoStart" -Type DWord -Value 1
		Start-Service "WSearch" -WarningAction SilentlyContinue    


	Write-Host -ForegroundColor $NotificationColor Disabling Fast Startup...
		Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Type DWord -Value 0


	Write-Host -ForegroundColor $NotificationColor Showing Taskbar Search icon...
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 1


	Write-Host -ForegroundColor $NotificationColor Hiding People icon...
		If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People")) {
			New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Type DWord -Value 0


	Write-Host -ForegroundColor $NotificationColor Enabling Clipboard History...
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Type DWord -Value 1


	Write-Host -ForegroundColor $NotificationColor Setting Control Panel view to small icons...
		If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel")) {
			New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "StartupPage" -Type DWord -Value 1
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "AllItemsIconView" -Type DWord -Value 1


	Write-Host -ForegroundColor $NotificationColor Enabling NumLock after startup...
		If (!(Test-Path "HKU:")) {
			New-PSDrive -Name "HKU" -PSProvider "Registry" -Root "HKEY_USERS" | Out-Null
		}
		Set-ItemProperty -Path "HKU:\.DEFAULT\Control Panel\Keyboard" -Name "InitialKeyboardIndicators" -Type DWord -Value 2147483650
		Add-Type -AssemblyName System.Windows.Forms
		If (!([System.Windows.Forms.Control]::IsKeyLocked('NumLock'))) {
			$wsh = New-Object -ComObject WScript.Shell
			$wsh.SendKeys('{NUMLOCK}')
		}


	Write-Host -ForegroundColor $NotificationColor Enabling verbose startup/shutdown status messages...
		If ((Get-CimInstance -Class "Win32_OperatingSystem").ProductType -eq 1) {
			Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 1
		} Else {
			Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -ErrorAction SilentlyContinue
		}


	Write-Host -ForegroundColor $NotificationColor Disabling Xbox features...
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 0
		If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR")) {
			New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" | Out-Null
		}
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Type DWord -Value 0


	Write-Host -ForegroundColor $NotificationColor Disabling First Logon Animation...
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableFirstLogonAnimation" -Type DWord -Value 0


	Write-Host -ForegroundColor $NotificationColor Removing Weather Taskbar Widget...
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Type DWord -Value 2

	Write-Host -ForegroundColor $NotificationColor Unpinning all Start Menu tiles...
		If ([System.Environment]::OSVersion.Version.Build -ge 15063 -And [System.Environment]::OSVersion.Version.Build -le 16299) {
			Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount" -Include "*.group" -Recurse | ForEach-Object {
				$data = (Get-ItemProperty -Path "$($_.PsPath)\Current" -Name "Data").Data -Join ","
				$data = $data.Substring(0, $data.IndexOf(",0,202,30") + 9) + ",0,202,80,0,0"
				Set-ItemProperty -Path "$($_.PsPath)\Current" -Name "Data" -Type Binary -Value $data.Split(",")
			}
		} ElseIf ([System.Environment]::OSVersion.Version.Build -ge 17134) {
			$key = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*start.tilegrid`$windows.data.curatedtilecollection.tilecollection\Current"
			$data = $key.Data[0..25] + ([byte[]](202,50,0,226,44,1,1,0,0))
			Set-ItemProperty -Path $key.PSPath -Name "Data" -Type Binary -Value $data
			Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
		}


		Write-Host -ForegroundColor $NotificationColor Showing all tray icons...
			If (!(Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer")) {
				New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" | Out-Null
			}
			Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoAutoTrayNotify" -Type DWord -Value 1

		Write-Host -ForegroundColor $NotificationColor Removing Meet Now Feature...
			If (!(Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer")) {
				New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" | Out-Null
			}
			Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -Type DWord -Value 1

	# Run the User-Config Script
	./DebloatScript-HKCU.ps1
	

# Implement User Logon Script

If ( $EnableUserLogonScript -eq "Yes" -or $EnableUserLogonScript -eq "Y") { 
	Write-Host -ForegroundColor $NotificationColor "Creating Directories 'C:\Windows\FirstUserLogon' and Copying files"
		mkdir "C:\Windows\FirstUserLogon" -ErrorAction SilentlyContinue
		Copy-Item "DebloatScript-HKCU.ps1" "C:\Windows\FirstUserLogon\DebloatScript-HKCU.ps1"
		Copy-Item "FirstLogon.bat" "C:\Windows\FirstUserLogon\FirstLogon.bat"
	Write-Host

	Write-Host -ForegroundColor $NotificationColor "Enabling Registry Keys to run Logon Script"
		REG LOAD HKEY_Users\DefaultUser "C:\Users\Default\NTUSER.DAT"
		Set-ItemProperty -Path "REGISTRY::HKEY_USERS\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Run" -Name "FirstUserLogon" -Value "C:\Windows\FirstUserLogon\FirstLogon.bat" -Type "String"
		REG UNLOAD HKEY_Users\DefaultUser
	
	Write-Host -ForegroundColor $NotificationColor "New User Logon Script Successfully Enabled"
}

	remove-item "DebloatScript-HKCU.ps1" -Force
	remove-item "FirstLogon.bat" -Force
	remove-item "cleanup.cmd" -Force

	Write-Host -ForegroundColor Red "Complete. Please review errors, and it is recommended to restart the computer now"
	
	Shutdown.exe -r -t 90
	Write-Host
	Write-Host -ForegroundColor Red "System will restart in 90 seconds. To abort, send command: Shutdown.exe -a "

	Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force







