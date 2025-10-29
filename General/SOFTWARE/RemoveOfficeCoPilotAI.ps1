<#
.SYNOPSIS
    A script to remove Microsoft Office AI components, disable the Copilot UI via
    the registry, and create a scheduled task to keep it that way.

.DESCRIPTION
    This script is the complete all-in-one solution. It stops all related processes,
    deletes AI engine files, sets the registry key to hide the Copilot UI, and
    automates the process with a scheduled task.
    VERSION 1.4: Added registry key modification to disable the Copilot UI.

.NOTES
    - This script must be run with Administrator privileges.
    - WARNING: This script will forcefully close all major Office applications
      (Word, Excel, Outlook, etc.) without saving open work.
    - Author: Gemini
    - Version: 1.4
#>

#==============================================================================
# SCRIPT REQUIRES ADMINISTRATOR PRIVILEGES
#==============================================================================
#Requires -RunAsAdministrator

#==============================================================================
# DEFINE SERVICE NAME
#==============================================================================
$officeServiceName = "ClickToRunSvc"

#==============================================================================
# MAIN SCRIPT BODY
#==============================================================================
Write-Host "Starting the Microsoft Office AI Removal Script (v1.4)..." -ForegroundColor Yellow
Write-Host "----------------------------------------------------"

# --- STEP 1: SET REGISTRY KEY TO DISABLE COPILOT UI ---
Write-Host "STEP 1: Setting registry key to disable the Copilot User Interface..."
try {
    $regPath = "HKCU:\Software\Microsoft\Office\16.0\Common\Security\AIC"
    $regName = "DisableAIC"
    $regValue = 1

    # Ensure the registry path exists before trying to set a value in it.
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
        Write-Host "Created registry key: $regPath" -ForegroundColor Cyan
    }

    # Set the registry value. This will create the value if it doesn't exist or overwrite it if it does.
    New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType DWord -Force | Out-Null
    Write-Host "Successfully set registry value '$regName' to '1' to disable Copilot UI." -ForegroundColor Green
}
catch {
    Write-Error "Failed to set the registry key. Error: $_"
}

Write-Host "----------------------------------------------------"

# --- STEP 2: STOP ANY RUNNING OFFICE AI PROCESS ---
Write-Host "STEP 2: Checking for and stopping the Office AI process (ai.exe)..."
try {
    $aiProcess = Get-Process -Name "ai" -ErrorAction SilentlyContinue
    if ($aiProcess) {
        Write-Host "Found running 'ai.exe' process. Terminating it now." -ForegroundColor Cyan
        Stop-Process -Name "ai" -Force
        Write-Host "'ai.exe' process terminated successfully." -ForegroundColor Green
    }
    else {
        Write-Host "No 'ai.exe' process found running."
    }
}
catch {
    Write-Warning "An error occurred while trying to stop the 'ai.exe' process: $_"
}

Write-Host "----------------------------------------------------"

# --- STEP 3: CLOSE ALL OFFICE APPLICATIONS TO RELEASE FILE LOCKS ---
Write-Host "STEP 3: Closing major Office applications to release file locks..."
Write-Host "WARNING: This will forcefully close Word, Excel, Outlook, etc. without saving." -ForegroundColor Red
$officeProcesses = @("WINWORD", "EXCEL", "OUTLOOK", "POWERPNT", "MSACCESS", "ONENOTE")
$appsClosed = $false
foreach ($procName in $officeProcesses) {
    $process = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($process) {
        $appsClosed = $true
        Write-Host "Found running process: $procName. Terminating it now." -ForegroundColor Cyan
        Stop-Process -Name $procName -Force
        Write-Host "'$procName' terminated." -ForegroundColor Green
    }
}
if (-not $appsClosed) {
    Write-Host "No major Office applications were found running."
}

Write-Host "----------------------------------------------------"

# --- STEPS 4 & 5 ARE WRAPPED IN A TRY/FINALLY BLOCK ---
try {
    # --- STEP 4: STOP OFFICE CLICK-TO-RUN BACKGROUND SERVICE ---
    Write-Host "STEP 4: Stopping the Office Click-to-Run service..."
    $officeService = Get-Service -Name $officeServiceName -ErrorAction SilentlyContinue
    if ($officeService -and $officeService.Status -ne 'Stopped') {
        Write-Host "Service '$($officeServiceName)' is running. Attempting to stop it." -ForegroundColor Cyan
        Stop-Service -Name $officeServiceName -Force -ErrorAction Stop
        Write-Host "Service '$($officeServiceName)' stopped successfully." -ForegroundColor Green
    }
    elseif ($officeService) {
        Write-Host "Service '$($officeServiceName)' is already stopped."
    }
    
    Write-Host "----------------------------------------------------"
    
    # --- STEP 5: DEFINE PATHS AND REMOVE AI FILES ---
    Write-Host "STEP 5: Searching for and deleting Office AI files..."
    $potentialPaths = @(
        "$env:ProgramFiles\Microsoft Office\root\vfs\ProgramFilesCommonX86\Microsoft Shared\OFFICE16",
        "$env:ProgramFiles\Microsoft Office\root\vfs\ProgramFilesCommonX64\Microsoft Shared\OFFICE16",
        "$env:ProgramFiles(x86)\Microsoft Office\root\vfs\ProgramFilesCommonX86\Microsoft Shared\OFFICE16",
        "$env:ProgramFiles(x86)\Microsoft Office\root\vfs\ProgramFilesCommonX64\Microsoft Shared\OFFICE16"
    )
    $aiFolderName = "AI"
    if ((Get-ChildItem -Path ($potentialPaths | Where-Object { Test-Path $_ }) -ErrorAction SilentlyContinue).Count -gt 0) {
        foreach ($path in $potentialPaths | Where-Object { Test-Path $_ }) {
            $aiFolderPath = Join-Path -Path $path -ChildPath $aiFolderName
            if (Test-Path -Path $aiFolderPath -PathType Container) {
                Write-Host "Found AI folder at: $aiFolderPath" -ForegroundColor Cyan
                $aiFiles = Get-ChildItem -Path $aiFolderPath -Force
                if ($aiFiles.Count -gt 0) {
                    Write-Host "Attempting to delete $($aiFiles.Count) item(s) from this folder..."
                    Remove-Item -Path "$aiFolderPath\*" -Recurse -Force -ErrorAction Stop
                    Write-Host "Successfully deleted contents of '$aiFolderPath'." -ForegroundColor Green
                }
                else {
                    Write-Host "AI folder is already empty."
                }
            }
        }
    }
    else {
        Write-Warning "Could not find any Office AI folders in the standard locations."
    }
}
catch {
    Write-Error "An error occurred during the service stop or file deletion process: $_"
}
finally {
    # --- THIS BLOCK ALWAYS RUNS TO ENSURE THE SERVICE IS RESTARTED ---
    Write-Host "----------------------------------------------------"
    Write-Host "FINAL STEP: Ensuring the Office Click-to-Run service is running..."
    $officeService = Get-Service -Name $officeServiceName -ErrorAction SilentlyContinue
    if ($officeService -and $officeService.Status -ne 'Running') {
        Write-Host "Service '$($officeServiceName)' is not running. Attempting to start it." -ForegroundColor Cyan
        Start-Service -Name $officeServiceName
        Write-Host "Service '$($officeServiceName)' started successfully." -ForegroundColor Green
    }
    elseif ($officeService) {
        Write-Host "Service '$($officeServiceName)' is already running as expected."
    }
}

Write-Host "----------------------------------------------------"

# --- STEP 6: CREATE OR UPDATE THE SCHEDULED TASK FOR AUTOMATION ---
Write-Host "STEP 6: Creating a scheduled task for daily cleanup..."
$taskName = "RemoveOfficeAI"
$taskDescription = "Runs daily to remove Microsoft Office AI components and disable the Copilot UI. This task was created by the Remove-OfficeAI.ps1 script."
$scriptPath = $MyInvocation.MyCommand.Definition
try {
    $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $taskTrigger = New-ScheduledTaskTrigger -Daily -At 5am
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings -Description $taskDescription -Force -ErrorAction Stop
    Write-Host "Successfully created/updated the scheduled task '$taskName'." -ForegroundColor Green
    Write-Host "This script will now run automatically every day at 5:00 AM."
}
catch {
    Write-Error "Failed to create the scheduled task. Please run this script as an Administrator."
    Write-Error "Error details: $_"
}

Write-Host "----------------------------------------------------"
Write-Host "Script execution complete. Please restart any open Office applications." -ForegroundColor Yellow