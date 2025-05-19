<#
    Gather Windows security–related logs and convert them into a single, ordered timeline (CSV).
    Two public functions:

        * Gather‑SecurityLogs   – Collects logs (default: security channels only) and saves them as .csv/.evtx.
        * Parse‑SecurityTimeline – Reads those exports (or any supplied folder) and produces a consolidated CSV sorted chronologically across hosts.


    Example usage:

    # Collect only security‑related channels and immediately build timeline
        Export-SecurityTimeline -Destination 'C:\Temp\SecurityLogs' -SecurityOnly -Verbose

    # Just gather everything (no parse)
        Export-SecurityTimeline -Destination 'C:\Temp\AllLogs' -AllLogs -GatherOnly

    # Parse an existing folder with custom window
        Parse-SecurityTimeline -LogFolder 'C:\Temp\AllLogs' -StartTime (Get-Date).AddDays(-7)

#>

function Test-IsAdmin {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}


# Gather
function Gather-SecurityLogs {
    [CmdletBinding(DefaultParameterSetName = 'Security')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [switch]$SecurityOnly,

        [Parameter(ParameterSetName = 'All')]
        [switch]$AllLogs,

        [string[]]$ExcludeLogs = @(),

        [string]$LogTag = $env:COMPUTERNAME,

        [switch]$IncludeAllEvtxFiles
    )

    if (-not (Test-IsAdmin)) {
        throw 'Administrator rights are required'
    }

    if (-not (Test-Path $OutputPath)) {
        Write-Verbose "Creating $OutputPath"
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Determine which logs to collect
    $allLogs = (Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }).LogName
    if ($SecurityOnly) {
        $targetLogs = $allLogs | Where-Object { $_ -match 'security' }
    }
    elseif ($AllLogs) {
        $targetLogs = $allLogs
    }
    else {
        # default – security related channels plus classic Security
        $targetLogs = $allLogs | Where-Object { $_ -match 'security' -or $_ -match 'audit' }
    }

    if ($ExcludeLogs) {
        $targetLogs = $targetLogs | Where-Object { $_ -notin $ExcludeLogs }
    }

    Write-Verbose ("Collecting {0} logs…" -f $targetLogs.Count)

    foreach ($log in $targetLogs) {
        try {
            $sanitized = ($log -replace '[\\/]', '_')
            $csvOut = Join-Path $OutputPath ("{0}-{1}.csv" -f $LogTag, $sanitized)
            $evtxOut = Join-Path $OutputPath ("{0}-{1}.evtx" -f $LogTag, $sanitized)

            # Export to CSV (fast) and optionally .evtx
            Get-WinEvent -LogName $log -ErrorAction Stop |
            Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, MachineName, Message |
            Export-Csv -NoTypeInformation -Path $csvOut

            if ($IncludeAllEvtxFiles) {
                wevtutil epl $log $evtxOut
                wevtutil archive-log $evtxOut /l:en-us
            }
        }
        catch {
            Write-Warning "Failed to export $log - $($_.Exception.Message)"
        }
    }

    Write-Verbose ("Log collection complete → {0}" -f (Resolve-Path $OutputPath).Path)
    return (Resolve-Path $OutputPath).Path
}


# Parallel Helper
function Invoke-Parallel {
    param(
        [Parameter(ValueFromPipeline = $true)]$InputObject,
        [scriptblock]$ScriptBlock,
        [int]$Throttle = [Environment]::ProcessorCount,
        [int]$Timeout = 0,
        $Parameter
    )
    begin {
        $iss = [management.automation.runspaces.initialsessionstate]::CreateDefault()
        $pool = [runspacefactory]::CreateRunspacePool(1, $Throttle, $iss, $host)
        $pool.Open()
        $jobs = @()
    }
    process {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        $null = $ps.AddScript($ScriptBlock).AddArgument($InputObject).AddArgument($Parameter)
        $job = [pscustomobject]@{Pipe = $ps; Handle = $ps.BeginInvoke(); Start = (Get-Date) } 
        $jobs += $job
        # reap
        foreach ($j in $jobs.Clone()) {
            if ($j.Handle.IsCompleted -or ($Timeout -gt 0 -and ((Get-Date) - $j.Start).TotalSeconds -gt $Timeout)) {
                $null = $j.Pipe.EndInvoke($j.Handle)
                $j.Pipe.Dispose()
                $jobs.Remove($j)
            }
        }
    }
    end {
        # Wait for remaining
        foreach ($j in $jobs) {
            $null = $j.Pipe.EndInvoke($j.Handle)
            $j.Pipe.Dispose()
        }
        $pool.Close()
        $pool.Dispose()
    }
}


# Parse
function Parse-SecurityTimeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({ Test-Path $_ })]
        [string]$LogFolder,

        [string]$OutputCsv = (Join-Path (Split-Path $LogFolder -Parent) 'SecurityTimeline.csv'),

        [int]$Threads = [Environment]::ProcessorCount,

        [int]$ThreadTimeout = 0,

        [datetime]$StartTime = (Get-Date -Year 1970),

        [datetime]$EndTime = (Get-Date)
    )

    Write-Verbose "Building timeline from $LogFolder"

    $allCsv = Get-ChildItem -Path $LogFolder -Filter *.csv -Recurse

    if (-not $allCsv) {
        throw 'No CSV log exports found - ensure Gather-SecurityLogs has been executed.'
    }

    $rows = [System.Collections.Concurrent.ConcurrentBag[pscustomobject]]::new()

    $sb = {
        param($file, $timeStart, $timeEnd, $bag)
        try {
            Import-Csv $file | Where-Object {
                ([datetime] $_.TimeCreated -ge $timeStart) -and ([datetime] $_.TimeCreated -le $timeEnd)
            } | ForEach-Object {
                $bag.Add($_)
            }
        }
        catch { }
    }

    $allCsv | Invoke-Parallel -ScriptBlock $sb -Throttle $Threads -Timeout $ThreadTimeout -Parameter @($StartTime, $EndTime, $rows)

    $ordered = $rows | Sort-Object { [datetime]$_.TimeCreated }

    $ordered | Export-Csv -Path $OutputCsv -NoTypeInformation

    Write-Verbose ("Timeline exported → {0}" -f $OutputCsv)
    return $OutputCsv
}


# Wrapper
function Export-SecurityTimeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Destination,

        [string]$TimelineCsv = (Join-Path $Destination 'SecurityTimeline.csv'),

        [switch]$GatherOnly,
        [switch]$ParseOnly,

        [switch]$IncludeAllEvtxFiles,

        [string[]]$ExcludeLogs = @(),

        [switch]$AllLogs,

        [switch]$SecurityOnly,

        [int]$Threads = [Environment]::ProcessorCount,

        [int]$ThreadTimeout = 0,

        [datetime]$StartTime = (Get-Date -Year 1970),

        [datetime]$EndTime = (Get-Date)
    )

    if (-not $ParseOnly) {
        Gather-SecurityLogs -OutputPath $Destination -IncludeAllEvtxFiles:$IncludeAllEvtxFiles `
            -ExcludeLogs $ExcludeLogs -AllLogs:$AllLogs -SecurityOnly:$SecurityOnly | Out-Null
    }

    if (-not $GatherOnly) {
        Parse-SecurityTimeline -LogFolder $Destination -OutputCsv $TimelineCsv `
            -Threads $Threads -ThreadTimeout $ThreadTimeout -StartTime $StartTime -EndTime $EndTime
    }
}