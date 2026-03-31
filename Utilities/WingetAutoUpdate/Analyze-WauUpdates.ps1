<#
.SYNOPSIS
    Compares Winget-AutoUpdate history with currently installed apps to analyze update statuses.

.DESCRIPTION
    This script provides a comprehensive analysis of application update health. It uses the
    'Get-WauUpdateData.ps1' script to get a history of all WAU update attempts, and then
    compares that data against a live list of installed applications from 'winget list'.

    The report shows the last attempt made by WAU for each application, provides an
    overall status, and concludes with a summary and a warning for apps that require
    manual intervention.

.NOTES
    Requires the 'Get-WauUpdateData.ps1' script to be in the same directory.

.EXAMPLE
    PS C:\> .\Analyze-WauUpdates.ps1

    Runs the full analysis and displays a detailed report, a final summary count,
    and a warning list for any applications that are still out of date.
#>
function Analyze-WauUpdates {
    [CmdletBinding()]
    param()

    # --- Configuration ---
    $wauDataScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-WauUpdateData.ps1"

    if (-not (Test-Path $wauDataScriptPath)) {
        Write-Error "Prerequisite script not found at '$wauDataScriptPath'. Please ensure both scripts are in the same directory."
        return
    }

    # --- Step 1: Gather WAU Update History ---
    Write-Host "Gathering update history from WAU logs..." -ForegroundColor Cyan
    try {
        $wauHistory = & $wauDataScriptPath -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to execute '$wauDataScriptPath'. Error: $($_.Exception.Message)"
        return
    }

    if (-not $wauHistory) {
        Write-Host "No update history found in the WAU log file." -ForegroundColor Green
        return
    }

    # --- Step 2: Get Currently Installed Apps from Winget ---
    Write-Host "Getting currently installed applications from Winget (this may take a moment)..." -ForegroundColor Cyan
    $installedApps = @{}
    try {
        $wingetOutput = winget list --accept-source-agreements
        foreach ($line in $wingetOutput) {
            if ($line -match '^(.+?)\s{2,}([\w\.\-]+)\s+([^\s]+)') {
                $name = $matches[1].Trim()
                $id = $matches[2].Trim()
                $version = $matches[3].Trim()
                if (-not $installedApps.ContainsKey($id)) {
                    $installedApps[$id] = @{ Name = $name; Version = $version }
                }
            }
        }
    }
    catch {
        Write-Error "Failed to execute 'winget list'. Ensure Winget is installed and working correctly."
        return
    }
    
    # --- Step 3: Analyze and Compare ---
    Write-Host "Analyzing update history against installed applications..." -ForegroundColor Cyan
    $analysisResults = @()

    $groupedHistory = $wauHistory | Group-Object { ($_.Application -split '\d', 2)[0].Trim() }

    foreach ($appGroup in $groupedHistory) {
        $latestAttempt = $appGroup.Group | Sort-Object DateTime -Descending | Select-Object -First 1
        $baseAppName = $appGroup.Name

        $matchedAppId = $null
        foreach ($id in $installedApps.Keys) {
            $installedBaseName = ($installedApps[$id].Name -split '\d', 2)[0].Trim()
            if ($baseAppName -eq $installedBaseName) {
                $matchedAppId = $id
                break
            }
        }
        
        $currentVersion = if ($matchedAppId) { $installedApps[$matchedAppId].Version } else { 'N/A' }
        $overallStatus = ''

        if (-not $matchedAppId) {
            $overallStatus = 'Uninstalled or Renamed'
        }
        else {
            try {
                if ($latestAttempt.Status -eq 'Success' -and [version]$currentVersion -eq [version]$latestAttempt.ToVersion) {
                    $overallStatus = 'Up-to-date (via WAU)'
                }
                elseif ($latestAttempt.Status -eq 'Success' -and [version]$currentVersion -gt [version]$latestAttempt.ToVersion) {
                    $overallStatus = 'Up-to-date (Superseded)'
                }
                elseif ($latestAttempt.Status -eq 'Failed' -and [version]$currentVersion -ge [version]$latestAttempt.ToVersion) {
                    $overallStatus = 'Up-to-date (External Update)'
                }
                else {
                    $overallStatus = 'Update Pending/Failed'
                }
            }
            catch {
                $overallStatus = 'Unknown (Version Incompatible)'
            }
        }

        $analysisResults += [PSCustomObject]@{
            ApplicationName  = $baseAppName
            LastAttempt      = $latestAttempt.DateTime
            LastResult       = $latestAttempt.Status
            AttemptedUpdate  = "$($latestAttempt.FromVersion) -> $($latestAttempt.ToVersion)"
            InstalledVersion = $currentVersion
            OverallStatus    = $overallStatus
        }
    }

    # --- Step 4: Display Report ---
    Write-Host "`n--- WAU Application Status Report ---" -ForegroundColor Green
    $analysisResults | Sort-Object ApplicationName | Format-Table -AutoSize

    # --- Step 5: Generate Summary and Warnings ---
    $summary = $analysisResults | Group-Object -Property OverallStatus

    Write-Host "`n--- Summary ---" -ForegroundColor Green
    foreach ($group in $summary) {
        Write-Host ("{0,-30} : {1}" -f $group.Name, $group.Count) -ForegroundColor Yellow
    }

    $failingApps = $analysisResults | Where-Object { $_.OverallStatus -eq 'Update Pending/Failed' }
    if ($failingApps) {
        Write-Host "`n--- ⚠️ WARNING: ACTION REQUIRED ⚠️ ---" -ForegroundColor Red
        Write-Host "The following applications have failed to update and are still on an old version:" -ForegroundColor Yellow
        $failingApps | Select-Object ApplicationName, InstalledVersion, AttemptedUpdate | Format-Table -AutoSize
    }
}

# Execute the function
Analyze-WauUpdates