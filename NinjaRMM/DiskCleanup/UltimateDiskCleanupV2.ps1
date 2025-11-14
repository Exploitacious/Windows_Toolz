# Script Title: Ultimate Disk Cleanup Utility
# Description: A modular, comprehensive disk cleanup tool. Features User Temp cleanup, Orphaned Installer detection, WinSxS compression, and Stale Profile deletion.
# Created by Alex Ivantsov

# Script Name and Type
$ScriptName = "Ultimate Disk Cleanup Utility"
$ScriptType = "Remediation"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
$LogPath = "C:\Temp\Ninja_DiskCleanup.txt"

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration (Checkbox / Text):

# customFieldName (Text) - Name of the custom field to write status to.

# cleanupPrefetch (Checkbox) - Default: True
# Description: Deletes files in C:\Windows\Prefetch. Safe, though applications may load slightly slower the very first time they run after cleanup.
if (-not $env:cleanupPrefetch) { $env:cleanupPrefetch = "true" }

# cleanupMinidump (Checkbox) - Default: True
# Description: Deletes Windows memory dump files (.dmp) created during system crashes (BSODs).
if (-not $env:cleanupMinidump) { $env:cleanupMinidump = "true" }

# cleanupUpdateCache (Checkbox) - Default: True
# Description: purge the C:\Windows\SoftwareDistribution\Download folder. This stops the BITS and wuauserv services temporarily.
if (-not $env:cleanupUpdateCache) { $env:cleanupUpdateCache = "true" }

# cleanupRMMPackages (Checkbox) - Default: True
# Description: Cleans up the Datto/Ninja/CentraStage "Packages" folder. Removes old agent components to save space.
if (-not $env:cleanupRMMPackages) { $env:cleanupRMMPackages = "true" }

# cleanupBrowserCaches (Checkbox) - Default: True
# Description: Clears internet cache files for Chrome, Edge, Firefox, and Brave for ALL discovered user profiles.
if (-not $env:cleanupBrowserCaches) { $env:cleanupBrowserCaches = "true" }

# cleanupWERLogs (Checkbox) - Default: True
# Description: Deletes Windows Error Reporting (WER) logs and report queues from ProgramData and User profiles.
if (-not $env:cleanupWERLogs) { $env:cleanupWERLogs = "true" }

# cleanupRecycleBin (Checkbox) - Default: True
# Description: Empties the Recycle Bin for all local drives detected on the system.
if (-not $env:cleanupRecycleBin) { $env:cleanupRecycleBin = "true" }

# cleanupCrashdumps (Checkbox) - Default: True
# Description: Deletes application crash dumps found in user %LocalAppData%\CrashDumps folders.
if (-not $env:cleanupCrashdumps) { $env:cleanupCrashdumps = "true" }

# cleanupWinSxS (Checkbox) - Default: True
# Description: Runs the DISM Component Store Cleanup. WARNING: This is CPU intensive and may take a long time to complete.
if (-not $env:cleanupWinSxS) { $env:cleanupWinSxS = "true" }

# cleanupOrphanedInstallers (Checkbox) - Default: True
# Description: Scans C:\Windows\Installer for .msi/.msp files that are NOT linked to any installed application and deletes them.
if (-not $env:cleanupOrphanedInstallers) { $env:cleanupOrphanedInstallers = "true" }

# cleanupStaleProfiles (Checkbox) - Default: True
# Description: Enables the logic to permanently delete user profiles that have not been used in X days.
if (-not $env:cleanupStaleProfiles) { $env:cleanupStaleProfiles = "true" }

# profileInactiveDays (Number) - Default: 30
# Description: If Stale Profile Deletion is enabled, this defines the number of days a profile must be inactive before deletion.
if (-not $env:profileInactiveDays) { $env:profileInactiveDays = 30 }

# profileExcludedUsers (Text) - Comma separated list
# Description: A comma-separated list of usernames that will NEVER be deleted, even if inactive (e.g., Administrator, Public, defaultuser0).
if (-not $env:profileExcludedUsers) { $env:profileExcludedUsers = "Administrator,Public,Default,Default User,defaultuser0,DefaultAccount,WDAGUtilityAccount,UmbrellaLA" }


# What to Write if Alert is Healthy
$Global:AlertHealthy = "Disk Cleanup completed successfully. | Last Checked $Date"

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
########    Functions   ##########

function Log-Message {
    param([string]$Message)
    $Global:DiagMsg += $Message
    # Also append to local log for this specific run
    $Message | Out-File -FilePath $LogPath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-Host $Message
}

function Get-DriveStatistics {
    param([string]$DriveLetter = "C")
    
    $Drive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
    if ($Drive) {
        $FreeGB = [math]::Round($Drive.Free / 1GB, 2)
        $UsedGB = [math]::Round($Drive.Used / 1GB, 2)
        $TotalGB = [math]::Round(($Drive.Free + $Drive.Used) / 1GB, 2)
        $PercentFree = [math]::Round(($Drive.Free / ($Drive.Free + $Drive.Used)) * 100, 2)
        
        return [PSCustomObject]@{
            Drive       = $DriveLetter
            FreeGB      = $FreeGB
            UsedGB      = $UsedGB
            TotalGB     = $TotalGB
            PercentFree = $PercentFree
        }
    }
    return $null
}

function Invoke-UserTempCleanup {
    Log-Message "--- Starting User Temporary Data Cleanup ---"
    
    # Get valid user profiles via Registry to avoid WMI overhead issues
    $ProfileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    $Profiles = Get-ChildItem -Path $ProfileListPath | Get-ItemProperty
    
    foreach ($Profile in $Profiles) {
        $ProfilePath = $Profile.ProfileImagePath
        $UserName = $ProfilePath | Split-Path -Leaf
        
        # Skip system profiles usually found in Windows\ServiceProfiles
        if ($ProfilePath -match "ServiceProfiles" -or -not (Test-Path $ProfilePath)) { continue }

        Log-Message "Processing User: $UserName"
        
        $PathsToClean = @(
            "$ProfilePath\AppData\Local\Temp",
            "$ProfilePath\AppData\Local\Microsoft\Windows\WER",
            "$ProfilePath\AppData\Local\CrashDumps"
        )

        if ($env:cleanupBrowserCaches -eq 'true') {
            $PathsToClean += "$ProfilePath\AppData\Local\Microsoft\Windows\INetCache\IE"
            $PathsToClean += "$ProfilePath\AppData\Local\Microsoft\Edge\User Data\Default\Cache"
            $PathsToClean += "$ProfilePath\AppData\Local\Google\Chrome\User Data\Default\Cache"
            $PathsToClean += "$ProfilePath\AppData\Local\Mozilla\Firefox\Profiles\*\cache2"
        }

        foreach ($Path in $PathsToClean) {
            if (Test-Path $Path) {
                try {
                    Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                }
                catch {
                    # Suppress individual file lock errors to keep logs clean
                }
            }
        }
    }
    Log-Message "--- User Cleanup Finished ---"
}

function Invoke-SystemCleanup {
    Log-Message "--- Starting System Global Cleanup ---"
    
    if ($env:cleanupRecycleBin -eq 'true') {
        Log-Message "- Emptying Recycle Bins..."
        Get-WmiObject Win32_LogicalDisk | ForEach-Object {
            $Drive = $_.DeviceID
            Remove-Item "$Drive\`$Recycle.Bin" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Log-Message "- Cleaning Global Temp ($env:TEMP)..."
    Get-ChildItem "$env:TEMP" -Recurse -Force -ErrorAction SilentlyContinue | 
    Where-Object { $_.FullName -ne $LogPath } | 
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    if ($env:cleanupPrefetch -eq 'true') {
        Log-Message "- Cleaning Prefetch..."
        Remove-Item "$env:SystemRoot\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($env:cleanupMinidump -eq 'true') {
        Log-Message "- Cleaning Minidumps..."
        Remove-Item "$env:SystemRoot\Minidump\*.dmp" -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($env:cleanupRMMPackages -eq 'true') {
        Log-Message "- Cleaning RMM Packages..."
        $PkgPath = "$env:ProgramData\CentraStage\Packages"
        if (Test-Path $PkgPath) {
            Get-ChildItem $PkgPath -Directory -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -match '^[a-f0-9]{8}-' } | 
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Log-Message "--- System Cleanup Finished ---"
}

function Invoke-WindowsUpdateCleanup {
    if ($env:cleanupUpdateCache -ne 'true') { return }
    
    Log-Message "--- Starting Windows Update Cleanup ---"
    $RebootReq = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
    
    if ($RebootReq) {
        Log-Message "!! SKIPPING: Reboot is pending. Touching WU cache is unsafe."
        return
    }

    Log-Message "- Stopping Services..."
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    Log-Message "- Clearing SoftwareDistribution..."
    Remove-Item "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue

    Log-Message "- Restarting Services..."
    Start-Service -Name bits -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Log-Message "--- Windows Update Cleanup Finished ---"
}

function Invoke-WinSxSCleanup {
    if ($env:cleanupWinSxS -ne 'true') { return }
    Log-Message "--- Starting WinSxS Component Cleanup (DISM) ---"
    Log-Message "- This process may take significant time."
    
    $Proc = Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /Quiet" -PassThru -Wait -NoNewWindow
    
    Log-Message "- DISM Exit Code: $($Proc.ExitCode)"
    Log-Message "--- WinSxS Cleanup Finished ---"
}

function Invoke-OrphanedInstallerCleanup {
    if ($env:cleanupOrphanedInstallers -ne 'true') { return }
    Log-Message "--- Starting Orphaned Installer Cleanup ---"

    $InstallerPath = "$env:SystemRoot\Installer"
    if (-not (Test-Path $InstallerPath)) { 
        Log-Message "- Installer directory not found."
        return 
    }

    Log-Message "- Scanning registry for registered installers..."
    $RegisteredFiles = New-Object System.Collections.Generic.List[string]
    
    $RegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\*\InstallProperties",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Patches\*\InstallProperties"
    )

    foreach ($Path in $RegPaths) {
        $Keys = Get-ItemProperty -Path $Path -Name "LocalPackage" -ErrorAction SilentlyContinue
        if ($Keys) {
            foreach ($Key in $Keys) {
                if (-not [string]::IsNullOrWhiteSpace($Key.LocalPackage)) {
                    $RegisteredFiles.Add($Key.LocalPackage)
                }
            }
        }
    }

    # FIX: Initialize HashSet safely to avoid overload errors
    $RegisteredSet = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::InvariantCultureIgnoreCase)
    foreach ($File in $RegisteredFiles) {
        $FileName = Split-Path $File -Leaf
        $null = $RegisteredSet.Add($FileName)
    }

    Log-Message "- Found $($RegisteredSet.Count) registered installers."
    Log-Message "- Scanning disk for orphaned .msi/.msp files..."

    $DiskFiles = Get-ChildItem -Path $InstallerPath -Include "*.msi", "*.msp" -Recurse -ErrorAction SilentlyContinue
    $OrphanedFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]

    foreach ($File in $DiskFiles) {
        if (-not $RegisteredSet.Contains($File.Name)) {
            $OrphanedFiles.Add($File)
        }
    }

    if ($OrphanedFiles.Count -gt 0) {
        $TotalSize = ($OrphanedFiles | Measure-Object -Property Length -Sum).Sum / 1MB
        Log-Message "- Found $($OrphanedFiles.Count) orphans. Total Size: $([math]::Round($TotalSize, 2)) MB"
        Log-Message "- Deleting orphans..."
        
        foreach ($Orphan in $OrphanedFiles) {
            try {
                Remove-Item -Path $Orphan.FullName -Force -ErrorAction Stop
            }
            catch {
                Log-Message "!! Error deleting $($Orphan.Name): $($_.Exception.Message)"
            }
        }
    }
    else {
        Log-Message "- No orphaned installers found."
    }
    Log-Message "--- Orphaned Installer Cleanup Finished ---"
}

function Invoke-StaleProfileCleanup {
    if ($env:cleanupStaleProfiles -ne 'true') { return }
    Log-Message "--- Starting Stale Profile Deletion ---"
    
    $Days = [int]$env:profileInactiveDays
    $Excluded = ($env:profileExcludedUsers -split ',').Trim()
    
    # Automatically exclude the user running the script to avoid locking errors
    $Excluded += $env:USERNAME
    
    $Cutoff = (Get-Date).AddDays(-$Days)
    
    Log-Message "- Threshold: $Days Days (Profiles older than $Cutoff)"
    
    try {
        $Profiles = Get-WmiObject -Class Win32_UserProfile -ErrorAction Stop
    }
    catch {
        Log-Message "!! ERROR: WMI Query failed. Skipping profile cleanup."
        return
    }

    foreach ($Profile in $Profiles) {
        if (-not $Profile.LocalPath) { continue }
        $Username = $Profile.LocalPath | Split-Path -Leaf
        
        if ($Profile.Special -or ($Excluded -contains $Username)) { continue }

        # Determine last use time
        $LastUse = $null
        $DatPath = Join-Path $Profile.LocalPath "NTUSER.DAT"
        
        try {
            # NTUSER.DAT is a hidden system file. -Force is required to read its properties.
            if (Test-Path $DatPath -Force) {
                $LastUse = (Get-Item $DatPath -Force -ErrorAction Stop).LastWriteTime
            }
            elseif (Test-Path $Profile.LocalPath) {
                $LastUse = (Get-Item $Profile.LocalPath -Force -ErrorAction Stop).LastWriteTime
            }
        }
        catch {
            Log-Message "!! WARNING: Could not determine age for '$Username' (Access Denied/Locked). Skipping."
            continue
        }

        if ($LastUse -and $LastUse -lt $Cutoff) {
            Log-Message "-> DELETING profile: $Username (Inactive since $($LastUse.ToString('yyyy-MM-dd')))"
            try {
                $Profile.Delete()
                # Clean up folder if WMI misses it
                if (Test-Path $Profile.LocalPath) {
                    Remove-Item $Profile.LocalPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Log-Message "!! Failed to delete $Username : $($_.Exception.Message)"
            }
        }
    }
    Log-Message "--- Stale Profile Cleanup Finished ---"
}

##################################
##################################
######## Start of Script #########

try {
    # 1. Admin Check
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "Script requires Administrator privileges."
    }

    # 2. Initialize Log
    if (-not (Test-Path "C:\Temp")) { New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null }
    "Detailed Cleanup Log - $Date" | Out-File -FilePath $LogPath -Force -Encoding UTF8

    # 3. Initial Stats
    $StartStats = Get-DriveStatistics "C"
    Log-Message "Initial State (Drive C): $($StartStats.FreeGB) GB Free ($($StartStats.PercentFree)%)"

    # 4. Run Modules
    Invoke-UserTempCleanup
    Invoke-SystemCleanup
    Invoke-WindowsUpdateCleanup
    Invoke-WinSxSCleanup
    Invoke-OrphanedInstallerCleanup
    Invoke-StaleProfileCleanup

    # 5. Final Stats
    $EndStats = Get-DriveStatistics "C"
    $SpaceRecovered = [math]::Round(($EndStats.FreeGB - $StartStats.FreeGB), 2)
    
    Log-Message "=============================================="
    Log-Message "Final State (Drive C): $($EndStats.FreeGB) GB Free ($($EndStats.PercentFree)%)"
    Log-Message "Space Recovered: $SpaceRecovered GB"
    
    $Global:customFieldMessage = "Cleanup Success. Recovered: ${SpaceRecovered}GB. Free: $($EndStats.PercentFree)%. ($Date)"
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