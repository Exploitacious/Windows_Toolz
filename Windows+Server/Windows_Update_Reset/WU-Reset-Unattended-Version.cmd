:: ==================================================================================
:: NAME:	Reset Windows Update Tool - Bastardized by Alex
:: DESCRIPTION:	This script reset the Windows Update Components.
:: AUTHOR(s):	Manuel Gil. Alex Ivantsov
:: VERSION:	10.5.4.1 - Date: 9/13/2021
:: Main modification includes ability to run main portion of the script as unatended with Datto RMM or other deployment solution.
:: - Asumes you are already running script as Admin.
:: ==================================================================================

:: Load the system values.
:: void getValues();
:: /************************************************************************************/
:getValues
	for /f "tokens=4 delims=[] " %%a in ('ver') do set version=%%a

	if %version% EQU 6.0.6000 (
		:: Name: "Microsoft Windows Vista"
		set name=Microsoft Windows Vista
		:: Family: Windows 6
		set family=6
		:: Compatibility: No
		set allow=No
	) else if %version% EQU 6.0.6001 (
		:: Name: "Microsoft Windows Vista SP1"
		set name=Microsoft Windows Vista SP1
		:: Family: Windows 6
		set family=6
		:: Compatibility: No
		set allow=No
	) else if %version% EQU 6.0.6002 (
		:: Name: "Microsoft Windows Vista SP2"
		set name=Microsoft Windows Vista SP2
		:: Family: Windows 6
		set family=6
		:: Compatibility: No
		set allow=No
	) else if %version% EQU 6.1.7600 (
		:: Name: "Microsoft Windows 7"
		set name=Microsoft Windows 7
		:: Family: Windows 7
		set family=7
		:: Compatibility: No
		set allow=No
	) else if %version% EQU 6.1.7601 (
		:: Name: "Microsoft Windows 7 SP1"
		set name=Microsoft Windows 7 SP1
		:: Family: Windows 7
		set family=7
		:: Compatibility: No
		set allow=No
	) else if %version% EQU 6.2.9200 (
		:: Name: "Microsoft Windows 8"
		set name=Microsoft Windows 8
		:: Family: Windows 8
		set family=8
		:: Compatibility: Yes
		set allow=Yes
	) else if %version% EQU 6.3.9200 (
		:: Name: "Microsoft Windows 8.1"
		set name=Microsoft Windows 8.1
		:: Family: Windows 8
		set family=8
		:: Compatibility: Yes
		set allow=Yes
	) else if %version% EQU 6.3.9600 (
		:: Name: "Microsoft Windows 8.1 Update 1"
		set name=Microsoft Windows 8.1 Update 1
		:: Family: Windows 8
		set family=8
		:: Compatibility: Yes
		set allow=Yes
	) else (
		ver | find "10.0." > nul
		if %errorlevel% EQU 0 (
			:: Name: "Microsoft Windows 10"
			set name=Microsoft Windows 10
			:: Family: Windows 10
			set family=10
			:: Compatibility: Yes
			set allow=Yes
		) else (
			:: Name: "Unknown"
			set name=Unknown
			:: Compatibility: No
			set allow=No
		)
	)

	call :print %name% detected . . .

	if %allow% EQU Yes goto permission

	call :print Sorry, this Operative System is not compatible with this tool.

	echo.    An error occurred while attempting to verify your system.
	echo.    Can this using a business or test version.
	echo.
	echo.    if not, verify that your system has the correct security fix.

	echo.

::	echo.Press any key to continue . . .
::	pause>nul
:: goto :eof
:: /************************************************************************************/


:: Print Top Text.
::		@param - text = the text to print (%*).
:: void print(string text);
:: /*************************************************************************************/
:print
	cls
	echo.
	echo.%name% [Version: %version%]
	echo.Reset Windows Update Tool.
	echo.
	echo.%*
	echo.
:: goto :eof
:: /*************************************************************************************/

