<#
.SYNOPSIS
    A script to automate common Windows Update and system file repair tasks.

.DESCRIPTION
    This script performs a sequence of actions to troubleshoot and repair issues with Windows Update and corrupted system files.
    1. It first checks for Administrator privileges, as they are required for all operations.
    2. It clears the local Windows Update download cache, which can resolve many update-related problems.
    3. It runs the Deployment Image Servicing and Management (DISM) tool to scan the health of the Windows component store.
    4. If DISM finds repairable corruption, it attempts to restore health and then runs the System File Checker (SFC) to repair system files.
    5. Finally, it gathers and displays the most recent logs from the DISM, SFC, and Windows Update processes for diagnostic review.

.AUTHOR
    Alex Ivantsov

.DATE
    September 27, 2025
#>

#------------------------------------------------------------------------------------
# --- User Configuration ---
# Modify the variables in this section to change the script's behavior.
#------------------------------------------------------------------------------------

# Specify a temporary directory where the generated Windows Update log will be stored.
$TempLogDirectory = "C:\Temp\SystemRepairLogs"


#------------------------------------------------------------------------------------
# --- Script Functions ---
# Do not modify the code below this line.
#------------------------------------------------------------------------------------

Function Test-IsAdmin {
    <#
    .SYNOPSIS
        Checks if the script is running with elevated (Administrator) privileges.
    #>
    Write-Host "Verifying Administrator privileges..." -ForegroundColor Cyan
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This script must be run as an Administrator. Please right-click the script and select 'Run as administrator'."
        # Pause to allow the user to read the error before the window closes.
        Start-Sleep -Seconds 10
        Exit 1
    }
    Write-Host "Administrator privileges confirmed." -ForegroundColor Green
}

Function Clear-WindowsUpdateCache {
    <#
    .SYNOPSIS
        Stops the Windows Update service, clears its download cache, and restarts the service.
    #>
    Write-Host "Phase 1: Clearing Windows Update download cache..." -ForegroundColor Cyan
    
    # Define the path to the Windows Update download folder.
    $updateCachePath = "C:\Windows\SoftwareDistribution\Download"

    if (-not(Test-Path -Path $updateCachePath)) {
        Write-Warning "Windows Update cache directory not found at '$updateCachePath'. Skipping cache clear."
        return
    }

    try {
        Write-Host "  -> Stopping Windows Update service (wuauserv)..."
        Stop-Service -Name wuauserv -Force -ErrorAction Stop

        Write-Host "  -> Deleting all items in '$updateCachePath'..."
        # The '-ErrorAction SilentlyContinue' is used because some files might be locked, which is acceptable.
        Remove-Item -Path "$updateCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "  -> Starting Windows Update service (wuauserv)..."
        Start-Service -Name wuauserv -ErrorAction Stop

        Write-Host "Windows Update cache cleared successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred while clearing the Windows Update cache: $($_.Exception.Message)"
        Write-Warning "Attempting to restart the Windows Update service to ensure system stability."
        # Ensure the service is started even if the deletion fails.
        if ((Get-Service -Name wuauserv).Status -ne 'Running') {
            Start-Service -Name wuauserv
        }
    }
}

Function Invoke-SystemFileRepair {
    <#
    .SYNOPSIS
        Runs DISM and SFC to check for and repair system file corruption.
    #>
    Write-Host "`nPhase 2: Checking system health with DISM and SFC..." -ForegroundColor Cyan

    # --- Step 1: Run DISM ScanHealth ---
    Write-Host "  -> Scanning the Windows image using 'DISM /ScanHealth'. This may take several minutes..."
    # Capture the output of the DISM command as a single string.
    $dismScanOutput = (DISM.exe /Online /Cleanup-Image /ScanHealth | Out-String)
    
    # Check if the output indicates that the component store is repairable.
    if ($dismScanOutput -match "The component store is repairable") {
        Write-Host "DISM scan found repairable issues. Proceeding with repair operations." -ForegroundColor Yellow

        # --- Step 2: Run DISM RestoreHealth ---
        Write-Host "  -> Attempting to repair the Windows image using 'DISM /RestoreHealth'. This can take a long time..."
        $dismRepairOutput = (DISM.exe /Online /Cleanup-Image /RestoreHealth | Out-String)
        
        $dismStatus = "Fail [WARNING]" # Default to fail
        if ($dismRepairOutput -match "The restore operation completed successfully") {
            Write-Host "DISM repair completed successfully." -ForegroundColor Green
            $dismStatus = "Success"
        }
        else {
            Write-Warning "DISM repair did not complete successfully. Check the DISM log for details."
        }

        # --- Step 3: Run SFC Scannow ---
        Write-Host "  -> Running System File Checker using 'sfc /scannow'..."
        $sfcOutput = (sfc.exe /scannow | Out-String)

        $sfcStatus = "Fail [WARNING]" # Default to fail
        if ($sfcOutput -match "Windows Resource Protection did not find any integrity violations") {
            Write-Host "SFC scan completed and found no integrity violations." -ForegroundColor Green
            $sfcStatus = "Success"
        }
        elseif ($sfcOutput -match "Windows Resource Protection found corrupt files and successfully repaired them") {
            Write-Host "SFC found and successfully repaired corrupt files." -ForegroundColor Green
            $sfcStatus = "Success"
        }
        else {
            Write-Warning "SFC found corrupt files but was unable to fix some of them. Check the CBS log for details."
        }

        # --- Final Repair Summary ---
        Write-Host "`n--------------------------- REPAIR SUMMARY ---------------------------" -ForegroundColor White
        Write-Host "  DISM Repair Status: $dismStatus"
        Write-Host "  SFC Repair Status:  $sfcStatus"
        if ($dismStatus -ne "Success" -or $sfcStatus -ne "Success") {
            Write-Host "One or more repair operations failed. Please review the diagnostic logs below." -ForegroundColor Yellow
        }
        else {
            Write-Host "All repair operations completed successfully." -ForegroundColor Green
        }
        Write-Host "--------------------------------------------------------------------" -ForegroundColor White
    }
    else {
        Write-Host "DISM scan did not find any repairable issues. No further repair actions are required." -ForegroundColor Green
    }
}

Function Get-LastRunLogContent {
    <#
    .SYNOPSIS
        A generic function to extract the log entries from the most recent run of a tool.
    .PARAMETER LogPath
        The full path to the log file to be parsed.
    .PARAMETER FilterPattern
        An optional string or regex pattern to filter lines before processing (e.g., "[SR]").
    #>
    param (
        [string]$LogPath,
        [string]$FilterPattern
    )

    if (-not (Test-Path -Path $LogPath)) {
        return "Log file not found at '$LogPath'."
    }

    try {
        # Read the content of the log file.
        $logContent = Get-Content -Path $LogPath -ErrorAction Stop
        
        # Apply the optional filter if provided.
        if (-not ([string]::IsNullOrEmpty($FilterPattern))) {
            $filteredLines = $logContent | Where-Object { $_ -match $FilterPattern }
        }
        else {
            $filteredLines = $logContent
        }

        # If no lines remain after filtering, return an appropriate message.
        if ($null -eq $filteredLines -or $filteredLines.Count -eq 0) {
            return "No relevant entries found in the log."
        }
        
        # Get the last line to determine the date of the last run.
        $lastLine = $filteredLines[-1]

        # Extract the date (YYYY-MM-DD format) from the beginning of the line.
        # This regex is more robust than a fixed-length substring.
        $dateMatch = [regex]::Match($lastLine, '^\d{4}-\d{2}-\d{2}')
        
        if ($dateMatch.Success) {
            $lastRunDate = $dateMatch.Value
            # Filter all lines to find those matching the date of the last run.
            $lastRunEntries = $filteredLines | Where-Object { $_.StartsWith($lastRunDate) }
            return $lastRunEntries
        }
        else {
            # If the date format isn't found, return the last 20 lines as a fallback.
            $fallbackCount = [System.Math]::Min($filteredLines.Count, 20)
            return $filteredLines | Select-Object -Last $fallbackCount
        }
    }
    catch {
        return "An error occurred while reading or parsing the log file '$LogPath': $($_.Exception.Message)"
    }
}

Function Show-DiagnosticLogs {
    <#
    .SYNOPSIS
        Generates and displays the relevant sections of key diagnostic logs.
    #>
    param(
        [string]$TempLogDir
    )

    Write-Host "`nPhase 3: Gathering and displaying diagnostic logs..." -ForegroundColor Cyan

    # Ensure the temporary directory for logs exists.
    if (-not (Test-Path -Path $TempLogDir)) {
        New-Item -Path $TempLogDir -ItemType Directory -Force | Out-Null
    }

    # --- Windows Update Log ---
    Write-Host "`n----------------------- WINDOWS UPDATE LOG -----------------------" -ForegroundColor White
    # NOTE: The Get-WindowsUpdateLog cmdlet is built into Windows 10 and newer.
    $wuLogPath = Join-Path -Path $TempLogDir -ChildPath "WindowsUpdate.log"
    Write-Host "  -> Generating Windows Update log to '$wuLogPath'..."
    try {
        Get-WindowsUpdateLog -LogPath $wuLogPath -ErrorAction Stop
        # Get the last 100 lines for context, as date parsing is unreliable for this log format.
        (Get-Content -Path $wuLogPath | Select-Object -Last 100)
    }
    catch {
        Write-Warning "Failed to generate the Windows Update log. This can happen on older OS versions or if the service is misconfigured."
        Write-Warning $_.Exception.Message
    }
    
    # --- DISM Log ---
    Write-Host "`n--------------------------- DISM LOG ---------------------------" -ForegroundColor White
    $dismLogPath = "$($env:windir)\Logs\DISM\dism.log"
    Write-Host "  -> Parsing last run from '$dismLogPath'..."
    Get-LastRunLogContent -LogPath $dismLogPath
    
    # --- SFC (CBS) Log ---
    Write-Host "`n---------------------------- SFC LOG ---------------------------" -ForegroundColor White
    $sfcLogPath = "$($env:windir)\Logs\CBS\CBS.log"
    Write-Host "  -> Parsing last run from '$sfcLogPath'..."
    # We filter for "[SR]" tags which are specific to SFC operations within the larger CBS log.
    Get-LastRunLogContent -LogPath $sfcLogPath -FilterPattern "\[SR\]"
    
    Write-Host "`n------------------------ END OF DIAGNOSTICS --------------------" -ForegroundColor White
}

#------------------------------------------------------------------------------------
# --- Main Script Body ---
#------------------------------------------------------------------------------------

# Start by confirming the script has the necessary permissions.
Test-IsAdmin

# Execute the primary script functions in logical order.
Clear-WindowsUpdateCache
Invoke-SystemFileRepair
Show-DiagnosticLogs -TempLogDir $TempLogDirectory

Write-Host "`nScript execution complete." -ForegroundColor Yellow
Write-Host "You can manually delete the log directory '$TempLogDirectory' when you are finished." -ForegroundColor Yellow

# --- End of Script ---