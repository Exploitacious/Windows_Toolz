# Powershell script for running as Current User - run once at logon
# This script DOES NOT require any admin rights to run. Should be ran as logged-on user context.

# Start Menu and Taskbar 

# - Enables Clipboard History

	Write-Host -ForegroundColor "Red" Disabling Cortana...
		If (!(Test-Path "HKCU:\Software\Microsoft\Personalization\Settings")) {
			New-Item -Path "HKCU:\Software\Microsoft\Personalization\Settings" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Type DWord -Value 0
		If (!(Test-Path "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore")) {
			New-Item -Path "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Type DWord -Value 1
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Type DWord -Value 1
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCortanaButton" -Type DWord -Value 0


	Write-Host -ForegroundColor "Red" Disabling Bing Search in Start Menu...
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Type DWord -Value 0


	Write-Host -ForegroundColor "Red" Disabling Application suggestions...
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Type DWord -Value 0
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
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Type DWord -Value 0
		If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement")) {
			New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Type DWord -Value 0


	Write-Host -ForegroundColor "Red" Unpinning all Start Menu tiles...
		If ([System.Environment]::OSVersion.Version.Build -ge 15063 -And [System.Environment]::OSVersion.Version.Build -le 16299) {
			Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount" -Include "*.group" -Recurse | ForEach-Object {
				$data = (Get-ItemProperty -Path "$($_.PsPath)\Current" -Name "Data").Data -Join ","
				$data = $data.Substring(0, $data.IndexOf(",0,202,30") + 9) + ",0,202,80,0,0"
				Set-ItemProperty -Path "$($_.PsPath)\Current" -Name "Data" -Type Binary -Value $data.Split(",")
			}
		}
		ElseIf ([System.Environment]::OSVersion.Version.Build -ge 17134) {
			$key = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*start.tilegrid`$windows.data.curatedtilecollection.tilecollection\Current"
			$data = $key.Data[0..25] + ([byte[]](202, 50, 0, 226, 44, 1, 1, 0, 0))
			Set-ItemProperty -Path $key.PSPath -Name "Data" -Type Binary -Value $data
			Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
		}



# System Tray Modifications

	Write-Host -ForegroundColor "Red" Showing Taskbar Search icon...
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 1


	Write-Host -ForegroundColor "Red" Hiding People icon...
		If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People")) {
			New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Type DWord -Value 0


	Write-Host -ForegroundColor "Red" Removing Weather Taskbar Widget...
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Type DWord -Value 2



# Other Modifications

	Write-Host -ForegroundColor "Red" Setting Control Panel view to small icons...
		If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel")) {
			New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "StartupPage" -Type DWord -Value 1
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "AllItemsIconView" -Type DWord -Value 1


	Write-Host -ForegroundColor "Red" Disabling Xbox features...
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Type DWord -Value 0
		Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 0


	Write-Host -ForegroundColor "Red" Disabling Feedback...
		If (!(Test-Path "HKCU:\Software\Microsoft\Siuf\Rules")) {
			New-Item -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Type DWord -Value 0


	Write-Host -ForegroundColor "Red" Enabling Clipboard History...
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Type DWord -Value 1


	Write-Host -ForegroundColor "Red" Enabling Storage Sense...
		If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy")) {
			New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Force | Out-Null
		}
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -Type DWord -Value 1
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "StoragePoliciesNotified" -Type DWord -Value 1


Write-Output "Restarting Explorer"
	Stop-Process -ProcessName explorer





