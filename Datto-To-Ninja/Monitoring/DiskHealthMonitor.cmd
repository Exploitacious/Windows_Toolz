#!/bin/bash
@echo off
goto WindowsScript
#UNIFIED DISK SMART MONITOR # build 24/seagull April 2025
#Thanks to Loic Deraed; Steph R., Datto Labs
# =============================================== UNIX ===============================================
function WriteAlert
{	
	echo "<-Start Result->"
	echo "SMART=$1"
	echo "<-End Result->"
}
function WriteDiag
{
	echo '<-Start Diagnostic->'
	echo "$1"
	echo '<-End Diagnostic->'
}

AlertText="ALERT!"
StatusText="OK"
Warn=0

#are we running macOS or Linux
if uname -a | grep -q "Darwin"
then 
	#macOS: SMART check
	for HardDisk in $(diskutil list | grep /dev/ | awk '{ print $1 }')
	do
		ResultN=$(diskutil info $HardDisk | grep "SMART Status")
		if ! echo "$ResultN" | grep -qi "Verified\|Supported"
		then
			AlertText="$AlertText Disk $HardDisk reports SMART issues."
			Warn=1
		fi
	done
else
	#Linux: SMART check
	if [[ ! $( smartctl -V ) ]]
	then 
		AlertText="SmartMonTools not installed. Please install it before continuing."
		Warn=1
	else			
		HardDisks=$(lsblk -dlnp -I 8,65,259 -o NAME)
		for HardDisk in $HardDisks
		do
			#filter out unknown USB bridge errors
			if ! smartctl -H $HardDisk | grep -F ')]'
			then
				#load into a variable
				varDisk=$(smartctl -H $HardDisk)
			
				#check for unhandled issues
				if echo $varDisk | grep -qi "Error counter logging not supported"
				then
					if echo $varDisk | grep -qi "Status: OK"
					then
						StatusText="Disk $HardDisk OK (no detailed information)."
					else
						if echo $varDisk | grep -qi "device lacks SMART capability"
						then 
							StatusText="Disk $HardDisk lacks SMART capability. Check drive."
						else
							AlertText="$AlertText Disk $HardDisk NOT OK (no detailed information)."
							Warn=1
						fi
					fi
				elif echo $varDisk | grep -qi "cciss\|areca\|hpt"
					then 
						StatusText="Hardware RAID not supported by this component. Please manually check SMART status."
				else
					#disk is reporting normally
					smarthealth=$(echo $varDisk | grep -i "PASSED\|Status: OK")
					smartattr=$(smartctl -A $HardDisk)
					prefail=$($smartattr | grep -i "Pre-fail")
					if [[ -z $smarthealth ]]
					then
						AlertText="$AlertText Disk $HardDisk reports SMART issues. Check Diagnostic."
						smartdiag=$( smartctl -HA -l error $HardDisk )
						Warn=1
					else 
						if [[ -n $prefail ]]
						then
							AlertText="$AlertText Disk $HardDisk reports SMART Pre-fail issues. Check Diagnostic."
							smartdiag=$( smartctl -HA $HardDisk )
							Warn=1
						fi
					fi
				fi
			fi
		done
	fi
fi

#deliver the alert
if [ $Warn == 1 ] ; then
	WriteAlert "$AlertText"
	WriteDiag "$smartdiag"
	exit 1
else
	WriteAlert "$StatusText"
	exit 0
fi

exit
:WindowsScript
REM ============================================ WINDOWS =============================================
setLocal enableDelayedExpansion

REM get kernel version
for /F "usebackq delims=" %%a in (`WMIC /interactive:off DATAFILE WHERE ^"Name^='C:\\Windows\\System32\\kernel32.dll'^" get Version ^| findstr .`) do set varKernel=%%a
for /F "usebackq tokens=4 delims=." %%b in ('^""echo .%varKernel%.^"') do set /a varKernel=%%b
if %varKernel% lss 6000 (set QuitCode=exit) else (set QuitCode=exit /b)

REM define alerting characteristics
set varAlertStatus=false
set varAlertText=ALERT!

REM loop through drives (not volumes!) and perform a SMART check
for /f "usebackq skip=1" %%c in (`wmic diskdrive get name 2^>nul ^| findstr ^/r ^/v ^"^^$^"`) do (
	set varDiskName=%%c
	set varDiskName=!varDiskName:~4!
	for /f "usebackq skip=1" %%d in (`wmic diskdrive where "name like '%%!varDiskName!%%'" get status ^| findstr /v "^^$"`) do (
		set varDiskStatus=%%d
		if !varDiskStatus! neq OK (
			set varAlertStatus=true
			set varAlertText=!varAlertText! SMART Error detected on !varDiskName!.
		)
		set varDiskStatus=
	)
)

REM if there is an alert, deliver it
if !varAlertStatus! equ true (
	echo ^<-Start Result-^>
	echo SMART^=%varAlertText%
	echo ^<-End Result-^>
	%QuitCode% 1
) else (
	echo ^<-Start Result-^>
	echo SMART^=OK
	echo ^<-End Result-^>
	%QuitCode% 0
)



REM SeaChest Script. Download a utility to check for drive tests, etc.

@echo Off 

if %scantype% == 1 (.\SeaChest_GenericTests_x64_windows.exe --longGeneric --hideLBACounter -d PD0) ELSE (IF %scantype% == 2 (.\seachest_basics_x64_windows.exe --shortDST -d PD0) ELSE (.\seachest_basics_x64_windows.exe --smartCheck -d PD0))
rem  uses the user input variable, if it is 1 it will do a long generic test, if it is 2 it will run a Short DST and if it is neither then it will run a smart test 
 
 timeout 120>nul
 if %scantype% == 2 (.\seachest_basics_x64_windows.exe --progress dst -d PD0)
rem wait 2 minutes and run the check for the progress of the DST after it has been run if the value of user input is 2 "Short DST"