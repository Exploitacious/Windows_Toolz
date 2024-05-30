REM ----------------------------------------------------------------------------------------------------------
REM Customizations for AVD
REM ### CMD User ONLY HKCU
REM ### Apps and app suggestions
REM ----------------------------------------------------------------------------------------------------------

	REM TITLE: Turn Off Automatic Installation of Suggested Apps in Windows 10
		REM LINK: https://www.tenforums.com/tutorials/68217-turn-off-automatic-installation-suggested-apps-windows-10-a.html
			REM OPTIONS: 0x00000001=On, 0x00000000=Off
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /V "SilentInstalledAppsEnabled" /T "REG_DWORD" /D "0x00000000" /F 1>NUL 2>&1

	REM TITLE: Turn Off Suggested Content Settings App Windows 10 Turn Off Suggested Content In Settings
		REM LINK: https://www.tenforums.com/tutorials/100541-turn-off-suggested-content-settings-app-windows-10-a.html
			REM OPTIONS: 0x00000001=On, 0x00000000=Off
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /V "SubscribedContent-338393Enabled" /T "REG_DWORD" /D "0x00000000" /F 1>NUL 2>&1
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /V "SubscribedContent-353694Enabled" /T "REG_DWORD" /D "0x00000000" /F 1>NUL 2>&1
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /V "SubscribedContent-353696Enabled" /T "REG_DWORD" /D "0x00000000" /F 1>NUL 2>&1
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /V "SubscribedContent-338388Enabled" /T "REG_DWORD" /D "0x00000000" /F 1>NUL 2>&1
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /V "SubscribedContent-338389Enabled" /T "REG_DWORD" /D "0x00000000" /F 1>NUL 2>&1
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /V "SystemPaneSuggestionsEnabled" /T "REG_DWORD" /D "0x00000000" /F 1>NUL 2>&1

REM ----------------------------------------------------------------------------------------------------------
REM ### Desktop, taskbar and notifications
REM ----------------------------------------------------------------------------------------------------------

	REM TITLE: Hide News and interests in the taskbar
		REM LINK: https://www.tenforums.com/tutorials/188597-add-remove-news-interests-icon-taskbar-windows-10-a.html
			REM OPTIONS: "0"=On, "2"=Off
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /V "ShellFeedsTaskbarViewMode" /T "REG_DWORD" /D "0x00000002" /F 1>NUL

	REM TITLE: Show file extensions in Windows explorer
		REM LINK: https://www.tenforums.com/tutorials/62842-hide-show-file-name-extensions-windows-10-a.html
			REM OPTIONS: "1"=On, "0"=Off
				REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V "HideFileExt" /T REG_DWORD /D "0x00000000" /F 1>NUL 2>&1

	REM TITLE: Remove Search Icon from Windows 10 Taskbar
		REM LINK: N/A
			REM OPTIONS: "1"=On, "0"=Off
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /V "SearchboxTaskbarMode" /T REG_DWORD /D "0x00000000" /F 1>NUL 2>&1

	REM TITLE: Remove Task View from Windows 10 Taskbar
		REM LINK: N/A
			REM OPTIONS: "1"=On, "0"=Off
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V "ShowTaskViewButton" /T REG_DWORD /D "0x00000000" /F 1>NUL 2>&1

	REM TITLE: Always show all icons in the notification area
		REM LINK: N/A
			REM OPTIONS: "1"=Never show, "0"=Always show
				REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /V EnableAutoTray /T REG_DWORD /D "0x00000000" /F 1>NUL 2>&1

	REM TITLE: Remove People Button from Taskbar
		REM LINK: N/A
			REM OPTIONS: "1"=On, "0"=Off
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" /V PeopleBand /T REG_DWORD /D "0x00000000" /F 1>NUL 2>&1

                	REM TITLE: Open This Computer to My Computer
		REM LINK: https://www.tenforums.com/tutorials/3734-open-pc-quick-access-file-explorer-windows-10-a.html
			REM OPTIONS: "1"=On, "0"=Off
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "LaunchTo" /t REG_DWORD /D "0x00000001"  /F 1>NUL 2>&1

	REM TITLE: Hide "Recently used files" in Quick access in Windows Explorer	
		REM LINK: https://www.tenforums.com/tutorials/2713-add-remove-recent-files-quick-access-windows-10-a.html
			REM OPTIONS: REG DEL values 
				REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V "Start_TrackDocs" /T "REG_DWORD" /D "0x00000000" /F 1>NUL 2>&1

	REM TITLE: Hide "Frequently used files" in Quick access in Windows Explorer	
		REM LINK: https://www.tenforums.com/tutorials/2712-add-remove-frequent-folders-quick-access-windows-10-a.html
			REM OPTIONS: "1"=On, "0"=Off
				REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /V "ShowFrequent" /T "REG_DWORD" /D "0x00000000" /F 1>NUL 2>&1

	REM TITLE: Turn on "Show all folders" in Windows Explorer navigation pane
		REM LINK: https://www.tenforums.com/tutorials/7078-turn-off-show-all-folders-windows-10-navigation-pane.html
			REM OPTIONS: "0x00000001"=Turn on, "0x00000000"=Turn off 
				REM REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V "NavPaneShowAllFolders" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
	
	REM TITLE: Disable making "-shortcut" text for shortcuts
		REM LINK: https://www.tenforums.com/tutorials/7078-turn-off-show-all-folders-windows-10-navigation-pane.html
			REM OPTIONS: "0x00000001"=Turn on, "0x00000000"=Turn off 
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /V link /T REG_Binary /D 00000000  /F 1>NUL 2>&1
				REG DEL "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates" /V ShortcutNameTemplate  /F 1>NUL 2>&1

	REM TITLE: Hide Meet Now icon in the taskbar
		REM LINK: https://www.tenforums.com/tutorials/165990-how-add-remove-meet-now-icon-taskbar-windows-10-a.html
			REM OPTIONS: "0x00000001"=Hide, "0x00000000"=Show
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /V "HideSCAMeetNow" /T "REG_DWORD" /D "0x00000001" /F 1>NUL

REM ----------------------------------------------------------------------------------------------------------
REM ### Privacy settings
REM ----------------------------------------------------------------------------------------------------------

	REM TITLE: Disable "Let websites provide locally relevant content by accessing my language list"
		REM LINK: https://www.tenforums.com/tutorials/82980-turn-off-website-access-language-list-windows-10-a.html
			REM OPTIONS: 1 means disable and 0 means enable
				REG ADD "HKCU\Control Panel\International\User Profile" /V "HttpAcceptLanguageOptOut" /T "REG_DWORD" /D "0x00000001" /F 1>NUL

	REM TITLE: Disable "Let Windows track app launches to improve Start and search results"
		REM LINK: https://www.tenforums.com/tutorials/82967-turn-off-app-launch-tracking-windows-10-a.html
			REM OPTIONS: 1 means disable and 0 means enable
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V "Start_TrackProgs" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

	REM TITLE: Disable "Online Speech recognition"
		REM LINK: https://www.tenforums.com/tutorials/101902-turn-off-online-speech-recognition-windows-10-a.html
			REM OPTIONS: 1 means disable and 0 means enable
				REG ADD "HKCU\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /V "HasAccepted" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

	REM TITLE: Disable "Personal typing / Ink and typing personalization"
		REM LINK: https://www.tenforums.com/tutorials/118127-turn-off-inking-typing-personalization-windows-10-a.html
			REM OPTIONS: To diable set RestrictImplicitInkCollection and RestrictImplicitTextCollection to 1 and HarvestContacts and AcceptedPrivacyPolicy to 0.
				REG ADD "HKCU\Software\Microsoft\InputPersonalization" /V "RestrictImplicitInkCollection" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
				REG ADD "HKCU\Software\Microsoft\InputPersonalization" /V "RestrictImplicitTextCollection" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
				REG ADD "HKCU\Software\Microsoft\InputPersonalization\TrainedDataStore" /V "HarvestContacts" /T "REG_DWORD" /D "0x00000000" /F 1>NUL
				REG ADD "HKCU\Software\Microsoft\Personalization\Settings" /V "AcceptedPrivacyPolicy" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

	REM TITLE: Turn off "Improve inking and typing"
		REM LINK: https://www.tenforums.com/tutorials/107050-turn-off-improve-inking-typing-recognition-windows-10-a.html
			REM OPTIONS: 0 means off 1 means on.
				REG ADD "HKCU\Software\Microsoft\Input\TIPC" /V "Enabled" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

	REM TITLE: Turn off "Tailored experiences based on the diagnostic data settings"
		REM LINK: https://www.tenforums.com/tutorials/76426-turn-off-tailored-experiences-diagnostic-data-windows-10-a.html
			REM OPTIONS: 0 means off 1 means on.
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /V "TailoredExperiencesWithDiagnosticDataEnabled" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

	REM TITLE: Turn off "Location service for your account and apps"
		REM LINK: https://www.tenforums.com/tutorials/100341-enable-disable-collect-activity-history-windows-10-a.html
			REM OPTIONS: 0 means off 1 means on
				REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL

	REM TITLE: Never ask for feedback
		REM LINK: https://www.tenforums.com/tutorials/2441-how-change-feedback-frequency-windows-10-a.html
			REM OPTIONS: 
				REG ADD "HKCU\Software\Microsoft\Windows\Siuf\Rules" /V "NumberOfSIUFInPeriod" /T "REG_DWORD" /D "0x00000000" /F 1>NUL 2>&1

	REM TITLE: Turn off "Location service for your account and apps"
		REM LINK: https://www.tenforums.com/tutorials/13225-turn-off-location-services-windows-10-a.html
			REM OPTIONS: 0 means off 1 means on
				REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL

	REM TITLE: Turn off "Allow apps to access your location"
		REM LINK: https://www.tenforums.com/tutorials/13225-turn-off-location-services-windows-10-a.html
			REM OPTIONS: 
				REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL

REM ----------------------------------------------------------------------------------------------------------
REM ### Visual performance options
REM ----------------------------------------------------------------------------------------------------------

	REM TITLE: Desktop Wallpaper Jpeg Quality Reduction Disable Windows 10 Disable Jpeg Desktop Wallpaper Import Quality	
		REM LINK: http://www.tenforums.com/tutorials/65668-desktop-wallpaper-jpeg-quality-reduction-disable-windows-10-a.html
			REM: OPTIONS: Retain compression: REG DELETE "HKCU\Control Panel\Desktop" /V "JPEGImportQuality" /F 1>NUL 2>&1
				REM REG ADD "HKCU\Control Panel\Desktop" /V "JPEGImportQuality" /T "REG_DWORD" /D "0x00000064" /F 1>NUL 2>&1
				
	REM TITLE: Show window contents while dragging
		REM LINK: https://www.tenforums.com/tutorials/27449-turn-off-show-window-contents-while-dragging-windows-10-a.html
			REM: OPTIONS: 1 = On 0 = Off
				REM REG ADD "HKEY_CURRENT_USER\Control Panel\Desktop" /V DragFullWindows /T REG_SZ /D 1 /F

	REM TITLE: Smooth edges of screen fonts
		REM LINK: https://www.tenforums.com/tutorials/126775-enable-disable-font-smoothing-windows.html
			REM: OPTIONS: 2 = On 0 = Off	
				REM REG ADD "HKEY_CURRENT_USER\Control Panel\Desktop" /V FontSmoothing /T REG_SZ /D 2 /F

	REM TITLE: Show borders on Windows (NOTE: This is a combination of multiple settings)
		REM LINK: https://www.tenforums.com/tutorials/6377-change-visual-effects-settings-windows-10-a.html#option4
			REM: OPTIONS: 9032078010000000 = 
				REM REG ADD "HKEY_CURRENT_USER\Control Panel\Desktop" /V UserPreferencesMask /t REG_BINARY /d 9032078010000000 /F

	REM TITLE: Animate Windows when Minimizing and Maximizing
		REM LINK: https://www.tenforums.com/tutorials/126788-enable-disable-animate-windows-when-minimizing-maximizing.html
			REM: OPTIONS: 2 = On 0 = Off
				REM REG ADD "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /V MinAnimate /T REG_SZ /D 2 /F

	REM TITLE: Nobody knows what this does, but Microsoft recommend turning it off for VMs
		REM LINK: https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-vdi-recommendations-2004
			REM: OPTIONS: Nobody knows
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /V ShellState /t REG_BINARY /d 240000003C2800000000000000000000 /F

	REM TITLE: Thumbnail Previews in File Explorer
		REM LINK: https://www.tenforums.com/tutorials/18834-enable-disable-thumbnail-previews-file-explorer-windows-10-a.html
			REM: OPTIONS: 0 = Thumbnails for picture files 1 = No thumbnails, only Icons
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V IconsOnly /t REG_DWORD /D 0 /F

	REM TITLE: Translucent Selection Rectangle on Desktop
		REM LINK: https://www.tenforums.com/tutorials/113254-turn-off-translucent-selection-rectangle-desktop-windows.html
			REM: OPTIONS:0 = Off 1 = On
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V ListviewAlphaSelect /t REG_DWORD /D 1 /F

	REM TITLE: Drop Shadows for Icon Labels
		REM LINK: https://www.tenforums.com/tutorials/126714-add-remove-drop-shadows-icon-labels-desktop-windows.html
			REM: OPTIONS:0 = Remove 1 = Add
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V ListviewShadow /t REG_DWORD /D 1 /F

	REM TITLE: show NTFS compressed files with another color
		REM LINK: https://www.tenforums.com/software-apps/117664-win10xpe-build-your-own-rescue-media-28.html
			REM: OPTIONS: ...
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V ShowCompColor /t REG_DWORD /D 1 /F

	REM TITLE: Show Pop-up Description for Folder and Desktop Items
		REM LINK: https://www.tenforums.com/tutorials/89239-hide-show-pop-up-descriptions-windows-10-a.html
			REM: OPTIONS:0 = Hide 1 = Show
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V ShowInfoTip /t REG_DWORD /D 1 /F

	REM TITLE: Animations in the Taskbar
		REM LINK: https://www.tenforums.com/tutorials/126795-enable-disable-animations-taskbar-windows-10-a.html
			REM: OPTIONS:0 = Remove 1 = Add
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V TaskbarAnimations /t REG_DWORD /D 0 /F

	REM TITLE: Change Visual Effects Settings
		REM LINK: https://www.tenforums.com/tutorials/6377-change-visual-effects-settings-windows-10-a.html
			REM: OPTIONS: 0 (zero) for Let Windows choose what's best for my computer settings. 1 for Adjust for best appearance settings. 2 for Adjust for best Performance settings. 3 for Custom settings.
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /V VisualFXSetting /t REG_DWORD /d 3 /F

	REM TITLE: Peek at Desktop
		REM LINK: https://www.tenforums.com/tutorials/47266-turn-off-peek-desktop-windows-10-a.html#option4
			REM: OPTIONS:0 = Off 1 = On
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\DWM" /V EnableAeroPeek /t REG_DWORD /D 0 /F

	REM TITLE: 
		REM LINK: 
			REM: OPTIONS:
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\DWM" /V AlwaysHiberNateThumbnails /t REG_DWORD /D 0 /F

	REM TITLE: Save Taskbar Thumbnail Previews to Cache in Windows
		REM LINK: https://www.tenforums.com/tutorials/126722-enable-disable-save-taskbar-thumbnail-previews-cache-windows.html
			REM: OPTIONS:0 = Disable 1 = Enable
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /V 01 /t REG_DWORD /D 0 /F

	REM TITLE: Let apps run in the background: Photos
		REM LINK: 
			REM: OPTIONS:
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.Windows.Photos_8wekyb3d8bbwe" /V Disabled /t REG_DWORD /D 1 /F

	REM TITLE: Let apps run in the background: Photos
		REM LINK: 
			REM: OPTIONS:
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.Windows.Photos_8wekyb3d8bbwe" /V DisabledByUser /t REG_DWORD /D 1 /F

	REM TITLE: Let apps run in the background: Skype
		REM LINK: 
			REM: OPTIONS:
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.SkypeApp_kzf8qxf38zg5c" /V Disabled /t REG_DWORD /D 1 /F

	REM TITLE: Let apps run in the background: Skype
		REM LINK: 
			REM: OPTIONS:
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.SkypeApp_kzf8qxf38zg5c" /V DisabledByUser /t REG_DWORD /D 1 /F

	REM TITLE: Let apps run in the background: Your Phone
		REM LINK: 
			REM: OPTIONS:
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.YourPhone_8wekyb3d8bbwe" /V Disabled /t REG_DWORD /D 1 /F

	REM TITLE: Let apps run in the background: Your Phone
		REM LINK: 
			REM: OPTIONS:
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.YourPhone_8wekyb3d8bbwe" /V DisabledByUser /t REG_DWORD /D 1 /F

	REM TITLE: Let apps run in the background: Edge
		REM LINK: 
			REM: OPTIONS:
				REM REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" /V Disabled /t REG_DWORD /D 1 /F

	REM TITLE: Let apps run in the background: Edge
		REM LINK: 
			REM: OPTIONS:
				REM REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" /V DisabledByUser /t REG_DWORD /D 1 /F

	REM TITLE: Get even more out of Windows message
		REM LINK: https://www.tenforums.com/tutorials/137645-turn-off-get-even-more-out-windows-suggestions-windows-10-a.html
			REM: OPTIONS: 0 = Off 1 = On
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /V ScoobeSystemSettingEnabled /t REG_DWORD /D 0 /F

REM ----------------------------------------------------------------------------------------------------------
REM ### Lock screen
REM ----------------------------------------------------------------------------------------------------------

	REM TITLE: Turn off "Get fun facts and more from Windows and Cortana on your lock screen"
		REM LINK: 
			REM OPTIONS: 
				REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /V "RotatingLockScreenOverlayEnabled" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

REM ----------------------------------------------------------------------------------------------------------
REM ### Desktop Settings
REM ----------------------------------------------------------------------------------------------------------

REM Tutorial: https://www.elevenforum.com/t/change-taskbar-alignment-in-windows-11.12/
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V "TaskbarAl" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

REM Tutorial: https://www.elevenforum.com/t/add-or-remove-search-button-on-taskbar-in-windows-11.1197/
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /V "SearchboxTaskbarMode" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

REM Tutorial: https://www.elevenforum.com/t/add-or-remove-task-view-button-on-taskbar-in-windows-11.1037/
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V "ShowTaskViewButton" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

REM Tutorial: https://www.elevenforum.com/t/add-or-remove-widgets-button-on-taskbar-in-windows-11.32/
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V "TaskbarDa" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

REM Tutorial: https://www.elevenforum.com/t/add-or-remove-chat-button-on-taskbar-in-windows-11.696/
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V "TaskbarMn" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

REM Tutorial: https://www.elevenforum.com/t/add-or-remove-copilot-button-on-taskbar-in-windows-11.16015/
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V "ShowCopilotButton" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

REM Tutorial: https://www.elevenforum.com/t/enable-or-disable-search-on-taskbar-and-start-menu-in-windows-11.8601/
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /V "InstalledWin32AppsRevision" /T "REG_SZ" /D "{68C27189-9CFE-4F68-97FB-29D0AFB49068}" /F 1>NUL
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /V "InstalledPackagedAppsRevision" /T "REG_SZ" /D "{FEAE1A90-911F-4196-B5C0-A52C39E23AE1}" /F 1>NUL
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /V "SearchboxTaskbarMode" /T "REG_DWORD" /D "0x00000000" /F 1>NUL
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Search\JumplistData" /V "windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel" /T "REG_QWORD" /D "0x01DA0F09D3882FB0" /F 1>NUL

REM: Tutorial: https://www.joseespitia.com/2019/07/24/registry-keys-for-windows-10-application-privacy-settings/
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL

REM Turn off transparency
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /V "EnableTransparency" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

REM Tutorial: https://www.elevenforum.com/t/turn-on-or-off-hidden-icon-menu-on-taskbar-corner-in-windows-11.5132/
REG ADD "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify" /V "SystemTrayChevronVisibility" /T "REG_DWORD" /D "0x00000001" /F 1>NUL

REM Tutorial: https://www.elevenforum.com/t/disable-show-more-options-context-menu-in-windows-11.1589/
REG ADD "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /V "" /D "" /F 1>NUL

REM Must be run at the end of the script because it will remove previous app suggestions in Start after you have turned off app suggestions
REM Tutorial: https://www.tenforums.com/tutorials/3087-reset-start-layout-windows-10-a.html
REG DELETE "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount" /F 1>NUL

taskkill /f /im explorer.exe
start explorer.exe