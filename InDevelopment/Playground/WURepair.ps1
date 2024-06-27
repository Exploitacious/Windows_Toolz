### Hacked together script for some broken Win Update installs

#Requires -Version 5.1
function Get-SFCLog {
    # Get the path of the SFC log file
    $log = "$env:windir\logs\cbs\cbs.log"

    # Check if the log file exists
    if (Test-Path $log) {
        # Read the log file and filter the lines with [SR] tag
        $lines = Get-Content $log | Where-Object {$_ -match "\[SR\]"}

        # Get the last line with [SR] tag
        $last = $lines[-1]

        # Parse the date from the last line
        $date = $last.Substring(0, 10)

        # Rescan the output grabbing only information from the same date
        $SfcLastRun = $lines | Where-Object {$_ -match "$date"}

    } else {
        # Write an error message to the console
        $SfcLastRun = "The SFC log file does not exist."
    }
    Return $sfcLastrun
}

function Get-WinUpdateLog {
    # Grab the Windows Update log
    $UpdateLogPath = "C:\ProgramData\CentraStage\Temp\WindowsUpdate.log"
    powershell "Get-WindowsUpdateLog -LogPath $updateLogPath" | Out-Null

    # Check if the log file exists
    if (Test-Path $UpdateLogPath) {
        # Read the log file
        $lines = Get-Content $UpdateLogPath

        # Get the last line
        $last = $lines[-1]

        # Parse the date from the last line
        $date = $last.Substring(0, 10)

        # Rescan the output grabbing only information from the same date
        $WULastRun = $lines | Where-Object {$_ -match "$date"}
    } else {
        # Write an error message to the console
        $WULastRun = "The Windows Update log file does not exist or something failed while generating the log. Please manually review the machine."
    }
    return $WULastRun
}

function Get-DismLog {
    # Grab the Windows Update log
    $DismLogPath = "C:\Windows\Logs\DISM\dism.log"
    #$DismUpdateLog = Get-WindowsUpdateLog -LogPath $updateLogPath -ErrorAction SilentlyContinue

    # Check if the log file exists
    if (Test-Path $DismLogPath) {
        # Read the log file
        $lines = Get-Content $DismLogPath

        # Get the last line
        $last = $lines[-1]

        # Parse the date from the last line
        $date = $last.Substring(0, 10)

        # Rescan the output grabbing only information from the same date
        $DismLastRun = $lines | Where-Object {$_ -match "$date"}
    } else {
        # Write an error message to the console
        $DismLastRun = "The DISM log file does not exist. Please manually review the machine."
    }
    return $DismLastRun
}

#$ComputerInfo = Get-ComputerInfo

# Scan the Windows image using DISM
Write-Host "Scanning the Windows image using DISM..."
$scan = DISM /Online /Cleanup-Image /ScanHealth

# Check if the scan found any issues
if ($scan -match "The component store is repairable") {
    Write-Host "The scan found some issues. Attempting to repair them..."

    # Repair the Windows image using DISM
    Write-Host "Repairing the Windows image using DISM..."
    $repair = DISM /Online /Cleanup-Image /RestoreHealth

    # Check if the repair was successful
    if ($repair -match "The restore operation completed successfully") {
        Write-Host "The repair was successful."
        $DismSuccess = "Success"
    }
    else {
        Write-Host "The repair failed. Please check the DISM log file for more details."
        $DismSuccess = "Fail [WARNING]"
    }

    # Run the SFC /scannow command
    Write-Host "Running the SFC /scannow command..."
    $sfc = sfc /scannow

    # Check if the SFC command found any issues

    switch ($sfc) {
        {$_ -match "Windows Resource Protection did not find any integrity violations"} {
            Write-Host "The SFC command did not find any issues."
            $SfcSuccess = "Success"
        }
        {$_ -match "Windows Resource Protection found corrupt files and successfully repaired them"} {
            Write-Host "The SFC command found and repaired some issues."
            $SfcSuccess = "Success"
        }
        {$_ -match "Windows Resource Protection found corrupt files but was unable to fix some of them"} {
            Write-Host "The SFC command found some issues but could not repair them. Please check the CBS log file for more details."
            $SfcSuccess = "Fail [WARNING]"
        }
        Default {
            Write-Host "The SFC command failed. Please check the SFC log file for more details."
            $SfcSuccess = "Fail [WARNING]"
        }
    }

    # Final Output for repair operations
    Write-Host "--------------------------------------------------------------------------------------------------------------"
    Write-Host "-- Attempted repair complete."
    Write-Host "-- DISM Repair: $DismSuccess"
    Write-Host "-- SFC Repair: $SfcSuccess"
    Write-Host "If either of the above report Fail, please review the diagnostic output"
    Write-Host "--------------------------------------------------------------------------------------------------------------"

} else {
    Write-Host "--------------------------------------------------------------------------------------------------------------"
    Write-Host "The scan did not find any issues. No further action is required."
    Write-Host "--------------------------------------------------------------------------------------------------------------"
}

Write-Host "------------------------------------------------DIAGNOSTIC----------------------------------------------------"
Write-Host "-- Windows Update Log"
Get-WinUpdateLog
Write-Host "--------------------------------------------------------------------------------------------------------------"
Write-Host "-- DISM Log"
Get-DismLog
Write-Host "--------------------------------------------------------------------------------------------------------------"
Write-Host "-- SFC Log"
Get-SFCLog
Write-Host "-----------------------------------------------------END------------------------------------------------------"


<#
TITLE: Clear Windows Updates Downloads [WIN]
PURPOSE: Deletes all contents in the Windows Updates Download directory.
CREATOR: Dan Meddock
CREATED: 07NOV2022
LAST UPDATED: 07NOV2022
#>

# Declarations
$winDownloads = "C:\Windows\SoftwareDistribution\Download\*"

# Main
Try{
	stop-service wuauserv
	Remove-Item $winDownloads -Force -Recurse
	start-service wuauserv
	Exit 0
	
}catch{
	Write-Error $_.Exception.Message 
	Exit 1
}