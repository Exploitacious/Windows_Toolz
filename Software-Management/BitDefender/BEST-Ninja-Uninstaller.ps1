# Script Title: Bitdefender and RMM Component Cleanup
# Description: Searches for and removes remnants of Bitdefender and related RMM integration components (eps.rmm, CagService).

# Script Name and Type
$ScriptName = "Bitdefender and RMM Component Cleanup"
$ScriptType = "Remediation" # Or "Monitoring", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"


## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# usrUninstallPassword (Password): An optional uninstall password for the Bitdefender tool.
# forceReboot (Checkbox): If checked, the script will force a system reboot upon completion of the cleanup.

## Test Variables
# $env:customFieldName = '' (Text): The name of the Text Custom Field to write the status to.
# $env:usrUninstallPassword = '' # (Password): An optional uninstall password for the Bitdefender tool.
# $env:forceReboot = $false # (Checkbox): If checked, the script will force a system reboot upon completion of the cleanup.


# URL for the official Bitdefender uninstaller
$BdUninstallToolUrl = "https://download.bitdefender.com/SMB/Hydra/release/bst_win/uninstallTool/BEST_uninstallTool.exe"
# Temporary directory for the uninstaller
$BdTempDir = "C:\Temp\BitdefenderCleanup"
# Default Bitdefender uninstall password.
# This will be used if the 'usrUninstallPassword' RMM variable is left blank.
$DefaultBdPassword = "breach-Thirsting-upward75!"

# List of search terms to identify Bitdefender remnants.
$SearchTerms = @(
    'Bitdefender',
    'CagService',    # DattoRMM
    'DattoRMM'       # DattoRMM
    'CentraStage'    # DattoRMM
    'eps.rmm',       # The RMM tool itself, specific to the BD component
    'bdservicehost', # Bitdefender service
    'gzflt',         # GravityZone filter driver
    'bdselfpr'       # Bitdefender self-protect driver
)

# Known File System FOLDERS to purge.
# Core RMM agent folders like C:\ProgramData\CentraStage are intentionally EXCLUDED.
$FileSystemPaths = @(
    "$env:ProgramFiles\Bitdefender",
    "$env:ProgramFiles(x86)\Bitdefender",
    "$env:ProgramData\Bitdefender",
    "$env:ProgramData\BitdefenderDattoRMM", # TARGETED: Specific to the BD integration component.
    "$env:ProgramData\bduninstalltool"
)

# Specific FILENAMES to hunt for across the entire C: drive.
$OrphanedFiles = @(
    'eps.rmm.exe',
    'latest.dat',
    'epsrmmversion.txt',
    'detect.txt',
    'installResult.txt',
    'isUpToDate.txt',
    'links.txt',
    'installer.tar',
    'bestInstallerFile.dmg'
)

# Known Registry hives to search.
$RegistryHives = @(
    'HKLM:\SOFTWARE',
    'HKLM:\SOFTWARE\WOW6432Node', # For 64-bit systems
    'HKCU:\SOFTWARE'
)

# What to Write if Alert is Healthy
$Global:AlertHealthy = "No Bitdefender/RMM remnants found. | Last Checked $Date"

# Log/Diagnostic Messaging
function write-RMMDiag ($messages) {
    Write-Host "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
$Global:DiagMsg = @()

# Alert Messaging
function write-RMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
$Global:AlertMsg = @()

# RMM Custom Field.
$Global:customFieldMessage = @()

# Script UID and intro messaging
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
$ScriptUID = GenRANDString 20
$Global:DiagMsg += "Script Type: $ScriptType"
$Global:DiagMsg += "Script Name: $ScriptName"
$Global:DiagMsg += "Script UID: $ScriptUID"
$Global:DiagMsg += "Executed On: $Date"

##################################
##################################
######## Start of Script #########

# Runs the official Bitdefender Uninstall Tool
function Invoke-BitdefenderUninstallTool {
    $Global:DiagMsg += "Attempting Bitdefender official uninstall..."
    $toolPath = Join-Path -Path $BdTempDir -ChildPath "BEST_uninstallTool.exe"
    
    $StdOutLogPath = Join-Path -Path $BdTempDir -ChildPath "BD_Uninstall.log"
    $StdErrLogPath = Join-Path -Path $BdTempDir -ChildPath "BD_Uninstall.error.log"

    if (-NOT (Test-Path -Path $BdTempDir)) {
        try {
            New-Item -Path $BdTempDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            $Global:DiagMsg += " - Created working directory: $BdTempDir"
        }
        catch {
            throw "Failed to create working directory '$BdTempDir'. Error: $_"
        }
    }

    # Download
    if (-NOT (Test-Path -Path $toolPath)) {
        $Global:DiagMsg += " - Downloading the Bitdefender Uninstall Tool from $BdUninstallToolUrl..."
        try {
            Invoke-WebRequest -Uri $BdUninstallToolUrl -OutFile $toolPath -ErrorAction Stop
            $Global:DiagMsg += " - SUCCESS: Uninstall tool downloaded to '$toolPath'."
        }
        catch {
            throw "Failed to download the uninstall tool. Error: $_"
        }
    }
    else {
        $Global:DiagMsg += " - Uninstaller executable already exists. Skipping download."
    }

    $Global:DiagMsg += " - Executing the uninstaller..."
    # Start with the base arguments
    $arguments = @("/bruteForce", "/destructive", "/noWait", "/log")
    
    # --- NEW: Password Selection Logic ---
    $Global:DiagMsg += " - Selecting uninstall password..."
    $passwordToUse = $null

    if (-not [string]::IsNullOrEmpty($env:usrUninstallPassword)) {
        # RMM variable is NOT empty, so we use it.
        $Global:DiagMsg += " - Using password provided in RMM variable 'usrUninstallPassword'."
        $passwordToUse = $env:usrUninstallPassword
    }
    else {
        # RMM variable IS empty, so we use the hard-coded default.
        $Global:DiagMsg += " - RMM variable is blank. Using hard-coded default password."
        $passwordToUse = $DefaultBdPassword
    }

    # Sanitize and build the argument
    if (-not [string]::IsNullOrEmpty($passwordToUse)) {
        # Trim whitespace and any quotes the user might have accidentally added
        $cleanPassword = $passwordToUse.Trim().Trim('"')
        
        # Add the argument, wrapping our clean password in quotes
        $arguments += "/password=`"$($cleanPassword)`""
    }
    else {
        $Global:DiagMsg += " - No password provided (RMM variable and default are both empty). Proceeding without password."
    }
    # --- End of Password Logic ---

    $Global:DiagMsg += " - BEST Uninstall Tool Command: `"$toolPath`" $($arguments -join ' ')"
    
    try {
        $process = Start-Process -FilePath $toolPath -ArgumentList $arguments -WorkingDirectory $BdTempDir -Wait -PassThru -NoNewWindow -RedirectStandardOutput $StdOutLogPath -RedirectStandardError $StdErrLogPath -ErrorAction Stop
        $Global:DiagMsg += " - Uninstall tool process completed with Exit Code: $($process.ExitCode)."
        
        # Exit Code 3010 specifically means "A reboot is required"
        if ($process.ExitCode -eq 3010) {
            $Global:DiagMsg += " - INFO: Exit Code 3010 indicates a reboot is required to complete the uninstall."
        }
        elseif ($process.ExitCode -ne 0) {
            $Global:DiagMsg += " - WARNING: Uninstall tool exited with non-zero code ($($process.ExitCode)). A reboot may be pending or an error occurred."
        }

        # --- MODIFIED: Read and report all captured logs together ---
        $Global:DiagMsg += "--- Begin Bitdefender Tool Output (stdout + stderr) ---"
        
        if (Test-Path $StdOutLogPath) {
            $StdOutContent = Get-Content $StdOutLogPath -ErrorAction SilentlyContinue
            if ($StdOutContent) {
                $Global:DiagMsg += $StdOutContent
            }
        }

        if (Test-Path $StdErrLogPath) {
            $StdErrContent = Get-Content $StdErrLogPath -ErrorAction SilentlyContinue
            if ($StdErrContent) {
                $Global:DiagMsg += $StdErrContent
            }
        }
        
        $Global:DiagMsg += "--- End Bitdefender Tool Output ---"
        # --- End of modification ---
    }
    catch {
        # Throw a fatal error if Start-Process fails
        throw "An error occurred while running the uninstall tool. Error: $_"
    }
}


try {
    # --- GLOBAL VARIABLES ---
    $Global:Findings = @{
        Services   = @()
        Drivers    = @()
        FileSystem = @()
        Files      = @()
        Registry   = @()
        Tasks      = @()
    }
    
    $removedCount = 0
    $failedCount = 0

    # Add user-specific paths for every user profile.
    $Global:DiagMsg += "Enumerating user profiles for AppData paths."
    try {
        $UserProfiles = Get-CimInstance -ClassName Win32_UserProfile
        foreach ($Profile in $UserProfiles) {
            $FileSystemPaths += Join-Path -Path $Profile.LocalPath -ChildPath 'AppData\Local\Bitdefender'
        }
    }
    catch {
        $Global:DiagMsg += "Warning: Could not enumerate all user profiles: $_"
    }

    # 0. Run the official Bitdefender uninstall tool
    $Global:DiagMsg += "----------------------------------------"
    $Global:DiagMsg += "OFFICIAL UNINSTALLER"
    # Call the function to download and run the official uninstaller
    Invoke-BitdefenderUninstallTool
    $Global:DiagMsg += "Official uninstall tool executed. Proceeding with manual remnant cleanup."
    $Global:DiagMsg += "----------------------------------------"

    # 1. Detect Services and Drivers
    $Global:DiagMsg += "[+] Searching for specific Services and Drivers..."
    try {
        $AllServices = Get-CimInstance -ClassName Win32_Service | Select-Object -Property Name, DisplayName, ServiceType
        
        foreach ($Term in $SearchTerms) {
            $Global:Findings.Services += $AllServices | Where-Object { ($_.DisplayName -like "*$Term*" -or $_.Name -like "*$Term*") -and $_.ServiceType -notlike '*Driver*' }
            $Global:Findings.Drivers += $AllServices | Where-Object { ($_.DisplayName -like "*$Term*" -or $_.Name -like "*$Term*") -and ($_.ServiceType -like '*KernelDriver*' -or $_.ServiceType -like '*FileSystemDriver*') }
        }
        $Global:Findings.Services = $Global:Findings.Services | Sort-Object -Property Name -Unique
        $Global:Findings.Drivers = $Global:Findings.Drivers | Sort-Object -Property Name -Unique
    }
    catch { $Global:DiagMsg += "Warning: An error occurred while searching for services: $_" }

    # 2. Detect Scheduled Tasks
    $Global:DiagMsg += "[+] Searching for Scheduled Tasks..."
    try {
        foreach ($Term in $SearchTerms) {
            $Global:Findings.Tasks += Get-ScheduledTask | Where-Object { $_.TaskName -like "*$Term*" -or $_.TaskPath -like "*$Term*" }
        }
        $Global:Findings.Tasks = $Global:Findings.Tasks | Sort-Object -Property TaskName -Unique
    }
    catch { $Global:DiagMsg += "Warning: An error occurred while searching scheduled tasks (may require admin): $_" }

    # 3. Detect File System FOLDER Remnants
    $Global:DiagMsg += "[+] Searching for known File System folders..."
    foreach ($Path in $FileSystemPaths) {
        if (Test-Path -Path $Path) {
            $Global:Findings.FileSystem += $Path
        }
    }


    # 4. Detect individual FILE Remnants (Targeted Scan)
    $Global:DiagMsg += "[+] Performing targeted scan for orphaned installer files..."
    
    # Define common locations where orphaned installer files are found
    $TargetedScanPaths = @(
        $BdTempDir, # The temp dir we created
        "C:\Windows\Temp",
        "C:\ProgramData" # Often used for installer logs/files
    )

    # Add user-specific temp and download folders
    $Global:DiagMsg += " - Enumerating user profiles for temp/download paths."
    try {
        Get-CimInstance -ClassName Win32_UserProfile | ForEach-Object {
            $TargetedScanPaths += Join-Path -Path $_.LocalPath -ChildPath 'AppData\Local\Temp'
            $TargetedScanPaths += Join-Path -Path $_.LocalPath -ChildPath 'Downloads'
        }
    }
    catch {
        $Global:DiagMsg += " - Warning: Could not enumerate all user profiles: $_"
    }

    $TargetedScanPaths = $TargetedScanPaths | Where-Object { Test-Path $_ } | Sort-Object -Unique

    foreach ($File in $OrphanedFiles) {
        foreach ($Path in $TargetedScanPaths) {
            try {
                # Scan non-recursively in ProgramData, but recursively in temp/download folders
                $isRecursive = $Path -notlike "C:\ProgramData"
                
                $foundFiles = Get-ChildItem -Path $Path -Recurse:$isRecursive -Filter $File -ErrorAction SilentlyContinue
                if ($foundFiles) {
                    $Global:Findings.Files += $foundFiles.FullName
                }
            }
            catch { $Global:DiagMsg += "Warning: Could not perform targeted file search in '$Path' for '$File'. Error: $_" }
        }
    }
    $Global:Findings.Files = $Global:Findings.Files | Sort-Object -Unique


    # 5. Detect Registry Remnants (Targeted Scan)
    $Global:DiagMsg += "[+] Searching the Registry (Targeted)..."
    
    # Locations for main software keys (non-recursive)
    $TargetedHives = @(
        'HKLM:\SOFTWARE',
        'HKLM:\SOFTWARE\WOW6432Node',
        'HKCU:\SOFTWARE'
    )
    
    # Locations for uninstall entries (recursive, but depth is limited)
    $UninstallHives = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    # Location for services (recursive, but depth is limited)
    $ServiceHive = 'HKLM:\SYSTEM\CurrentControlSet\Services'

    foreach ($Term in $SearchTerms) {
        # A) Find main software keys (e.g., HKLM:\SOFTWARE\Bitdefender)
        $Global:DiagMsg += " - Checking main hives for '$Term'..."
        foreach ($Hive in $TargetedHives) {
            try {
                # Note: No -Recurse. Much faster.
                $FoundKeys = Get-ChildItem -Path $Hive -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Term*" }
                if ($FoundKeys) { $Global:Findings.Registry += $FoundKeys.PSPath }
            }
            catch { $Global:DiagMsg += "Warning: Could not access or search hive '$Hive'. Error: $_" }
        }

        # B) Find Uninstall entries
        $Global:DiagMsg += " - Checking Uninstall keys for '$Term'..."
        foreach ($Hive in $UninstallHives) {
            try {
                $FoundKeys = Get-ChildItem -Path $Hive -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Term*" -or (Get-ItemProperty -Path $_.PSPath -Name 'DisplayName' -ErrorAction SilentlyContinue).DisplayName -like "*$Term*" }
                if ($FoundKeys) { $Global:Findings.Registry += $FoundKeys.PSPath }
            }
            catch { $Global:DiagMsg += "Warning: Could not access or search hive '$Hive'. Error: $_" }
        }

        # C) Find Service entries
        $Global:DiagMsg += " - Checking Services for '$Term'..."
        try {
            $FoundKeys = Get-ChildItem -Path $ServiceHive -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Term*" -or (Get-ItemProperty -Path $_.PSPath -Name 'DisplayName' -ErrorAction SilentlyContinue).DisplayName -like "*$Term*" }
            if ($FoundKeys) { $Global:Findings.Registry += $FoundKeys.PSPath }
        }
        catch { $Global:DiagMsg += "Warning: Could not access or search hive '$ServiceHive'. Error: $_" }
    }
    
    $Global:Findings.Registry = $Global:Findings.Registry | Sort-Object -Unique


    # --- REPORTING & AUTOMATIC DELETION PHASE ---
    $Global:DiagMsg += "----------------------------------------"
    $Global:DiagMsg += "DETECTION REPORT COMPLETE"
    
    $TotalFindings = ($Global:Findings.Values | ForEach-Object { $_.Count }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $Global:DiagMsg += "Total items found: $TotalFindings"

    if ($TotalFindings -eq 0) {
        $Global:DiagMsg += "SUCCESS: No targeted Bitdefender or RMM component remnants were found."
        $Global:customFieldMessage = "No remnants found. System is clean. ($Date)"
        # $Global:AlertMsg remains empty, so script exits 0
    }
    else {
        $Global:DiagMsg += "PHASE 2: AUTOMATIC DELETION"
        $Global:DiagMsg += "Proceeding with removal of $TotalFindings items..."
        
        # --- Begin Deletion ---
        foreach ($category in $Global:Findings.Keys) {
            if ($Global:Findings[$category].Count -gt 0) {
                $Global:DiagMsg += "[-] Removing $category..."
                
                switch ($category) {
                    "Services" {
                        foreach ($item in $Global:Findings.Services) {
                            try {
                                $Global:DiagMsg += "  -> Deleting service: $($item.Name)"
                                Stop-Service -Name $item.Name -Force -ErrorAction SilentlyContinue
                                sc.exe delete "$($item.Name)" | Out-Null
                                $Global:DiagMsg += "     - SUCCESS"
                                $removedCount++
                            }
                            catch { $Global:DiagMsg += "     - FAILED: $_.Exception.Message"; $failedCount++ }
                        }
                    }
                    "Drivers" {
                        foreach ($item in $Global:Findings.Drivers) {
                            try {
                                $Global:DiagMsg += "  -> Deleting driver: $($item.Name)"
                                sc.exe delete "$($item.Name)" | Out-Null
                                $Global:DiagMsg += "     - SUCCESS"
                                $removedCount++
                            }
                            catch { $Global:DiagMsg += "     - FAILED: $_.Exception.Message"; $failedCount++ }
                        }
                    }
                    "Tasks" {
                        foreach ($item in $Global:Findings.Tasks) {
                            try {
                                $Global:DiagMsg += "  -> Deleting task: $($item.TaskName)"
                                Unregister-ScheduledTask -TaskName $item.TaskName -Confirm:$false -ErrorAction Stop
                                $Global:DiagMsg += "     - SUCCESS"
                                $removedCount++
                            }
                            catch { $Global:DiagMsg += "     - FAILED: $_.Exception.Message"; $failedCount++ }
                        }
                    }
                    "FileSystem" {
                        foreach ($item in $Global:Findings.FileSystem) {
                            try {
                                $Global:DiagMsg += "  -> Deleting folder: $item"
                                Remove-Item -Path $item -Recurse -Force -ErrorAction Stop
                                $Global:DiagMsg += "     - SUCCESS"
                                $removedCount++
                            }
                            catch { $Global:DiagMsg += "     - FAILED: $_.Exception.Message"; $failedCount++ }
                        }
                    }
                    "Files" {
                        foreach ($item in $Global:Findings.Files) {
                            try {
                                $Global:DiagMsg += "  -> Deleting file: $item"
                                Remove-Item -Path $item -Force -ErrorAction Stop
                                $Global:DiagMsg += "     - SUCCESS"
                                $removedCount++
                            }
                            catch { $Global:DiagMsg += "     - FAILED: $_.Exception.Message"; $failedCount++ }
                        }
                    }
                    "Registry" {
                        $SortedKeys = $Global:Findings.Registry | Sort-Object -Property Length -Descending
                        foreach ($item in $SortedKeys) {
                            try {
                                $Global:DiagMsg += "  -> Deleting key: $item"
                                Remove-Item -Path $item -Recurse -Force -ErrorAction Stop
                                $Global:DiagMsg += "     - SUCCESS"
                                $removedCount++
                            }
                            catch { $Global:DiagMsg += "     - FAILED: $_.Exception.Message"; $failedCount++ }
                        }
                    }
                }
            }
        }
        
        # --- FINAL MESSAGE & REBOOT ---
        $Global:DiagMsg += "----------------------------------------"
        $Global:DiagMsg += "DELETION COMPLETE"
        $Global:DiagMsg += "Removed: $removedCount, Failed: $failedCount."
        
        $Global:AlertMsg = "Removed $removedCount/$TotalFindings Bitdefender remnants. Failures: $failedCount. | Last Checked $Date"
        $Global:customFieldMessage = "Cleanup complete. Removed $removedCount/$TotalFindings items. Failures: $failedCount. ($Date)"

        [bool]$forceReboot = $env:forceReboot -eq 'true'
        if ($forceReboot) {
            $Global:DiagMsg += "Force Reboot parameter is true. Initiating system reboot in 30 seconds."
            $Global:customFieldMessage += " Rebooting..."
            Restart-Computer -Force -Delay 30
        }
        else {
            $Global:DiagMsg += "A system reboot is ESSENTIAL to finalize the removal process. Auto-reboot is disabled."
            $Global:customFieldMessage += " Reboot recommended."
        }
    }

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
    $Global:customFieldMessage = "Script failed with an error. ($Date)"
}


######## End of Script ###########
##################################
##################################

# Write the collected information to the specified Custom Field before exiting.
if ($env:customFieldName) {
    $Global:DiagMsg += "Attempting to write '$($Global:customFieldMessage)' to Custom Field '$($env:customFieldName)'."
    try {
        Ninja-Property-Set -Name $env:customFieldName -Value $Global:customFieldMessage
        $Global:DiagMsg += "Successfully updated Custom Field."
    }
    catch {
        $Global:DiagMsg += "Error writing to Custom Field '$($env:customFieldName)': $($_.Exception.Message)"
    }
}
else {
    $Global:DiagMsg += "Custom Field name not provided in RMM variable 'customFieldName'. Skipping update."
}

if ($Global:AlertMsg) {
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-RMMAlert $Global:AlertMsg
    write-RMMDiag $Global:DiagMsg
    Exit 1
}
else {
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"
    write-RMMAlert $Global:AlertHealthy
    write-RMMDiag $Global:DiagMsg
    Exit 0
}