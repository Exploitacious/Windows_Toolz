<#
.SYNOPSIS
    Finds and quarantines orphaned Windows Installer files (.msi, .msp) from the C:\Windows\Installer folder.

.DESCRIPTION
    This script identifies installer files that are no longer associated with any installed application in the Windows Registry.
    Instead of deleting them, it moves them to a quarantine folder (C:\_OrphanedInstallers by default) for safety.
    This allows for easy restoration if an application unexpectedly needs a file.

.PARAMETER DryRun
    If specified, the script will only report which files it would move without actually moving them.

.PARAMETER QuarantinePath
    Specifies a custom path to move the orphaned files to. Defaults to "C:\_OrphanedInstallers".

.EXAMPLE
    .\Find-OrphanedInstallers.ps1 -Verbose
    Scans for orphans and moves them, showing detailed progress.

.EXAMPLE
    .\Find-OrphanedInstallers.ps1 -DryRun -Verbose
    Performs a test run, showing which files are considered orphans without moving anything.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$QuarantinePath = "C:\_OrphanedInstallers"
)

# This script must be run with administrative privileges.
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run with administrative privileges. Please re-run it in an elevated PowerShell session."
    Start-Sleep -Seconds 5
    Exit
}

# --- SCRIPT START ---

# 1. Get all installer files physically present on the disk
Write-Host "Step 1: Scanning for all .msi and .msp files in C:\Windows\Installer..." -ForegroundColor Yellow
$installerPath = Join-Path -Path $env:SystemRoot -ChildPath "Installer"
$diskFiles = Get-ChildItem -Path $installerPath -Recurse -Include "*.msi", "*.msp" -ErrorAction SilentlyContinue

if ($null -eq $diskFiles) {
    Write-Host "No .msi or .msp files found in the installer directory. Exiting." -ForegroundColor Green
    Exit
}

# 2. Get all installer files registered by Windows
Write-Host "Step 2: Querying the registry for all *active* installer products and patches..." -ForegroundColor Yellow
$registeredFiles = [System.Collections.Generic.List[string]]::new()

# Query both Products and Patches registry hives
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\*\InstallProperties",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Patches\*\InstallProperties"
)

foreach ($path in $registryPaths) {
    Write-Verbose "Querying registry path: $path"
    $items = Get-ItemProperty -Path $path -Name "LocalPackage" -ErrorAction SilentlyContinue
    if ($null -ne $items) {
        $items.LocalPackage | ForEach-Object { $registeredFiles.Add($_) }
    }
}

# 3. Compare the lists to find orphans
Write-Host "Step 3: Comparing disk files against the registry to find orphans..." -ForegroundColor Yellow
$orphanedFiles = Compare-Object -ReferenceObject $registeredFiles -DifferenceObject $diskFiles.FullName -PassThru | Where-Object { $_ }

# --- SCRIPT END ---

# 4. Process the orphans
if ($orphanedFiles.Count -eq 0) {
    Write-Host "`nNo orphaned installer files were found. Your system is clean! ✨" -ForegroundColor Green
    Exit
}

Write-Host "`nFound $($orphanedFiles.Count) orphaned files." -ForegroundColor Cyan

# Create the quarantine directory if it doesn't exist
if (-NOT (Test-Path -Path $QuarantinePath) -AND -NOT $DryRun) {
    Write-Verbose "Creating quarantine directory at $QuarantinePath"
    New-Item -Path $QuarantinePath -ItemType Directory | Out-Null
}

$totalSize = 0
foreach ($orphan in $orphanedFiles) {
    $fileInfo = Get-Item -Path $orphan
    $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
    $totalSize += $fileInfo.Length

    if ($DryRun) {
        Write-Host "[DRY RUN] Would move $($fileInfo.Name) ($($fileSizeMB) MB)" -ForegroundColor Gray
    }
    else {
        Write-Host "Moving $($fileInfo.Name) ($($fileSizeMB) MB) to $QuarantinePath"
        Move-Item -Path $fileInfo.FullName -Destination $QuarantinePath -Force
    }
}

# 5. Final Report
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)
Write-Host "---"
if ($DryRun) {
    Write-Host "[DRY RUN] Process complete." -ForegroundColor Green
    Write-Host "A real run would have moved $($orphanedFiles.Count) files, freeing up $($totalSizeMB) MB." -ForegroundColor Green
}
else {
    Write-Host "Process Complete! ✅" -ForegroundColor Green
    Write-Host "Moved $($orphanedFiles.Count) files to $QuarantinePath, reclaiming $($totalSizeMB) MB of space." -ForegroundColor Green
    Write-Host "It is recommended to keep this folder for a few weeks to ensure no applications have issues." -ForegroundColor Yellow
}