<#
.SYNOPSIS
    A definitive script that collects comprehensive data about a QuickBooks Desktop
    installation for use in automation and other scripts.

.DESCRIPTION
    This script confidently identifies a QuickBooks installation by searching for
    edition-specific executables (QBWPro.exe, QBWPrem.exe, QBWEnt.exe). It gathers
    numerous data points including the year, edition, version, file paths, and
    company details. It also checks for the QuickBooks Tool Hub. All collected
    data is compiled into a single, structured PowerShell object for easy use.

.AUTHOR
    Alex Ivantsov

.DATE
    August 29, 2025
#>

# --- Functions ---

function Find-QuickBooksExecutable {
    Write-Host "Phase 1: Searching for QuickBooks executable..." -ForegroundColor Yellow
    $executableNames = @("QBWPro.exe", "QBWPrem.exe", "QBWEnt.exe")
    $searchPaths = @("$env:ProgramFiles(x86)", "$env:ProgramFiles") | Get-Unique

    foreach ($exeName in $executableNames) {
        Write-Host "  - Checking for '$exeName'..." -ForegroundColor Gray
        foreach ($path in $searchPaths) {
            if (Test-Path $path) {
                $qbwFile = Get-ChildItem -Path $path -Filter $exeName -Recurse -ErrorAction SilentlyContinue -Force | Select-Object -First 1
                if ($qbwFile) {
                    Write-Host "  [SUCCESS] Found executable at: $($qbwFile.FullName)" -ForegroundColor Green
                    return $qbwFile
                }
            }
        }
    }
    Write-Host "  [FAIL] Could not find a known QuickBooks edition executable." -ForegroundColor Red
    return $null
}

function Get-QuickBooksEditionFromRegistry {
    param([string]$VersionNumber)
    Write-Host "Phase 2: Verifying edition details in registry..." -ForegroundColor Yellow
    if (-not $VersionNumber) { return $null }
    
    $searchPaths = @("HKLM:\SOFTWARE\Intuit", "HKLM:\SOFTWARE\Wow6432Node\Intuit", "HKCU:\SOFTWARE\Intuit")
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $versionKey = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq $VersionNumber } | Select-Object -First 1
            if ($versionKey) {
                $flavor = (Get-ItemProperty -Path $versionKey.PSPath -Name "Flavor" -ErrorAction SilentlyContinue).Flavor
                if ($flavor) {
                    Write-Host "  [SUCCESS] Found definitive edition in registry." -ForegroundColor Green
                    return $flavor
                }
            }
        }
    }
    Write-Host "  [INFO] No specific edition details found in registry." -ForegroundColor Yellow
    return $null
}

function Test-QuickBooksToolHubInstallation {
    Write-Host "Phase 3: Checking for QuickBooks Tool Hub..." -ForegroundColor Yellow
    $uninstallPaths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $toolHub = Get-ItemProperty -Path $uninstallPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq "QuickBooks Tool Hub" }
    
    if ($toolHub) {
        Write-Host "  [SUCCESS] QuickBooks Tool Hub is installed." -ForegroundColor Green
        return $true
    }
    Write-Host "  [INFO] QuickBooks Tool Hub is not installed." -ForegroundColor Yellow
    return $false
}

# --- Main Script Execution ---
Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   QuickBooks System Data Collector"
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

$qbwFileObject = Find-QuickBooksExecutable

# Initialize the data object with default values
$quickbooksData = [PSCustomObject]@{
    IsInstalled      = $false
    FullName         = $null
    Year             = $null
    Edition          = $null
    VersionRevision  = $null
    FileVersion      = $null
    ExecutablePath   = $null
    InstallDirectory = $null
    CompanyName      = $null
    ToolHubInstalled = Test-QuickBooksToolHubInstallation
}

if ($qbwFileObject) {
    # --- Populate the data object if QuickBooks was found ---
    $quickbooksData.IsInstalled = $true
    $quickbooksData.ExecutablePath = $qbwFileObject.FullName
    $quickbooksData.InstallDirectory = $qbwFileObject.DirectoryName
    
    # Get version info from the file
    $versionInfo = $qbwFileObject.VersionInfo
    $quickbooksData.VersionRevision = $versionInfo.ProductVersion
    $quickbooksData.FileVersion = $versionInfo.FileVersion
    $quickbooksData.CompanyName = $versionInfo.CompanyName
    
    # Determine Year
    $quickbooksData.Year = if ($qbwFileObject.DirectoryName -match '(\d{4})') { $matches[1] } else { 'Unknown' }
    
    # Determine Edition
    $versionNumber = $versionInfo.ProductVersion.Split('.')[0]
    $registryEdition = Get-QuickBooksEditionFromRegistry -VersionNumber $versionNumber
    
    if ($registryEdition) {
        # Prioritize the full name from the registry
        $quickbooksData.Edition = $registryEdition
    }
    else {
        # Confidently build the name from the executable filename
        $quickbooksData.Edition = switch -Wildcard ($qbwFileObject.Name) {
            '*Pro*' { 'Pro Plus' }
            '*Prem*' { 'Premier Plus' }
            '*Ent*' { 'Enterprise Solutions' }
            default { 'Unknown' }
        }
    }
    
    # Construct the full name
    $quickbooksData.FullName = "QuickBooks Desktop $($quickbooksData.Edition) $($quickbooksData.Year)"
}

# --- Final Output ---
Write-Host ""
Write-Host "-------------------- Collected Data --------------------" -ForegroundColor Green
Write-Host ""

# Display the final data object
$quickbooksData