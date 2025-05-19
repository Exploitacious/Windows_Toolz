# 
## Remediation for Disk Errors for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Disk Health Remediation" # Quick and easy name of Script to help identify
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

# Initialize summary
$summary = @()
$summary += "Disk Health Remediation Process Initiated"

# Function to check if a file is potentially corrupt
function Test-FileCorruption {
    param (
        [string]$FilePath
    )
    $fileInfo = Get-Item $FilePath
    $versionInfo = $fileInfo.VersionInfo
    
    if ($null -eq $versionInfo.FileVersion -and 
        ($fileInfo.Attributes -band [System.IO.FileAttributes]::System) -and 
        ($null -eq $versionInfo.CompanyName -or $versionInfo.CompanyName -ne "Microsoft Corporation") -and
        ($fileInfo.Length -eq 0 -or $fileInfo.LastWriteTime -lt (Get-Date).AddYears(-5))) {
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
        $summary += "Low disk space detected on $DriveLetter"
    }

    # Check for file system errors
    $fsutilOutput = fsutil repair query $DriveLetter
    if ($fsutilOutput -match "There are problems in the file system") {
        Write-Host "WARNING: File system errors detected on $DriveLetter. Consider running chkdsk on next reboot."
        $Global:DiagMsg += "WARNING: File system errors detected on $DriveLetter. Consider running chkdsk on next reboot."
        $summary += "File system errors detected on $DriveLetter"
    }

    # Check S.M.A.R.T. status
    try {
        $partition = Get-Partition -DriveLetter $DriveLetter.Trim(':')
        $disk = Get-Disk -Number $partition.DiskNumber
        $physicalDisk = Get-PhysicalDisk -UniqueId $disk.UniqueId

        if ($physicalDisk) {
            $healthStatus = $physicalDisk.HealthStatus
            $operationalStatus = $physicalDisk.OperationalStatus
            Write-Host "Disk health status for $DriveLetter - Health: $healthStatus, Operational: $operationalStatus"
            $Global:DiagMsg += "Disk health status for $DriveLetter - Health: $healthStatus, Operational: $operationalStatus"
            if ($healthStatus -ne "Healthy" -or $operationalStatus -ne "OK") {
                Write-Host "WARNING: Disk $DriveLetter may require attention"
                $Global:DiagMsg += "WARNING: Disk $DriveLetter may require attention"
                $summary += "Disk health issues detected on $DriveLetter"
            }
        }
    }
    catch {
        Write-Host "Error retrieving disk health status for $DriveLetter : $_"
        $Global:DiagMsg += "Error retrieving disk health status for $DriveLetter : $_"
    }
}

# Start of main script execution
$scriptStartTime = Get-Date
Write-Host "Starting Disk Health Remediation process..."

# Check System Event Logs
$diskEventSources = @('disk', 'ntfs', 'volsnap', 'storagespace', 'volmgr', 'partmgr', 'iaStor', 'Chkdsk')
$diskEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    StartTime = (Get-Date).AddHours(-24)
} -ErrorAction SilentlyContinue | Where-Object {
    $diskEventSources -contains $_.ProviderName
}

if ($diskEvents) {
    Write-Host "Found important disk-related events in the last 24 hours:"
    $Global:DiagMsg += "Found important disk-related events in the last 24 hours:"
    foreach ($event in $diskEvents) {
        $eventMessage = "Event ID: $($event.Id), Source: $($event.ProviderName), Message: $($event.Message)"
        Write-Host $eventMessage
        $Global:DiagMsg += $eventMessage
    }
    $summary += "Disk-related events detected"
}
else {
    Write-Host "No relevant disk events found in System Event Log in the last 24 hours"
    $Global:DiagMsg += "No relevant disk events found in System Event Log in the last 24 hours"
    $summary += "No disk-related events detected"
}

# Check partitions and disk health
$partitionlist = Get-Partition
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
                $summary += "CheckDisk scheduled for $driveLetter"
            }
            else {
                Write-Host "Failed to schedule CheckDisk for $driveLetter. Exit code: $LASTEXITCODE"
                $Global:DiagMsg += "Failed to schedule CheckDisk for $driveLetter. Exit code: $LASTEXITCODE"
            }
        }
        
        Test-DiskHealth -DriveLetter $driveLetter
    }
}

# Check for Windows installations
$windowsInstallations = @()
foreach ($partition in $partitionlist) {
    if (Test-Path ($partition.DriveLetter + ":\Windows\System32\winload.exe")) {
        $windowsInstallations += @{
            OsDrive = $partition.DriveLetter + ":"
            OsPath  = $partition.DriveLetter + ":\Windows\System32\winload.exe"
        }
    }
}

if ($windowsInstallations.Count -eq 0) {
    Write-Host "No Windows installations found."
    $Global:DiagMsg += "No Windows installations found."
    $summary += "No Windows installations detected"
}
else {
    foreach ($windows in $windowsInstallations) {
        Write-Host "Windows installation found on drive $($windows.OsDrive)"
        $Global:DiagMsg += "Windows installation found on drive $($windows.OsDrive)"
        
        Write-Host "Starting Windows image repair process for $($windows.OsDrive)..."
        $Global:DiagMsg += "Starting Windows image repair process for $($windows.OsDrive)"
        
        Write-Host "Reverting pending actions to Windows Image..."
        $dismResult = dism.exe /online /cleanup-image /revertpendingactions
        Write-Host "DISM revert completed."
        $Global:DiagMsg += "DISM revert completed"
        $summary += "DISM pending actions reverted"

        Write-Host "Running SFC on $($windows.OsDrive)\windows..."
        $sfcOutput = & sfc /scannow | Where-Object { $_ -match 'Windows Resource Protection' }
        Write-Host $sfcOutput
        $Global:DiagMsg += $sfcOutput
        $summary += "SFC scan completed"

        Write-Host "Running DISM to restore health..."
        $dismRestoreResult = Dism.exe /Online /Cleanup-Image /RestoreHealth
        Write-Host "DISM restore completed."
        $Global:DiagMsg += "DISM restore completed"
        $summary += "DISM health restore completed"

        Write-Host "Checking for potentially corrupt system files..."
        $potentiallyCorruptFiles = Get-ChildItem -Path "$($windows.OsDrive)\Windows\System32\*" -Include *.dll, *.exe | 
        Where-Object { Test-FileCorruption $_.FullName } |
        Select-Object FullName
        
        if ($potentiallyCorruptFiles) {
            Write-Host "WARNING: Potentially corrupt files found that require further examination:"
            $Global:DiagMsg += "WARNING: Potentially corrupt files found that require further examination:"
            foreach ($file in $potentiallyCorruptFiles) {
                Write-Host $file.FullName
                $Global:DiagMsg += $file.FullName
            }
            $summary += "Potentially corrupt files detected"
        }
        else {
            Write-Host "No critically corrupt files found"
            $Global:DiagMsg += "No critically corrupt files found"
            $summary += "No critically corrupt files detected"
        }
    }
}

# Check for new events that occurred during remediation
$newDiskEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    StartTime = $scriptStartTime
} -ErrorAction SilentlyContinue | Where-Object {
    $diskEventSources -contains $_.ProviderName
}

if ($newDiskEvents) {
    Write-Host "WARNING: New disk-related events occurred during remediation:"
    $Global:DiagMsg += "WARNING: New disk-related events occurred during remediation:"
    foreach ($event in $newDiskEvents) {
        $eventMessage = "Event ID: $($event.Id), Source: $($event.ProviderName), Message: $($event.Message)"
        Write-Host $eventMessage
        $Global:DiagMsg += $eventMessage
    }
    Write-Host "Actionable steps for the engineer:"
    Write-Host "1. Review the new events in detail using Event Viewer"
    Write-Host "2. Check disk health using manufacturer-specific tools"
    Write-Host "3. Consider running extended hardware diagnostics"
    Write-Host "4. If problems persist, consider disk replacement"
    $summary += "New disk events occurred during remediation - further action required"
}
else {
    Write-Host "No new disk-related events occurred during remediation"
    $Global:DiagMsg += "No new disk-related events occurred during remediation"
    $summary += "No new disk events during remediation"
}

# Final summary
Write-Host "`nDisk Health Remediation process completed. Summary of actions:"
foreach ($item in $summary) {
    Write-Host "- $item"
}

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