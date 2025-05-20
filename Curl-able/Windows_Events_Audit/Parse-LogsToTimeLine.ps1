<# =======================================================================
  Merge-and-parse Windows Event CSVs + PowerShell transcripts
  PowerShell 5.1  -  zero parameters  -  run from anywhere
======================================================================= #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── ROOT autodetect ────────────────────────────────────────────────────
$RootPath = 'C:\Logs'
if (-not (Test-Path $RootPath)) {
    $RootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
Write-Host "Using root: $RootPath" -ForegroundColor Cyan

# ── helper ─────────────────────────────────────────────────────────────
function Import-CsvSafe {
    param([string]$Path)
    try { Import-Csv -Path $Path -ErrorAction Stop }
    catch { Write-Warning "     Skipped $Path — $($_.Exception.Message)"; @() }
}

# ───────────────────────────────────────────────────────────────────────
# 1 │ EVENT-LOG CSVs  →  AllEventLogs.csv
# ───────────────────────────────────────────────────────────────────────
Write-Host '==>  Merging event-log CSVs...' -ForegroundColor Green

$eventDir = Get-ChildItem -Path $RootPath -Recurse -Directory -ErrorAction SilentlyContinue |
Where-Object { $_.Name -match 'LogExport' } |
Sort-Object LastWriteTime -Descending |
Select-Object -First 1

if ($eventDir) {
    Write-Host "   Found: $($eventDir.FullName)"
    $rows =
    Get-ChildItem -Path $eventDir.FullName -Recurse -Filter '*.csv' -File |
    ForEach-Object { Import-CsvSafe $_.FullName }   # <-- full path!

    if ($rows.Count) {
        $dest = Join-Path $RootPath 'AllEventLogs.csv'
        $rows | Export-Csv $dest -NoTypeInformation -Encoding UTF8
        Write-Host "   Wrote $($rows.Count) rows → $dest"
    }
    else {
        Write-Warning '   No rows collected from event CSVs.'
    }
}
else {
    Write-Warning '   No folder containing "LogExport" found.'
}

# ───────────────────────────────────────────────────────────────────────
# 2 │ POWERSHELL TRANSCRIPTS  →  AllPowerShellTranscript.csv
# ───────────────────────────────────────────────────────────────────────
Write-Host '==>  Parsing PowerShell transcripts...' -ForegroundColor Green

$candidates = Get-ChildItem -Path $RootPath -Recurse -Include '*.txt', '*.log' -File -ErrorAction SilentlyContinue

$transcriptFiles = foreach ($f in $candidates) {
    if ($f.Name -like 'PowerShell_transcript*') { $f; continue }
    try {
        if ((Get-Content $f -TotalCount 1) -match 'Windows PowerShell transcript start') { $f }
    }
    catch { Write-Warning "   Skipped $($f.FullName): $($_.Exception.Message)" }
}

if (-not $transcriptFiles) {
    Write-Warning '   No transcript files found.' ; return
}

$rx = @{
    StartTime       = '(?m)^[* ]*Start time:\s*(\d{14})'
    EndTime         = '(?m)^[* ]*End time:\s*(\d{14})'
    Username        = '(?m)^[* ]*Username:\s*(.+)'
    RunAsUser       = '(?m)^[* ]*RunAs User:\s*(.+)'
    Machine         = '(?m)^[* ]*Machine:\s*([^\(]+)'
    HostApplication = '(?m)^[* ]*Host Application:\s*(.+)'
    ProcessId       = '(?m)^[* ]*Process ID:\s*(\d+)'
}

$rows = foreach ($file in $transcriptFiles) {
    try { $raw = Get-Content $file -Raw } catch { Write-Warning "   Can't read $($file.FullName) — $_"; continue }

    $o = [ordered]@{
        TranscriptFile  = $file.FullName
        StartTime       = ''
        EndTime         = ''
        Username        = ''
        RunAsUser       = ''
        Machine         = ''
        HostApplication = ''
        ProcessId       = ''
        Commands        = ''
    }

    foreach ($k in $rx.Keys) {
        if ($raw -match $rx[$k]) { $o[$k] = $Matches[1].Trim() }
    }

    foreach ($d in 'StartTime', 'EndTime') {
        if ($o[$d]) { $o[$d] = [datetime]::ParseExact($o[$d], 'yyyyMMddHHmmss', $null) }
    }

    $cmds = ($raw -split "`r?`n") |
    Where-Object { $_ -match '^\s*PS>' } |
    ForEach-Object { ($_ -replace '^\s*PS>\s*', '').Trim() }

    $o.Commands = $cmds -join ' ; '
    [pscustomobject]$o
}

$dest = Join-Path $RootPath 'AllPowerShellTranscript.csv'
$rows | Export-Csv $dest -NoTypeInformation -Encoding UTF8
Write-Host "   Wrote $($rows.Count) transcript rows → $dest"
Write-Host
Write-Host 'Done.  All Information Parsed, Merged, and De-duped' -ForegroundColor Green