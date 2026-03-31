#
## Template for Scripting Component Monitors for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Monitor - System Uptime" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation
$Date = get-date -Format "MM/dd/yyy hh:mm tt"

# What to Write if Alert is Healthy
$Global:AlertHealthy = "System uptime is within the defined threshold. | Last Checked $Date" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
# There is another palce to put NO ALERT Healthy messages down below, to try and capture more script info.

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:usrUDF = 15 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:UptimeThresholdDays = 7 # Datto User Input variable "UptimeThresholdDays"

<#
This is a Datto RMM Monitoring Script, used to deliver a result such as "Healthy" or "Not Healthy", in order to trigger the creation of tickets, etc.

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

Datto RMM Variables to be created for this component:
1. UptimeThresholdDays (Type: Number) - The maximum number of days a system can be online before an alert is triggered. Default: 7
2. usrUDF (Type: Number) - Optional. The UDF number to write the current uptime string to.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
function write-DRMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:AlertMsg = @() # Combined Alert message. If left blank, will not trigger Alert status. Use " $Global:AlertMsg += " to append messages to be alerted on in Datto.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########

function Get-SystemUptime {
    <#
    .SYNOPSIS
        Calculates the total time the system has been running since the last boot.
    .OUTPUTS
        [System.TimeSpan] An object representing the system's uptime.
    #>
    try {
        # Retrieve operating system information using WMI (Windows Management Instrumentation).
        $osInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop

        # Convert the LastBootUpTime property to a PowerShell DateTime object.
        $lastBootTime = $osInfo.ConvertToDateTime($osInfo.LastBootUpTime)

        # Calculate the difference between the current time and the last boot time.
        $uptime = (Get-Date) - $lastBootTime

        # Return the calculated uptime as a TimeSpan object.
        return $uptime
    }
    catch {
        # If WMI fails, write an error and return a zero TimeSpan.
        $Global:DiagMsg += "ERROR: Failed to retrieve system uptime. Error: $($_.Exception.Message)"
        return (New-TimeSpan -Seconds 0)
    }
}

# Check for the threshold variable, provide a default if it doesn't exist.
if (-not $env:UptimeThresholdDays) {
    $Global:DiagMsg += "UptimeThresholdDays variable not found. Using default of 7 days."
    $UptimeThresholdDays = 7
}
else {
    $UptimeThresholdDays = [int]$env:UptimeThresholdDays
}

$Global:DiagMsg += "Uptime threshold is set to $UptimeThresholdDays days."

# Get the current system uptime
$uptime = Get-SystemUptime
$uptimeFormatted = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
$Global:DiagMsg += "Current system uptime is $uptimeFormatted."

# Write uptime to UDF string
$Global:varUDFString += $uptimeFormatted

# Compare uptime days with the threshold
if ($uptime.Days -ge $UptimeThresholdDays) {
    $Global:AlertMsg += "REBOOT REQUIRED: System uptime of $($uptime.Days) days exceeds the threshold of $UptimeThresholdDays days."
}
else {
    $Global:AlertHealthy = "System uptime of $uptimeFormatted is within the $UptimeThresholdDays-day threshold. | Last Checked $Date"
}

######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {     
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Exit script with proper Datto alerting, diagnostic and API Results.
#######################################################################
if ($Global:AlertMsg) {
    # If your AlertMsg has value, this is how it will get reported.
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-DRMMAlert $Global:AlertMsg
    write-DRMMDiag $Global:DiagMsg

    # Exit 1 means DISPLAY ALERT
    Exit 1
}
else {
    # If the AlertMsg variable is blank (nothing was added), the script will report healthy status with whatever was defined above.
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"

    ##### You may alter the NO ALERT Exit Message #####
    write-DRMMAlert "$Global:AlertHealthy"
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}