:: Download and run the system debloat scripts directly from GitHub
:: Created by: Alex Ivantsov

@echo off

:: Checking for Administrator elevation.

        openfiles>nul 2>&1

        if %errorlevel% EQU 0 goto :Download

        echo.
        echo.
        echo.    You are not running as Administrator.
        echo.    This script cannot do it's job without elevation.
        echo.
        echo.    You need run this tool as Administrator.
        echo.

    exit


:: Download Required Files from https://github.com/Exploitacious/Windows_Toolz/tree/main/Curl-able/Windows_Update_Reset
:Download

    PowerShell -executionpolicy bypass -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/refs/heads/main/Curl-able/Windows_Update_Reset/WUReset-Unattended.cmd', 'WU-Reset-Unattended-Version.cmd')"


:: Start Running the SYSTEM DEBLOAT scripts
:RunScript

    SET ThisScriptsDirectory=%~dp0

    WU-Reset-Unattended-Version.cmd