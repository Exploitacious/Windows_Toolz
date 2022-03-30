:: Download and run the solarwinds removal tool directly from GitHub
:: Created by: Alex Ivantsov

@echo off

:: Checking for Administrator elevation.

        openfiles>nul 2>&1

        if %errorlevel% EQU 0 goto :Download

        echo.
        echo.
        echo.
        echo.
        echo.
        echo.    You are not running as Administrator.
        echo.    This script cannot do it's job without elevation.
        echo.
        echo.    You need run this tool as Administrator.
        echo.

    exit


:: Download Required Files from https://github.com/Exploitacious/Windows_Toolz/tree/main/Software/NAble_Removal
:Download

    PowerShell -Command "mkdir C:\Temp\SWRemoval -erroraction silentlycontinue"
    
    cd "C:\Temp\SWRemoval"

    PowerShell -executionpolicy bypass -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/Software/NAble_Removal/Remove-NCentral.ps1', 'SWRemoval.ps1')"


:: Start Running the SYSTEM DEBLOAT scripts
:RunScript

    SET ThisScriptsDirectory=C:\Temp\SWRemoval\
    SET PowerShellScriptPath=%ThisScriptsDirectory%SWRemoval.ps1
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%PowerShellScriptPath%'";