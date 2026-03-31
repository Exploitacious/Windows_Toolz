# 
## Remediation for Disk & System Health for Datto RMM with PowerShell
# Original by Alex Ivantsov @Exploitacious | Enhanced by Gemini
#

# Script Name and Type
$ScriptName = "Comprehensive System Health Remediation"
$ScriptType = "Remediation" 

## Verify/Elevate to Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Functions
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}

function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}

# Extra Info and Variables
$Global:DiagMsg = @() 
$Global:varUDFString = ""
$ScriptUID = GenRANDString 20
$Date = Get-Date -Format "MM/dd/yyy hh:mm tt"
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date 
##################################
##################################
######## Start of Script #########

# Initialize a structured report object
$Report = [PSCustomObject]@{
    SystemInfo      = @{}
    DiskChecks      = @() # Initialize as an empty array
    EventLogSummary = @{}
    WindowsHealth   = @{}
    Remediation     = @{}
}

# PHASE 1: DIAGNOSTICS & INFORMATION GATHERING
$Global:DiagMsg += "PHASE 1: Starting Diagnostics..."
$Report.SystemInfo.Hostname = $env:COMPUTERNAME
$Report.SystemInfo.ScriptStartTime = Get-Date

# 1A: Check Physical Disk Health (S.M.A.R.T. & CIM)
$Global:DiagMsg += "Checking physical disk health (CIM & S.M.A.R.T.)..."
try {
    $physicalDisks = Get-PhysicalDisk -ErrorAction Stop
    # MODIFICATION: Replaced deprecated 'wmic' with modern 'Get-CimInstance'
    $cimDiskStatus = Get-CimInstance -ClassName Win32_DiskDrive | Select-Object Model, Status
    
    $diskChecksList = New-Object System.Collections.Generic.List[System.Object]

    foreach ($disk in $physicalDisks) {
        # Match the disk model to get its status from the CIM query
        $cimMatch = $cimDiskStatus | Where-Object { $_.Model -eq $disk.FriendlyName } | Select-Object -First 1
        $cimStatus = if ($cimMatch) { $cimMatch.Status } else { 'N/A' }

        $diskReportObject = [PSCustomObject]@{
            DiskNumber        = $disk.DeviceID
            Model             = $disk.FriendlyName
            MediaType         = $disk.MediaType
            HealthStatus      = $disk.HealthStatus
            OperationalStatus = [string]$disk.OperationalStatus
            CIM_Status        = $cimStatus
            Temperature       = "N/A"
            ReadErrors        = "N/A"
            WriteErrors       = "N/A"
        }

        try {
            $smartCounters = $disk | Get-StorageReliabilityCounter
            if ($smartCounters) {
                $diskReportObject.Temperature = $smartCounters.Temperature
                $diskReportObject.ReadErrors = $smartCounters.ReadErrorsTotal
                $diskReportObject.WriteErrors = $smartCounters.WriteErrorsTotal
            }
        }
        catch {
            $Global:DiagMsg += "WARN: Could not retrieve advanced S.M.A.R.T. data for disk $($disk.DeviceID) ($($disk.FriendlyName))."
        }
        $diskChecksList.Add($diskReportObject)
    }
    $Report.DiskChecks = $diskChecksList.ToArray()
}
catch {
    $Global:DiagMsg += "FATAL: Could not retrieve physical disk information. Error: $($_.Exception.Message)"
}

# 1B: Check Logical Volume Health
$Global:DiagMsg += "Checking logical volume health..."
$logicalDisks = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
foreach ($volume in $logicalDisks) {
    $driveLetter = $volume.DriveLetter + ":"
    # Find the corresponding physical disk report object to add to
    $diskCheck = $Report.DiskChecks | Where-Object { $_.DiskNumber -eq $volume.DiskNumber }
    if ($diskCheck) {
        $dirtyBit = fsutil dirty query $driveLetter
        $freeSpacePercent = [math]::Round(($volume.SizeRemaining / $volume.Size) * 100, 2)
        
        $diskCheck | Add-Member -MemberType NoteProperty -Name "DriveLetter" -Value $driveLetter -Force
        $diskCheck | Add-Member -MemberType NoteProperty -Name "FileSystem" -Value $volume.FileSystem -Force
        $diskCheck | Add-Member -MemberType NoteProperty -Name "FreeSpacePercent" -Value $freeSpacePercent -Force
        $diskCheck | Add-Member -MemberType NoteProperty -Name "IsDirty" -Value ($dirtyBit -notmatch "NOT Dirty") -Force
    }
}

# 1C: Summarize Disk-Related Events
$Global:DiagMsg += "Summarizing disk-related events from the last 24 hours..."
$diskEventSources = @('disk', 'ntfs', 'volsnap', 'storagespace', 'volmgr', 'partmgr', 'iaStor', 'Chkdsk', 'storahci', 'diskfail')
$diskEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    StartTime = (Get-Date).AddHours(-24)
} -ErrorAction SilentlyContinue | Where-Object { $diskEventSources -contains $_.ProviderName }

if ($diskEvents) {
    $Report.EventLogSummary.Status = "Disk-related events found."
    $Report.EventLogSummary.Events = $diskEvents | Group-Object ProviderName, ID | Select-Object Count, @{N = 'Provider'; E = { $_.Group[0].ProviderName } }, @{N = 'EventID'; E = { $_.Group[0].Id } } | Sort-Object Count -Descending
}
else {
    $Report.EventLogSummary.Status = "No relevant disk events found."
}

# 1D: Check Core Windows Health
$Global:DiagMsg += "Checking core Windows health..."
$Report.WindowsHealth.RebootPending = (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations") -or (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -Name "RebootRequired" -ErrorAction SilentlyContinue)
$vssWriters = & vssadmin list writers
$vssErrors = $vssWriters | Where-Object { $_ -match 'State' -and $_ -notmatch 'State: \[1\] Stable' }
$Report.WindowsHealth.VSS_Writer_Status = if ($vssErrors) { "Errors found" } else { "All stable" }
$Report.WindowsHealth.VSS_Errors_Count = ($vssErrors | Measure-Object).Count

# --- Diagnostic Phase Complete ---
$Global:DiagMsg += "PHASE 1 COMPLETE. Diagnostic report generated."
$Global:DiagMsg += $Report.DiskChecks | Format-Table | Out-String 

# PHASE 2: REMEDIATION
$Global:DiagMsg += "PHASE 2: Starting Remediation..."

# 2A: Schedule Chkdsk if necessary
$dirtyDrives = $Report.DiskChecks | Where-Object { $_.IsDirty -eq $true }
if ($dirtyDrives) {
    $Report.Remediation.Chkdsk = "Dirty bit found. Scheduling chkdsk."
    foreach ($drive in $dirtyDrives) {
        $Global:DiagMsg += "INFO: Scheduling chkdsk for $($drive.DriveLetter) on next reboot."
        & chkdsk.exe $drive.DriveLetter /f
        # Confirm it's scheduled
        if ((& chkntfs.exe $drive.DriveLetter) -match "has been scheduled") {
            $Global:DiagMsg += "SUCCESS: chkdsk confirmed as scheduled for $($drive.DriveLetter)."
        }
        else {
            $Global:DiagMsg += "WARN: Failed to confirm chkdsk schedule for $($drive.DriveLetter)."
        }
    }
}
else {
    $Report.Remediation.Chkdsk = "No dirty drives found. Skipped."
}

# 2B: Run SFC and DISM if an OS is found
if (Test-Path "$($env:SystemDrive)\Windows\System32\winload.exe") {
    $Global:DiagMsg += "INFO: Windows installation found. Running SFC and DISM."
    
    $Global:DiagMsg += "Running System File Checker (SFC)..."
    $sfcResult = (& sfc.exe /scannow) | Out-String
    $Report.Remediation.SFC_Result = $sfcResult
    # MODIFICATION: Removed the verbose SFC output from the main diagnostic log.
    # $Global:DiagMsg += "SFC Result: $sfcResult" 

    $Global:DiagMsg += "Running DISM RestoreHealth..."
    $dismResult = (& Dism.exe /Online /Cleanup-Image /RestoreHealth) | Out-String
    $Report.Remediation.DISM_Result = $dismResult
    $Global:DiagMsg += "DISM RestoreHealth completed."
}
else {
    $Global:DiagMsg += "WARN: No Windows installation found on system drive. Skipping SFC/DISM."
    $Report.Remediation.SFC_DISM = "Skipped (No OS found)."
}

# --- Remediation Phase Complete ---
$Global:DiagMsg += "PHASE 2 COMPLETE. Remediation actions finished."

# PHASE 3: FINAL REPORTING
$Global:DiagMsg += "PHASE 3: Final Reporting..."
$finalSummary = "Disk Health Summary:`n"
if ($Report.DiskChecks) {
    foreach ($disk in $Report.DiskChecks) {
        $finalSummary += "- Disk $($disk.DiskNumber) ($($disk.Model)): Drive $($disk.DriveLetter), Status $($disk.HealthStatus), Free $($disk.FreeSpacePercent)%, Dirty $($disk.IsDirty).`n"
    }
}
else {
    $finalSummary += "- No physical disks found or could not be queried.`n"
}

$finalSummary += "`nWindows Health Summary:`n"
$finalSummary += "- Events (24hr): $($Report.EventLogSummary.Status)`n"
$finalSummary += "- VSS Writers: $($Report.WindowsHealth.VSS_Writer_Status)`n"
$finalSummary += "- Reboot Pending: $($Report.WindowsHealth.RebootPending)`n"
$finalSummary += "`nRemediation:`n"
$finalSummary += "- Chkdsk: $($Report.Remediation.Chkdsk)`n"

$sfcSummaryForReport = "Not run"
if ($Report.Remediation.SFC_Result) {
    $sfcSummaryForReport = if ($Report.Remediation.SFC_Result -match "found no integrity violations") {
        "No integrity violations found."
    }
    elseif ($Report.Remediation.SFC_Result -match "successfully repaired") {
        "Repairs were successful."
    }
    elseif ($Report.Remediation.SFC_Result -match "found corrupt files but was unable to fix") {
        "Found corruption, could not repair."
    }
    else {
        "Completed. Review log for details."
    }
}
$finalSummary += "- SFC: $sfcSummaryForReport`n"

# Prepare string for Datto RMM UDF (concise summary)
$diskHealthStatus = if ($Report.DiskChecks) { ($Report.DiskChecks.HealthStatus | Select-Object -Unique) -join ', ' } else { "Unknown" }
$eventsSummary = $Report.EventLogSummary.Status.Replace("Disk-related events found.", "Found").Replace("No relevant disk events found.", "None")
$Global:varUDFString = "Disk Health: $diskHealthStatus. VSS: $($Report.WindowsHealth.VSS_Writer_Status). Events: $eventsSummary. Reboot: $($Report.WindowsHealth.RebootPending)."

$Global:DiagMsg += "Final Summary:`n$finalSummary"

######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {    
    if ($Global:varUDFString.Length -gt 255) {
        $Global:DiagMsg += " - Writing to UDF (truncated): " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name "custom$($env:usrUDF)" -Value $($Global:varUDFString.Substring(0, 255)) -Force -ErrorAction SilentlyContinue
    }
    else {
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name "custom$($env:usrUDF)" -Value $Global:varUDFString -Force -ErrorAction SilentlyContinue
    }
}
### Info to be sent to into JSON POST to API Endpoint (Optional)
$APIinfoHashTable = @{
    'CS_PROFILE_UID' = $env:CS_PROFILE_UID
    'Script_Diag'    = $Global:DiagMsg
    'Script_UID'     = $ScriptUID
    'Report_Object'  = $Report | ConvertTo-Json -Depth 5 -Compress
}
#######################################################################
### Exit script with proper Datto diagnostic and API Results.
# Add Script Result and POST to API if an Endpoint is Provided
if ($env:APIEndpoint) {
    try {
        $Global:DiagMsg += " - Sending Results to API"
        Invoke-WebRequest -Uri $env:APIEndpoint -Method POST -Body ($APIinfoHashTable | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -ErrorAction Stop
    }
    catch {
        $Global:DiagMsg += " - ERROR: Failed to send results to API. $($_.Exception.Message)"
    }
}
# Exit with writing diagnostic back to the ticket / remediation component log
write-DRMMDiag $Global:DiagMsg
Exit 0