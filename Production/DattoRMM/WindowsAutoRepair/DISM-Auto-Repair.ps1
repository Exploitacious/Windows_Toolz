
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.

$Global:AlertMsg = @() # Combined Alert message. If left blank, will not trigger Alert status. Use " $Global:AlertMsg += " to append messages to be alerted on in Datto.

$Global:AlertHealthy = "DISM, SFC and ChkDsk" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.

$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.

# DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    Write-Host '<-End Diagnostic->'
}
function write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "$message"
    Write-Host '<-End Result->'
}

function Get-Disk-Partitions() {
    $partitionlist = $null
    $disklist = get-wmiobject Win32_diskdrive # | Where-Object { $_.model -like 'Microsoft Virtual Disk' } 
    ForEach ($disk in $disklist) {
        $diskID = $disk.index
        $command = @"
		select disk $diskID
		online disk noerr
"@
        $command | diskpart | out-null

        $partitionlist += Get-Partition -DiskNumber $diskID
    }
    return $partitionlist
}

$partitionlist = Get-Disk-Partitions
$partitionGroup = $partitionlist | group DiskNumber 

$Global:DiagMsg += 'Enumerate partitions to reconfigure boot cfg'
forEach ( $partitionGroup in $partitionlist | group DiskNumber ) {
    # reset paths for each part group (disk)
    $isBcdPath = $false
    $bcdPath = ''
    $bcdDrive = ''
    $isOsPath = $false
    $osPath = ''
    $osDrive = ''

    #scan all partitions of a disk for bcd store and os file location 
    ForEach ($drive in $partitionGroup.Group | select -ExpandProperty DriveLetter ) {      
        #check if no bcd store was found on the previous partition already
        if ( -not $isBcdPath ) {
            $bcdPath = $drive + ':\boot\bcd'
            $bcdDrive = $drive + ':'
            $isBcdPath = Test-Path $bcdPath

            #if no bcd was found yet at the default location look for the uefi location too
            if ( -not $isBcdPath ) {
                $bcdPath = $drive + ':\efi\microsoft\boot\bcd'
                $bcdDrive = $drive + ':'
                $isBcdPath = Test-Path $bcdPath

            } 
        }        
        
        #check if os loader was found on the previous partition already
        if (-not $isOsPath) {
            $osPath = $drive + ':\windows\system32\winload.exe'
            $isOsPath = Test-Path $osPath
            if ($isOsPath) {
                $osDrive = $drive + ':'
            }
        }
    }

    #if both was found update bcd store
    if ( $isBcdPath -and $isOsPath ) {
        #revert pending actions to let sfc succeed in most cases
        dism.exe /image:$osDrive /cleanup-image /revertpendingactions

        $Global:DiagMsg += "Running SFC.exe $osDrive\windows"
        sfc /scannow /offbootdir=$osDrive /offwindir=$osDrive\windows

        $Global:DiagMsg += "Running dism to restore health on $osDrive" 
        Dism /Image:$osDrive /Cleanup-Image /RestoreHealth /Source:c:\windows\winsxs
        
        $Global:DiagMsg += "Enumvering corrupt system files in $osDrive\windows\system32\"
        get-childitem -Path $osDrive\windows\system32\* -include *.dll, *.exe `
        | % { $_.VersionInfo | ? FileVersion -eq $null | select FileName, ProductVersion, FileVersion }  

        $Global:DiagMsg += "Setting bcd recovery and default id for $bcdPath"
        $bcdout = bcdedit /store $bcdPath /enum bootmgr /v
        $defaultLine = $bcdout | Select-String 'displayorder' | select -First 1
        $defaultId = '{' + $defaultLine.ToString().Split('{}')[1] + '}'
        
        bcdedit /store $bcdPath /default $defaultId
        bcdedit /store $bcdPath /set $defaultId  recoveryenabled Off
        bcdedit /store $bcdPath /set $defaultId  bootstatuspolicy IgnoreAllFailures

        #setting os device does not support multiple recovery disks attached at the same time right now (as default will be overwritten each iteration)
        $isDeviceUnknown = bcdedit /store $bcdPath /enum osloader | Select-String 'device' | Select-String 'unknown'
        
        if ($isDeviceUnknown) {
            bcdedit /store $bcdPath /set $defaultId device partition=$osDrive 
            bcdedit /store $bcdPath /set $defaultId osdevice partition=$osDrive 
        }
              

        #load reg to make sure system regback contains data
        $RegBackup = Get-ChildItem  $osDrive\windows\system32\config\Regback\system
        If ($RegBackup.Length -ne 0) {
            $Global:DiagMsg += "Restoring registry on $osDrive" 
            move $osDrive\windows\system32\config\system $osDrive\windows\system32\config\system_org -Force
            copy $osDrive\windows\system32\config\Regback\system $osDrive\windows\system32\config\system -Force
        }
        
    }      
}


# Schedule a CheckDisk on Next Computer Start if needed
forEach ( $partition in $partitionlist ) {
    $driveLetter = ($partition.DriveLetter + ":")
    $dirtyFlag = fsutil dirty query $driveLetter
    Write-Host

    If ($dirtyFlag -notmatch "NOT Dirty") {
        $Global:DiagMsg += "$driveLetter dirty bit set  -> running chkdsk"
        Start-Job -Name ChkDsk -ScriptBlock { Write-Output 'y' | chkdsk.exe /R $driveLetter } 
        # Launch ChkDsk with /R to includes automated recovery plus hardware checking. Opens a seperate job and takes care of the (Y/N) schedule prompt
    }
    else {
        $Global:DiagMsg += "$driveLetter dirty bit not set  -> skipping chkdsk"
    }
}


### Exit script with proper Datto alerting and diagnostic.
if ($Global:AlertMsg) {
    # If your AlertMsg has value, this is how it will get reported.
    write-DRMMAlert $Global:AlertMsg
    write-DRMMDiag $Global:DiagMsg
    Exit 1
    # Exit 1 means DISPLAY ALERT
}
else {
    # If the AlertMsg variable is blank (nothing was added), the script will report healthy status with whatever was defined above.
    write-DRMMAlert $Global:AlertHealthy
    write-DRMMDiag $Global:DiagMsg
    Exit 0
    # Exit 0 means all is well. No Alert.
}