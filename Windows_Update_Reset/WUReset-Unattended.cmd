:: ==================================================================================
:: NAME:	Reset Windows Update Tool - Bastardized by Alex
:: DESCRIPTION:	This script reset the Windows Update Components automagically without any user input required.
:: AUTHOR(s):	Manuel Gil. + (Edited by) Alex Ivantsov
:: VERSION:	10.5.4.1 - Date: 9/13/2021
:: Main modification includes ability to run main portion of the script as unatended with Datto RMM or other deployment solution.
:: - Asumes you are already running script as Admin. Will Terminate itself if Admin Permission is not detected.
:: ==================================================================================

@echo off

:: Checking for Administrator elevation.
:: void permission();
:: /************************************************************************************/

	openfiles>nul 2>&1

	if %errorlevel% EQU 0 goto :WUReset

	echo.
	echo.    You are not running as Administrator.
	echo.    This tool cannot do it's job without elevation.
	echo.
	echo.    You need run this tool as Administrator.
	echo.

exit
:: /************************************************************************************/


:: Run the reset Windows Update components.
:: void components();
:: /*************************************************************************************/
	
	:: ----- Stopping the Windows Update services -----

:WUReset
	echo Stopping the Windows Update services.
	net stop bits /y

	echo Stopping the Windows Update services.
	net stop wuauserv /y

	echo Stopping the Windows Update services.
	net stop appidsvc /y

	echo Stopping the Windows Update services.
	net stop cryptsvc /y

	echo Canceling the Windows Update process.
	taskkill /im wuauclt.exe /f
	taskkill /im wuauserv.exe /f


	:: ----- Checking the services status -----
	echo Checking the services status.

	sc query bits | findstr /I /C:"STOPPED"
	if %errorlevel% NEQ 0 (
		echo.    Failed to stop the BITS service.
		echo.
		echo.Press any key to continue . . .
		pause>nul
		goto :eof
	)

	echo Checking the services status.

	sc query wuauserv | findstr /I /C:"STOPPED"
	if %errorlevel% NEQ 0 (
		echo.    Failed to stop the Windows Update service.
		echo.
		echo.Press any key to continue . . .
		pause>nul
		goto :eof
	)

	echo Checking the services status.

	sc query appidsvc | findstr /I /C:"STOPPED"
	if %errorlevel% NEQ 0 (
		sc query appidsvc | findstr /I /C:"OpenService FAILED 1060"
		if %errorlevel% NEQ 0 (
			echo.    Failed to stop the Application Identity service.
		)
	)

	echo Checking the services status.

	sc query cryptsvc | findstr /I /C:"STOPPED"
	if %errorlevel% NEQ 0 (
		echo.    Failed to stop the Cryptographic Services service.
	)

	:: ----- Delete the qmgr*.dat files -----
	echo Deleting the qmgr*.dat files.

	del /s /q /f "%ALLUSERSPROFILE%\Application Data\Microsoft\Network\Downloader\qmgr*.dat"
	del /s /q /f "%ALLUSERSPROFILE%\Microsoft\Network\Downloader\qmgr*.dat"


	:: ----- Renaming the softare distribution folders backup copies -----
	echo Deleting the old software distribution backup copies.

	cd /d %SYSTEMROOT%

	if exist "%SYSTEMROOT%\winsxs\pending.xml.bak" (
		del /s /q /f "%SYSTEMROOT%\winsxs\pending.xml.bak"
	)
	if exist "%SYSTEMROOT%\SoftwareDistribution.bak" (
		rmdir /s /q "%SYSTEMROOT%\SoftwareDistribution.bak"
	)
	if exist "%SYSTEMROOT%\system32\Catroot2.bak" (
		rmdir /s /q "%SYSTEMROOT%\system32\Catroot2.bak"
	)
	if exist "%SYSTEMROOT%\WindowsUpdate.log.bak" (
		del /s /q /f "%SYSTEMROOT%\WindowsUpdate.log.bak"
	)

	echo Renaming the software distribution folders.

	if exist "%SYSTEMROOT%\winsxs\pending.xml" (
		takeown /f "%SYSTEMROOT%\winsxs\pending.xml"
		attrib -r -s -h /s /d "%SYSTEMROOT%\winsxs\pending.xml"
		ren "%SYSTEMROOT%\winsxs\pending.xml" pending.xml.bak
	)
	if exist "%SYSTEMROOT%\SoftwareDistribution" (
		attrib -r -s -h /s /d "%SYSTEMROOT%\SoftwareDistribution"
		ren "%SYSTEMROOT%\SoftwareDistribution" SoftwareDistribution.bak
		if exist "%SYSTEMROOT%\SoftwareDistribution" (
			echo.
			echo.    Failed to rename the SoftwareDistribution folder.
			echo.
		)
	)
	if exist "%SYSTEMROOT%\system32\Catroot2" (
		attrib -r -s -h /s /d "%SYSTEMROOT%\system32\Catroot2"
		ren "%SYSTEMROOT%\system32\Catroot2" Catroot2.bak
	)
	if exist "%SYSTEMROOT%\WindowsUpdate.log" (
		attrib -r -s -h /s /d "%SYSTEMROOT%\WindowsUpdate.log"
		ren "%SYSTEMROOT%\WindowsUpdate.log" WindowsUpdate.log.bak
	)

	:: ----- Reset the BITS service and the Windows Update service to the default security descriptor -----
	echo Reset the BITS service and the Windows Update service to the default security descriptor.

	sc.exe sdset wuauserv D:(A;CI;CCLCSWRPLORC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)S:(AU;FA;CCDCLCSWRPWPDTLOSDRCWDWO;;;WD)
	sc.exe sdset bits D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)S:(AU;SAFA;WDWO;;;BA)
	sc.exe sdset cryptsvc D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;CCLCSWRPWPDTLOCRRC;;;SO)(A;;CCLCSWLORC;;;AC)(A;;CCLCSWLORC;;;S-1-15-3-1024-3203351429-2120443784-2872670797-1918958302-2829055647-4275794519-765664414-2751773334)
	sc.exe sdset trustedinstaller D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRRC;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)S:(AU;SAFA;WDWO;;;BA)

	:: ----- Reregister the BITS files and the Windows Update files -----
	echo Reregister the BITS files and the Windows Update files.

	cd /d %SYSTEMROOT%\system32
	regsvr32.exe /s atl.dll
	regsvr32.exe /s urlmon.dll
	regsvr32.exe /s mshtml.dll
	regsvr32.exe /s shdocvw.dll
	regsvr32.exe /s browseui.dll
	regsvr32.exe /s jscript.dll
	regsvr32.exe /s vbscript.dll
	regsvr32.exe /s scrrun.dll
	regsvr32.exe /s msxml.dll
	regsvr32.exe /s msxml3.dll
	regsvr32.exe /s msxml6.dll
	regsvr32.exe /s actxprxy.dll
	regsvr32.exe /s softpub.dll
	regsvr32.exe /s wintrust.dll
	regsvr32.exe /s dssenh.dll
	regsvr32.exe /s rsaenh.dll
	regsvr32.exe /s gpkcsp.dll
	regsvr32.exe /s sccbase.dll
	regsvr32.exe /s slbcsp.dll
	regsvr32.exe /s cryptdlg.dll
	regsvr32.exe /s oleaut32.dll
	regsvr32.exe /s ole32.dll
	regsvr32.exe /s shell32.dll
	regsvr32.exe /s initpki.dll
	regsvr32.exe /s wuapi.dll
	regsvr32.exe /s wuaueng.dll
	regsvr32.exe /s wuaueng1.dll
	regsvr32.exe /s wucltui.dll
	regsvr32.exe /s wups.dll
	regsvr32.exe /s wups2.dll
	regsvr32.exe /s wuweb.dll
	regsvr32.exe /s qmgr.dll
	regsvr32.exe /s qmgrprxy.dll
	regsvr32.exe /s wucltux.dll
	regsvr32.exe /s muweb.dll
	regsvr32.exe /s wuwebv.dll

	:: ----- Removing WSUS Client Settings -----

TRANSLATE FROM POWERSHELL
https://gist.github.com/desbest/1a15622ae7d0421a735c6e78493510b3

	Write-Host "7) Removing WSUS client settings..." 

	Remove more registry keys

	HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate
		REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v AccountDomainSid /f 
		REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v PingID /f 
		REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v SusClientId /f 

		HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update /V AUOptions -0


	HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update

		Remove-Item HKLM: \Software\Policies\Microsoft\Windows\WindowsUpdate -Recurse

		REG.exe DELETE HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /V WUServer  /F

		REG.exe DELETE HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /V WUStatusServer  /F

		REG.exe DELETE HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /V TargetGroup /F

		REG.exe DELETE HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /V TargetGroupEnabled /F

		REG.exe DELETE HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /V NoAutoUpdate  /F

		REG.exe DELETE HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /V UseWUServer  /F


	NAble Windows Update Mods
		https://success.n-able.com/kb/solarwinds_n-central/Registry-Keys-modified-when-Patch-Management-is-enabled-or-disabled

		Set Defaults from Microsoft https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd939844(v=ws.10)?redirectedfrom=MSDN#registry-keys-for-configuring-automatic-updates

			HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer

				NoWindowsUpdate	Reg_DWORD 0

			HKEY_LOCAL_MACHINE\SYSTEM\Internet Communication Management\Internet Communication

				DisableWindowsUpdateAccess	Reg_DWORD 0

			HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate

				DisableWindowsUpdateAccess	Reg_DWORD 0

			HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate

				AcceptTrustedPublisherCerts	Reg_DWORD	1
				DisableWindowsUpdateAccess	Reg_DWORD	0
				ElevateNonAdmins	Reg_DWORD			1
				TargetGroup	Reg_SZ				TargetGroupEnabled 	Delete?
				TargetGroupEnabled	Reg_DWORD			0
				TargetGroupEnabled	Reg_DWORD			DELETE
				WUStatusServer	Reg_SZ					DELETE

			HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU

				AUOptions	Reg_DWORD	Range = 2|3|4|5
					- 2 = Notify before download.
					- 3 = Automatically download and notify of installation.
					- 4 = Automatically download and schedule installation. Only valid if values exist for ScheduledInstallDay and ScheduledInstallTime.
					- 5 = Automatic Updates is required and users can configure it.
					
					AutoInstallMinorUpdates	Reg_DWORD	Range = 0|1
					- 0 = Treat minor updates like other updates.
					- 1 = Silently install minor updates.
					
					DetectionFrequency	Reg_DWORD	Range = n, where n = time in hours (1–22).
					- Time between detection cycles.
					
					DetectionFrequencyEnabled	Reg_DWORD	Range = 0|1
					- 1 = Enable detection frequency.
					- 0 = Disable custom detection frequency (use default value of 22 hours).
					
					NoAutoRebootWithLoggedOnUsers	Reg_DWORD	Range = 0|1
					- 1 = Logged-on user can decide whether to restart the client computer.
					- 0 = Automatic Updates notifies the user that the computer will restart in 15 minutes.
					
					NoAutoUpdate	Reg_DWORD	Range = 0|1
					- 0 = Enable Automatic Updates.
					- 1 = Disable Automatic Updates.
					
					RebootRelaunchTimeout	Reg_DWORD	Range = n, where n = time in minutes (1–1,440).
					- Time between prompts for a scheduled restart.
					
					RebootRelaunchTimeoutEnabled	Reg_DWORD	Range = 0|1
					- 1 = Enable RebootRelaunchTimeout.
					- 0 = Disable custom RebootRelaunchTimeout(use default value of 10 minutes).
					
					RebootWarningTimeout	Reg_DWORD	Range = n, where n = time in minutes (1–30).
					- Length, in minutes, of the restart warning countdown after updates have been installed that have a deadline or scheduled updates.
					
					RebootWarningTimeoutEnabled	Reg_DWORD	Range = 0|1
					- 1 = Enable RebootWarningTimeout.
					- 0 = Disable custom RebootWarningTimeout (use default value of 5 minutes).
					
					RescheduleWaitTime	Reg_DWORD	Range = n, where n = time in minutes (1–60).
					- Time in minutes that Automatic Updates waits at startup before it applies updates from a missed scheduled installation time.
					- This policy applies only to scheduled installations, not to deadlines. Updates with deadlines that have expired should always be installed as soon as possible.
					
					RescheduleWaitTimeEnabled	Reg_DWORD	Range = 0|1
					- 1 = Enable RescheduleWaitTime .
					- 0 = Disable RescheduleWaitTime (attempt the missed installation during the next scheduled installation time).
					
					ScheduledInstallDay	Reg_DWORD	Range = 0|1|2|3|4|5|6|7
					- 0 = Every day.
					- 1 through 7 = the days of the week from Sunday (1) to Saturday (7).
					(Only valid if AUOptions = 4.)
					
					ScheduledInstallTime	Reg_DWORD	Range = n, where n = the time of day in 24-hour format (0–23).
					
					UseWUServer	Reg_DWORD	Range = 0|1
					- 1 = The computer gets its updates from a WSUS server.
					- 0 = The computer gets its updates from Microsoft Update.
					- The WUServer value is not respected unless this key is set.


	:: ----- Resetting Winsock -----
	echo Resetting Winsock.
	netsh winsock reset

	:: ----- Resetting WinHTTP Proxy -----
	echo Resetting WinHTTP Proxy.

	netsh winhttp reset proxy


	:: ----- Set the startup type as automatic -----
	echo Resetting the services as automatics.
	sc.exe config wuauserv start= auto
	sc.exe config bits start= delayed-auto
	sc.exe config cryptsvc start= auto
	sc.exe config TrustedInstaller start= demand
	sc.exe config DcomLaunch start= auto

	:: ----- Starting the Windows Update services -----
	echo Starting the Windows Update services.
	net start bits

	echo Starting the Windows Update services.
	net start wuauserv

	echo Starting the Windows Update services.
	net start appidsvc

	echo Starting the Windows Update services.
	net start cryptsvc

	echo Starting the Windows Update services.
	net start DcomLaunch

	:: ----- End process -----
	echo The operation completed successfully.

:: /*************************************************************************************/

:eof