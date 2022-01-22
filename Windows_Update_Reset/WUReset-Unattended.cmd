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
	echo.
	echo.
	echo.
	echo Checking the bits services status.

	sc query bits | findstr /I /C:"STOPPED"
	if %errorlevel% NEQ 0 (
		echo.    Failed to stop the BITS service. Restart/Kill BITS and try again.
		echo.
		goto :eof
	)

	echo.
	echo Checking the wuauserv services status.

	sc query wuauserv | findstr /I /C:"STOPPED"
	if %errorlevel% NEQ 0 (
		echo.    Failed to stop the Windows Update service. Restart/Kill WU and try again.
		echo.
		goto :eof
	)

	echo.
	echo Checking the services status.

	sc query appidsvc | findstr /I /C:"STOPPED"
	if %errorlevel% NEQ 0 (
		sc query appidsvc | findstr /I /C:"FAILED 1060"
		if %errorlevel% NEQ 0 (
			echo.    Failed to stop the Application Identity service.
		)
	)

	echo.
	echo Checking the services status.

	sc query cryptsvc | findstr /I /C:"STOPPED"
	if %errorlevel% NEQ 0 (
		echo.    Failed to stop the Cryptographic Services service.
	)

	:: ----- Delete the qmgr*.dat files -----
	echo.
	echo.
	echo.
	echo Deleting the qmgr*.dat files.

	del /s /q /f "C:\ProgramData\Application Data\Microsoft\Network\Downloader\qmgr*.dat"
	del /s /q /f "C:\ProgramData\Microsoft\Network\Downloader\qmgr*.dat"
	del /s /q /f "%ALLUSERSPROFILE%\Application Data\Microsoft\Network\Downloader\qmgr*.dat"
	del /s /q /f "%ALLUSERSPROFILE%\Microsoft\Network\Downloader\qmgr*.dat"


	:: ----- Renaming the softare distribution folders backup copies -----
	echo.
	echo.
	echo.
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
		if exist "%SYSTEMROOT%\winsxs\pending.xml.old" (
		del /s /q /f "%SYSTEMROOT%\winsxs\pending.xml.old"
	)
	if exist "%SYSTEMROOT%\SoftwareDistribution.old" (
		rmdir /s /q "%SYSTEMROOT%\SoftwareDistribution.old"
	)
	if exist "%SYSTEMROOT%\system32\Catroot2.old" (
		rmdir /s /q "%SYSTEMROOT%\system32\Catroot2.old"
	)
	if exist "%SYSTEMROOT%\WindowsUpdate.log.old" (
		del /s /q /f "%SYSTEMROOT%\WindowsUpdate.log.old"
	)


	echo.
	echo.
	echo.
	echo Renaming the software distribution folders - SYSTEMROOT\winsxs\pending.xml, SoftwareDistribution, Catroot2, WindowsUpdate.log 

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
	echo.
	echo.
	echo.
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


	:: ----- Resolving WSUS Client Settings -----

:: TRANSLATE FROM POWERSHELL
:: https://gist.github.com/desbest/1a15622ae7d0421a735c6e78493510b3

:: 	NAble Windows Update Mods
::	https://success.n-able.com/kb/solarwinds_n-central/Registry-Keys-modified-when-Patch-Management-is-enabled-or-disabled


	echo.
	echo.
	echo.
	echo 7) Resolving WSUS Client Settings and deleting bogus registry keys ... (ignore any missing keys)

		REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /V AccountDomainSid /F
		REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /V PingID /F
		REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /V SusClientId /F

		REG DELETE "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoWindowsUpdate /F 
		REG DELETE "HKLM\SYSTEM\Internet Communication Management\Internet Communication" /v DisableWindowsUpdateAccess /F 
		REG DELETE "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate" /v DisableWindowsUpdateAccess /F

		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v AcceptTrustedPublisherCerts /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v ElevateNonAdmins /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v TargetGroupEnabled /F
		REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /V WUServer  /F
		REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /V WUStatusServer  /F
		REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /V TargetGroup /F
		REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /V TargetGroupEnabled /F

		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AutoInstallMinorUpdates /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v DetectionFrequency /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v DetectionFrequencyEnabled /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RebootRelaunchTimeout /F
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RebootRelaunchTimeoutEnabled /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RebootWarningTimeout /F
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RebootWarningTimeoutEnabled /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RescheduleWaitTime /F
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RescheduleWaitTimeEnabled /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallDay /F 
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallTime /F
		REG DELETE "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v UseWUServer /F 


	::	Remove-Item HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate -Recurse


::		Set Defaults from Microsoft https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd939844(v=ws.10)?redirectedfrom=MSDN#registry-keys-for-configuring-automatic-updates

	echo Setting Default Registry Keys from Microsoft...

			REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoWindowsUpdate /t Reg_DWORD /d 0
			REG ADD "HKLM\SYSTEM\Internet Communication Management\Internet Communication" /v DisableWindowsUpdateAccess /t Reg_DWORD /d 0
			REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate" /v DisableWindowsUpdateAccess /t Reg_DWORD /d 0

			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v AcceptTrustedPublisherCerts /t Reg_DWORD /d 1
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /t Reg_DWORD /d 0
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v ElevateNonAdmins /t Reg_DWORD /d 1
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v TargetGroupEnabled /t Reg_DWORD /d 0

			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t Reg_DWORD /d 3
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AutoInstallMinorUpdates /t Reg_DWORD /d 1
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v DetectionFrequency /t Reg_DWORD /d 6
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v DetectionFrequencyEnabled /t Reg_DWORD /d 1
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t Reg_DWORD /d 1
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t Reg_DWORD /d 0
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RebootRelaunchTimeout /t Reg_DWORD /d 270
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RebootRelaunchTimeoutEnabled /t Reg_DWORD /d 1
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RebootWarningTimeout /t Reg_DWORD /d 30
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RebootWarningTimeoutEnabled /t Reg_DWORD /d 1
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RescheduleWaitTime /t Reg_DWORD /d 15
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v RescheduleWaitTimeEnabled /t Reg_DWORD /d 1
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallDay /t Reg_DWORD /d 0
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallTime /t Reg_DWORD /d 20
			REG ADD "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v UseWUServer /t Reg_DWORD /d 0


	:: ----- Resetting Winsock -----
	
	echo.
	echo.
	echo.
	echo Resetting Winsock.
	netsh winsock reset

	:: ----- Resetting WinHTTP Proxy -----
	
	echo.
	echo Resetting WinHTTP Proxy.

	netsh winhttp reset proxy


	:: ----- Set the startup type as automatic -----
	echo.
	echo.
	echo.
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
	echo The operation completed successfully if you are seeing this message. Review any errors in script output.

:: /*************************************************************************************/

:eof