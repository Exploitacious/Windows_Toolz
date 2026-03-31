# 
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Microsoft SARA Tool" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:usrScenario = "TeamsAddinScenario" # Which SARA Scenario to run.

<#
This Script is a Remediation compoenent, based on the official Microsoft SARA non-interactive launcher.
It downloads (with caching), unpacks, and runs the selected scenario with the correct parameters.
It then collects all generated logs from the default SARA locations and outputs them to the diagnostic log.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date
##################################
##################################
######## Start of Script #########

# Record the script start time to accurately gather logs created by this session
$scriptStartTime = Get-Date

# --- Script Configuration ---
$stagingPath = "C:\Temp\SARA"
$zipFile = Join-Path -Path $stagingPath -ChildPath "SaRA.zip"
$downloadUrl = "https://aka.ms/SaRA_EnterpriseVersionFiles"
# Set how long to keep the downloaded zip file before refreshing (default is 24 hours)
$cacheDuration = New-TimeSpan -Hours 24
# --- End Configuration ---

# Check if a scenario was provided from Datto RMM
if ([string]::IsNullOrWhiteSpace($env:usrScenario)) {
    $Global:DiagMsg += "FATAL: The 'usrScenario' variable was not provided. Please select a scenario."
    write-DRMMDiag $Global:DiagMsg
    Exit 1
}
$Global:DiagMsg += "SARA Scenario selected: $env:usrScenario"

# Build the argument string based on the selected scenario
$argumentString = ""
switch ($env:usrScenario) {
    "ExpertExperienceAdminTask" { $argumentString = "-S ExpertExperienceAdminTask -Script -AcceptEula" }
    "OfficeScrubScenario" { $argumentString = "-S OfficeScrubScenario -Script -AcceptEula" }
    "TeamsAddinScenario" { $argumentString = "-S TeamsAddinScenario -Script -AcceptEula -CloseOutlook" }
    "OfficeSharedComputerScenario" { $argumentString = "-S OfficeSharedComputerScenario -Script -AcceptEula -CloseOffice" }
    "OutlookCalendarCheckTask" { $argumentString = "-S OutlookCalendarCheckTask -Script -AcceptEula" }
    "OfficeActivationScenario" { $argumentString = "-S OfficeActivationScenario -Script -AcceptEula -CloseOffice" }
    "ResetOfficeActivation" { $argumentString = "-S ResetOfficeActivation -Script -AcceptEula -CloseOffice" }
    default {
        $Global:DiagMsg += "FATAL: Invalid scenario name provided: '$($env:usrScenario)'."
        write-DRMMDiag $Global:DiagMsg
        Exit 1
    }
}
$Global:DiagMsg += "Constructed arguments: $argumentString"

# Create staging directory if it doesn't exist
try {
    if (-not (Test-Path -Path $stagingPath)) {
        New-Item -Path $stagingPath -ItemType Directory -Force | Out-Null
        $Global:DiagMsg += "Created staging directory: $stagingPath"
    }
}
catch {
    $Global:DiagMsg += "FATAL: Could not create staging directory. Error: $_"
    write-DRMMDiag $Global:DiagMsg
    Exit 1
}

# *** CORRECTED LOGIC ***: Check for cached file and decide if download is needed
$downloadNeeded = $true
if (Test-Path $zipFile) {
    $fileAge = (Get-Date) - (Get-Item $zipFile).LastWriteTime
    if ($fileAge -lt $cacheDuration) {
        $Global:DiagMsg += "Found recent SARA.zip file (less than $($cacheDuration.TotalHours) hours old). Skipping download."
        $downloadNeeded = $false
    }
    else {
        $Global:DiagMsg += "Local SARA.zip is older than $($cacheDuration.TotalHours) hours. It will be replaced."
    }
}
else {
    $Global:DiagMsg += "Local SARA.zip not found."
}

if ($downloadNeeded) {
    $Global:DiagMsg += "Downloading fresh copy from $downloadUrl..."
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
        $Global:DiagMsg += "Successfully downloaded SARA."
    }
    catch {
        $Global:DiagMsg += "FATAL: Failed to download SARA. Error: $_"
        write-DRMMDiag $Global:DiagMsg
        Exit 1
    }
}

# Unpack SARA
try {
    # Clear any old files before unpacking
    Get-ChildItem -Path $stagingPath -Exclude "SaRA.zip" | Remove-Item -Force -Recurse
    $Global:DiagMsg += "Unpacking files from $zipFile..."
    Expand-Archive -Path $zipFile -DestinationPath $stagingPath -Force
    $Global:DiagMsg += "Successfully unpacked SARA files."
}
catch {
    $Global:DiagMsg += "FATAL: Failed to unpack archive. Error: $_"
    write-DRMMDiag $Global:DiagMsg
    Exit 1
}

# Dynamically find the SaRAcmd.exe path
$Global:DiagMsg += "Searching for SaRAcmd.exe in $stagingPath..."
$saraExecutable = Get-ChildItem -Path $stagingPath -Filter "SaRAcmd.exe" -Recurse | Select-Object -First 1

if ($saraExecutable) {
    $saraExecutablePath = $saraExecutable.FullName
    $Global:DiagMsg += "Found SARA executable at: $saraExecutablePath"
    $Global:DiagMsg += "Executing SARA. This may take several minutes..."
    $Global:DiagMsg += "Running Command: `"$saraExecutablePath`" $argumentString"

    try {
        $process = Start-Process -FilePath $saraExecutablePath -ArgumentList $argumentString -Wait -PassThru -NoNewWindow
        $Global:DiagMsg += "SARA process finished with Exit Code: $($process.ExitCode)."
    }
    catch {
        $Global:DiagMsg += "FATAL: An error occurred while running SARA. Error: $_"
    }
}
else {
    $Global:DiagMsg += "FATAL: SaRAcmd.exe was NOT FOUND within the unpacked files at '$stagingPath'."
}

# Gather all logs created during this session from SARA's default locations
$Global:DiagMsg += "================ GATHERING SARA LOGS ================"
$logLocations = @(
    "$env:LOCALAPPDATA\SaraLogs\Log\",
    "$env:LOCALAPPDATA\SaraLogs\UploadLogs\",
    "$env:LOCALAPPDATA\SaraResults\"
)

$logsFound = $false
foreach ($location in $logLocations) {
    if (Test-Path $location) {
        $logFiles = Get-ChildItem -Path $location -Recurse | Where-Object { $_.LastWriteTime -gt $scriptStartTime }
        if ($logFiles) {
            $logsFound = $true
            foreach ($log in $logFiles) {
                $Global:DiagMsg += "--- Reading Log File: $($log.FullName) ---"
                try {
                    $logContent = Get-Content -Path $log.FullName -Raw -ErrorAction Stop
                    $Global:DiagMsg += $logContent
                    $Global:DiagMsg += "--- End of File: $($log.Name) ---"
                }
                catch {
                    $Global:DiagMsg += "Could not read content of log file. Error: $_"
                }
            }
        }
    }
}

if (-not $logsFound) {
    $Global:DiagMsg += "No new log files were found in standard SARA directories."
}
$Global:DiagMsg += "================ LOG GATHERING COMPLETE =============="

# Cleanup the staging directory, keeping the cached zip file
$Global:DiagMsg += "Cleaning up staging directory, keeping cached zip file."
Get-ChildItem -Path $stagingPath -Exclude "SaRA.zip" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue


######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) { 
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Info to be sent to into JSON POST to API Endpoint (Optional)
$APIinfoHashTable = @{
    'CS_PROFILE_UID' = $env:CS_PROFILE_UID
    'Script_Diag'    = $Global:DiagMsg
    'Script_UID'     = $ScriptUID
}
#######################################################################
### Exit script with proper Datto diagnostic and API Results.
# Add Script Result and POST to API if an Endpoint is Provided
if ($null -ne $env:APIEndpoint) {
    $Global:DiagMsg += " - Sending Results to API"
    Invoke-WebRequest -Uri $env:APIEndpoint -Method POST -Body ($APIinfoHashTable | ConvertTo-Json) -ContentType "application/json"
}
# Exit with writing diagnostic back to the ticket / remediation component log
write-DRMMDiag $Global:DiagMsg
Exit 0