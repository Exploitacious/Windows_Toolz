<#
.SYNOPSIS
    A fully automated script that downloads tools, analyzes Windows crash data, and gathers
    important system events to generate a comprehensive two-part report.

.DESCRIPTION
    This script is a comprehensive, all-in-one tool for diagnosing a Blue Screen of Death (BSOD)
    or other critical system failures. It automates the entire process from tool acquisition
    to final analysis and reporting.

    The script performs four key actions:
    1. TOOLING: It automatically downloads and extracts NirSoft's BlueScreenView utility if it's not
       already present.
    2. DATA GATHERING: It runs BlueScreenView to create a report from all .dmp files. It also queries
       the Windows Event Logs for 'Critical' and 'Error' events within a specified number of days.
    3. ANALYSIS: It parses the raw data from both reports and intelligently combines them into a
       single collection of event objects.
    4. REPORTING: It generates a two-part report directly in the console. First, it displays a full,
       chronological timeline of all events. Second, it displays a summary that groups identical
       events to highlight recurring issues.

.AUTHOR
    Alex Ivantsov

.DATE
    August 17, 2025
#>

#------------------------------------------------------------------------------------
# Section 1: User-Configurable Variables
#------------------------------------------------------------------------------------

# The base directory where a 'Tools' folder and a 'Reports' folder will be created.
$WorkDirectory = "C:\Temp\BSODVIEW"

# The number of days back to search for Critical and Error events in the logs.
$EventLogDays = 40

# The direct download URL for the BlueScreenView zip file.
$DownloadURL = "https://www.nirsoft.net/utils/bluescreenview.zip"

#------------------------------------------------------------------------------------
# Section 2: Data Gathering Functions
#------------------------------------------------------------------------------------

Function Ensure-BlueScreenView {
    <#
    .SYNOPSIS
        Checks for BlueScreenView.exe, and downloads/extracts it if not found.
    #>
    param (
        [string]$ToolsPath
    )
    $exePath = Join-Path -Path $ToolsPath -ChildPath "BlueScreenView.exe"
    $zipPath = Join-Path -Path $ToolsPath -ChildPath "bluescreenview.zip"

    if (Test-Path -Path $exePath -PathType Leaf) {
        Write-Host "[INFO] BlueScreenView.exe found at '$exePath'."
        return $exePath
    }

    Write-Host "[INFO] BlueScreenView.exe not found. Attempting to download..."
    try {
        if (-not (Test-Path -Path $ToolsPath)) {
            New-Item -Path $ToolsPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        Write-Host "[INFO] Downloading from '$DownloadURL'..."
        (New-Object System.Net.WebClient).DownloadFile($DownloadURL, $zipPath)
        Write-Host "[INFO] Extracting archive to '$ToolsPath'..."
        Expand-Archive -LiteralPath $zipPath -DestinationPath $ToolsPath -Force -ErrorAction Stop
        if (Test-Path -Path $exePath -PathType Leaf) {
            Write-Host "[SUCCESS] BlueScreenView is now ready."
            return $exePath
        }
        else {
            throw "Extraction completed, but BlueScreenView.exe was not found in the archive."
        }
    }
    catch {
        Write-Error "[FATAL] Failed to download or set up BlueScreenView."
        Write-Error $_.Exception.Message
        return $null
    }
}

Function Get-CrashDumpInfo {
    <#
    .SYNOPSIS
        Uses BlueScreenView.exe to analyze and report on Windows minidump files.
    #>
    param (
        [string]$BlueScreenViewExe,
        [string]$ReportPath
    )
    Write-Host "[INFO] Starting crash dump analysis..."
    $MinidumpPath = "$env:SystemRoot\Minidump"

    if ((Test-Path -Path $MinidumpPath) -and (Get-ChildItem -Path $MinidumpPath -Filter "*.dmp")) {
        Write-Host "[INFO] Minidump files found. Generating report..."
        $Arguments = "/stext `"$ReportPath`""
        Start-Process -FilePath $BlueScreenViewExe -ArgumentList $Arguments -Wait -WindowStyle Hidden
        Write-Host "[SUCCESS] Crash dump report saved to '$ReportPath'."
    }
    else {
        Write-Host "[INFO] No minidump files were found in '$MinidumpPath'."
        "INFO: No crash dump (.dmp) files were found in '$MinidumpPath'." | Out-File -FilePath $ReportPath -Encoding utf8
    }
}

Function Get-ImportantSystemEvents {
    <#
    .SYNOPSIS
        Queries logs for Critical and Error events within a specific timeframe.
    #>
    param (
        [string]$ReportPath,
        [int]$Days
    )
    Write-Host "[INFO] Searching for Critical and Error events from the last $Days days..."
    
    $eventFilter = @{
        LogName   = @('System', 'Application')
        Level     = @(1, 2) # 1=Critical, 2=Error
        StartTime = (Get-Date).AddDays(-$Days)
    }
    
    $events = Get-WinEvent -FilterHashtable $eventFilter -ErrorAction SilentlyContinue

    if ($null -ne $events) {
        Write-Host "[SUCCESS] Found $($events.Count) important event(s). Saving to report..."
        $events | Select-Object -Property TimeCreated, ProviderName, Id, Message, LevelDisplayName | Format-List | Out-File -FilePath $ReportPath -Encoding utf8
    }
    else {
        Write-Host "[INFO] No Critical or Error events found in the last $Days days."
        "INFO: No Critical or Error events found in the last $Days days." | Out-File -FilePath $ReportPath -Encoding utf8
    }
}

#------------------------------------------------------------------------------------
# Section 3: Parsing and Analysis Functions
#------------------------------------------------------------------------------------

Function Parse-CrashDumpReport {
    <#
    .SYNOPSIS
        Parses the text report generated by BlueScreenView.
    #>
    param (
        [string]$ReportPath
    )
    Write-Host "[INFO] Parsing BlueScreenView crash report..."
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

Function Parse-SystemEventReport {
    <#
    .SYNOPSIS
        Parses the text report of system event logs.
    #>
    param (
        [string]$ReportPath
    )
    Write-Host "[INFO] Parsing system event report..."
    $content = Get-Content -Path $ReportPath -Raw
    $events = @()
    
    $records = $content -split '(\r?\n){2,}' | Where-Object { $_.Trim() -ne '' -and $_ -notlike 'INFO:*' }

    foreach ($record in $records) {
        $timeCreated = if ($record -match '(?m)^TimeCreated\s+:\s+(.+)') { [datetime]$Matches[1].Trim() } else { $null }
        $provider = if ($record -match '(?m)^ProviderName\s+:\s+(.+)') { $Matches[1].Trim() } else { 'N/A' }
        $id = if ($record -match '(?m)^Id\s+:\s+(.+)') { $Matches[1].Trim() } else { 'N/A' }
        $level = if ($record -match '(?m)^LevelDisplayName\s+:\s+(.+)') { $Matches[1].Trim() } else { 'Event' }
        
        $message = 'No message available.'
        # Truncate long messages for the grouping summary to be effective.
        $messageMatch = [regex]::Match($record, '(?ms)^Message\s+:\s+(.*)')
        if ($messageMatch.Success) {
            $message = $messageMatch.Groups[1].Value.Trim()
            if ($message.Length -gt 150) {
                $message = $message.Substring(0, 150) + "..."
            }
        }

        if ($timeCreated) {
            $events += [PSCustomObject]@{
                Timestamp = $timeCreated
                EventType = "System $level"
                Source    = $provider
                Details   = "Event ID $id : $message"
            }
        }
    }
    return @($events)
}

Function Generate-CombinedReport {
    <#
    .SYNOPSIS
        Creates a two-part report: a raw timeline and a grouped summary.
    #>
    param (
        [string]$CrashReportFile,
        [string]$SystemEventFile
    )

    # Parse data once and store it.
    $allEvents = @()
    $allEvents += Parse-CrashDumpReport -ReportPath $CrashReportFile
    $allEvents += Parse-SystemEventReport -ReportPath $SystemEventFile

    if ($allEvents.Count -eq 0) {
        Write-Host "[INFO] No crashes or important events were found to generate a report."
        return
    }

    # --- PART 1: CHRONOLOGICAL TIMELINE ---
    Write-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "          Part 1: Chronological Timeline          " -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan

    foreach ($item in ($allEvents | Sort-Object -Property Timestamp)) {
        if ($item.EventType -eq 'BSOD') {
            Write-Host ("[{0}] - {1}" -f $item.Timestamp, $item.EventType) -ForegroundColor Red
            Write-Host ("  -> Source: {0}" -f $item.Source) -ForegroundColor Red
            Write-Host ("  -> Details: {0}" -f $item.Details) -ForegroundColor Red
        }
        elseif ($item.EventType -eq 'System Critical') {
            Write-Host ("[{0}] - {1}" -f $item.Timestamp, $item.EventType) -ForegroundColor Magenta
            Write-Host ("  -> Source: {0}" -f $item.Source)
            Write-Host ("  -> Details: {0}" -f $item.Details)
        }
        else {
            # Errors and other types
            Write-Host ("[{0}] - {1}" -f $item.Timestamp, $item.EventType) -ForegroundColor DarkYellow
            Write-Host ("  -> Source: {0}" -f $item.Source)
            Write-Host ("  -> Details: {0}" -f $item.Details)
        }
        Write-Host
    }

    # --- PART 2: SUMMARIZED REPORT ---
    Write-Host
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host "            Part 2: Summarized Report             " -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Yellow

    $groupedEvents = $allEvents | Group-Object -Property EventType, Source, Details | Sort-Object -Property Count -Descending

    foreach ($group in $groupedEvents) {
        $sampleEvent = $group.Group[0]
        
        $color = "DarkYellow" # Default for Error
        if ($sampleEvent.EventType -eq 'BSOD') { $color = "Red" }
        if ($sampleEvent.EventType -eq 'System Critical') { $color = "Magenta" }

        Write-Host ("Event: {0} (Occurred {1} times)" -f $sampleEvent.EventType, $group.Count) -ForegroundColor $color
        Write-Host ("  -> Source: {0}" -f $sampleEvent.Source)
        Write-Host ("  -> Details: {0}" -f $sampleEvent.Details)
        Write-Host ("  -> Timestamps of Occurrences:")
        foreach ($item in ($group.Group | Sort-Object Timestamp)) {
            Write-Host ("     - {0}" -f $item.Timestamp)
        }
        Write-Host
    }
}

#------------------------------------------------------------------------------------
# Section 4: Main Execution
#------------------------------------------------------------------------------------

Clear-Host
Write-Host "==================================================" -ForegroundColor DarkCyan
Write-Host "     Automated Windows Crash & Log Analyzer       " -ForegroundColor DarkCyan
Write-Host "==================================================" -ForegroundColor DarkCyan
Write-Host

# --- 1. Setup Phase ---
$ToolsDirectory = Join-Path -Path $WorkDirectory -ChildPath "Tools"
$ReportBaseDirectory = Join-Path -Path $WorkDirectory -ChildPath "Reports"
$blueScreenViewPath = Ensure-BlueScreenView -ToolsPath $ToolsDirectory
if (-not $blueScreenViewPath) {
    Write-Error "[FATAL] Cannot proceed without BlueScreenView. Exiting script."
    exit 1
}

# --- 2. Data Generation Phase ---
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportOutputDirectory = Join-Path -Path $ReportBaseDirectory -ChildPath "CrashReport_$timestamp"
New-Item -Path $ReportOutputDirectory -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
$CrashReportFile = Join-Path -Path $ReportOutputDirectory -ChildPath "Crash_Dump_Analysis.txt"
$SystemEventFile = Join-Path -Path $ReportOutputDirectory -ChildPath "Important_System_Events.txt"

Get-CrashDumpInfo -BlueScreenViewExe $blueScreenViewPath -ReportPath $CrashReportFile
Get-ImportantSystemEvents -ReportPath $SystemEventFile -Days $EventLogDays

# --- 3. Analysis & Reporting Phase ---
Generate-CombinedReport -CrashReportFile $CrashReportFile -SystemEventFile $SystemEventFile

# --- 4. Final Summary ---
Write-Host
Write-Host "==================================================" -ForegroundColor Green
Write-Host "                 Analysis Complete                " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host
Write-Host "Raw report files have been saved to:"
Write-Host $ReportOutputDirectory -ForegroundColor Yellow
Write-Host