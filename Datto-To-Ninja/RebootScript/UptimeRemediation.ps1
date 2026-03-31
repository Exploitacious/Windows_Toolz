# 
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Remediation - Asynchronous Reboot with User Notification" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. This is required for this script to function.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:RebootDelayMinutes = 15
#$env:CompanyName = "Umbrella IT Solutions"
#$env:WindowTitle = "System Maintenance Reboot"

<#
This script solves the Session 0 isolation problem by using the Windows Task Scheduler to launch the UI
in the active user's session while simultaneously scheduling the actual reboot to run as SYSTEM.
This allows Datto RMM to "fire and forget" the component.

Datto RMM Variables to be created for this component:
1. RebootDelayMinutes (Type: Number) - Time in minutes to wait before reboot. Default: 15
2. CompanyName (Type: String) - Your company name to display in the message.
3. WindowTitle (Type: String) - The title of the notification pop-up window.
#>
# DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
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


# !!!! USE THIS IN THE FUTURE !!!
$logged_on_user = (
    Get-WmiObject -Class win32_process -computer . -Filter "name='explorer.exe'" |
    Foreach-Object { $_.GetOwner() } |
    select -ExpandProperty "User"
)
if ($logged_on_user) {
    LogWrite "User $logged_on_user is still logged on"
    LogWrite "Forcing a reboot in $delay_minutes minutes, but notifying the logged on user first"
    Write-Output "Logged in user $logged_on_user was notified they had $delay_minutes minutes before reboot"
    Msg * "Security updates have been pending for several days.`nYour PC will be rebooted in $delay_minutes minutes to apply them.`nPlease save your work.`nThis reboot cannot be stopped."
    shutdown -r -f -t $delay_seconds
}


# --- Housekeeping: Clean up orphaned scheduled tasks from previous runs ---
$Global:DiagMsg += "Performing cleanup of any orphaned Datto RMM reboot tasks."
try {
    # Clean up UI tasks
    $orphanedUiTasks = Get-ScheduledTask -TaskName "DattoRMM_UINotification_*" -ErrorAction SilentlyContinue
    if ($orphanedUiTasks) {
        $orphanedUiTasks | Unregister-ScheduledTask -Confirm:$false
        $Global:DiagMsg += "Found and removed $($orphanedUiTasks.Count) orphaned UI task(s): $($orphanedUiTasks.TaskName -join ', ')"
    }
    else {
        $Global:DiagMsg += "No orphaned UI tasks found."
    }

    # Clean up Reboot tasks
    $orphanedRebootTasks = Get-ScheduledTask -TaskName "DattoRMM_ForcedReboot_*" -ErrorAction SilentlyContinue
    if ($orphanedRebootTasks) {
        $orphanedRebootTasks | Unregister-ScheduledTask -Confirm:$false
        $Global:DiagMsg += "Found and removed $($orphanedRebootTasks.Count) orphaned reboot task(s): $($orphanedRebootTasks.TaskName -join ', ')"
    }
    else {
        $Global:DiagMsg += "No orphaned reboot tasks found."
    }
}
catch {
    $Global:DiagMsg += "An unexpected error occurred during the cleanup phase: $($_.Exception.Message)"
}


# --- Set User-configurable variables from Datto RMM with defaults ---
[int]$RebootDelayMinutes = if ($env:RebootDelayMinutes) { $env:RebootDelayMinutes } else { 15 }
[string]$CompanyName = if ($env:CompanyName) { $env:CompanyName } else { "Your IT Department" }
[string]$WindowTitle = if ($env:WindowTitle) { $env:WindowTitle } else { "System Reboot Notification" }

$Global:DiagMsg += "Configuration: Reboot Delay ($($RebootDelayMinutes)min), Company ($($CompanyName)), Title ($($WindowTitle))"

# --- Logic to find the currently active user session ---
try {
    $ActiveSession = query user | Where-Object { $_ -match 'Active' } | Select-Object -First 1
    if ($ActiveSession) {
        $userColumn = ($ActiveSession.Trim() -split '\s+')[0]
        $LoggedInUser = $userColumn.TrimStart('>')
        $Global:DiagMsg += "Active user found: $LoggedInUser. Proceeding with user notification."
    }
    else {
        $Global:DiagMsg += "No active user session found."
    }
}
catch {
    $Global:DiagMsg += "Could not determine active user. Error: $($_.Exception.Message)"
}

# --- If no user is logged in, just reboot immediately and exit ---
if (-not $LoggedInUser) {
    $Global:DiagMsg += "No active user is logged on. Rebooting computer immediately."
    Restart-Computer -Force
    write-DRMMDiag $Global:DiagMsg
    Exit 0
}

# --- Create the Scheduled Task for the future reboot ---
$Global:DiagMsg += "Creating scheduled task for the guaranteed reboot."
$rebootTime = (Get-Date).AddMinutes($RebootDelayMinutes)
$rebootTaskName = "DattoRMM_ForcedReboot_$(genRandString 8)"
$rebootAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -Command `"Restart-Computer -Force`""
$rebootTrigger = New-ScheduledTaskTrigger -Once -At $rebootTime
$rebootPrincipal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest

try {
    Register-ScheduledTask -TaskName $rebootTaskName -Action $rebootAction -Trigger $rebootTrigger -Principal $rebootPrincipal -Description "Datto RMM initiated reboot. Do not delete." -Force
    $Global:DiagMsg += "Successfully registered reboot task '$rebootTaskName' to run at $rebootTime."
}
catch {
    $Global:DiagMsg += "FATAL: Failed to register reboot task. Error: $($_.Exception.Message)"
    write-DRMMDiag $Global:DiagMsg
    Exit 1
}

# --- Define UI task name and temporary script path ---
$uiTaskName = "DattoRMM_UINotification_$(genRandString 8)"
$tempScriptPath = "$env:TEMP\$($uiTaskName).ps1"

# --- Create the self-cleaning UI notification script ---
$Global:DiagMsg += "Creating UI notification script to run as user '$LoggedInUser'."
$uiScriptContent = @"
# This is a temporary, self-cleaning script launched by Datto RMM.
param (
    [string]`$TaskName
)
try {
    `$ErrorActionPreference = 'SilentlyContinue'
    Add-Type -AssemblyName PresentationFramework
    function Get-SystemUptime {
        `$osInfo = Get-WmiObject -Class Win32_OperatingSystem
        `$lastBootTime = `$osInfo.ConvertToDateTime(`$osInfo.LastBootUpTime)
        return (Get-Date) - `$lastBootTime
    }
    `$username = "`$env:USERNAME"
    `$uptime = Get-SystemUptime
    `$uptimeFormatted = "{0} days, {1} hours, and {2} minutes" -f `$uptime.Days, `$uptime.Hours, `$uptime.Minutes
    `$message = @'
Hello, this is a message from Umbrella IT Solutions.

Your computer has been running for quite some time and to ensure
optimal performance and apply important updates, a reboot is required.

Please save all your work and close any open applications now.
You can click the button below to restart immediately, or
This system WILL AUTOMATICALLY REBOOT in 15 minutes.

Thank you for your cooperation!
'@
    `$window = New-Object System.Windows.Window
    `$window.Title = '$($WindowTitle)'
    `$window.Width = 450
    `$window.Height = 375
    `$window.WindowStartupLocation = 'CenterScreen'
    `$window.Topmost = `$true
    `$window.ResizeMode = 'NoResize'
    `$dockPanel = New-Object System.Windows.Controls.DockPanel
    `$textBlock = New-Object System.Windows.Controls.TextBlock
    `$textBlock.Text = `$message
    `$textBlock.TextWrapping = "Wrap"
    `$textBlock.Margin = "15"
    [System.Windows.Controls.DockPanel]::SetDock(`$textBlock, 'Top')
    `$dockPanel.Children.Add(`$textBlock)
    `$button = New-Object System.Windows.Controls.Button
    `$button.Content = "Reboot Now"
    `$button.Width = 120
    `$button.Height = 30
    `$button.Margin = "0,0,15,15"
    `$button.HorizontalAlignment = "Right"
    `$button.Add_Click({ Restart-Computer -Force })
    [System.Windows.Controls.DockPanel]::SetDock(`$button, 'Bottom')
    `$dockPanel.Children.Add(`$button)
    `$window.Content = `$dockPanel
    [void]`$window.ShowDialog()
}
finally {
    if (-not [string]::IsNullOrEmpty(`$TaskName)) {
        Unregister-ScheduledTask -TaskName `$TaskName -Confirm:`$false
    }
    Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
}
"@
$uiScriptContent | Out-File -FilePath $tempScriptPath -Encoding utf8 -Force

# --- Schedule the UI script to run immediately as the logged-in user ---
$Global:DiagMsg += "Attempting to register and run UI task as user: $LoggedInUser"
$uiAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$tempScriptPath`" -TaskName `"$uiTaskName`""
$uiPrincipal = New-ScheduledTaskPrincipal -UserId $LoggedInUser -LogonType Interactive

try {
    Register-ScheduledTask -TaskName $uiTaskName -Action $uiAction -Principal $uiPrincipal -Description "Datto RMM UI component." -Force
    Start-ScheduledTask -TaskName $uiTaskName
    $Global:DiagMsg += "Successfully launched self-cleaning UI task '$uiTaskName'."

}
catch {
    $Global:DiagMsg += "ERROR: Failed to register or run UI notification task. This can happen if the user lacks 'Log on as a batch job' permissions. Error: $($_.Exception.Message)"
}

######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {     
    if ($Global:varUDFString.length -gt 255) {
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
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
if ($null -ne $env:APIEndpoint) {
    $Global:DiagMsg += " - Sending Results to API"
    Invoke-WebRequest -Uri $env:APIEndpoint -Method POST -Body ($APIinfoHashTable | ConvertTo-Json) -ContentType "application/json"
}
$Global:DiagMsg += "Main script finished. Reboot and UI tasks are now managed by Windows Task Scheduler."
write-DRMMDiag $Global:DiagMsg
Exit 0