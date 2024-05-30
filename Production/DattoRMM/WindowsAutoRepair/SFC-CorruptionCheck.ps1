# Run SFC, DISM and Checkdisk on next bootup for affected drives and partitions

$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.

$Global:AlertMsg = @() # Combined Alert message. If left blank, will not trigger Alert status. Use " $Global:AlertMsg += " to append messages to be alerted on in Datto.

$Global:AlertHealthy = "Healthy" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.

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



# Pull up all particians and number them
$partitionlist = Get-Partition
$partitionGroup = $partitionlist | Group-Object DiskNumber

#######################################################################

# Schedule a CheckDisk on Next Computer Start if needed
forEach ( $partition in $partitionlist ) {
    $driveLetter = ($partition.DriveLetter + ":")
    $dirtyFlag = fsutil dirty query $driveLetter
    Write-Host

    If ($dirtyFlag -notmatch "NOT Dirty") {
        Write-Host "$driveLetter dirty bit set  -> running chkdsk"
        Start-Job -Name ChkDsk -ScriptBlock { Write-Output 'y' | chkdsk.exe /R $driveLetter } 
        # Launch ChkDsk with /R to includes automated recovery plus hardware checking. Opens a seperate job and takes care of the (Y/N) schedule prompt
    }
    else {
        Write-Host "$driveLetter dirty bit not set  -> skipping chkdsk"
    }
}


# Run DISM and SFC on Windows Volumes

forEach ( $partitionGroup in $partitionlist | Group-Object DiskNumber ) {
    Write-Host
    Write-Host "Running DISM / SFC"
    Write-Host
    #reset paths for each part group (disk)
    $isOsPath = $false
    $osPath = ''
    $osDrive = ''

    # Scan all partitions of a disk for bcd store and os file location 
    ForEach ($drive in $partitionGroup.Group | Select-Object -ExpandProperty DriveLetter ) {      
                
        # Check if OS loader was found on the previous partition
        if (-not $isOsPath) {
            $osPath = $drive + ':\windows\system32\winload.exe'
            $isOsPath = Test-Path $osPath
            if ($isOsPath) {
                $osDrive = $drive + ':'
            }
        }
    }

    Write-Host "OsDrive $OsDrive"
    Write-Host "OsPath $OsPath"
    Write-Host "isOsPath $isOsPath"
    Write-Host

    # Run DISM and SFC
    if ( $isOsPath -eq $true ) {
        
        Write-Host "Revert pending actions to Windows Image to let SFC succeed in most cases"
        dism.exe /online /cleanup-image /revertpendingactions
        Write-Host

        Write-Host "Running SFC on $osDrive\windows"
        sfc /scannow # Offline File Options: /offbootdir=$osDrive /offwindir=$osDrive\windows
        Write-Host

        Write-Host "Running DISM to restore health on $osDrive" 
        Dism.exe /Online /Cleanup-Image /RestoreHealth
        Write-Host
        
        Write-Host "Enumerating potentially corrupt system files in $osDrive\windows\system32\"
        Get-ChildItem -Path $osDrive\windows\system32\* -Include *.dll, *.exe `
        | ForEach-Object { $_.VersionInfo | Where-Object FileVersion -EQ $null | Select-Object FileName, ProductVersion, FileVersion }                
        
    }      
}