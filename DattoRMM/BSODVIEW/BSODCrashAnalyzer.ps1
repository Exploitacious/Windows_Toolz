#
## Template for Scripting Component Monitors for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "BSOD and Crash Dump Analyzer" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation
$Date = Get-Date -Format "MM/dd/yyy hh:mm tt"

# What to Write if Alert is Healthy
$Global:AlertHealthy = "No BSODs or Critical Events found. | Last Checked $Date" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.

## Verify/Elevate to Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ##
# To use, create a variable in the Datto RMM Component UI with the same name.
# $env:usrUDF = 14 # Example: Which UDF to write the summary to.
# $env:usrEventLogDays = 7 # Example: The number of days back to search for Critical and Error events in the logs.

# DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
function write-DRMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:AlertMsg = @() # Combined Alert message. If left blank, will not trigger Alert status. Use " $Global:AlertMsg += " to append messages to be alerted on in Datto.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date
##################################
##################################
######## Start of Script #########

#------------------------------------------------------------------------------------
# Section 1: User-Configurable Variables (with Datto RMM overrides)
#------------------------------------------------------------------------------------

# The base directory where a 'Tools' folder will be created. Using ProgramData for persistence.
$WorkDirectory = "$env:ProgramData\DattoRMM\BSODVIEW"

# The number of days back to search for logs. Default to 7 if not set in Datto.
$EventLogDays = if ($env:usrEventLogDays) { $env:usrEventLogDays } else { 7 }
$Global:DiagMsg += "[CONFIG] Event log search window set to $EventLogDays days."


# The direct download URL for the BlueScreenView zip file.
$DownloadURL = "https://www.nirsoft.net/utils/bluescreenview.zip"

#------------------------------------------------------------------------------------
# Section 2: Data Gathering Functions
#------------------------------------------------------------------------------------

Function Ensure-BlueScreenView {
    param (
        [string]$ToolsPath
    )
    $exePath = Join-Path -Path $ToolsPath -ChildPath "BlueScreenView.exe"
    $zipPath = Join-Path -Path $ToolsPath -ChildPath "bluescreenview.zip"

    if (Test-Path -Path $exePath -PathType Leaf) {
        $Global:DiagMsg += "[INFO] BlueScreenView.exe found at '$exePath'."
        return $exePath
    }

    $Global:DiagMsg += "[INFO] BlueScreenView.exe not found. Attempting to download..."
    try {
        if (-not (Test-Path -Path $ToolsPath)) {
            New-Item -Path $ToolsPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        $Global:DiagMsg += "[INFO] Downloading from '$DownloadURL'..."
        (New-Object System.Net.WebClient).DownloadFile($DownloadURL, $zipPath)
        $Global:DiagMsg += "[INFO] Extracting archive to '$ToolsPath'..."
        Expand-Archive -LiteralPath $zipPath -DestinationPath $ToolsPath -Force -ErrorAction Stop
        if (Test-Path -Path $exePath -PathType Leaf) {
            $Global:DiagMsg += "[SUCCESS] BlueScreenView is now ready."
            return $exePath
        }
        else {
            throw "Extraction completed, but BlueScreenView.exe was not found in the archive."
        }
    }
    catch {
        $Global:DiagMsg += "[FATAL] Failed to download or set up BlueScreenView."
        $Global:DiagMsg += $_.Exception.Message
        # Populate alert message on fatal tool error
        $Global:AlertMsg += "FATAL: Could not download or install BlueScreenView analysis tool."
        return $null
    }
}

Function Get-CrashDumpInfo {
    param (
        [string]$BlueScreenViewExe,
        [string]$ReportPath
    )
    $Global:DiagMsg += "[INFO] Starting crash dump analysis..."
    $MinidumpPath = "$env:SystemRoot\Minidump"

    if ((Test-Path -Path $MinidumpPath) -and (Get-ChildItem -Path $MinidumpPath -Filter "*.dmp")) {
        $Global:DiagMsg += "[INFO] Minidump files found. Generating report..."
        $Arguments = "/stext `"$ReportPath`""
        Start-Process -FilePath $BlueScreenViewExe -ArgumentList $Arguments -Wait -WindowStyle Hidden
        $Global:DiagMsg += "[SUCCESS] Crash dump report saved to '$ReportPath'."
    }
    else {
        $Global:DiagMsg += "[INFO] No minidump files were found in '$MinidumpPath'."
        # Create an empty file to prevent parsing errors
        Set-Content -Path $ReportPath -Value "INFO: No crash dump (.dmp) files were found."
    }
}

Function Get-ImportantSystemEvents {
    param (
        [int]$Days
    )
    $Global:DiagMsg += "[INFO] Searching for Critical and Error events from the last $Days days..."
    
    $eventFilter = @{
        LogName   = @('System', 'Application')
        Level     = @(1, 2) # 1=Critical, 2=Error
        StartTime = (Get-Date).AddDays(-$Days)
    }
    
    $events = Get-WinEvent -FilterHashtable $eventFilter -ErrorAction SilentlyContinue

    if ($null -ne $events) {
        $Global:DiagMsg += "[SUCCESS] Found $($events.Count) important event(s)."
        return $events
    }
    else {
        $Global:DiagMsg += "[INFO] No Critical or Error events found in the last $Days days."
        return $null
    }
}

#------------------------------------------------------------------------------------
# Section 3: Parsing and Analysis Functions
#------------------------------------------------------------------------------------

Function Parse-CrashDumpReport {
    param (
        [string]$ReportPath
    )
    $Global:DiagMsg += "[INFO] Parsing BlueScreenView crash report..."
    # Check if the file was created and is not empty before parsing
    if (-not (Test-Path $ReportPath) -or ((Get-Item $ReportPath).Length -eq 0)) {
        $Global:DiagMsg += "[WARN] Crash report file is missing or empty. Skipping."
        return @()
    }
    $content = Get-Content -Path $ReportPath -Raw
    $crashes = @()

    $records = $content -split '(?m)^==================================================\r?\n' | Where-Object { $_.Trim() -ne '' -and $_ -notlike 'INFO:*' }

    foreach ($record in $records) {
        $crashTime = if ($record -match 'Crash Time\s+:\s+(.+)') { [datetime]$Matches[1].Trim() } else { $null }
        $bugCheck = if ($record -match 'Bug Check String\s+:\s+(.+)') { $Matches[1].Trim() } else { 'N/A' }
        $driver = if ($record -match 'Caused By Driver\s+:\s+(.+)') { $Matches[1].Trim() } else { 'N/A' }

        if ($crashTime) {
            $crashes += [PSCustomObject]@{
                Timestamp = $crashTime
                EventType = "BSOD"
                Source    = $driver
                Details   = $bugCheck
            }
        }
    }
    return @($crashes)
}

Function Parse-SystemEventObjects {
    param (
        [array]$WinEvents
    )
    $Global:DiagMsg += "[INFO] Parsing system event objects..."
    $events = @()

    if ($null -eq $WinEvents) { return @() }
    
    foreach ($winEvent in $WinEvents) {
        $message = $winEvent.Message.Trim()
        # Truncate long messages for the grouping summary to be effective.
        if ($message.Length -gt 150) {
            $message = $message.Substring(0, 150) + "..."
        }
        
        $events += [PSCustomObject]@{
            Timestamp = $winEvent.TimeCreated
            EventType = "System $($winEvent.LevelDisplayName)"
            Source    = $winEvent.ProviderName
            Details   = "Event ID $($winEvent.Id) : $message"
        }
    }
    return @($events)
}

#------------------------------------------------------------------------------------
# Section 4: Main Execution
#------------------------------------------------------------------------------------

try {
    # --- 1. Setup Phase ---
    $ToolsDirectory = Join-Path -Path $WorkDirectory -ChildPath "Tools"
    $ReportDirectory = Join-Path -Path $WorkDirectory -ChildPath "Reports"
    New-Item -Path $ReportDirectory -ItemType Directory -Force | Out-Null
    
    $blueScreenViewPath = Ensure-BlueScreenView -ToolsPath $ToolsDirectory
    # If Ensure-BlueScreenView failed, it will have set an alert, so we can exit.
    if (-not $blueScreenViewPath) { throw "Setup failed." }

    # --- 2. Data Generation Phase ---
    $CrashReportFile = Join-Path -Path $ReportDirectory -ChildPath "Crash_Dump_Analysis.txt"
    
    Get-CrashDumpInfo -BlueScreenViewExe $blueScreenViewPath -ReportPath $CrashReportFile
    $systemEvents = Get-ImportantSystemEvents -Days $EventLogDays

    # --- 3. Analysis & Reporting Phase ---
    $allEvents = @()
    $allEvents += Parse-CrashDumpReport -ReportPath $CrashReportFile
    $allEvents += Parse-SystemEventObjects -WinEvents $systemEvents

    if ($allEvents.Count -eq 0) {
        $Global:DiagMsg += "[INFO] No crashes or important events were found to generate a report."
        $Global:varUDFString = "Status: Healthy. No BSODs/Errors found in last $EventLogDays days."
    }
    else {
        # Sort all events chronologically
        $allEvents = $allEvents | Sort-Object -Property Timestamp
        
        # Count event types for summary
        $bsodCount = ($allEvents | Where-Object { $_.EventType -eq 'BSOD' }).Count
        $criticalCount = ($allEvents | Where-Object { $_.EventType -eq 'System Critical' }).Count
        $errorCount = ($allEvents | Where-Object { $_.EventType -eq 'System Error' }).Count

        # Populate Datto RMM Alert and UDF variables
        if ($bsodCount -gt 0 -or $criticalCount -gt 0) {
            $Global:AlertMsg += "BSOD/Crash Alert: $bsodCount BSOD(s), $criticalCount Critical, $errorCount Error(s) in last $EventLogDays days."
        }
        $Global:varUDFString += "BSODs: $bsodCount, Critical: $criticalCount, Errors: $errorCount (last $EventLogDays d)"

        # --- Generate Diagnostic Report ---
        $Global:DiagMsg += "--------------------------------------------------"
        $Global:DiagMsg += "Part 1: Chronological Timeline"
        $Global:DiagMsg += "--------------------------------------------------"
        foreach ($item in $allEvents) {
            $Global:DiagMsg += "[{0}] - {1}" -f $item.Timestamp, $item.EventType
            $Global:DiagMsg += "  -> Source: {0}" -f $item.Source
            $Global:DiagMsg += "  -> Details: {0}" -f $item.Details
            $Global:DiagMsg += ""
        }

        $Global:DiagMsg += "--------------------------------------------------"
        $Global:DiagMsg += "Part 2: Summarized Report"
        $Global:DiagMsg += "--------------------------------------------------"
        $groupedEvents = $allEvents | Group-Object -Property EventType, Source, Details | Sort-Object -Property Count -Descending
        foreach ($group in $groupedEvents) {
            $sampleEvent = $group.Group[0]
            $Global:DiagMsg += "Event: {0} (Occurred {1} times)" -f $sampleEvent.EventType, $group.Count
            $Global:DiagMsg += "  -> Source: {0}" -f $sampleEvent.Source
            $Global:DiagMsg += "  -> Details: {0}" -f $sampleEvent.Details
            $Global:DiagMsg += "  -> Timestamps: $(($group.Group.Timestamp | ForEach-Object { $_.ToString('yyyy-MM-dd HH:mm') }) -join ', ')"
            $Global:DiagMsg += ""
        }
    }
}
catch {
    # This will catch fatal script errors (like permissions, failed downloads etc.)
    $Global:DiagMsg += "[FATAL SCRIPT ERROR] An unexpected error occurred: $($_.Exception.Message)"
    if (!$Global:AlertMsg) {
        $Global:AlertMsg += "BSOD Analyzer script failed to run. Check diagnostic logs."
    }
}
finally {
    # --- 4. Cleanup ---
    if (Test-Path $ReportDirectory) {
        $Global:DiagMsg += "[INFO] Cleaning up report files from '$ReportDirectory'."
        Remove-Item -Path $ReportDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}


######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString
        # Limit UDF Entry to 255 Characters
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($Global:varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($Global:varUDFString) -Force
    }
}
### Exit script with proper Datto alerting, diagnostic and API Results.
#######################################################################
if ($Global:AlertMsg) {
    # If your AlertMsg has value, this is how it will get reported.
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-DRMMAlert $Global:AlertMsg
    write-DRMMDiag $Global:DiagMsg

    # Exit 1 means DISPLAY ALERT
    Exit 1
}
else {
    # If the AlertMsg variable is blank (nothing was added), the script will report healthy status with whatever was defined above.
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"

    ##### You may alter the NO ALERT Exit Message #####
    write-DRMMAlert "$Global:AlertHealthy"
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}