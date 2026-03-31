@echo off
REM windows product key finder :: based off scripting simon's VBS :: build 3b/seagull
setLocal enableDelayedExpansion
set varKey=undefined
for /f "usebackq" %%a in (`wmic path softwarelicensingservice get OA3xOriginalProductKey 2^> nul ^| find ^"-^"`) do set varKey=%%a
if !varKey! equ undefined (
	echo - Unable to locate Windows Original Product Key.
	echo - Running legacy script...
	cscript /nologo oldScript.vbs
) else (
	echo - Windows Original Product Key found: !varKey!
	echo   Written to UDF9.
	reg add "HKLM\Software\CentraStage" /v "Custom9" /t REG_SZ /d "!varKey! (Windows)" /f >nul 2>&1
)
echo ---------------------------------------