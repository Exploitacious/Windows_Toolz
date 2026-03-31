# Requires -RunAsAdministrator

# This script enables TRACE logging for the SNAP agent and DEBUG logging for the ZTAC agent.
# It will automatically request administrator privileges if not already running as an admin.

# --- Script Start ---

Write-Host "--- Enabling Verbose Logging for SNAP and ZTAC ---" -ForegroundColor Green

# --- Section 1: SNAP Agent Configuration ---

$snapLogFile = "C:\Program Files (x86)\Blackpoint\SnapAgent\log.xml"
$snapService = "Snap"
$snapInfoString = '<level value="INFO" />'
$snapTraceString = '<level value="TRACE" />'

Write-Host "`n[SNAP] Attempting to enable TRACE logging..."
try {
    # Check if the log file exists before trying to modify it
    if (Test-Path $snapLogFile) {
        # Read the file, replace the logging level, and write it back
        (Get-Content -Path $snapLogFile -Raw) -replace $snapInfoString, $snapTraceString | Set-Content -Path $snapLogFile
        Write-Host "[SNAP] Successfully set logging level to TRACE in '$snapLogFile'." -ForegroundColor Cyan

        # Restart the service to apply changes
        Write-Host "[SNAP] Restarting the '$snapService' service..."
        Restart-Service -Name $snapService -ErrorAction Stop
        Write-Host "[SNAP] Service '$snapService' restarted successfully." -ForegroundColor Cyan
    }
    else {
        Write-Warning "[SNAP] Log file not found at '$snapLogFile'. Skipping."
    }
}
catch {
    Write-Error "[SNAP] An error occurred: $_"
}


# --- Section 2: ZTAC Agent Configuration ---

$ztacConfigFile = "C:\Program Files (x86)\Blackpoint\ZTAC\config.yml"
$ztacService = "ZTAC"
$ztacInfoString = "logLevel: info"
$ztacDebugString = "logLevel: debug"

Write-Host "`n[ZTAC] Attempting to enable DEBUG logging..."
try {
    # Check if the config file exists
    if (Test-Path $ztacConfigFile) {
        # Read the file, replace the logging level, and write it back
        (Get-Content -Path $ztacConfigFile -Raw) -replace $ztacInfoString, $ztacDebugString | Set-Content -Path $ztacConfigFile
        Write-Host "[ZTAC] Successfully set logging level to DEBUG in '$ztacConfigFile'." -ForegroundColor Cyan

        # Restart the service to apply changes
        Write-Host "[ZTAC] Restarting the '$ztacService' service..."
        Restart-Service -Name $ztacService -ErrorAction Stop
        Write-Host "[ZTAC] Service '$ztacService' restarted successfully." -ForegroundColor Cyan
    }
    else {
        Write-Warning "[ZTAC] Config file not found at '$ztacConfigFile'. Skipping."
    }
}
catch {
    Write-Error "[ZTAC] An error occurred: $_"
}

Write-Host "`n--- Script finished ---" -ForegroundColor Green
Write-Host "Please allow the services to run for 10-15 minutes to gather logs before collecting them."