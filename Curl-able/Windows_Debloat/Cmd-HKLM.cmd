REM ----------------------------------------------------------------------------------------------------------
REM Customizations for AVD
REM ### CMD SYSTEM ONLY HKLM
REM ### Desktop, taskbar and notifications
REM ----------------------------------------------------------------------------------------------------------


	REM TITLE: Disable Microsoft Edge shortcut creation on desktop for new user profiles
		REM LINK: https://social.technet.microsoft.com/wiki/contents/articles/51546.windows-10-build-1803-registry-tweak-to-disable-microsoft-edge-shortcut-creation-on-desktop.aspx
			REM OPTIONS: REG DEL the registry key to enable
				REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer /v "DisableEdgeDesktopShortcutCreation" /t REG_DWORD /D "0x00000001"  /F 1>NUL 2>&1
				DEL "%userprofile%\Desktop\Microsoft Edge.lnk"


	REM TITLE: Hide Meet Now icon in the taskbar
		REM LINK: https://www.tenforums.com/tutorials/165990-how-add-remove-meet-now-icon-taskbar-windows-10-a.html
			REM OPTIONS: "0x00000001"=Hide, "0x00000000"=Show
				REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /V "HideSCAMeetNow" /T "REG_DWORD" /D "0x00000001" /F 1>NUL

REM ----------------------------------------------------------------------------------------------------------
REM ### Privacy settings
REM ----------------------------------------------------------------------------------------------------------

	REM TITLE: Disable "Use sign-in info to auto finish setting up device and reopen apps after update or restart" (for all users)
		REM LINK: https://www.tenforums.com/tutorials/49963-use-sign-info-auto-finish-after-update-restart-windows-10-a.html
			REM OPTIONS: 1 means disable and 0 means enable
				REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /V "DisableAutomaticRestartSignOn" /T "REG_DWORD" /D "0x00000001" /F 1>NUL

	REM TITLE: Disable "Let apps use advertising ID to make ads more interesting to you based on your app activity (Turning this off will reset your ID.)"
		REM LINK: https://www.tenforums.com/tutorials/76453-enable-disable-advertising-id-relevant-ads-windows-10-a.html
			REM OPTIONS: 1 means disable and 0 means enable
				REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /V "DisabledByGroupPolicy" /T "REG_DWORD" /D "0x00000001" /F 1>NUL

	REM TITLE: Set diagnostic data to Basic instead of full
		REM LINK: https://www.tenforums.com/tutorials/7032-change-diagnostic-data-settings-windows-10-a.html#option5
			REM OPTIONS: 1 equals basic and 0 equals full.
				REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /V "AllowTelemetry" /T "REG_DWORD" /D "0x00000001" /F 1>NUL


	REM TITLE: Turn off "View diagnostic data"
		REM LINK: https://www.tenforums.com/tutorials/103059-enable-disable-diagnostic-data-viewer-windows-10-a.html#option4
			REM OPTIONS: 1 means off 0 means on.
				REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /V "DisableDiagnosticDataViewer" /T "REG_DWORD" /D "0x00000001" /F 1>NUL

	REM TITLE: Turn off Microsoft asking for your feedback a.k.a "Feedback frequency"
		REM LINK: https://www.tenforums.com/tutorials/2441-change-feedback-frequency-windows-10-a.html
			REM OPTIONS: 1 means off 0 means on.
				REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /V "DoNotShowFeedbackNotifications" /T "REG_DWORD" /D "0x00000001" /F 1>NUL

	REM TITLE: Turn off Microsoft asking for your feedback a.k.a "Feedback frequency"
		REM LINK: https://www.tenforums.com/tutorials/113553-turn-off-automatic-recommended-troubleshooting-windows-10-a.html
			REM OPTIONS: 1= Only fix critical problems for me 2 = Ask me before fixing problems 3 = Tell me when problems get fixed 4= Fix problems for me without asking
				REG ADD "HKLM\SOFTWARE\Microsoft\WindowsMitigation" /V "UserPreference" /T "REG_DWORD" /D "0x00000002" /F 1>NUL

	REM TITLE: Disable Collect Activity History (requires sign out and sign in)
		REM LINK: https://www.tenforums.com/tutorials/100341-enable-disable-collect-activity-history-windows-10-a.html
			REM OPTIONS: 0 means off 1 means on
				REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /V "PublishUserActivities" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

	REM TITLE: Disable Collect Activity History (requires sign out and sign in)
		REM LINK: https://www.tenforums.com/tutorials/100341-enable-disable-collect-activity-history-windows-10-a.html
			REM OPTIONS: 0 means off 1 means on
				REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /V "PublishUserActivities" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

	REM TITLE: Turn off Location for this device (disable allow access to location on this device)
		REM LINK: https://www.tenforums.com/tutorials/13225-turn-off-location-services-windows-10-a.html
			REM OPTIONS: 
				REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL

REM ----------------------------------------------------------------------------------------------------------
REM ### Explorer and context menu
REM ----------------------------------------------------------------------------------------------------------

	REM TITLE: Remove folder shortcuts in "This PC"
		REM LINK: 
			REM OPTIONS: Reg DEL removes the shortcut
				REM Remove Desktop From This PC
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /F 1>NUL
				REM Remove Documents From This PC
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" /F 1>NUL
				REM Remove Downloads From This PC
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" /F 1>NUL
				REM Remove Music From This PC
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" /F 1>NUL
				REM Remove Pictures From This PC
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" /F 1>NUL
				REM Remove Videos From This PC
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}" /F 1>NUL
				REM REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" /F 1>NUL
				REM Remove 3D Objects
				REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /F 1>NUL
				REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /F 1>NUL

		REM TITLE: Remove Default Desktop Icons (This PC, Users folder, Network, Recycle bin, Control Panel)
			REM LINK: https://www.tenforums.com/tutorials/6942-add-remove-default-desktop-icons-windows-10-a.html
				REM OPTIONS: See link for description. "0x00000001=remove shortcut"
					REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /V "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
					REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" /V "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
					REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /V "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
					REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" /V "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
					REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /V "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
					REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" /V "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
					REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /V "{645FF040-5081-101B-9F08-00AA002F954E}" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
					REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" /V "{645FF040-5081-101B-9F08-00AA002F954E}" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
					REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /V "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" /T "REG_DWORD" /D "0x00000001" /F 1>NUL
					REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" /V "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" /T "REG_DWORD" /D "0x00000001" /F 1>NUL

		REM TITLE: Remove default extensions in the "new file" context menu
			REM LINK: 
				REM OPTIONS: "reg delete" to delete the extension. "REG ADD" to add
					REM reg delete "HKCR\.accdb\Access.Application.16\ShellNew"  /F 1>NUL 2>&1
					REM reg delete "HKCR\.mdb\ShellNew"  /F 1>NUL 2>&1
					REM reg delete "HKCR\.bmp\ShellNew" /F 1>NUL 2>&1
					REM reg delete "HKCR\.docx\Word.Document.12\ShellNew" /F 1>NUL 2>&1
					REM reg delete "HKCR\.xlsx\Excel.Sheet.12\ShellNew" /v "FileName" /T REG_SZ /D "C:\Program Files\Microsoft Office\Root\VFS\Windows\ShellNew\excel12.xlsx" /F 1>NUL 2>&1
					REM reg delete "HKCR\.pptx\PowerPoint.Show.12\ShellNew" /F 1>NUL 2>&1
					REM reg delete "HKCR\.pub\Publisher.Document.16\ShellNew" /F 1>NUL 2>&1
					REM reg delete "HKCR\.rtf\ShellNew" /F 1>NUL 2>&1
					REM reg delete "HKCR\.zip\CompressedFolder\ShellNew" /F 1>NUL 2>&1
					REM reg delete "HKCR\.zip\ShellNew" /F 1>NUL 2>&1
					REM reg delete "HKEY_CLASSES_ROOT\.contact\ShellNew" /F 1>NUL 2>&1

		REM TITLE: Add “Open elevated PowerShell window here” (Only works in Batch file)
			REM LINK: https://www.tenforums.com/tutorials/25721-open-elevated-windows-powershell-windows-10-a.html
				REM OPTIONS: 
					REG ADD "HKCR\Directory\Background\shell\PowerShellAsAdmin" /V "" /D "Open PowerShell window here as administrator" /F 1>NUL 2>&1
					REG DELETE "HKCR\Directory\Background\shell\PowerShellAsAdmin" /V "Extended" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\Background\shell\PowerShellAsAdmin" /V "HasLUAShield" /T "REG_SZ" /D "" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\Background\shell\PowerShellAsAdmin" /V "Icon" /T "REG_SZ" /D "powershell.exe" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\Background\shell\PowerShellAsAdmin\command" /V "" /D "PowerShell -windowstyle hidden -Command \"Start-Process cmd -ArgumentList '/s,/k,pushd,%%%V ^&^& start PowerShell ^&^& exit' -Verb RunAs\"" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\shell\PowerShellAsAdmin" /V "" /D "Open PowerShell window here as administrator" /F 1>NUL 2>&1
					REG DELETE "HKCR\Directory\shell\PowerShellAsAdmin" /V "Extended" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\shell\PowerShellAsAdmin" /V "HasLUAShield" /T "REG_SZ" /D "" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\shell\PowerShellAsAdmin" /V "Icon" /T "REG_SZ" /D "powershell.exe" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\shell\PowerShellAsAdmin\command" /V "" /D "PowerShell -windowstyle hidden -Command \"Start-Process cmd -ArgumentList '/s,/k,pushd,%%%V ^&^& start PowerShell ^&^& exit' -Verb RunAs\"" /F 1>NUL 2>&1
					REG ADD "HKCR\Drive\shell\PowerShellAsAdmin" /V "" /D "Open PowerShell window here as administrator" /F 1>NUL 2>&1
					REG DELETE "HKCR\Drive\shell\PowerShellAsAdmin" /V "Extended" /F 1>NUL 2>&1
					REG ADD "HKCR\Drive\shell\PowerShellAsAdmin" /V "HasLUAShield" /T "REG_SZ" /D "" /F 1>NUL 2>&1
					REG ADD "HKCR\Drive\shell\PowerShellAsAdmin" /V "Icon" /T "REG_SZ" /D "powershell.exe" /F 1>NUL 2>&1
					REG ADD "HKCR\Drive\shell\PowerShellAsAdmin\command" /V "" /D "PowerShell -windowstyle hidden -Command \"Start-Process cmd -ArgumentList '/s,/k,pushd,%%%V ^&^& start PowerShell ^&^& exit' -Verb RunAs\"" /F 1>NUL 2>&1
					REG ADD "HKCR\LibraryFolder\Background\shell\PowerShellAsAdmin" /V "" /D "Open PowerShell window here as administrator" /F 1>NUL 2>&1
					REG DELETE "HKCR\LibraryFolder\Background\shell\PowerShellAsAdmin" /V "Extended" /F 1>NUL 2>&1
					REG ADD "HKCR\LibraryFolder\Background\shell\PowerShellAsAdmin" /V "HasLUAShield" /T "REG_SZ" /D "" /F 1>NUL 2>&1
					REG ADD "HKCR\LibraryFolder\Background\shell\PowerShellAsAdmin" /V "Icon" /T "REG_SZ" /D "powershell.exe" /F 1>NUL 2>&1
					REG ADD "HKCR\LibraryFolder\Background\shell\PowerShellAsAdmin\command" /V "" /D "PowerShell -windowstyle hidden -Command \"Start-Process cmd -ArgumentList '/s,/k,pushd,%%%V ^&^& start PowerShell ^&^& exit' -Verb RunAs\"" /F 1>NUL 2>&1

		REM TITLE: Add "Open elevated command window here" (Only works in Batch file)
			REM LINK: https://www.tenforums.com/tutorials/59686-open-command-window-here-administrator-add-windows-10-a.html
				REM OPTIONS: 
					REG ADD "HKCR\Directory\shell\OpenCmdHereAsAdmin" /V "" /D "Open command window here as administrator" /F 1>NUL 2>&1
					REG DELETE "HKCR\Directory\shell\OpenCmdHereAsAdmin" /V "Extended" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\shell\OpenCmdHereAsAdmin" /V "Icon" /T "REG_SZ" /D "imageres.dll,-5324" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\shell\OpenCmdHereAsAdmin\command" /V "" /D "PowerShell -windowstyle hidden -Command \"Start-Process cmd -ArgumentList '/s,/k,pushd,%%%V' -Verb RunAs\"" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\Background\shell\OpenCmdHereAsAdmin" /V "" /D "Open command window here as administrator" /F 1>NUL 2>&1
					REG DELETE "HKCR\Directory\Background\shell\OpenCmdHereAsAdmin" /V "Extended" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\Background\shell\OpenCmdHereAsAdmin" /V "Icon" /T "REG_SZ" /D "imageres.dll,-5324" /F 1>NUL 2>&1
					REG ADD "HKCR\Directory\Background\shell\OpenCmdHereAsAdmin\command" /V "" /D "PowerShell -windowstyle hidden -Command \"Start-Process cmd -ArgumentList '/s,/k,pushd,%%%V' -Verb RunAs\"" /F 1>NUL 2>&1
					REG ADD "HKCR\Drive\shell\OpenCmdHereAsAdmin" /V "" /D "Open command window here as administrator" /F 1>NUL 2>&1
					REG DELETE "HKCR\Drive\shell\OpenCmdHereAsAdmin" /V "Extended" /F 1>NUL 2>&1
					REG ADD "HKCR\Drive\shell\OpenCmdHereAsAdmin" /V "Icon" /T "REG_SZ" /D "imageres.dll,-5324" /F 1>NUL 2>&1
					REG ADD "HKCR\Drive\shell\OpenCmdHereAsAdmin\command" /V "" /D "PowerShell -windowstyle hidden -Command \"Start-Process cmd -ArgumentList '/s,/k,pushd,%%%V' -Verb RunAs\"" /F 1>NUL 2>&1
					REG ADD "HKCR\LibraryFolder\background\shell\OpenCmdHereAsAdmin" /V "" /D "Open command window here as administrator" /F 1>NUL 2>&1
					REG DELETE "HKCR\LibraryFolder\background\shell\OpenCmdHereAsAdmin" /V "Extended" /F 1>NUL 2>&1
					REG ADD "HKCR\LibraryFolder\background\shell\OpenCmdHereAsAdmin" /V "Icon" /T "REG_SZ" /D "imageres.dll,-5324" /F 1>NUL 2>&1
					REG ADD "HKCR\LibraryFolder\background\shell\OpenCmdHereAsAdmin\command" /V "" /D "PowerShell -windowstyle hidden -Command \"Start-Process cmd -ArgumentList '/s,/k,pushd,%%%V' -Verb RunAs\"" /F 1>NUL 2>&1


REM ----------------------------------------------------------------------------------------------------------
REM ### Sound settings
REM ----------------------------------------------------------------------------------------------------------

	REM TITLE: Turn off system sounds
		REM LINK: 
			REM OPTIONS: 
				REM REG ADD "HKCU\AppEvents\Schemes" /V "" /D ".None" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default" /V "" /D "Windows" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default" /V "DispFileName" /T "REG_SZ" /D "@mmres.dll,-5856" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\.Default\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\.Default\.Default" /V "" /D "C:\Windows\media\Windows Background.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\.Default\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\AppGPFault\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\AppGPFault\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\AppGPFault\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\CCSelect\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\CCSelect\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\CCSelect\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\ChangeTheme\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\ChangeTheme\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\ChangeTheme\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Close\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Close\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Close\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\CriticalBatteryAlarm\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\CriticalBatteryAlarm\.Default" /V "" /D "C:\Windows\media\Windows Foreground.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\CriticalBatteryAlarm\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\DeviceConnect\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\DeviceConnect\.Default" /V "" /D "C:\Windows\media\Windows Hardware Insert.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\DeviceConnect\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\DeviceDisconnect\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\DeviceDisconnect\.Default" /V "" /D "C:\Windows\media\Windows Hardware Remove.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\DeviceDisconnect\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\DeviceFail\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\DeviceFail\.Default" /V "" /D "C:\Windows\media\Windows Hardware Fail.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\DeviceFail\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\FaxBeep\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\FaxBeep\.Default" /V "" /D "C:\Windows\media\Windows Notify Email.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\FaxBeep\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\LowBatteryAlarm\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\LowBatteryAlarm\.Default" /V "" /D "C:\Windows\media\Windows Background.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\LowBatteryAlarm\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MailBeep\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MailBeep\.Default" /V "" /D "C:\Windows\media\Windows Notify Email.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MailBeep\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Maximize\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Maximize\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Maximize\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MenuCommand\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MenuCommand\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MenuCommand\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MenuPopup\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MenuPopup\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MenuPopup\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MessageNudge\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MessageNudge\.Default" /V "" /D "C:\Windows\media\Windows Message Nudge.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\MessageNudge\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Minimize\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Minimize\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Minimize\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Default\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Default\.Default" /V "" /D "C:\Windows\media\Windows Notify System Generic.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Default\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.IM\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.IM\.Default" /V "" /D "C:\Windows\media\Windows Notify Messaging.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.IM\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,31,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,31,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm10\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,31,00,30,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm10\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,31,00,30,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm2\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,32,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm2\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,32,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm3\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,33,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm3\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,33,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm4\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,34,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm4\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,34,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm5\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,35,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm5\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,35,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm6\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,36,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm6\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,36,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm7\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,37,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm7\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,37,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm8\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,38,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm8\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,38,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm9\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,39,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Alarm9\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,41,00,6c,00,61,00,72,00,6d,00,30,00,39,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,31,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,31,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call10\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,31,00,30,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call10\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,31,00,30,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call2\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,32,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call2\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,32,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call3\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,33,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call3\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,33,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call4\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,34,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call4\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,34,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call5\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,35,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call5\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,35,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call6\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,36,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call6\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,36,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call7\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,37,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call7\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,37,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call8\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,38,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call8\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,38,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call9\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,39,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Looping.Call9\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,52,00,69,00,6e,00,67,00,30,00,39,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Mail\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Mail\.Default" /V "" /D "C:\Windows\media\Windows Notify Email.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Mail\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Proximity\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Proximity\.Default" /V "" /D "C:\Windows\media\Windows Proximity Notification.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Proximity\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Reminder\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Reminder\.Default" /V "" /D "C:\Windows\media\Windows Notify Calendar.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.Reminder\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.SMS\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.SMS\.Default" /V "" /D "C:\Windows\media\Windows Notify Messaging.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Notification.SMS\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Open\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Open\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\Open\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\PrintComplete\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\PrintComplete\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\PrintComplete\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\ProximityConnection\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\ProximityConnection\.Default" /V "" /D "C:\Windows\media\Windows Proximity Connection.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\ProximityConnection\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\RestoreDown\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\RestoreDown\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\RestoreDown\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\RestoreUp\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\RestoreUp\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\RestoreUp\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\ShowBand\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\ShowBand\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\ShowBand\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemAsterisk\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemAsterisk\.Default" /V "" /D "C:\Windows\media\Windows Background.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemAsterisk\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemExclamation\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemExclamation\.Default" /V "" /D "C:\Windows\media\Windows Background.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemExclamation\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemHand\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemHand\.Default" /V "" /D "C:\Windows\media\Windows Foreground.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemHand\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemNotification\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemNotification\.Default" /V "" /D "C:\Windows\media\Windows Background.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemNotification\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemQuestion\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemQuestion\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\SystemQuestion\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\WindowsLogon\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,4c,00,6f,00,67,00,6f,00,6e,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\WindowsLogon\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,4c,00,6f,00,67,00,6f,00,6e,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\WindowsUAC\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\WindowsUAC\.Default" /V "" /D "C:\Windows\media\Windows User Account Control.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\WindowsUAC\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\WindowsUnlock\.Current" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,55,00,6e,00,6c,00,6f,00,63,00,6b,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\.Default\WindowsUnlock\.Default" /V "" /D "ex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,74,00,25,00,5c,00,6d,00,65,00,64,00,69,00,61,00,5c,00,57,00,69,00,6e,00,64,00,6f,00,77,00,73,00,20,00,55,00,6e,00,6c,00,6f,00,63,00,6b,00,2e,00,77,00,61,00,76,00,00,0" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer" /V "" /D "File Explorer" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer" /V "DispFileName" /T "REG_SZ" /D "@mmres.dll,-5854" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\ActivatingDocument\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\ActivatingDocument\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\ActivatingDocument\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\BlockedPopup\.current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\BlockedPopup\.default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\BlockedPopup\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\EmptyRecycleBin\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\EmptyRecycleBin\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\EmptyRecycleBin\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\FeedDiscovered\.current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\FeedDiscovered\.default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\FeedDiscovered\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\MoveMenuItem\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\MoveMenuItem\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\MoveMenuItem\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\Navigating\.Current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\Navigating\.Default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\Navigating\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\SecurityBand\.current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\SecurityBand\.default" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\Explorer\SecurityBand\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr" /V "" /D "Speech Recognition" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr" /V "DispFileName" /T "REG_SZ" /D "@C:\Windows\System32\speech\speechux\sapi.cpl,-5555" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\DisNumbersSound\.current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\DisNumbersSound\.default" /V "" /D "C:\Windows\media\Speech Disambiguation.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\DisNumbersSound\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\HubOffSound\.current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\HubOffSound\.default" /V "" /D "C:\Windows\media\Speech Off.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\HubOffSound\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\HubOnSound\.current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\HubOnSound\.default" /V "" /D "C:\Windows\media\Speech On.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\HubOnSound\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\HubSleepSound\.current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\HubSleepSound\.default" /V "" /D "C:\Windows\media\Speech Sleep.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\HubSleepSound\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\MisrecoSound\.current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\MisrecoSound\.default" /V "" /D "C:\Windows\media\Speech Misrecognition.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\MisrecoSound\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\PanelSound\.current" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\PanelSound\.default" /V "" /D "C:\Windows\media\Speech Disambiguation.wav" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Apps\sapisvr\PanelSound\.None" /V "" /D "" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Names\.Default" /V "" /D "Windows Default" /F 1>NUL
				REM REG ADD "HKCU\AppEvents\Schemes\Names\.None" /V "" /D "No Sounds" /F 1>NUL

REM ----------------------------------------------------------------------------------------------------------
REM ### Security settings
REM ----------------------------------------------------------------------------------------------------------

	REM TITLE: Enable XTS-AES 256-bit BitLocker encryption for all drives
		REM LINK: https://www.tenforums.com/tutorials/36827-change-bitlocker-encryption-method-cipher-strength-windows-10-a.html
			REM OPTIONS: 
				REM REG ADD "HKLM\SOFTWARE\Policies\Microsoft\FVE" /V "EncryptionMethodWithXtsOs" /T "REG_DWORD" /D "0x00000007" /F 1>NUL 2>&1
				REM REG ADD "HKLM\SOFTWARE\Policies\Microsoft\FVE" /V "EncryptionMethodWithXtsFdv" /T "REG_DWORD" /D "0x00000007" /F 1>NUL 2>&1
				REM REG ADD "HKLM\SOFTWARE\Policies\Microsoft\FVE" /V "EncryptionMethodWithXtsRdv" /T "REG_DWORD" /D "0x00000007" /F 1>NUL 2>&1

REM Tutorial: https://www.tenforums.com/tutorials/71414-turn-off-let-apps-use-pc-camera-windows-10-a.html
REM Tutorial: http://www.tenforums.com/tutorials/71414-camera-turn-off-let-apps-use-windows-10-a.html
REM REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /V "LetAppsAccessCamera" /T "REG_DWORD" /D "0x00000002" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /V "LetAppsAccessCamera_UserInControlOfTheseApps" /T "REG_MULTI_SZ" /D "

REM: Tutorial: https://www.joseespitia.com/2019/07/24/registry-keys-for-windows-10-application-privacy-settings/
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appointments" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\bluetoothSync" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\broadFileSystemAccess" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\downloadsFolder" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\email" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\musicLibrary" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCall" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\radios" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\videosLibrary" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\gazeInput" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureProgrammatic" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL
REM REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\graphicsCaptureWithoutBorder" /V "Value" /T "REG_SZ" /D "Deny" /F 1>NUL

REM Tutorial: https://www.elevenforum.com/t/reset-and-clear-pinned-items-on-taskbar-in-windows-11.3634/
DEL /F /S /Q /A "%AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*"
REG DELETE HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband /F

REM Remove features

REM Tutorial: https://www.elevenforum.com/t/enable-or-disable-widgets-feature-in-windows-11.1196/
REG ADD "HKLM\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" /V "value" /T "REG_DWORD" /D "0x00000000" /F 1>NUL
REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /V "AllowNewsAndInterests" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

REM Make system use dark theme (Windows mode - Make taskbar dark)
REM REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /V "SystemUsesLightTheme" /T "REG_DWORD" /D "0x00000000" /F 1>NUL

REM Tutorial: https://www.elevenforum.com/t/disable-show-more-options-context-menu-in-windows-11.1589/
REG ADD "HKLM\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /V "" /D "File Explorer Context Menu" /F 1>NUL
REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InProcServer32" /F 1>NUL
REG ADD "HKLM\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InProcServer32" /V "" /D "" /F 1>NUL



:: taskkill /f /im explorer.exe
:: start explorer.exe