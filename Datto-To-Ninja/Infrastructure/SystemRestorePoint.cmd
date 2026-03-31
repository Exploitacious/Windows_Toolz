@echo off
setLocal enableDelayedExpansion
REM make a system restore point, seagull redux :: build 23, may 2020 :: thanks to nirajan c.
echo System Restore Point
echo ==============================================================

REM cmd doesn't like it when you check the values of empty variables, so let's define them
set varValue=x
set varLastPoint=x

REM check the registry to see if system restore is enabled
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SPP\Clients" /v "{09F7EDC5-294E-4180-AF6A-FB0E6A0E9513}" 2^> nul') do set varValue=%%b
set varValue=%varValue: =%

REM clean up the previous component's mess
if %varValue% equ 1 (
	echo - A previously-available Component set a Registry value incorrectly; this value has been corrected.
	echo   System Restore has been initialised. This Component will set it up again properly.
	set varValue=x
)

if %varValue% neq x (
	Wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "RMM Restore Point", 100, 12
	echo ==============================================================
	echo - Restore Point successfully created. 
	echo ==============================================================
	ping -n 15 127.0.0.1 > nul
	echo - Current system date/time: %date% %time%
	for /f "usebackq tokens=*" %%c in (`vssadmin list shadows /For^=%systemdrive% ^| findstr "%date%"`) do set varLastPoint=%%c
	if !varLastPoint! equ x (
		echo - NOTICE: The Volume Shadow Service is not reporting that a System Restore point has been made.
		echo   There are a few reasons why this might be the case:
		echo : If System Restores have just recently been enabled, the initial enablement process can take some time.
		echo   Waiting a few hours post-enablement and then rebooting the device generally gives good results.
		echo : Windows is configured by default to only permit making one Restore point every 24 hours.
		echo   If another restore point has already been made today, the most recent request will have been ignored.
		echo - Advice is to wait a day and try again. If the issue persists, inspect the device.
	) else (
		echo - VSS console reports drive %systemdrive% !varLastPoint!.
		echo   If the creation date of this shadow copy does not collude with the time given above then a Restore
		echo   point may not have been created due to limitations prohibiting more than one Restore point from
		echo   being made per day; however, there is still at least one active Restore point for today's date.
	)
	echo - Operations complete. Exiting.
	exit
)

REM no system restore data in registry: enable in registry by adding explicit reference to system drive
REM -- get the volume ID of the system drive
for /f "usebackq tokens=*" %%b in (`mountvol %systemDrive% /L`) do set varVolume=%%b
REM -- add the data
set varSystemDrive=%systemDrive::=%
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SPP\Clients" /v "{09F7EDC5-294E-4180-AF6A-FB0E6A0E9513}" /t REG_MULTI_SZ /d "%varVolume%:(!varSystemDrive!%%3A)" /f >nul 2>&1
REM advise the user
echo - NOTICE: This device did not have System Restore enabled.
echo   While it has now been enabled, the system will need to be rebooted before points can be made.
echo - No System Restore point has been made. Please reboot this device first.