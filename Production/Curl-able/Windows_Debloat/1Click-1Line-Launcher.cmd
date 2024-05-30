:: Download and run the system debloat scripts directly from GitHub
:: Created by: Alex Ivantsov @Exploitacious

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

:: Download Required Files from https://github.com/https://github.com/Exploitacious/Windows_Toolz/tree/main/Production/Curl-able/Windows_Debloat
:Download

    PowerShell -Command "mkdir C:\Temp\Cleanup -erroraction silentlycontinue"
    cd "C:\Temp\Cleanup"
    PowerShell -executionpolicy bypass -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/Production/Curl-able/Windows_Debloat/Cmd-HKCU.cmd', 'Cmd-HKCU.cmd')"
    PowerShell -executionpolicy bypass -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/Production/Curl-able/Windows_Debloat/Cmd-HKLM.cmd', 'Cmd-HKLM.cmd')"
    PowerShell -executionpolicy bypass -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/Production/Curl-able/Windows_Debloat/FirstLogon.bat', 'FirstLogon.bat')"
    PowerShell -executionpolicy bypass -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/Production/Curl-able/Windows_Debloat/InstallNewApps.ps1', 'InstallNewApps.ps1')"
    PowerShell -executionpolicy bypass -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/Production/Curl-able/Windows_Debloat/PS-HKCU.ps1', 'PS-HKCU.ps1')"
    PowerShell -executionpolicy bypass -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/Production/Curl-able/Windows_Debloat/PS-HKLM.ps1', 'PS-HKLM.ps1')"
    PowerShell -executionpolicy bypass -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/Production/Curl-able/Windows_Debloat/PSandWindowsUpdates.ps1', 'PSandWindowsUpdates.ps1')"
    PowerShell -executionpolicy bypass -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/Production/Curl-able/Windows_Debloat/UninstallBloat.ps1', 'UninstallBloat.ps1')"

:: Start Running the SYSTEM DEBLOAT scripts
:RunScript

    SET ThisScriptsDirectory=C:\Temp\Cleanup\
    SET PowerShellScriptPath=%ThisScriptsDirectory%SYSTEM-Debloat-MAIN.ps1
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%PowerShellScriptPath%'";