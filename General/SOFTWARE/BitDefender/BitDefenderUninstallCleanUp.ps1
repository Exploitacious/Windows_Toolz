#
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Force Uninstall Bitdefender BEST" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:usrUninstallPassword = "" # Enter the uninstall password required by your GravityZone policy. Create a variable in Datto RMM named 'usrUninstallPassword'.
#$env:usrForceReboot = "false"   # Set to "true" to automatically restart. Create a variable in Datto RMM named 'usrForceReboot'.

<#
This is a "Scorched Earth" remediation component for Bitdefender, designed for the most stubborn cases.
It downloads and runs the official uninstaller, then aggressively removes remnant files, folders, services,
and Windows Installer registration keys to allow for a clean re-installation.
USE WITH CAUTION.
#>
# DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $messages) { $Message + ' `' }
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


### SCRIPT CONFIGURATION AND PRE-FLIGHT CHECKS ###
$Global:DiagMsg += "Step 1: Initializing script..."
$workingDir = "C:\Temp\BitdefenderCleanup"
$toolUrl = "https://download.bitdefender.com/SMB/Hydra/release/bst_win/uninstallTool/BEST_uninstallTool.exe"
$toolPath = Join-Path -Path $workingDir -ChildPath "BEST_uninstallTool.exe"
if (-NOT (Test-Path -Path $workingDir)) { New-Item -Path $workingDir -ItemType Directory -Force | Out-Null }

### DOWNLOAD AND PREPARE UNINSTALLER ###
$Global:DiagMsg += "Step 2: Downloading the Bitdefender Uninstall Tool..."
try {
    Invoke-WebRequest -Uri $toolUrl -OutFile $toolPath -ErrorAction Stop
    $Global:DiagMsg += " - SUCCESS: Uninstall tool downloaded to '$toolPath'."
}
catch {
    $Global:DiagMsg += " - FATAL: Failed to download the uninstall tool. Error: $_"
    write-DRMMDiag $Global:DiagMsg
    Exit 1
}

### EXECUTE THE UNINSTALL TOOL ###
$Global:DiagMsg += "Step 3: Executing the uninstaller..."
$arguments = @("/bruteForce", "/destructive", "/noWait", "/log")
if (-not [string]::IsNullOrEmpty($env:usrUninstallPassword)) {
    $Global:DiagMsg += " - Using the provided uninstall password."
    $arguments += "/password=`"$($env:usrUninstallPassword)`""
}
$Global:DiagMsg += " - Command: `"$toolPath`" $($arguments -join ' ')"
try {
    $process = Start-Process -FilePath $toolPath -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
    $Global:DiagMsg += " - Uninstall tool process completed with Exit Code: $($process.ExitCode)."
}
catch {
    $Global:DiagMsg += " - FATAL: An error occurred while running the uninstall tool. Error: $_"
    write-DRMMDiag $Global:DiagMsg
    Exit 1
}

$Global:DiagMsg += "Step 4: Deep-cleaning system for Bitdefender remnants..."

# List of search terms to identify Bitdefender-specific remnants.
$SearchTerms = @('Bitdefender', 'eps.rmm', 'bdservicehost', 'gzflt', 'bdselfpr')

# Known File System FOLDERS to purge.
$FileSystemPaths = @(
    "$env:ProgramFiles\Bitdefender",
    "$env:ProgramFiles(x86)\Bitdefender",
    "$env:ProgramData\Bitdefender",
    "$env:ProgramData\BitdefenderDattoRMM",
    "$env:ProgramData\bduninstalltool"
)
try {
    $UserProfiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue
    foreach ($Profile in $UserProfiles) {
        $FileSystemPaths += Join-Path -Path $Profile.LocalPath -ChildPath 'AppData\Local\Bitdefender'
    }
}
catch {
    $Global:DiagMsg += " - WARNING: Could not query user profiles to expand search paths. $_"
}


# Specific FILENAMES to hunt for across the entire C: drive.
$OrphanedFiles = @( 'eps.rmm.exe', 'latest.dat', 'epsrmmversion.txt', 'detect.txt', 'installResult.txt', 'isUpToDate.txt', 'links.txt', 'installer.tar', 'bestInstallerFile.dmg')

# Known Registry hives to search.
$RegistryHives = @( 'HKLM:\SOFTWARE', 'HKLM:\SOFTWARE\WOW6432Node', 'HKCU:\SOFTWARE' )

# --- GLOBAL FINDINGS HASH TABLE ---
$Global:Findings = @{ Services = @(); Drivers = @(); FileSystem = @(); Files = @(); Registry = @(); Tasks = @() }

# --- DETECTION PHASE ---
$Global:DiagMsg += " - Searching for specific Services and Drivers..."
try {
    $AllServices = Get-CimInstance -ClassName Win32_Service | Select-Object -Property Name, DisplayName, ServiceType
    foreach ($Term in $SearchTerms) {
        $Global:Findings.Services += $AllServices | Where-Object { ($_.DisplayName -like "*$Term*" -or $_.Name -like "*$Term*") -and $_.ServiceType -notlike '*Driver*' }
        $Global:Findings.Drivers += $AllServices | Where-Object { ($_.DisplayName -like "*$Term*" -or $_.Name -like "*$Term*") -and ($_.ServiceType -like '*KernelDriver*' -or $_.ServiceType -like '*FileSystemDriver*') }
    }
    $Global:Findings.Services = $Global:Findings.Services | Sort-Object -Property Name -Unique
    $Global:Findings.Drivers = $Global:Findings.Drivers | Sort-Object -Property Name -Unique
}
catch { $Global:DiagMsg += " - WARNING: An error occurred while searching for services: $_" }

$Global:DiagMsg += " - Searching for Scheduled Tasks..."
try {
    foreach ($Term in $SearchTerms) {
        $Global:Findings.Tasks += Get-ScheduledTask | Where-Object { $_.TaskName -like "*$Term*" -or $_.TaskPath -like "*$Term*" }
    }
    $Global:Findings.Tasks = $Global:Findings.Tasks | Sort-Object -Property TaskName -Unique
}
catch { $Global:DiagMsg += " - WARNING: An error occurred while searching scheduled tasks: $_" }

$Global:DiagMsg += " - Searching for known File System folders..."
foreach ($Path in $FileSystemPaths) {
    if (Test-Path -Path $Path) { $Global:Findings.FileSystem += $Path }
}

$Global:DiagMsg += " - Performing deep scan for orphaned installer files..."
foreach ($File in $OrphanedFiles) {
    try {
        $foundFiles = Get-ChildItem -Path 'C:\' -Recurse -Filter $File -ErrorAction SilentlyContinue
        if ($foundFiles) { $Global:Findings.Files += $foundFiles.FullName }
    }
    catch { $Global:DiagMsg += " - WARNING: Could not perform deep file search for '$File'. Error: $_" }
}
$Global:Findings.Files = $Global:Findings.Files | Sort-Object -Unique

$Global:DiagMsg += " - Searching the Registry..."
foreach ($Hive in $RegistryHives) {
    foreach ($Term in $SearchTerms) {
        try {
            $FoundKeys = Get-ChildItem -Path $Hive -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Term*" }
            if ($FoundKeys) { $Global:Findings.Registry += $FoundKeys.PSPath }
        }
        catch { $Global:DiagMsg += " - WARNING: Could not access or search hive '$Hive'. Error: $_" }
    }
}
$Global:Findings.Registry = $Global:Findings.Registry | Sort-Object -Unique

# --- REPORTING & DELETION PHASE ---
$TotalFindings = ($Global:Findings.Values | ForEach-Object { $_.Count }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum

if ($TotalFindings -eq 0) {
    $Global:DiagMsg += " - SUCCESS: No targeted Bitdefender or RMM component remnants were found."
}
else {
    $Global:DiagMsg += " - Found $TotalFindings items to be removed."
    $Global:DiagMsg += "-------------------- DELETION REPORT --------------------"
    
    # --- REPORT FINDINGS TO LOG ---
    if ($Global:Findings.Services.Count -gt 0) { $Global:DiagMsg += "--- SERVICES ---"; $Global:Findings.Services | Select-Object Name, DisplayName | Out-String | ForEach-Object { $Global:DiagMsg += $_ } }
    if ($Global:Findings.Drivers.Count -gt 0) { $Global:DiagMsg += "--- DRIVERS ---"; $Global:Findings.Drivers | Select-Object Name, DisplayName | Out-String | ForEach-Object { $Global:DiagMsg += $_ } }
    if ($Global:Findings.Tasks.Count -gt 0) { $Global:DiagMsg += "--- SCHEDULED TASKS ---"; $Global:Findings.Tasks | Select-Object TaskName, TaskPath | Out-String | ForEach-Object { $Global:DiagMsg += $_ } }
    if ($Global:Findings.FileSystem.Count -gt 0) { $Global:DiagMsg += "--- FILE SYSTEM FOLDERS ---"; $Global:Findings.FileSystem | ForEach-Object { $Global:DiagMsg += "  $_" } }
    if ($Global:Findings.Files.Count -gt 0) { $Global:DiagMsg += "--- ORPHANED FILES ---"; $Global:Findings.Files | ForEach-Object { $Global:DiagMsg += "  $_" } }
    if ($Global:Findings.Registry.Count -gt 0) { $Global:DiagMsg += "--- REGISTRY KEYS ---"; $Global:Findings.Registry | ForEach-Object { $Global:DiagMsg += "  $_" } }

    # --- BEGIN DELETION ---
    foreach ($category in $Global:Findings.Keys) {
        if ($Global:Findings[$category].Count -gt 0) {
            $Global:DiagMsg += " " # Add spacer
            $Global:DiagMsg += "[-] Removing $category..."
            
            switch ($category) {
                "Services" {
                    foreach ($item in $Global:Findings.Services) {
                        $logMessage = "  -> Deleting service: $($item.Name)"
                        try { Stop-Service -Name $item.Name -Force -ErrorAction SilentlyContinue; sc.exe delete "$($item.Name)" | Out-Null; $logMessage += " - SUCCESS" }
                        catch { $logMessage += " - FAILED: $($_.Exception.Message)" }
                        $Global:DiagMsg += $logMessage
                    }
                }
                "Drivers" {
                    foreach ($item in $Global:Findings.Drivers) {
                        $logMessage = "  -> Deleting driver: $($item.Name)"
                        try { sc.exe delete "$($item.Name)" | Out-Null; $logMessage += " - SUCCESS" }
                        catch { $logMessage += " - FAILED: $($_.Exception.Message)" }
                        $Global:DiagMsg += $logMessage
                    }
                }
                "Tasks" {
                    foreach ($item in $Global:Findings.Tasks) {
                        $logMessage = "  -> Deleting task: $($item.TaskName)"
                        try { Unregister-ScheduledTask -TaskName $item.TaskName -Confirm:$false -ErrorAction Stop; $logMessage += " - SUCCESS" }
                        catch { $logMessage += " - FAILED: $($_.Exception.Message)" }
                        $Global:DiagMsg += $logMessage
                    }
                }
                "FileSystem" {
                    foreach ($item in $Global:Findings.FileSystem) {
                        $logMessage = "  -> Deleting folder: $item"
                        try { Remove-Item -Path $item -Recurse -Force -ErrorAction Stop; $logMessage += " - SUCCESS" }
                        catch { $logMessage += " - FAILED: $($_.Exception.Message)" }
                        $Global:DiagMsg += $logMessage
                    }
                }
                "Files" {
                    foreach ($item in $Global:Findings.Files) {
                        $logMessage = "  -> Deleting file: $item"
                        try { Remove-Item -Path $item -Force -ErrorAction Stop; $logMessage += " - SUCCESS" }
                        catch { $logMessage += " - FAILED: $($_.Exception.Message)" }
                        $Global:DiagMsg += $logMessage
                    }
                }
                "Registry" {
                    $SortedKeys = $Global:Findings.Registry | Sort-Object -Property Length -Descending
                    foreach ($item in $SortedKeys) {
                        $logMessage = "  -> Deleting key: $item"
                        try { Remove-Item -Path $item -Recurse -Force -ErrorAction Stop; $logMessage += " - SUCCESS" }
                        catch { $logMessage += " - FAILED: $($_.Exception.Message)" }
                        $Global:DiagMsg += $logMessage
                    }
                }
            }
        }
    }
    $Global:DiagMsg += "-------------------- DELETION COMPLETE --------------------"
}

### FINAL REBOOT ###
$Global:DiagMsg += "Step 5: Cleanup process finished. A system reboot is essential to finalize the removal process."

$rebootCheck = if ($null -ne $env:usrForceReboot) { ($env:usrForceReboot).Trim().ToLower() } else { "false" }
if ($rebootCheck -eq 'true') {
    $Global:DiagMsg += " - Configuration set to force reboot."
    shutdown.exe /r /t 30 /f /c "Bitdefender removal complete. Restarting the computer in 30 seconds..."
}
else {
    $Global:DiagMsg += " - Force reboot variable is not set to 'true'. A manual reboot is required."
}


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