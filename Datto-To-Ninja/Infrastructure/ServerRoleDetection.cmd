@echo off

REM v5 Release Notes
REM 
REM Added detection for:
REM Network Policy Server ("NPS")
REM As per contribution from Michael McCool via the Datto RMM community: https://community.kaseya.com/RMM-Endpoint_Management/discussion/68884/server-role-detection-win-network-policy-server

set t=%systemdrive%\temp
if not exist %t% mkdir %t%

if exist %t%\serverroles.txt del %t%\serverroles.txt
if exist %t%\fshares.txt del %t%\fshares.txt
if exist %t%\pshares.txt del %t%\pshares.txt
if exist %t%\netstart.log.txt del %t%\netstart.log.txt
if exist %t%\netshare.log.txt del %t%\netshare.log.txt
net start > %t%\netstart.log.txt
net share > %t%\netshare.log.txt

REM SQL Server Services
find /i "SQL Server (" %t%\netstart.log.txt
if not errorlevel 1 set SQL=1
find /i "MSSQL" %t%\netstart.log.txt
if not errorlevel 1 set SQL=1

REM Exchange Server Services
find /i "Microsoft Exchange Information Store" %t%\netstart.log.txt
if not errorlevel 1 set EXC=1

REM Fax Server Services
find /i "Fax" %t%\netstart.log.txt
if not errorlevel 1 set FAX=1

REM Hyper-V Host Services
find /i "Hyper-V Virtual Machine Management" %t%\netstart.log.txt
if not errorlevel 1 set HYPV=1

REM Legacy SMTP Services
find /i "Simple Mail Transfer Protocol" %t%\netstart.log.txt
if not errorlevel 1 set SMTP=1

REM Exchange Server Services
find /i "Microsoft Exchange MTA Stacks" %t%\netstart.log.txt
if not errorlevel 1 set MTA=1

REM Exchange IMAP Services
find /i "Microsoft Exchange IMAP4" %t%\netstart.log.txt
if not errorlevel 1 set IMAP=1

REM Exchange POP3 Services
find /i "Microsoft Exchange POP3" %t%\netstart.log.txt
if not errorlevel 1 set POP3=1

REM Active Directory Services
for /f "tokens=3" %%x in ('reg query "hklm\system\currentcontrolset\control\productoptions" /v producttype') do set srvtyp=%%x
if "%srvtyp%" == "LanmanNT" set ADC=1
find /i "Active Directory Federation Services" %t%\netstart.log.txt
if not errorlevel 1 set ADFS=1
find /i "Active Directory Certificate Services" %t%\netstart.log.txt
if not errorlevel 1 set ADCS=1

REM PDC Emulator
FOR /F "delims=" %%F IN ('netdom query fsmo ^| find "PDC"') DO SET varPDC=%%F
echo.%varPDC%|findstr /I /C:%computername%. >nul 2>&1
if not errorlevel 1 set PDC=1

REM Cluster Node Services
find /i "Cluster Service" %t%\netstart.log.txt
if not errorlevel 1 set CLUS=1

REM ISA Services
find /i "Microsoft ISA Server Control" %t%\netstart.log.txt
if not errorlevel 1 set ISA=1

REM DNS Services
find /i "DNS Server" %t%\netstart.log.txt
if not errorlevel 1 set DNS=1

REM DHCP Services
find /i "DHCP Server" %t%\netstart.log.txt
if not errorlevel 1 set DHCP=1
find /i "DHCP-Server" %t%\netstart.log.txt
if not errorlevel 1 set DHCP=1

REM WINS Services
find /i "Windows Internet Name Service" %t%\netstart.log.txt
if not errorlevel 1 set WINS=1

REM Network Policy Server
find /i "Network Policy Server" %t%\netstart.log.txt
if not errorlevel 1 set NPS=1

REM Routing and Remote Access Services
find /i "Routing and Remote Access" %t%\netstart.log.txt
if not errorlevel 1 set RRAS=1

REM Web Server Services
find /i "World Wide Web Publishing Service" %t%\netstart.log.txt
if not errorlevel 1 set IIS=1
find /i "ColdFusion" %t%\netstart.log.txt
if not errorlevel 1 set CFS=1 

REM SharePoint Server Services
find /i "MSSQL$SHAREPOINT" %t%\netstart.log.txt
if not errorlevel 1 set SPS=1
find /i "SharePoint Timer" %t%\netstart.log.txt
if not errorlevel 1 set SPS=1

REM Backup Server Services
find /i "Backup Exec Server" %t%\netstart.log.txt
if not errorlevel 1 set BEX=1
find /i "Backup Exec Continuous Protection Web Restore Backend" %t%\netstart.log.txt
if not errorlevel 1 set BECP=1
find /i "Arcserve Job Engine" %t%\netstart.log.txt
if not errorlevel 1 set ARC=1
find /i "BrightStor Job Engine" %t%\netstart.log.txt
if not errorlevel 1 set ARC=1
find /i "AppAssure Core" %t%\netstart.log.txt
if not errorlevel 1 set APPA=1
find /i "Rapid Recovery Core" %t%\netstart.log.txt
if not errorlevel 1 set RAPI=1
find /i "Veeam Backup" %t%\netstart.log.txt
if not errorlevel 1 set VEEM=1

REM Citrix Services
find /i "Independent Management Architecture" %t%\netstart.log.txt
if not errorlevel 1 set CTX=1
find /i "Secure Gateway" %t%\netstart.log.txt
if not errorlevel 1 set CSG=1
find /i "Citrix StoreFront" %t%\netstart.log.txt
if not errorlevel 1 set CSF=1
find /i "Web Interface" %t%\netstart.log.txt
if not errorlevel 1 set CWI=1

REM Terminal Server Services
find /i "Terminal Services" %t%\netstart.log.txt
if not errorlevel 1 set TSA=0
if %TSA%.== 0. reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v TSAppCompat | find /i "0x1"
if not errorlevel 1 set TSA=1
find /i "Terminal Server Licensing" %t%\netstart.log.txt
if not errorlevel 1 set TSL=1

REM RDS Server Services
find /i "Remote Desktop Services" %t%\netstart.log.txt
if not errorlevel 1 set RDS=0
if %RDS%.== 0. reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v TSAppCompat | find /i "0x1"
if not errorlevel 1 set RDS=1

REM Blackberry Enterprise Server Services
find /i "BlackBerry" %t%\netstart.log.txt
if not errorlevel 1 set BES=1

REM Small Business Server Identification
ver | find /i "Small Business"
if not errorlevel 1 set SBS=1

REM AntiVirus & Endpoint Securi
find /i "Symantec System Center" %t%\netstart.log.txt
if not errorlevel 1 set SSC=1
find /i "AVG TCP Server Service" %t%\netstart.log.txt
if not errorlevel 1 set AVGM=1
find /i "Symantec Embedded Database" %t%\netstart.log.txt
if not errorlevel 1 set SEPM=1
find /i "Sophos Management Service" %t%\netstart.log.txt
if not errorlevel 1 set SOPM=1

REM Print Servers
find /i "print$" %t%\netshare.log.txt
if not errorlevel 1 set PSV=0
type %t%\netshare.log.txt|find /i "Spooled" > %t%\pshares.txt
if %PSV%.== 0. find /i "Spooled" %t%\netshare.log.txt
if not errorlevel 1 set PSV=1

REM File Server Servers
type %t%\netshare.log.txt|find /i ":"|find /i /v "Default share"|find /i /v "\WINDOWS"|find /i ":" > %t%\fshares.txt
type %t%\netshare.log.txt|find /i ":"|find /i /v "Default share"|find /i /v "\WINDOWS"|find /i ":"
if not errorlevel 1 set FSV=1

REM Generate Roles String for Custom Field
echo :> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %SQL%. == 1.  echo %singleString%SQL:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %EXC%. == 1.  echo %singleString%Exchange:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %POP3%.== 1.  echo %singleString%POP3:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %IMAP%.== 1.  echo %singleString%IMAP4:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %SMTP%.== 1.  echo %singleString%SMTP:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %MTA%. == 1.  echo %singleString%MTA:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %ADC%. == 1.  echo %singleString%ADC:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %PDC%. == 1.  echo %singleString%PDC:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %ISA%. == 1.  echo %singleString%ISA:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %HYPV%. == 1.  echo %singleString%HyperV:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %DNS%. == 1.  echo %singleString%DNS:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %DHCP%.== 1.  echo %singleString%DHCP:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %WINS%.== 1.  echo %singleString%WINS:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %NPS%.== 1.  echo %singleString%NPS:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %IIS%. == 1.  echo %singleString%IIS:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %CFS%. == 1.  echo %singleString%ColdFusion:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %SPS%. == 1.  echo %singleString%SharePoint:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %CTX%. == 1.  echo %singleString%Citrix:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %CSG%. == 1.  echo %singleString%Citrix SG:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %CSF%. == 1.  echo %singleString%Citrix SF:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %CSF%. == 1.  echo %singleString%Citrix WI:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %TSA%. == 1.  echo %singleString%TS:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %RDS%. == 1.  echo %singleString%RDS:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %TSL%. == 1.  echo %singleString%Lic:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %BES%. == 1.  echo %singleString%BES:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %SBS%. == 1.  echo %singleString%SBS:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %SSC%. == 1.  echo %singleString%SymantecAV Mgmt:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %AVGM%. == 1.  echo %singleString%AVG Mgmt:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %SEPM%.== 1.  echo %singleString%SymantecEP Mgmt:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %SOPM%.== 1.  echo %singleString%Sophos Mgmt:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %PSV%. == 1.  echo %singleString%Print:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %FSV%. == 1.  echo %singleString%File:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %VEEM%.== 1.  echo %singleString%Veeam:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %APPA%.== 1.  echo %singleString%Appassure:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %RAPI%.== 1.  echo %singleString%RapRecov:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %BEX%. == 1.  echo %singleString%Backup Exec:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %BECP%.== 1.  echo %singleString%BECP:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %ARC%. == 1.  echo %singleString%Arcserve:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %CLUS%.== 1.  echo %singleString%ClusSvc:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %ADFS%.== 1.  echo %singleString%ADFS:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %ADCS%.== 1.  echo %singleString%ADCertSvc:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %FAX%.== 1.  echo %singleString%Fax:> %t%\serverroles.txt
set /p singleString=<%t%\serverroles.txt
if %RRAS%.== 1.  echo %singleString%RRAS:> %t%\serverroles.txt

set /p ROLES=<c:\temp\serverroles.txt

echo.
echo Server Roles: %ROLES%
echo.

:CheckOS
IF EXIST "%PROGRAMFILES(X86)%" (GOTO 64BIT) ELSE (GOTO 32BIT)

:64BIT
REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v %CustomUDF% /t REG_SZ /d "%ROLES%" /f /reg:64
GOTO END

:32BIT
REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v %CustomUDF% /t REG_SZ /d "%ROLES%" /f
GOTO END

:END