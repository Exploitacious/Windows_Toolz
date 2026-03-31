@echo off
for /f "tokens=3 delims=: " %%a in ('cscript //nologo "%systemroot%\system32\slmgr.vbs" /dli ^| find "License Status:"') do set "licenseStatus=%%a"

if /i "%LicenseStatus%" == "Licensed" (goto ISLIC) else (goto NOTLIC)

:ISLIC

for /f "tokens=4 delims=: " %%b in ('cscript //nologo "%systemroot%\system32\slmgr.vbs" /dli ^| find "Timebased activation expiration:"') do set "TrialKey=yes"

if /i "%TrialKey%" == "Yes" (goto ISTRIAL) else (goto NOTTRIAL)

:ISTRIAL

for /f "tokens=5 " %%c in ('cscript //nologo "%systemroot%\system32\slmgr.vbs" /xpr ^| find "Timebased activation will expire"') do set "ExpiryDate=%%c"

REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v Custom%CUSTOMFLD% /t REG_SZ /d "Trial (Expires %ExpiryDate%)" /f
echo Windows is licensed with a temporary activation on this machine
goto END

:NOTTRIAL
REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v Custom%CUSTOMFLD% /t REG_SZ /d "Activated" /f
echo Windows is permanently licensed on this machine
goto END

:NOTLIC
REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v Custom%CUSTOMFLD% /t REG_SZ /d "Not Licensed or Unknown" /f
echo Windows is either not licensed on this machine of the status was unknown. Result was '%LicenseStatus%'.
goto END

:END