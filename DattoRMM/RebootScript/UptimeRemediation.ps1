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

# --- Set User-configurable variables from Datto RMM with defaults ---
[int]$RebootDelayMinutes = if ($env:RebootDelayMinutes) { $env:RebootDelayMinutes } else { 15 }
[string]$CompanyName = if ($env:CompanyName) { $env:CompanyName } else { "Your IT Department" }
[string]$WindowTitle = if ($env:WindowTitle) { $env:WindowTitle } else { "System Reboot Notification" }

$Global:DiagMsg += "Configuration: Reboot Delay ($($RebootDelayMinutes)min), Company ($($CompanyName)), Title ($($WindowTitle))"

# --- Logic to find the currently active user session ---
try {
    # Query all terminal sessions, find the one that is "Active" and take the first result
    $ActiveSession = query user | Where-Object { $_ -match 'Active' } | Select-Object -First 1
    
    if ($ActiveSession) {
        # FIXED: This new parsing logic is simple and robust.
        # It takes the first block of text (which is '>username' or 'username') and removes the leading '>' if it exists.
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
    # This part of the script will not be reached, but is included for clarity
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
    # Exit here since the primary goal failed
    write-DRMMDiag $Global:DiagMsg
    Exit 1
}


# --- Create and launch the UI notification in the user's session ---
$Global:DiagMsg += "Creating UI notification script to run as user '$LoggedInUser'."
$uiScriptContent = @"
# This is a temporary script launched by Datto RMM to display a reboot notification.
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
    `$message = @"
    Hello `$username,
    
    This is a message from your system administrators at '$($CompanyName)'.
    
    Your computer has been running for `$uptimeFormatted.
    To ensure optimal performance and apply important updates, a reboot is now required.
    
    This system WILL AUTOMATICALLY REBOOT in $($RebootDelayMinutes) minutes.
    
    Please save all your work and close any open applications now.
    You can click the button below to restart immediately, otherwise this window can be closed.
    
    Thank you for your cooperation!
    "@
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
"@

$tempScriptPath = "$env:TEMP\datto_ui_notify.ps1"
$uiScriptContent | Out-File -FilePath $tempScriptPath -Encoding utf8 -Force

# --- Schedule the UI script to run immediately as the logged-in user ---
# NOTE: This requires the target user ($LoggedInUser) to have "Log on as a batch job" rights.
# Administrator accounts have this by default. If targeting standard users, this step may fail.
$Global:DiagMsg += "Attempting to register and run UI task as user: $LoggedInUser"
$uiTaskName = "DattoRMM_UINotification_$(genRandString 8)"
$uiAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$tempScriptPath`""
$uiPrincipal = New-ScheduledTaskPrincipal -UserId $LoggedInUser -LogonType Interactive

try {
    Register-ScheduledTask -TaskName $uiTaskName -Action $uiAction -Principal $uiPrincipal -Description "Datto RMM UI component." -Force
    Start-ScheduledTask -TaskName $uiTaskName
    $Global:DiagMsg += "Successfully launched UI task '$uiTaskName'."
    Start-Sleep -s 2
    Unregister-ScheduledTask -TaskName $uiTaskName -Confirm:$false
    $Global:DiagMsg += "Cleaned up UI task '$uiTaskName'."
}
catch {
    # FIXED: Corrected the variable escaping to ensure the actual error message is logged.
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
# Exit with writing diagnostic back to the ticket / remediation component log
$Global:DiagMsg += "Main script finished. Reboot and UI tasks are now managed by Windows Task Scheduler."
write-DRMMDiag $Global:DiagMsg
Exit 0