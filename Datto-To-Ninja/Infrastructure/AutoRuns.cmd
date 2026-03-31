@echo off
setLocal enableDelayedExpansion
REM russinovich installer :: build 9/seagull :: autoruns build 2
REM to switch, search for this string: $@!#@!!
REM ==================================

REM kernel
for /F "usebackq delims=" %%a in (`WMIC /interactive:off DATAFILE WHERE ^"Name^='C:\\Windows\\System32\\kernel32.dll'^" get Version ^ | findstr .`) do for /F "usebackq tokens=4 delims=." %%b in ('^""echo .%%a.^"') do set /a varKernel=%%b

    REM software name / $@!#@!!
    set varSoftwareName=Autoruns

    echo Software: SysInternals %varSoftwareName%
    echo ==========================================

    REM get installer name
    for /f "usebackq tokens=*" %%a in (`dir /b %varSoftwareName%-*.exe`) do set varInstaller=%%a

        REM find architecture
        if defined ProgramFiles(x86) (
            set varArch=64
            REM $@!#@!!
            set varSoftwareCode=74118C15-7E5B-41A8-A4FC-EC59FC39400F
        ) else (
            set varArch=32
            REM $@!#@!!
            set varSoftwareCode=72BEF287-CDCF-46B3-B870-5CEE1B4CDE2D
        )

        REM remove previous iterations
        wmic product where "IdentifyingNumber like '{!varSoftwareCode!}'" get IdentifyingNumber 2> nul | findstr /c:"{" > nul 2>&1
        if %errorlevel% equ 0 (
            msiexec /x { !varSoftwareCode! } /qn
            echo - Removed previous iteration of software from prior Component installation
        ) else (
            echo - No existing iteration of Software detected. Installing...
        )

        REM install an
        mkdir "%programfiles%\%varSoftwareName%" > nul 2>&1
        start "" "%varInstaller%" -o"%programfiles%\%varSoftwareName%" -y

        REM make a shnortcut
        for /f "usebackq tokens=2 delims=:" %%b in (`reg query ^"HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders^" /v ^"Common AppData^"`) do (
                if %varKernel% lss 6000 (
                    REM Windows XP
                    set varStart=%systemDrive%%%b\..\Start Menu\Programs
                ) else (
                    REM Windows Vista+
                    set varStart=%systemDrive%%%b\Microsoft\Windows\Start Menu\Programs
                )
            )

            REM $@!#@!!
            CALL :VBSCut "%programfiles%\%varSoftwareName%\autoruns.exe" 86

            if %varArch% equ 64 (
                REM $@!#@!!
                CALL :VBSCut "%programfiles%\%varSoftwareName%\autoruns64.exe" 64
            )

            echo - %varSoftwareName% installed successfully. Shortcuts created for Start Menu.
            echo Exiting...
            exit

            :VBScut
            echo >> shortcut.vbs Set oWS = WScript.CreateObject("WScript.Shell")
            echo >> shortcut.vbs sLinkFile = "%varStart%\%varSoftwareName% (x%2).lnk"
            echo >> shortcut.vbs Set oLink = oWS.CreateShortcut(sLinkFile)
            echo >> shortcut.vbs     oLink.TargetPath = %1
            echo >> shortcut.vbs 	oLink.Description = "Launch %varSoftwareName% (x%2)"
            echo >> shortcut.vbs oLink.Save
            cscript //nologo shortcut.vbs >nul 2>&1
            del shortcut.vbs /f /s /q >nul 2>&1
            goto :eof