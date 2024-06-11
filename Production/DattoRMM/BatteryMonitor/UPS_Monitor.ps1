#
## Template for Scripting Component Monitors for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "UPS Battery Monitoring" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation

# What to Write if Alert is Healthy
$Global:AlertHealthy = "| Last Checked $Date" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
# There is also another palce to put NO ALERT Healthy messages down below, to try and capture more script info.

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
$env:usrUDF = 6 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

<#
This is a Datto RMM Monitoring Script, used to deliver a result such as "Healthy" or "Not Healthy", in order to trigger the creation of tickets, etc.

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}
function write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
Function GenRANDString ([Int]$CharLength, [Char[]]$CharSets = "ULNS") {
    $Chars = @()
    $TokenSet = @()
    If (!$TokenSets) {
        $Global:TokenSets = @{
            U = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                # Upper case
            L = [Char[]]'abcdefghijklmnopqrstuvwxyz'                                # Lower case
            N = [Char[]]'0123456789'                                                # Numerals
            S = [Char[]]'!"#%&()*+,-./:;<=>?@[\]^_{}~'                             # Symbols
        }
    }
    $CharSets | ForEach-Object {
        $Tokens = $TokenSets."$_" | ForEach-Object { If ($Exclude -cNotContains $_) { $_ } }
        If ($Tokens) {
            $TokensSet += $Tokens
            If ($_ -cle [Char]"Z") { $Chars += $Tokens | Get-Random }             #Character sets defined in upper case are mandatory
        }
    }
    While ($Chars.Count -lt $CharLength) { $Chars += $TokensSet | Get-Random }
    ($Chars | Sort-Object { Get-Random }) -Join ""                                #Mix the (mandatory) characters and output string
};
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:AlertMsg = @() # Combined Alert message. If left blank, will not trigger Alert status. Use " $Global:AlertMsg += " to append messages to be alerted on in Datto.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 15 UN # Generate random UID for script
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$System = Get-WmiObject WIN32_ComputerSystem
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID  
#$OS = Get-CimInstance WIN32_OperatingSystem 
#$Core = Get-WmiObject win32_processor 
#$GPU = Get-WmiObject WIN32_VideoController  
#$Disk = get-WmiObject win32_logicaldisk
##################################
##################################
######## Start of Script #########

# Function to check if WMIC is available
function Test-WMIC {
    try {
        $null = wmic /? 2>$null
        return $true
    }
    catch {
        return $false
    }
}
if (-not (Test-WMIC)) {
    write-DRMMAlert "WMIC is not available on this system."
    exit 1
}
# Function to get UPS information using CIM
function Get-UPSInfo {
    try {
        # Query UPS data using CIM
        $upsInfo = Get-CimInstance -ClassName Win32_Battery
        return $upsInfo
    }
    catch {
        $Global:DiagMsg += "Failed to retrieve UPS data using CIM: $_"
        return $null
    }
}

## Generate UPS report
$upsInfo = Get-UPSInfo
if ($null -eq $upsInfo) {
    write-DRMMAlert "No UPS detected or CIM did not return any data."
    exit 1
}

# Extract relevant information
$availability = $upsInfo.Availability
$batteryStatus = [int]$upsInfo.BatteryStatus
$caption = $upsInfo.Caption
$chemistry = [int]$upsInfo.Chemistry
$designVoltage = $upsInfo.DesignVoltage
$deviceID = $upsInfo.DeviceID
$estimatedChargeRemaining = $upsInfo.EstimatedChargeRemaining
$estimatedRunTime = $upsInfo.EstimatedRunTime
$name = $upsInfo.Name
$status = $upsInfo.Status
$systemName = $upsInfo.SystemName
# Explanation of Battery codes
$batteryStatusExplanation = @{
    1 = "Discharging"
    2 = "Charging"
    3 = "Fully charged"
}
$chemistryExplanation = @{
    1 = "Other"
    2 = "Unknown"
    3 = "Lead Acid"
    4 = "Nickel Cadmium"
    5 = "Nickel Metal Hydride"
    6 = "Lithium-ion"
    7 = "Zinc Air"
    8 = "Lithium Polymer"
}
# Extract numeric value from DeviceID and append "VA"
$vaRating = if ($deviceID -match '\d+') { "$($matches[0])VA" } else { "Unknown" }
# Get battery status explanation or default to "Unknown"
$batteryStatusDesc = if ($batteryStatusExplanation.ContainsKey($batteryStatus)) { $batteryStatusExplanation[$batteryStatus] } else { "Unknown" }
# Get chemistry explanation or default to "Unknown"
$chemistryDesc = if ($chemistryExplanation.ContainsKey($chemistry)) { $chemistryExplanation[$chemistry] } else { "Unknown" }

# Create the report string
$Global:DiagMsg += " "
$Global:DiagMsg += "Health: $status"
$Global:DiagMsg += "Battery Status: $batteryStatus ($batteryStatusDesc)"
$Global:DiagMsg += "Estimated Charge Remaining: $estimatedChargeRemaining %"
$Global:DiagMsg += "Estimated Run Time: $estimatedRunTime minutes"
$Global:DiagMsg += " "
$Global:DiagMsg += "Model: $name"
$Global:DiagMsg += "VA Rating: $vaRating"
$Global:DiagMsg += "Chemistry: $chemistry ($chemistryDesc)"
$Global:DiagMsg += "Design Voltage: $designVoltage mV"
$Global:DiagMsg += "Device ID: $deviceID"

# Check UPS Status
if ($status -ne "OK") {
    $Global:AlertMsg += "$chemistryDesc $vaRating UPS $status | Check Diagnostic Log"
}

if ($Global:AlertMsg) {
    # Display Alert in UDF if there is Alert
    $Global:varUDFString += $Global:AlertMsg
}
else {
    # Display UPS Info in UDF if UPS Detected
    $Global:varUDFString += "$chemistryDesc $name $vaRating UPS $status | $batteryStatusDesc $estimatedChargeRemaining % | Runtime: $estimatedRunTime minutes $Global:AlertHealthy"
}


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
    write-DRMMAlert "$chemistryDesc $vaRating UPS $status $Global:AlertHealthy"
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}