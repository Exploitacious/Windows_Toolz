# FILE: Get-WauUpdateData.ps1

function Get-WauUpdateData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = 'C:\Program Files\Winget-AutoUpdate\logs\updates.log'
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        Write-Error "Log file not found at '$Path'."
        return
    }

    $updateRecords = @()
    $currentDate = $null
    # A hashtable to temporarily store version info for an app being updated
    $pendingUpdates = @{}

    $logContent = Get-Content -Path $Path
    foreach ($line in $logContent) {
        # 1. Find the date for the current session and clear old pending data
        if ($line -match '#\s+(\d{1,2}/\d{1,2}/\d{4})\s+-') {
            $currentDate = $matches[1]
            $pendingUpdates.Clear()
        }

        # 2. Find the announcement of an available update to get version info
        if ($line -match '-> Available update : (.+?)\. Current version : (.+?)\. Available version : (.*?)\.?$') {
            $appNameAndVersion = $matches[1].Trim()
            $currentVersion = $matches[2].Trim()
            $availableVersion = $matches[3].Trim()
            # Store the version info, keyed by the full app name string
            $pendingUpdates[$appNameAndVersion] = @{ Current = $currentVersion; Target = $availableVersion }
        }

        # 3. Look for a success message
        if ($line -match '^(\d{2}:\d{2}:\d{2})\s+-\s+(.+?)\s+updated to\s+(.+?)\s+!') {
            $timestamp = $matches[1]
            $appName = $matches[2].Trim()
            $newVersion = $matches[3].Trim()
            
            $pendingKey = $pendingUpdates.Keys | Where-Object { $_ -like "$appName*" } | Select-Object -First 1
            if ($pendingKey) {
                $versions = $pendingUpdates[$pendingKey]
                $updateRecords += [PSCustomObject]@{
                    DateTime    = [datetime]::Parse("$currentDate $timestamp")
                    Application = $appName
                    Status      = 'Success'
                    FromVersion = $versions.Current
                    ToVersion   = $newVersion
                }
                $pendingUpdates.Remove($pendingKey)
            }
        }

        # 4. Look for a failure message
        if ($line -match '^(\d{2}:\d{2}:\d{2})\s+-\s+(.+?)\s+update failed\.') {
            $timestamp = $matches[1]
            $failedAppName = $matches[2].Trim()

            if ($pendingUpdates.ContainsKey($failedAppName)) {
                $versions = $pendingUpdates[$failedAppName]
                $updateRecords += [PSCustomObject]@{
                    DateTime    = [datetime]::Parse("$currentDate $timestamp")
                    Application = $failedAppName
                    Status      = 'Failed'
                    FromVersion = $versions.Current
                    ToVersion   = $versions.Target
                }
                $pendingUpdates.Remove($failedAppName)
            }
        }
    }

    # Output all collected records
    return $updateRecords
}

Get-WauUpdateData @PSBoundParameters