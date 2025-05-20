<#
.SYNOPSIS
    Gathers All Event Logs from Windows 7/2008R2 and newer operating systems. Export **all** Windows Event Logs to per-log CSV files

.DESCRIPTION
    • Works on PowerShell 5.1
    • Caches SID-to-account translations (biggest time-saver).  
    • Shows Write-Progress so you can watch it crawl.  
    • Still supports -excludeEvtxFiles and -IncludeAllEvtxFiles switches.  
    • Writes one UTF-8 CSV per log:  <LogTag>-<LogName>.csv
#>

[CmdletBinding()]
param(
    [string]  $output = "C:\Logs\" + "LogExport_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"), # default to current time
    [string[]]$excludeEvtxFiles = @(), # nothing excluded unless you pass names
    [string]  $logTag = $env:COMPUTERNAME,
    [switch]  $IncludeAllEvtxFiles
)

# ---------------------------------------------------------------------------
# CONFIG – put the Event IDs you never want in the CSV right here.
# Example: CPU microcode spam (4), useless Kerb stuff (16), etc. Check the description for details
[int[]]$SkipEventIds = @(4, 6, 13, 42, 98, 142, 7036, 10010, 10016, 1014, 10, 1033, 102, 103, 400, 403, 4703) # add/remove IDs
# ---------------------------------------------------------------------------

#--- admin check (skip if you know you’re SYSTEM) -----------------------------
function Test-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if (-not (Test-Admin)) { Write-Error "Run as admin needed."; exit 1 }

#--- prep --------------------------------------------------------------------
$null = New-Item -Path $output -ItemType Directory -Force
$UtcFmt = 'yyyy-MM-dd HH:mm:ss'
$SidCache = @{}

function Resolve-SidCached {
    param([string]$Sid)
    if (-not $Sid) { return $null }
    if ($SidCache.ContainsKey($Sid)) { return $SidCache[$Sid] }

    try {
        $name = ([System.Security.Principal.SecurityIdentifier]$Sid
        ).Translate([System.Security.Principal.NTAccount]).Value 
    }
    catch { $name = $Sid }   # unresolved ⇒ keep SID

    $SidCache[$Sid] = $name
    return $name
}

#--- decide which logs to touch ----------------------------------------------
$logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }
if (-not $IncludeAllEvtxFiles) {
    $logs = $logs | Where-Object { $excludeEvtxFiles -notcontains $_.LogName }
}

$total = $logs.Count
if ($total -eq 0) { Write-Warning "No logs selected. Exiting."; return }

# Build the XPath once (or $null if nothing to skip)
$SkipXPath = $null
if ($SkipEventIds.Count) {
    $clauses = ( $SkipEventIds | ForEach-Object { "(EventID!=$_)" } ) -join ' and '
    $SkipXPath = "*[System[$clauses]]"
}

Write-Host "`nExporting $total logs to CSV → $output`n"

# --- main loop (sequential, with progress bar) ------------------------------
$index = 0
foreach ($log in $logs) {

    $index++
    Write-Progress -Activity "Exporting logs" `
        -Status  ("{0}/{1}  {2}" -f $index, $total, $log.LogName) `
        -PercentComplete ([int](100 * $index / $total))

    $nameSafe = $log.LogName -replace '/', '%4'
    $csvPath = Join-Path $output "$logTag-$nameSafe.csv"

    try {
        # apply XPath filter only if we have one
        if ($SkipXPath) {
            $events = Get-WinEvent -LogName $log.LogName -FilterXPath $SkipXPath -ErrorAction Stop
        }
        else {
            $events = Get-WinEvent -LogName $log.LogName -ErrorAction Stop
        }

        $objects = $events | ForEach-Object {
            [pscustomobject]@{
                containerLog     = "$logTag-$nameSafe"
                id               = $_.Id
                levelDisplayName = $_.LevelDisplayName
                MachineName      = $_.MachineName
                LogName          = $log.LogName
                ProcessId        = $_.ProcessId
                UserId           = Resolve-SidCached $_.UserId
                ProviderName     = $_.ProviderName
                TimeCreated      = ($_.TimeCreated.ToUniversalTime()).ToString($UtcFmt)
                Message          = ($_.Message -replace "\r?\n", ' | ')
            }
        }

        $objects | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Force
    }
    catch {
        Write-Warning "   !  $($log.LogName) blew up: $($_.Exception.Message)"
    }
}

Write-Progress -Activity "Exporting logs" -Completed -Status "Done"
Write-Host "`nFinished. SID cache size: $($SidCache.Count)`n"

Write-Host
Write-Host
write-host "Completed the log gathering. Launching the Parser"
.\Parse-LogsToTimeLine.ps1