#
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Ultimate Disk Cleanup Utility" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

#======================================== VARIABLE CONFIG ========================================
## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables.
#$env:APIEndpoint = "https://prod-36.westus.logic.azure.com:443/workflows/6c032a1ca84045b9a7a1436864ecf696/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=c-dVa333HMzhWli_Fp_4IIAqaJOMwFjP2y5Zfv4j_zA"
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

# --- General File Cleanup Modules ---
$env:usrPrefetch = $true
$env:usrMinidump = $true
$env:usrUpdateCache = $true
$env:usrPackagesFolder = $true
$env:usrBrowserCaches = $true
$env:usrWERLogs = $true
$env:usrRecycleBin = $true
$env:usrCrashdumps = $true
$env:usrWinSxSCleanup = $true
$env:usrOrphanedInstallers = $true

# --- Stale Profile Deletion Module ---
$env:usrDeleteOldProfiles = $true
[int]$env:usrInactiveDays = 30 # Days a profile must be inactive before deletion.
[string[]]$env:usrExcludedUsers = @( # List of user accounts to explicitly protect from deletion.
    'Administrator', 'Public', 'Default User', 'defaultuser0', 'DefaultAccount', 'WDAGUtilityAccount', 'UmbrellaLA'
)

$varUBR = ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name UBR -ea 0).UBR)
if (!$varUBR) {
    $varUBR = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\Windows\system32\kernel32.dll")).ProductVersion.split('\.')[3]
}

<#
This Script is a Remediation component, meaning it performs only one task with a log of granular detail. These task results can be added back into tickets as time entries using the API.

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
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

#======================================== FUNCTIONS & FUNCTIONS ========================================

function getDriveSpace ($drive) {
    #give out the basics
    write-host ": Statistics for Drive $drive"
    $varDriveFree = ([math]::Round(((get-psdrive $($env:SystemDrive).replace(':', '')).Free) / 1GB, 2))
    write-host "- Free Space: $([math]::Round(((get-psdrive $($env:SystemDrive).replace(':', '')).Free) / 1GB, 2)) GB"
    $varDriveUsed = ([math]::Round(((get-psdrive $($env:SystemDrive).replace(':', '')).Used) / 1GB, 2))
    write-host "- Used Space: $([math]::Round(((get-psdrive $($env:SystemDrive).replace(':', '')).Used) / 1GB, 2)) GB"
    #calculate a percentage
    $varDrivePerc = [math]::Round($varDriveFree / ($varDriveFree + $varDriveUsed) * 100, 2)
    write-host "- % Free:       $varDrivePerc%"

    if ($script:varPriorResult) {
        write-host "- (Was:          $($script:varPriorResult)%)"
        $script:varNowResult = $varDrivePerc
    }
    else {
        $script:varPriorResult = $varDrivePerc
    }
}

#windows relative identifier lookup table :: copyright datto, inc. 2022
function checkRID ($SID) {
    switch -regex ($SID) {
        '-18$' { write-host ": Account Type:         LocalSystem" }
        '-19$' { write-host ": Account Type:         NT Authority" }
        '-20$' { write-host ": Account Type:         NetworkService" }
        '-500$' { write-host ": Account Type:         Default Administrator" }
        '-501$' {
            write-host ": Account Type:         Guest"
            return $true
        }
        '-502$' { write-host ": Account Type:         Key Distribution Centre" }
        '-503$' { write-host ": Account Type:         Default" }
        '-504$' { write-host ": Account Type:         Windows Defender AppGuard [Windows Sandbox]" }
        default {
            if ($SID -match $varLocalSID) {
                write-host ": Account Type:         User [Local]"
            }
            else {
                write-host ": Account Type:         User [Domain]"
            }

            if ($(get-itemproperty "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID" -Name "ProfileLoadTimeHigh" -ea 0).ProfileLoadTimeHigh -eq 0) {
                return $true
            }
        }
    }
}

function teeString ($string) {
    write-host $string
    $script:arrLog += "$string"
}

Function Get-StaleUserProfiles {
    param (
        [Parameter(Mandatory = $true)][int]$InactiveDays,
        [Parameter(Mandatory = $true)][string[]]$ExcludedUsers
    )

    teeString "Searching for user profiles inactive for more than $InactiveDays days..."
    $CutoffDate = (Get-Date).AddDays(-$InactiveDays)
    $StaleProfiles = @()

    try {
        $AllProfiles = Get-WmiObject -Class Win32_UserProfile -ErrorAction Stop
    }
    catch {
        teeString "!! ERROR: Failed to query user profiles via WMI. Ensure you are running with Administrator privileges."
        teeString "!! ERROR: $($_.Exception.Message)"
        return $null
    }

    foreach ($Profile in $AllProfiles) {
        if (-not $Profile.LocalPath -or -not (Test-Path $Profile.LocalPath)) {
            continue
        }

        $Username = $Profile.LocalPath.Split('\')[-1]
        
        # --- PRE-FILTERING for excluded/special accounts ---
        if ($Profile.Special -or ($ExcludedUsers -contains $Username)) {
            continue
        }
        
        # --- CORE LOGIC with Fallback ---
        $LastLogonTime = $null
        $Method = ""
        $ntuserPath = Join-Path -Path $Profile.LocalPath -ChildPath "NTUSER.DAT"

        $ntuserItem = Get-Item -Path $ntuserPath -ErrorAction SilentlyContinue
        if ($ntuserItem) {
            $LastLogonTime = $ntuserItem.LastWriteTime
            $Method = "NTUSER.DAT"
        } 
        else {
            $folderItem = Get-Item -Path $Profile.LocalPath -ErrorAction SilentlyContinue
            if ($folderItem) {
                $LastLogonTime = $folderItem.LastWriteTime
                $Method = "Folder Date"
            }
        }

        # --- EVALUATION ---
        if ($LastLogonTime) {
            if ($LastLogonTime -lt $CutoffDate) {
                $StaleProfiles += [PSCustomObject]@{
                    ProfileObject = $Profile
                    Reason        = "Inactive since $($LastLogonTime.ToString('yyyy-MM-dd')) (via $Method)"
                }
            }
        }
        else {
            if (-not (Test-Path $ntuserPath)) {
                $StaleProfiles += [PSCustomObject]@{
                    ProfileObject = $Profile
                    Reason        = "Corrupted (NTUSER.DAT missing)"
                }
            }
        }
    }
    return $StaleProfiles
}

Function Remove-UserProfiles {
    param (
        [Parameter(Mandatory = $true)][array]$ProfilesToDelete
    )
    
    teeString "Starting profile deletion process..."
    $DeletionCount = 0

    foreach ($Entry in $ProfilesToDelete) {
        $Profile = $Entry.ProfileObject
        $Username = $Profile.LocalPath.Split('\')[-1]
        teeString "-> Attempting to delete profile for user: $Username..."
        
        try {
            $Profile.Delete()
            
            if (Test-Path -Path $Profile.LocalPath) {
                teeString "!! WARNING: WMI left the profile folder. Forcefully removing '$($Profile.LocalPath)'..."
                Remove-Item -Path $Profile.LocalPath -Recurse -Force -ErrorAction Stop
                teeString "-> Forceful folder removal successful."
            }
            else {
                teeString "-> Successfully deleted profile for $Username."
            }
            $DeletionCount++
        }
        catch {
            teeString "!! ERROR: Failed to delete profile for '$Username'. Path: $($Profile.LocalPath)"
            teeString "!! ERROR: $($_.Exception.Message)"
        }
    }
    teeString "- Profile cleanup complete. Total profiles deleted: $DeletionCount"
}

#============================================== CODE =============================================

write-host "Ultimate Disk Cleanup Utility - ($(get-date))"
write-host "======================================="
write-host "Windows Version: $((get-WMiObject win32_operatingSystem).caption) [$((get-WMiObject win32_operatingSystem).version).$varUBR]"
write-host "Device Name:       $env:COMPUTERNAME"
write-host "Home Drive:        $env:SystemDrive"
write-host "Running From:      $($PWD.Path)"
write-host "---------------------------------------"
write-host "All cleanup modules are set to ACTIVE. All deletions are permanent."
write-host "---------------------------------------"
getDriveSpace $env:SystemDrive
write-host "======================================="

#boilerplate
$script:arrLog = @()
$script:arrLog += "================================================"
$script:arrLog += "Ultimate Disk Cleanup Log: $(get-date)"
$script:arrLog += "The following operations were performed:"
$script:arrLog += "------------------------------------------------"

#get information on users for temp file cleanup
$varLocalSID = (get-wmiobject win32_useraccount -filter "LocalAccount=True" | ? { $_.SID -match '-500$' }).SID -replace ".{3}$"
$arrUsers = @()
gci -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" | % { Get-ItemProperty $_.PSPath } | % {
    write-host ": Account Name:         $(($_.ProfileImagePath).split('\')[-1])"
    if (checkRID $($_.PSChildName)) {
        write-host ": Valid for Tmp Cleanup:  YES"
        $arrUsers += $_.ProfileImagePath
    }
    else {
        write-host ": Valid for Tmp Cleanup:  NO"
    }
    write-host "------"
}

#clear out user-specific data
write-host "- The following user directories' temporary data will be cleared:"
$arrUsers | % { write-host ": $_" }
write-host "======================================="

$arrUsers | % {
    if (!$_) { break }
    $currentUser = $_
    teeString ": User: $currentUser"
    teeString "- Clearing local temporary data"
    gci "$currentUser\AppData\Local\Temp" -Recurse -Force -ea 0 | % { remove-item $_.FullName -Force -Recurse -ea 0 }
    if ($env:usrWERLogs) {
        teeString "- Clearing Windows Error Reporting logs [User]"
        gci "$currentUser\AppData\Local\Microsoft\Windows\WER" -Recurse -Force -ea 0 | % { remove-item $_.FullName -Force -Recurse -ea 0 }
    }
    if ($env:usrCrashdumps) {
        teeString "- Clearing crash dumps [User]"
        gci "$currentUser\AppData\Local\CrashDumps" -Recurse -Force -ea 0 | % { remove-item $_.FullName -Force -Recurse -ea 0 }
    }
    if ($env:usrBrowserCaches) {
        teeString "- Clearing Browser Caches"
        gci "$currentUser\AppData\Local\Microsoft\Windows\INetCache\IE" -ea 0 -Recurse -Force | % { remove-item $_.FullName -Force -Recurse -ea 0 }
        gci "$currentUser\AppData\Local\Microsoft\Edge\User Data\Default\Cache" -ea 0 -Recurse -Force | % { remove-item $_.FullName -Force -Recurse -ea 0 }
        ("$currentUser\AppData\Local\Google\Chrome\User Data\Default\Cache", "$currentUser\AppData\Local\Google\Chrome\User Data\Default\Cache2", "$currentUser\AppData\Local\Google\Chrome\User Data\Default\Media Cache") | % { gci $_ -ea 0 -Recurse -Force | % { remove-item $_.FullName -Force -Recurse -ea 0 } }
        gci "$currentUser\AppData\Local\Vivaldi\User Data\Default\Cache" -ea 0 -Recurse -Force | % { remove-item $_.FullName -Force -Recurse -ea 0 }
        gci "$currentUser\AppData\Local\Mozilla\Firefox\Profiles\" -ea 0 -Force | ? { $_.PSIsContainer } | % { gci "$($_.FullName)\cache2\entries" -ea 0 -Recurse | % { remove-item $_.FullName -Force -Recurse -ea 0 } }
        gci "$currentUser\AppData\Local\BraveSoftware\User Data\Default\Cache" -ea 0 -Recurse -Force | % { remove-item $_.FullName -Force -Recurse -ea 0 }
    }
    write-host "------"
}
write-host "- Finished clearing per-user data."
write-host "======================================="

#clear out global data
if ($env:usrRecycleBin) {
    teeString "- Clearing Recycle Bins on all drives"
    Get-WmiObject win32_logicaldisk | % {
        remove-item "$($_.DeviceID)\RECYCLER" -Force -Recurse -ea 0
        remove-item "$($_.DeviceID)\RECYCLED" -Force -Recurse -ea 0
        remove-item "$($_.DeviceID)\`$RECYCLE.BIN" -Force -Recurse -ea 0
    }
}
teeString "- Clearing Temp directory"
gci "$env:TEMP" -ea 0 -Recurse -Force | ? { $_.FullName -ne $script:MyInvocation.MyCommand.Path } | % { remove-item $_.FullName -Force -Recurse -ea 0 }
if ($env:usrPrefetch) {
    teeString "- Clearing PreFetch directory"
    gci "$env:SystemRoot\PreFetch" -ea 0 -Recurse -Force | % { remove-item $_.FullName -Force -Recurse -ea 0 }
}
if ($env:usrUpdateCache) {
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA 0 | ? { $_.Property }) {
        teeString "! NOTICE: Unable to clear Windows Update cache; a reboot is pending."
    }
    else {
        teeString "- Clearing Windows Update cache"
        Stop-Service bits -Force -ea 0
        Stop-Service wuauserv -Force -ea 0
        start-sleep -Seconds 5
        gci "$env:SystemRoot\SoftwareDistribution\Download" -ea 0 -Recurse -Force | % { remove-item $_.FullName -Force -Recurse -ea 0 }
        Start-Service bits -ea 0
        Start-Service wuauserv -ea 0
    }
}
if ($env:usrWinSxSCleanup) {
    teeString "- Starting DISM Component Store cleanup (WinSxS). This may take a long time..."
    Dism.exe /Online /Cleanup-Image /StartComponentCleanup /Quiet | Out-Null
    teeString "- DISM Component Store cleanup finished."
}
if ($env:usrOrphanedInstallers) {
    teeString "- Starting Orphaned Installer cleanup..."
    $installerPath = Join-Path -Path $env:SystemRoot -ChildPath "Installer"
    $diskFiles = Get-ChildItem -Path $installerPath -Recurse -Include "*.msi", "*.msp" -ErrorAction SilentlyContinue
    if ($diskFiles) {
        $registeredFilePaths = [System.Collections.Generic.List[string]]::new()
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\*\InstallProperties",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Patches\*\InstallProperties"
        )
        foreach ($path in $registryPaths) {
            $items = Get-ItemProperty -Path $path -Name "LocalPackage" -ErrorAction SilentlyContinue
            if ($null -ne $items) {
                $items.LocalPackage | ForEach-Object { if (-not [string]::IsNullOrEmpty($_)) { $registeredFilePaths.Add($_) } }
            }
        }

        # Create a HashSet of registered filenames for a fast, case-insensitive lookup.
        $registeredFileNames = $registeredFilePaths | Split-Path -Leaf
        $registeredNamesSet = [System.Collections.Generic.HashSet[string]]::new($registeredFileNames, [System.StringComparer]::InvariantCultureIgnoreCase)

        # Create a clean list of orphaned files by checking them against the HashSet.
        $orphanedFileObjects = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        foreach ($file in $diskFiles) {
            if (-not $registeredNamesSet.Contains($file.Name)) {
                $orphanedFileObjects.Add($file)
            }
        }
        
        if ($orphanedFileObjects.Count -gt 0) {
            teeString "- Found $($orphanedFileObjects.Count) orphaned installers. Deleting them permanently."
            
            # Calculate the total size accurately from our clean list of file objects.
            $totalSize = ($orphanedFileObjects | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
            
            # Loop through the clean list and delete. This loop will no longer encounter null items.
            foreach ($orphan in $orphanedFileObjects) {
                try {
                    Remove-Item -Path $orphan.FullName -Force -Recurse -ErrorAction Stop
                }
                catch {
                    teeString "!! ERROR: Could not delete orphaned file: $($orphan.FullName) - $($_.Exception.Message)"
                }
            }
            
            teeString "- Deleted $totalSizeMB MB of orphaned installer files."
        }
        else {
            teeString "- No orphaned installer files found."
        }
    }
}
if ($env:usrMinidump) {
    teeString "- Clearing Minidumps"
    gci "$env:SystemRoot\Minidump\*.dmp" -ea 0 -Recurse -Force | % { remove-item $_.FullName -Force -Recurse -ea 0 }
}
if ($env:usrPackagesFolder) {
    teeString "- Clearing RMM Packages Folder"
    gci "$env:PROGRAMDATA\CentraStage\Packages" -Force -ea 0 | ? { $_.PSIsContainer } | % {
        if ($_.FullName -ne $PWD.Path -and $_.Name -match '-') {
            remove-item $_.FullName -Force -Recurse -ea 0
        }
    }
}
if ($env:usrWERLogs) {
    teeString "- Clearing Windows Error Reporting logs [Global]"
    gci "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportQueue" -Recurse -Force -ea 0 | % { remove-item $_.FullName -Force -Recurse -ea 0 }
}

write-host "======================================="

# --- Stale Profile Deletion ---
if ($env:usrDeleteOldProfiles) {
    teeString "--- Starting Stale User Profile Deletion Module ---"
    $StaleProfiles = Get-StaleUserProfiles -InactiveDays $env:usrInactiveDays -ExcludedUsers $env:usrExcludedUsers

    if ($null -eq $StaleProfiles -or $StaleProfiles.Count -eq 0) {
        teeString "- No stale or corrupted profiles found matching the criteria. System is clean."
    }
    else {
        teeString "- The following $($StaleProfiles.Count) user profiles will be PERMANENTLY DELETED:"
        $StaleProfiles | ForEach-Object {
            $Username = $_.ProfileObject.LocalPath.Split('\')[-1]
            teeString "  - Username: $($Username) (Reason: $($_.Reason))"
        }
        Remove-UserProfiles -ProfilesToDelete $StaleProfiles
    }
    teeString "--- Finished Stale User Profile Deletion Module ---"
}
else {
    teeString "- Stale User Profile Deletion Module is disabled."
}


#recalculate/display disk space
write-host "======================================="
write-host "- Disk cleanup completed!"
getDriveSpace $env:SystemDrive

#deletion log
New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
$logPath = "C:\Temp\DRMM_UltimateCleanup.txt"
$script:arrLog | Out-File -FilePath $logPath -Append
write-host "- A log has been saved to $logPath."
write-host "======================================="
write-host "- Exiting..."

# Populate the Datto RMM Diagnostic Message with the script's log and final results
$Global:DiagMsg += $script:arrLog
$Global:DiagMsg += "================================================"
$Global:DiagMsg += "Cleanup Summary for Drive $env:SystemDrive :"
$Global:DiagMsg += " - Space Before: $script:varPriorResult% Free"
$Global:DiagMsg += " - Space After:  $script:varNowResult% Free"


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