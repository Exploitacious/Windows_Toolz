#
## Template for Scripting Component Monitors for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Analyze Winget-AutoUpdate (WAU) Status (Last 3 Months)" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation
$Date = get-date -Format "MM/dd/yyy hh:mm tt"

# What to Write if Alert is Healthy
$Global:AlertHealthy = "WAU: All applications are reporting as up-to-date." # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
# There is another palce to put NO ALERT Healthy messages down below, to try and capture more script info.

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = 'C:\Program Files\Winget-AutoUpdate\logs\updates.log' # Datto User Input variable "usrString" for custom log file path

<#
This is a Datto RMM Monitoring Script, used to deliver a result such as "Healthy" or "Not Healthy", in order to trigger the creation of tickets, etc.

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
function write-DRMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:AlertMsg = @() # Combined Alert message. If left blank, will not trigger Alert status. Use " $Global:AlertMsg += " to append messages to be alerted on in Datto.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########

function Get-WauUpdateData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = 'C:\Program Files\Winget-AutoUpdate\logs\updates.log'
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        $Global:DiagMsg += "ERROR: WAU Log file not found at '$Path'."
        $Global:AlertMsg += "WAU Log file not found at '$Path'. Cannot check update status."
        return $null
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
    return $updateRecords
}

function Analyze-WauUpdates {
    # --- Configuration ---
    $logPath = if (-not [string]::IsNullOrEmpty($env:usrString)) { $env:usrString } else { 'C:\Program Files\Winget-AutoUpdate\logs\updates.log' }
    $Global:DiagMsg += "Using WAU log path: $logPath"

    # --- Step 1: Gather WAU Update History ---
    $Global:DiagMsg += "Gathering update history from WAU logs..."
    $wauHistory = Get-WauUpdateData -Path $logPath
    
    if ($Global:AlertMsg) { return }

    # --- NEW: Filter history to only include the last 3 months ---
    $threeMonthsAgo = (Get-Date).AddMonths(-3)
    $wauHistory = $wauHistory | Where-Object { $_.DateTime -ge $threeMonthsAgo }
    $Global:DiagMsg += "Analyzing update records since $($threeMonthsAgo.ToString('MM/dd/yyyy'))..."

    if (-not $wauHistory) {
        $Global:DiagMsg += "No update history found in the WAU log file within the last 3 months."
        return
    }

    # --- Step 2: Get Currently Installed Apps from Winget ---
    $Global:DiagMsg += "Getting currently installed applications from Winget (this may take a moment)..."
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
        $Global:DiagMsg += "ERROR: Failed to execute 'winget list'. Ensure Winget is installed and working correctly. Error: $($_.Exception.Message)"
        $Global:AlertMsg += "Failed to execute 'winget list'. Cannot check application versions."
        return
    }
    
    # --- Step 3: Analyze and Compare ---
    $Global:DiagMsg += "Analyzing update history against installed applications..."
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
                if ($latestAttempt.Status -eq 'Success' -and [version]$currentVersion -ge [version]$latestAttempt.ToVersion) {
                    $overallStatus = 'Up-to-date (via WAU)'
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
        
        # --- NEW: Consolidated Status for Summary ---
        $consolidatedStatus = switch ($overallStatus) {
            { $_ -like 'Up-to-date*' } { 'Successful' }
            'Update Pending/Failed' { 'Failed' }
            default { 'Unknown' } # Covers 'Uninstalled or Renamed' and 'Unknown (Version Incompatible)'
        }

        $analysisResults += [PSCustomObject]@{
            ApplicationName    = $baseAppName
            LastAttempt        = $latestAttempt.DateTime
            LastResult         = $latestAttempt.Status
            AttemptedUpdate    = "$($latestAttempt.FromVersion) -> $($latestAttempt.ToVersion)"
            InstalledVersion   = $currentVersion
            OverallStatus      = $overallStatus
            ConsolidatedStatus = $consolidatedStatus
        }
    }

    # --- Step 4: Populate Datto RMM Variables ---
    if ($analysisResults.Count -gt 0) {
        $reportTable = $analysisResults | Sort-Object ApplicationName | Select-Object ApplicationName, LastAttempt, LastResult, AttemptedUpdate, InstalledVersion, OverallStatus | Format-Table -AutoSize | Out-String
        $Global:DiagMsg += "`n--- WAU Application Status Report (Last 3 Months) ---"
        $Global:DiagMsg += $reportTable

        # --- UPDATED: Group by consolidated status ---
        $summary = $analysisResults | Group-Object -Property ConsolidatedStatus
        $Global:DiagMsg += "`n--- Summary ---"
        $udfSummary = @()
        foreach ($group in $summary) {
            $Global:DiagMsg += ("{0,-15} : {1}" -f $group.Name, $group.Count)
            $udfSummary += "$($group.Name): $($group.Count)"
        }
        $Global:varUDFString += ($udfSummary -join ' | ')

        $failingApps = $analysisResults | Where-Object { $_.OverallStatus -eq 'Update Pending/Failed' }
        if ($failingApps) {
            $Global:AlertMsg += "WAU Failure: $($failingApps.Count) application(s) require attention: $($failingApps.ApplicationName -join ', ')"
            $failingAppsList = $failingApps | Select-Object ApplicationName, InstalledVersion, AttemptedUpdate | Format-Table -AutoSize | Out-String
            $Global:DiagMsg += "`n--- ⚠️ WARNING: ACTION REQUIRED ⚠️ ---"
            $Global:DiagMsg += "The following applications have failed to update and are still on an old version:"
            $Global:DiagMsg += $failingAppsList
        }
    }
    else {
        $Global:DiagMsg += "No applications with WAU history were found to analyze in the last 3 months."
    }
}

# Execute the main function
Analyze-WauUpdates


######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {     
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Exit script with proper Datto alerting, diagnostic and API Results.
#######################################################################
if ($Global:AlertMsg) {
    # If your AlertMsg has value, this is how it will get reported.
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-DRMMAlert $Global:AlertMsg
    write-DRMMDiag $Global:DiagMsg

    # Exit 1 means DISPLAY ALERT
    Exit 1
}
else {
    # If the AlertMsg variable is blank (nothing was added), the script will report healthy status with whatever was defined above.
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"

    ##### You may alter the NO ALERT Exit Message #####
    # Use the UDF string for a dynamic healthy message if it exists
    if ($Global:varUDFString) {
        write-DRMMAlert "WAU Healthy | $Global:varUDFString"
    }
    else {
        write-DRMMAlert $Global:AlertHealthy
    }
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}