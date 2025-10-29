# List of search terms to identify Bitdefender-specific remnants.
# 'CentraStage' and 'DattoRMM' have been EXCLUDED to protect the core RMM agent.
$SearchTerms = @(
    'Bitdefender',
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
# Add user-specific paths for every user profile.
$UserProfiles = Get-CimInstance -ClassName Win32_UserProfile
foreach ($Profile in $UserProfiles) {
    $FileSystemPaths += Join-Path -Path $Profile.LocalPath -ChildPath 'AppData\Local\Bitdefender'
}

# Specific FILENAMES to hunt for across the entire C: drive. These are temporary files
# created by the Bitdefender installer component and are safe to remove.
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

# Known Registry hives to search. The $SearchTerms array above keeps this safe.
$RegistryHives = @(
    'HKLM:\SOFTWARE',
    'HKLM:\SOFTWARE\WOW6432Node', # For 64-bit systems
    'HKCU:\SOFTWARE'
)

# --- GLOBAL VARIABLES ---
$Global:Findings = @{
    Services   = @()
    Drivers    = @()
    FileSystem = @()
    Files      = @() # New category for individual files
    Registry   = @()
    Tasks      = @()
}

# 1. Detect Services and Drivers
Write-Host "`n[+] Searching for specific Services and Drivers..." -ForegroundColor Yellow
try {
    # Using Get-CimInstance for more robust property selection
    $AllServices = Get-CimInstance -ClassName Win32_Service | Select-Object -Property Name, DisplayName, ServiceType
    
    foreach ($Term in $SearchTerms) {
        $Global:Findings.Services += $AllServices | Where-Object { ($_.DisplayName -like "*$Term*" -or $_.Name -like "*$Term*") -and $_.ServiceType -notlike '*Driver*' }
        $Global:Findings.Drivers += $AllServices | Where-Object { ($_.DisplayName -like "*$Term*" -or $_.Name -like "*$Term*") -and ($_.ServiceType -like '*KernelDriver*' -or $_.ServiceType -like '*FileSystemDriver*') }
    }
    # Remove duplicates
    $Global:Findings.Services = $Global:Findings.Services | Sort-Object -Property Name -Unique
    $Global:Findings.Drivers = $Global:Findings.Drivers | Sort-Object -Property Name -Unique
}
catch { Write-Warning "An error occurred while searching for services: $_" }

# 2. Detect Scheduled Tasks
Write-Host "[+] Searching for Scheduled Tasks..." -ForegroundColor Yellow
try {
    foreach ($Term in $SearchTerms) {
        $Global:Findings.Tasks += Get-ScheduledTask | Where-Object { $_.TaskName -like "*$Term*" -or $_.TaskPath -like "*$Term*" }
    }
    $Global:Findings.Tasks = $Global:Findings.Tasks | Sort-Object -Property TaskName -Unique
}
catch { Write-Warning "An error occurred while searching scheduled tasks: $_" }

# 3. Detect File System FOLDER Remnants
Write-Host "[+] Searching for known File System folders..." -ForegroundColor Yellow
foreach ($Path in $FileSystemPaths) {
    if (Test-Path -Path $Path) {
        $Global:Findings.FileSystem += $Path
    }
}

# 4. Detect individual FILE Remnants (Deep Scan)
Write-Host "[+] Performing deep scan for orphaned installer files (this may take a few minutes)..." -ForegroundColor Yellow
foreach ($File in $OrphanedFiles) {
    try {
        $foundFiles = Get-ChildItem -Path 'C:\' -Recurse -Filter $File -ErrorAction SilentlyContinue
        if ($foundFiles) {
            $Global:Findings.Files += $foundFiles.FullName
        }
    }
    catch { Write-Warning "Could not perform deep file search for '$File'. Error: $_" }
}
$Global:Findings.Files = $Global:Findings.Files | Sort-Object -Unique


# 5. Detect Registry Remnants
Write-Host "[+] Searching the Registry..." -ForegroundColor Yellow
foreach ($Hive in $RegistryHives) {
    foreach ($Term in $SearchTerms) {
        try {
            $FoundKeys = Get-ChildItem -Path $Hive -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Term*" }
            if ($FoundKeys) {
                $Global:Findings.Registry += $FoundKeys.PSPath
            }
        }
        catch { Write-Warning "Could not access or search hive '$Hive'. Error: $_" }
    }
}
$Global:Findings.Registry = $Global:Findings.Registry | Sort-Object -Unique


# --- REPORTING & AUTOMATIC DELETION PHASE ---
Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "DETECTION REPORT COMPLETE" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------`n"

$TotalFindings = ($Global:Findings.Values | ForEach-Object { $_.Count }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum

if ($TotalFindings -eq 0) {
    Write-Host "SUCCESS: No targeted Bitdefender or RMM component remnants were found." -ForegroundColor Green
    if ($Host.Name -eq 'ConsoleHost') { Read-Host -Prompt "Press Enter to exit" }
    exit 0
}

Write-Host "The following $TotalFindings items have been detected and will be automatically removed:`n" -ForegroundColor Red

# --- Display Report ---
if ($Global:Findings.Services.Count -gt 0) { Write-Host "--- SERVICES ---" -ForegroundColor White; $Global:Findings.Services | Select-Object Name, DisplayName | Format-Table -AutoSize }
if ($Global:Findings.Drivers.Count -gt 0) { Write-Host "--- DRIVERS ---" -ForegroundColor White; $Global:Findings.Drivers | Select-Object Name, DisplayName | Format-Table -AutoSize }
if ($Global:Findings.Tasks.Count -gt 0) { Write-Host "--- SCHEDULED TASKS ---" -ForegroundColor White; $Global:Findings.Tasks | Select-Object TaskName, TaskPath | Format-Table -AutoSize }
if ($Global:Findings.FileSystem.Count -gt 0) { Write-Host "--- FILE SYSTEM FOLDERS ---" -ForegroundColor White; $Global:Findings.FileSystem | ForEach-Object { Write-Host "  $_" }; Write-Host "" }
if ($Global:Findings.Files.Count -gt 0) { Write-Host "--- ORPHANED FILES ---" -ForegroundColor White; $Global:Findings.Files | ForEach-Object { Write-Host "  $_" }; Write-Host "" }
if ($Global:Findings.Registry.Count -gt 0) { Write-Host "--- REGISTRY KEYS ---" -ForegroundColor White; $Global:Findings.Registry | ForEach-Object { Write-Host "  $_" }; Write-Host "" }

# --- Begin Deletion ---
Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "PHASE 2: AUTOMATIC DELETION" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------`n"
Write-Host "[!] Proceeding with removal of all detected items..." -ForegroundColor Red

# Loop through all findings and remove them
foreach ($category in $Global:Findings.Keys) {
    if ($Global:Findings[$category].Count -gt 0) {
        Write-Host "`n[-] Removing $category..." -ForegroundColor Yellow
        
        switch ($category) {
            "Services" {
                foreach ($item in $Global:Findings.Services) {
                    Write-Host "  -> Deleting service: $($item.Name)" -NoNewline
                    try { Stop-Service -Name $item.Name -Force -ErrorAction SilentlyContinue; sc.exe delete "$($item.Name)" | Out-Null; Write-Host " - SUCCESS" -ForegroundColor Green }
                    catch { Write-Host " - FAILED: $_.Exception.Message" -ForegroundColor Red }
                }
            }
            "Drivers" {
                foreach ($item in $Global:Findings.Drivers) {
                    Write-Host "  -> Deleting driver: $($item.Name)" -NoNewline
                    try { sc.exe delete "$($item.Name)" | Out-Null; Write-Host " - SUCCESS" -ForegroundColor Green }
                    catch { Write-Host " - FAILED: $_.Exception.Message" -ForegroundColor Red }
                }
            }
            "Tasks" {
                foreach ($item in $Global:Findings.Tasks) {
                    Write-Host "  -> Deleting task: $($item.TaskName)" -NoNewline
                    try { Unregister-ScheduledTask -TaskName $item.TaskName -Confirm:$false -ErrorAction Stop; Write-Host " - SUCCESS" -ForegroundColor Green }
                    catch { Write-Host " - FAILED: $_.Exception.Message" -ForegroundColor Red }
                }
            }
            "FileSystem" {
                foreach ($item in $Global:Findings.FileSystem) {
                    Write-Host "  -> Deleting folder: $item" -NoNewline
                    try { Remove-Item -Path $item -Recurse -Force -ErrorAction Stop; Write-Host " - SUCCESS" -ForegroundColor Green }
                    catch { Write-Host " - FAILED: $_.Exception.Message" -ForegroundColor Red }
                }
            }
            "Files" {
                foreach ($item in $Global:Findings.Files) {
                    Write-Host "  -> Deleting file: $item" -NoNewline
                    try { Remove-Item -Path $item -Force -ErrorAction Stop; Write-Host " - SUCCESS" -ForegroundColor Green }
                    catch { Write-Host " - FAILED: $_.Exception.Message" -ForegroundColor Red }
                }
            }
            "Registry" {
                $SortedKeys = $Global:Findings.Registry | Sort-Object -Property Length -Descending
                foreach ($item in $SortedKeys) {
                    Write-Host "  -> Deleting key: $item" -NoNewline
                    try { Remove-Item -Path $item -Recurse -Force -ErrorAction Stop; Write-Host " - SUCCESS" -ForegroundColor Green }
                    catch { Write-Host " - FAILED: $_.Exception.Message" -ForegroundColor Red }
                }
            }
        }
    }
}


# --- FINAL MESSAGE ---
Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "DELETION COMPLETE" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------`n"
Write-Host "A system reboot is ESSENTIAL to finalize the removal process." -ForegroundColor Yellow
Write-Host "Please restart the computer now."
