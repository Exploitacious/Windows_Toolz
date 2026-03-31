<#
.SYNOPSIS
    Scans Windows Event Logs for audio-related errors and events.

.DESCRIPTION
    This script queries the System, Application, and Microsoft Windows Audio operational logs
    for the past 24 hours to find entries containing specific audio-related keywords.
    This can help diagnose issues like device disconnections or driver failures.

.NOTES
    Run this script with administrative privileges for full access to event logs.
#>

try {
    # Define the time frame for the log search (last 24 hours)
    $startTime = (Get-Date).AddDays(-1)

    # List of keywords to search for in the log messages
    $keywords = @(
        'audio',
        'sound',
        'speaker',
        'headphone',
        'jack',
        'disconnect',
        'endpoint',
        'Realtek',    # Common audio driver manufacturer
        'Intel SST',  # Intel Smart Sound Technology
        'HD Audio'    # High Definition Audio
    )

    # Create a regex pattern from the keywords for efficient searching (e.g., 'audio|sound|speaker...')
    $pattern = $keywords -join '|'

    # Log names to search through. Includes standard logs and specific audio logs.
    $logNames = @(
        'System',
        'Application',
        'Microsoft-Windows-Audio/Operational'
    )

    Write-Host "Searching for audio-related events in the last 24 hours..." -ForegroundColor Green

    # Loop through each specified log name
    foreach ($log in $logNames) {
        # Define a filter for Get-WinEvent to improve performance
        $filter = @{
            LogName   = $log
            StartTime = $startTime
        }

        Write-Host "--- Checking Log: $log ---" -ForegroundColor Cyan

        # Get events from the specified log using the filter
        $events = Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue

        if ($null -ne $events) {
            # Filter the events where the message matches any of our keywords
            $filteredEvents = $events | Where-Object { $_.Message -match $pattern }

            if ($null -ne $filteredEvents) {
                # Format and display the results found in this log
                $filteredEvents | Format-Table TimeCreated, LogName, LevelDisplayName, Message -Wrap
            }
            else {
                Write-Host "No audio-related events found in this log."
            }
        }
        else {
            Write-Host "Could not retrieve events from log '$log'. It may be empty or you may lack permissions." -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "An unexpected error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "Script finished." -ForegroundColor Green