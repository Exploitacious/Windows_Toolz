<#
  EventLog-Baseline-AuditAndFix.ps1
  - Audits Windows event-logging against Umbrella IT / Microsoft / CIS baseline
  - Optional auto-remediation with 10-second cancel window
  - Tested on Windows 10/11 & Server 2016-2022  (PowerShell 5.1)
#>

# ------------------------ CONFIG SECTION ----------------------------------
$ShowDebug = $false          # flip to $true for verbose troubleshooting
$ApplyTimeout = 10           # seconds to wait before auto-apply
$Report = @()      # always start with an empty array

# -------------- baseline definitions (edit as needed) ---------------------
$BaselineLogs = @(
    @{Name = 'Security'; MinMB = 128; Retain = $false },
    @{Name = 'System'; MinMB = 64; Retain = $false },
    @{Name = 'Application'; MinMB = 64; Retain = $false }
)

$RequiredOpChannels = @(
    'Microsoft-Windows-PowerShell/Operational',
    'Microsoft-Windows-WMI-Activity/Operational'
)

$AuditCategories = @(
    @{Name = 'Account Logon'; S = $true; F = $true },
    @{Name = 'Account Management'; S = $true; F = $true },
    @{Name = 'Logon/Logoff'; S = $true; F = $true },
    @{Name = 'Privilege Use'; S = $true; F = $true },
    @{Name = 'Policy Change'; S = $true; F = $true },
    @{Name = 'System'; S = $true; F = $true },
    @{Name = 'Object Access'; S = $false; F = $true },
    @{Name = 'DS Access'; S = $true; F = $false }
)

$PSExpect = @{
    ScriptBlockLogging = @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'; Value = 'EnableScriptBlockLogging'; Expect = 1 }
    ModuleLogging      = @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'; Value = 'EnableModuleLogging'; Expect = 1 }
    ModuleNames        = @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'; Value = 'ModuleNames'; Expect = '*' }
    Transcription      = @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription'; Value = 'EnableTranscripting'; Expect = 1 }
    TranscriptDir      = @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription'; Value = 'OutputDirectory'; Expect = 'C:\Logs\PowerShell' }
}
# -------------------------------------------------------------------------

# ----------------------- RUNTIME SET-UP ----------------------------------
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($ShowDebug) { 'Continue' } else { 'SilentlyContinue' }

# helper converts bool → enable|disable
function Get-Flag([bool]$b) { if ($b) { 'enable' } else { 'disable' } }

# helper prints + returns PSCustomObject with Fix property
function Write-Result {
    param(
        [string]$Item,
        [string]$Status, # PASS | WARN | FAIL
        [string]$Note = '',
        [string]$Fix = ''   # may be empty
    )

    Write-Host ""            # <-- adds the blank line before each item

    switch ($Status) {
        'PASS' {
            Write-Host ("PASS  {0,-55} -  {1}" -f $Item, $Note) -ForegroundColor Green
        }
        'WARN' {
            Write-Host ("WARN  {0,-55} -  {1}" -f $Item, $Note) -ForegroundColor Yellow
        }
        'FAIL' {
            Write-Host ("FAIL  {0,-55} -  {1}" -f $Item, $Note) -ForegroundColor Red
            if ($Fix) {
                Write-Host ("      Fix: {0}" -f $Fix) -ForegroundColor Yellow
            }
        }
    }

    # return an object that always carries Note & Fix
    return [pscustomobject]@{
        Item   = $Item
        Status = $Status
        Note   = $Note
        Fix    = $Fix
    }
}

############################################################################
# 1. Classic log size / retention  (Security section already OK)
############################################################################
foreach ($b in $BaselineLogs) {
    try {
        $cfg = [System.Diagnostics.Eventing.Reader.EventLogConfiguration]::new($b.Name)
        $size = [math]::Round($cfg.MaximumSizeInBytes / 1MB)
        $mode = $cfg.LogMode
        $note = "Size=${size} MB  Mode=$mode"

        $okSz = ($size -ge $b.MinMB)
        $okRet = (($mode -eq 'Retain') -eq $b.Retain)

        if ($okSz -and $okRet) {
            $Report += Write-Result "Log $($b.Name)" 'PASS' $note
        }
        else {
            $fix = "wevtutil sl $($b.Name) /ms:$($b.MinMB*1MB) /rt:$($b.Retain)"
            $Report += Write-Result "Log $($b.Name)" 'FAIL' $note $fix
        }
    }
    catch {
        $Report += Write-Result "Log $($b.Name)" 'FAIL' 'log not found'
    }
}


############################################################################
# 2. Operational channels
############################################################################
$sysmon = 'Microsoft-Windows-Sysmon/Operational'
if (Get-WinEvent -ListLog $sysmon -ErrorAction SilentlyContinue) {
    $RequiredOpChannels += $sysmon
}

foreach ($ch in $RequiredOpChannels) {
    $info = Get-WinEvent -ListLog $ch -ErrorAction SilentlyContinue
    $note = if ($info) { "Enabled=$($info.IsEnabled)" } else { 'not present' }

    if ($info -and $info.IsEnabled) {
        $Report += Write-Result "Channel $ch" 'PASS' $note
    }
    else {
        $fix = "wevtutil sl `"$ch`" /e:true"
        $Report += Write-Result "Channel $ch" 'FAIL' $note $fix
    }
}

############################################################################
# 3. Analytic | Debug noise check        
############################################################################

$noisy = @()    # collect only logs we can read

foreach ($logName in wevtutil el) {
    try {
        $info = Get-WinEvent -ListLog $logName -ErrorAction Stop
        if ($info.LogName -match 'Analytic|Debug' -and $info.IsEnabled) {
            $noisy += $info
        }
    }
    catch {
        # ignore logs that cannot be queried (e.g., WordChannel, low resources)
        if ($ShowDebug) { Write-Verbose "Skipped $logName - $($_.Exception.Message)" }
    }
}

if ($noisy) {
    $note = ($noisy.LogName) -join '; '
    $Report += Write-Result 'Analytic/Debug disabled' 'FAIL' $note 'wevtutil sl <log> /e:false'
}
else {
    $Report += Write-Result 'Analytic/Debug disabled' 'PASS' 'none'
}

############################################################################
# 4. Advanced audit categories
############################################################################
foreach ($c in $AuditCategories) {

    $raw = auditpol /get /r /category:"$($c.Name)" 2>$null |
    Select-String $c.Name |
    ForEach-Object { ($_ -replace '\s{2,}', ',').Split(',') }

    $succFlag = if ($c.S) { 'enable' } else { 'disable' }
    $failFlag = if ($c.F) { 'enable' } else { 'disable' }
    $fixCmd = "auditpol /set /category:`"$($c.Name)`" /success:$succFlag /failure:$failFlag"

    if (!$raw -or $raw.Length -lt 3) {
        $Report += Write-Result "Audit $($c.Name)" 'WARN' 'no data from auditpol' $fixCmd
        continue
    }

    $succ = $raw[1]; $fail = $raw[2]
    $note = "current S:$succ  F:$fail"
    $succOK = (($succ -eq 'Success') -eq $c.S)
    $failOK = (($fail -eq 'Failure') -eq $c.F)

    if ($succOK -and $failOK) {
        $Report += Write-Result "Audit $($c.Name)" 'PASS' $note
    }
    else {
        $Report += Write-Result "Audit $($c.Name)" 'FAIL' $note $fixCmd
    }
}

############################################################################
# 5. PowerShell logging settings
############################################################################
foreach ($key in $PSExpect.GetEnumerator()) {
    $p = $key.Value
    $actual = (Get-ItemProperty -Path $p.Path -ErrorAction SilentlyContinue).$($p.Value)
    $note = "current=$actual"

    $ok = ($null -ne $actual) -and ( ($actual -join ',') -eq $p.Expect.ToString() )
    if ($ok) {
        $Report += Write-Result "PS $($key.Key)" 'PASS' $note
    }
    else {
        $regType = if ($key.Key -eq 'ModuleNames') { 'REG_MULTI_SZ' } else { 'REG_DWORD' }
        $fix = "reg add `"$($p.Path -replace 'HKLM:\\','HKLM\\')`" /v $($p.Value) /t $regType /d $($p.Expect) /f"
        $Report += Write-Result "PS $($key.Key)" 'FAIL' $note $fix
    }
}


# ===================== Summary & Optional Auto-Fix ======================

# 1)  Save the audit report
$csvPath = 'C:\Logs\EventLog_Audit.csv'
$Report | Export-Csv -NoTypeInformation -Path $csvPath
Write-Host "`nAudit results written to $csvPath"

# 2)  Collect the remediation commands
$PendingFixes = $Report |
Where-Object { $_.Status -eq 'FAIL' -and ($_.Fix -is [string]) -and $_.Fix } |
Select-Object -ExpandProperty Fix

if (-not $PendingFixes) {
    Write-Host "`nNothing to fix - baseline already met." -ForegroundColor Green
    return
}
Write-Host
Write-Host
Write-Host "`nTo remediate all FAILs, the following commands will be executed:" -ForegroundColor Cyan
$PendingFixes | ForEach-Object { Write-Host "  $_" }
Write-Host

# 3)  Simple, host-independent countdown
Write-Host "`nPress Ctrl-C to cancel auto-fixing" -ForegroundColor Yellow
try {
    foreach ($sec in 15..1) {
        Write-Host ("  {0}s remaining" -f $sec) -NoNewline
        Start-Sleep 1
        Write-Host "`r" -NoNewline      # redraw same line
    }
    Write-Host                          # drop to next line
}
catch [System.Management.Automation.StopUpstreamCommandsException] {
    Write-Warning "User cancelled - no changes applied."
    return
}

# 4)  Run the fixes
Write-Host
Write-Host "Applying fixes..." -ForegroundColor Yellow
foreach ($cmd in $PendingFixes) {
    Write-Host "  $cmd"
    try {
        Invoke-Expression $cmd
        Write-Host "    -> OK" -ForegroundColor Green
    }
    catch {
        Write-Host "    -> FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host "`nDone. Re-run the script to confirm all checks pass."