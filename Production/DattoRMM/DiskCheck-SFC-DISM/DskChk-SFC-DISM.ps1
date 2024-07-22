# 
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Install System Update" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:APIEndpoint = "https://prod-36.westus.logic.azure.com:443/workflows/6c032a1ca84045b9a7a1436864ecf696/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=c-dVa333HMzhWli_Fp_4IIAqaJOMwFjP2y5Zfv4j_zA"
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

<#
This Script is a Remediation compoenent, meaning it performs only one task with a log of granular detail. These task results can be added back ito tickets as time entries using the API. 

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}
Function GenRANDString ([Int]$CharLength, [Char[]]$CharSets = "ULNS") {
    $Chars = @()
    $TokenSet = @()
    If (!$TokenSets) {
        $Global:TokenSets = @{
            U = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                # Upper case
            L = [Char[]]'abcdefghijklmnopqrstuvwxyz'                                # Lower case
            N = [Char[]]'0123456789'                                                # Numerals
            S = [Char[]]'!"#%&()*+,-./:;<=>?@[\]^_{}~'                             # Symbols
        }
    }
    $CharSets | ForEach-Object {
        $Tokens = $TokenSets."$_" | ForEach-Object { If ($Exclude -cNotContains $_) { $_ } }
        If ($Tokens) {
            $TokensSet += $Tokens
            If ($_ -cle [Char]"Z") { $Chars += $Tokens | Get-Random }             #Character sets defined in upper case are mandatory
        }
    }
    While ($Chars.Count -lt $CharLength) { $Chars += $TokensSet | Get-Random }
    ($Chars | Sort-Object { Get-Random }) -Join ""                                #Mix the (mandatory) characters and output string
};
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 15 UN # Generate random UID for script
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########




Write-Host "Starting Disk Health Remediation process..."

# Function to check if a file is potentially corrupt
function Test-FileCorruption {
    param (
        [string]$FilePath
    )
    $fileInfo = Get-Item $FilePath
    $versionInfo = $fileInfo.VersionInfo
    
    # Check if file has no version info or if it's a system file with unexpected attributes
    if ($null -eq $versionInfo.FileVersion -or 
        ($fileInfo.Attributes -band [System.IO.FileAttributes]::System) -and 
        ($null -eq $versionInfo.CompanyName -or $versionInfo.CompanyName -ne "Microsoft Corporation")) {
        return $true
    }
    return $false
}

# Function to check disk health
function Test-DiskHealth {
    param (
        [string]$DriveLetter
    )
    Write-Host "Checking disk health for drive $DriveLetter..."
    $Global:DiagMsg += "Checking disk health for drive $DriveLetter"
    
    # Check disk space
    $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$DriveLetter'"
    $freeSpacePercent = ($disk.FreeSpace / $disk.Size) * 100
    if ($freeSpacePercent -lt 10) {
        Write-Host "WARNING: Low disk space on $DriveLetter. Only $([math]::Round($freeSpacePercent,2))% free."
        $Global:DiagMsg += "WARNING: Low disk space on $DriveLetter. Only $([math]::Round($freeSpacePercent,2))% free."
    }

    # Check for file system errors using fsutil
    Write-Host "Checking file system on $DriveLetter..."
    $fsutilOutput = fsutil repair query $DriveLetter
    if ($fsutilOutput -match "There are problems in the file system") {
        Write-Host "WARNING: File system errors detected on $DriveLetter. Consider running chkdsk on next reboot."
        $Global:DiagMsg += "WARNING: File system errors detected on $DriveLetter. Consider running chkdsk on next reboot."
    }
    else {
        Write-Host "No file system errors detected on $DriveLetter"
        $Global:DiagMsg += "No file system errors detected on $DriveLetter"
    }

    # Check S.M.A.R.T. status using Get-PhysicalDisk
    Write-Host "Checking S.M.A.R.T. status for $DriveLetter..."
    $Global:DiagMsg += "Checking S.M.A.R.T. status for $DriveLetter"
    try {
        # Get the partition associated with the drive letter
        $partition = Get-Partition -DriveLetter $DriveLetter.Trim(':')

        # Get the disk associated with the partition
        $disk = Get-Disk -Number $partition.DiskNumber

        # Get the physical disk associated with the disk
        $physicalDisk = Get-PhysicalDisk -UniqueId $disk.UniqueId

        if ($physicalDisk) {
            $healthStatus = $physicalDisk.HealthStatus
            $operationalStatus = $physicalDisk.OperationalStatus
            Write-Host "Disk health status for $DriveLetter - Health: $healthStatus, Operational: $operationalStatus"
            $Global:DiagMsg += "Disk health status for $DriveLetter - Health: $healthStatus, Operational: $operationalStatus"
            if ($healthStatus -ne "Healthy" -or $operationalStatus -ne "OK") {
                Write-Host "WARNING: Disk $DriveLetter may require attention"
                $Global:DiagMsg += "WARNING: Disk $DriveLetter may require attention"
            }
        }
        else {
            Write-Host "Unable to find physical disk for $DriveLetter"
            $Global:DiagMsg += "Unable to find physical disk for $DriveLetter"
        }
    }
    catch {
        Write-Host "Error retrieving disk health status for $DriveLetter : $_"
        $Global:DiagMsg += "Error retrieving disk health status for $DriveLetter : $_"
    }
}

Write-Host "Checking System Event Logs for disk-related events..."
$Global:DiagMsg += "Checking System Event Logs for disk-related events"

# Define an array of disk-related event sources
$diskEventSources = @('disk', 'ntfs', 'volsnap', 'storagespace', 'volmgr', 'partmgr', 'iaStor', 'Chkdsk')

# Get disk-related events from the last 24 hours
$diskEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    StartTime = (Get-Date).AddHours(-24)
} -ErrorAction SilentlyContinue | Where-Object {
    $diskEventSources -contains $_.ProviderName
}

if ($diskEvents) {
    Write-Host "Found the following important disk-related events:"
    $Global:DiagMsg += "Found the following important disk-related events:"
    foreach ($event in $diskEvents) {
        $eventMessage = "Event ID: $($event.Id), Source: $($event.ProviderName), Message: $($event.Message)"
        Write-Host $eventMessage
        $Global:DiagMsg += $eventMessage
    }
}
else {
    Write-Host "No relevant disk events found in System Event Log in the last 24 hours"
    $Global:DiagMsg += "No relevant disk events found in System Event Log in the last 24 hours"
}

# Get all partitions
Write-Host "Retrieving partition information..."
$partitionlist = Get-Partition
$partitionGroup = $partitionlist | Group-Object DiskNumber

# Check disk health and schedule CheckDisk if necessary
Write-Host "Checking partitions and disk health..."
foreach ($partition in $partitionlist) {
    $driveLetter = ($partition.DriveLetter + ":")
    if ($driveLetter -ne ":") {
        Write-Host "Checking $driveLetter"
        $Global:DiagMsg += "Checking $driveLetter"
        $dirtyFlag = fsutil dirty query $driveLetter
        
        If ($dirtyFlag -notmatch "NOT Dirty") {
            Write-Host "$driveLetter dirty bit set -> scheduling chkdsk on next reboot"
            $Global:DiagMsg += "$driveLetter dirty bit set -> scheduling chkdsk on next reboot"
            $chkdskResult = chkdsk $driveLetter /f /r /x /b
            if ($LASTEXITCODE -eq 0) {
                Write-Host "CheckDisk scheduled successfully for $driveLetter on next reboot"
                $Global:DiagMsg += "CheckDisk scheduled successfully for $driveLetter on next reboot"
            }
            else {
                Write-Host "Failed to schedule CheckDisk for $driveLetter. Exit code: $LASTEXITCODE"
                $Global:DiagMsg += "Failed to schedule CheckDisk for $driveLetter. Exit code: $LASTEXITCODE"
            }
        }
        else {
            Write-Host "$driveLetter dirty bit not set -> skipping chkdsk"
            $Global:DiagMsg += "$driveLetter dirty bit not set -> skipping chkdsk"
        }
        
        # Run additional disk health checks
        Test-DiskHealth -DriveLetter $driveLetter
    }
}

# Run DISM and SFC on Windows Volumes
Write-Host "Checking for Windows installations and running system file checks..."
foreach ( $partitionGroup in $partitionlist | Group-Object DiskNumber ) {
    Write-Host "Checking partition group for Windows installation"
    $Global:DiagMsg += "Checking partition group for Windows installation"
    #reset paths for each part group (disk)
    $isOsPath = $false
    $osPath = ''
    $osDrive = ''

    # Scan all partitions of a disk for bcd store and os file location 
    ForEach ($drive in $partitionGroup.Group | Select-Object -ExpandProperty DriveLetter ) {      
        if (-not $isOsPath -and $drive) {
            $osPath = $drive + ':\windows\system32\winload.exe'
            $isOsPath = Test-Path $osPath
            if ($isOsPath) {
                $osDrive = $drive + ':'
            }
        }
    }

    Write-Host "OsDrive: $OsDrive"
    Write-Host "OsPath: $OsPath"
    Write-Host "isOsPath: $isOsPath"
    $Global:DiagMsg += "OsDrive: $OsDrive"
    $Global:DiagMsg += "OsPath: $OsPath"
    $Global:DiagMsg += "isOsPath: $isOsPath"

    # Run DISM and SFC
    if ( $isOsPath -eq $true ) {
        Write-Host "Starting Windows image repair process..."
        $Global:DiagMsg += "Starting Windows image repair process"
        
        Write-Host "Reverting pending actions to Windows Image..."
        $Global:DiagMsg += "Reverting pending actions to Windows Image"
        $dismResult = dism.exe /online /cleanup-image /revertpendingactions
        Write-Host "DISM revert result: $dismResult"
        $Global:DiagMsg += "DISM revert result: $dismResult"

        Write-Host "Running SFC on $osDrive\windows..."
        $Global:DiagMsg += "Running SFC on $osDrive\windows"
        $sfcOutput = & sfc /scannow
        Write-Host "SFC output:"
        $sfcOutput | ForEach-Object { 
            Write-Host $_
            $Global:DiagMsg += $_
        }

        Write-Host "Running DISM to restore health on $osDrive..." 
        $Global:DiagMsg += "Running DISM to restore health on $osDrive" 
        $dismRestoreResult = Dism.exe /Online /Cleanup-Image /RestoreHealth
        Write-Host "DISM restore result: $dismRestoreResult"
        $Global:DiagMsg += "DISM restore result: $dismRestoreResult"

        Write-Host "Enumerating potentially corrupt system files in $osDrive\windows\system32\..."
        $Global:DiagMsg += "Enumerating potentially corrupt system files in $osDrive\windows\system32\"
        $potentiallyCorruptFiles = Get-ChildItem -Path $osDrive\windows\system32\* -Include *.dll, *.exe | 
        Where-Object { Test-FileCorruption $_.FullName } |
        Select-Object FullName
        
        if ($potentiallyCorruptFiles) {
            Write-Host "Potentially corrupt files found:"
            $Global:DiagMsg += "Potentially corrupt files found:"
            foreach ($file in $potentiallyCorruptFiles) {
                Write-Host $file.FullName
                $Global:DiagMsg += $file.FullName
            }
        }
        else {
            Write-Host "No potentially corrupt files found"
            $Global:DiagMsg += "No potentially corrupt files found"
        }
    }      
}

# Check if the original events have been resolved
Write-Host "Checking if original events have been resolved..."
$Global:DiagMsg += "Checking if original events have been resolved"
$newDiskEvents = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ID      = @(7, 33, 57)
} -ErrorAction SilentlyContinue

if ($newDiskEvents.Count -lt $diskEvents.Count) {
    Write-Host "Some disk-related events have been resolved"
    $Global:DiagMsg += "Some disk-related events have been resolved"
}
elseif ($newDiskEvents.Count -eq $diskEvents.Count) {
    Write-Host "No change in disk-related events. Further investigation may be needed."
    $Global:DiagMsg += "No change in disk-related events. Further investigation may be needed."
}
else {
    Write-Host "WARNING: New disk-related events have occurred during remediation"
    $Global:DiagMsg += "WARNING: New disk-related events have occurred during remediation"
}

Write-Host "Disk Health Remediation process completed."



######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {    
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Info to be sent to into JSON POST to API Endpoint (Optional)
$APIinfoHashTable = @{
    'CS_PROFILE_UID' = $env:CS_PROFILE_UID
    'Script_Diag'    = $Global:DiagMsg
    'Script_UID'     = $ScriptUID
}
#######################################################################
### Exit script with proper Datto diagnostic and API Results.
# Add Script Result and POST to API if an Endpoint is Provided
if ($null -ne $env:APIEndpoint) {
    $Global:DiagMsg += " - Sending Results to API"
    Invoke-WebRequest -Uri $env:APIEndpoint -Method POST -Body ($APIinfoHashTable | ConvertTo-Json) -ContentType "application/json"
}
# Exit with writing diagnostic back to the ticket / remediation component log
write-DRMMDiag $Global:DiagMsg
Exit 0