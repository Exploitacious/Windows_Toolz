@echo off
:: Script to download and run system debloat scripts from GitHub
:: Created by: Alex Ivantsov @Exploitacious

:: Function to check for Administrator elevation
:CheckAdmin
    openfiles >nul 2>&1
    if %errorlevel% EQU 0 (
        goto :Download
    ) else (
        echo.
        echo.    You are not running as Administrator.
        echo.    This script cannot do its job without elevation.
        echo.    Please run this tool as Administrator.
        exit /b
    )

:: Function to download required files from GitHub
:Download
    :: Create a temporary directory for cleanup scripts
    echo Creating temporary directories in C:\Temp\Cleanup
    PowerShell -Command "mkdir C:\Temp\Cleanup -ErrorAction SilentlyContinue"
    cd "C:\Temp\Cleanup"

    :: List of files to download
    echo Downloading Files...

:: Base URL for downloading files
    set "baseURL=https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/Curl-able/Windows_Debloat"

:: Loop through each file and download it using PowerShell
    for %%f in (
        "Cmd-HKCU.cmd"
        "Cmd-HKLM.cmd"
        "FirstLogon.bat"
        "InstallNewApps.ps1"
        "PS-HKCU.ps1"
        "PS-HKLM.ps1"
        "PSandWindowsUpdates.ps1"
        "UninstallBloat.ps1"
        "Main-Stager.ps1"
    ) do (
        echo Downloading %%~f...
        curl -L "%baseURL%/%%~f" -o "%%~f"
    )

:: Function to run the main debloat script
:RunPowerShell
    SET ThisScriptsDirectory=C:\Temp\Cleanup\
    SET PowerShellScriptPath=%ThisScriptsDirectory%Main-Stager.ps1

    :: Execute the main PowerShell script
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%PowerShellScriptPath%'"

:: Start the script by checking for admin privileges
goto :CheckAdmin
