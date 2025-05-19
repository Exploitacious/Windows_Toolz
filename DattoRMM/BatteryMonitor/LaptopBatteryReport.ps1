## Laptop Battery Monitoring Script
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Battery Monitoring" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation

# What to Write if Alert is Healthy
$Global:AlertHealthy = "| Last Measured $Date" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
# There is also another palce to put NO ALERT Helthy messages down below, to try and capture more script info.

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:usrString = Example # Datto User Input variable "usrString"
$env:batteryReportPath = "C:\Temp\BatteryReport\Battery-Report.html" # Define the path for the battery report
$env:cycleCountThresh = 100 # Alert if Battery is greater than this many cycles
$env:degradeThresh = 10 # Percentage. Alert if battery degredation is beyond xx%
#$env:usrUDF = 14 # UDF to write info to

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

# Create the directory if it doesn't exist
if (-not (Test-Path -Path "C:\Temp\BatteryReport")) {
    New-Item -ItemType Directory -Path "C:\Temp\BatteryReport"
}

# Function to check if powercfg is available
function Test-PowerCfg {
    try {
        $null = powercfg /? 2>$null
        return $true
    }
    catch {
        return $false
    }
}

# Check if powercfg is available
if (-not (Test-PowerCfg)) {
    $Global:AlertMsg += "powercfg is not available on this system."
}
else {
    $Global:DiagMsg += "Full Battery Report Here: $env:batteryReportPath"
}

# Generate the battery report
powercfg /batteryreport /output $env:batteryReportPath

# Wait for the report to be generated
Start-Sleep -Seconds 5

# Extract and read the information from the battery report
$reportContent = Get-Content -Path $env:batteryReportPath -Raw

# Extract the information using regex
$designCapacity = [regex]::Match($reportContent, 'DESIGN CAPACITY.*?(\d+,?\d*) mWh').Groups[1].Value -replace ',', ''
$fullChargeCapacity = [regex]::Match($reportContent, 'FULL CHARGE CAPACITY.*?(\d+,?\d*) mWh').Groups[1].Value -replace ',', ''
$cycleCount = [regex]::Match($reportContent, 'CYCLE COUNT.*?(\d+)').Groups[1].Value
$biosDate = [regex]::Match($reportContent, 'BIOS\s*.*?(\d{2}/\d{2}/\d{4})').Groups[1].Value

# Calculate the degradation percentage
$degradationPercentage = [math]::Round((1 - ($fullChargeCapacity / $designCapacity)) * 100, 2)
$remainingPercentage = 100 - $degradationPercentage

# Parse the BIOS date flexibly
$biosDateTime = [datetime]::ParseExact($biosDate, 'MM/dd/yyyy', $null)

# Calculate the estimated battery age based on the BIOS date
$currentDateTime = Get-Date
$batteryAgeDays = ($currentDateTime - $biosDateTime).Days
$batteryAgeYears = [math]::Round($batteryAgeDays / 365, 2)

# Create a report strings
$Global:DiagMsg += "Battery Design Capacity: $designCapacity mWh"
$Global:DiagMsg += "Current Max Charge Capacity: $fullChargeCapacity mWh"
$Global:DiagMsg += "Estimated Battery Degradation: $degradationPercentage %"
$Global:DiagMsg += "Max Battery Capacity: $remainingPercentage %"
$Global:DiagMsg += "Estimated Battery Age based on BIOS: $batteryAgeYears years ($batteryAgeDays days)"
$Global:DiagMsg += "Lifetime Recharge Cycle Count: $cycleCount"

# Test strings for Alerts
if ($cycleCount -gt $env:cycleCountThresh) {
    $Global:AlertMsg += "Battery has surpassed a Recharge Cycle Count of $env:cycleCountThresh "
    $Global:DiagMsg += "Battery Health has surpassed the set limits of: $env:cycleCountThresh total recharge cycles ($cycleCount)"
}
else {
    $Global:DiagMsg += "Lifetime Recharge Cycle Count ($cycleCount) is below threshold of $env:cycleCountThresh"
}

if ($degradationPercentage -gt $env:degradeThresh) {
    $Global:AlertMsg += "Battery has surpassed the degredation threshold of $env:degradeThresh % "
    $Global:DiagMsg += "The Battery has degraded beyond $env:degradeThresh % ($degradationPercentage %)"
}
else {
    $Global:DiagMsg += "Estimated Battery Degradation ($degradationPercentage %) is below threshold of $env:degradeThresh %"
}

#UDF Result
$Global:varUDFString += "Battery is $remainingPercentage % of Original Capacity with $cycleCount Total Recharge Cycles $Global:AlertHealthy"

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
    write-DRMMAlert "Battery is $remainingPercentage % of Original Capacity with $cycleCount Total Recharge Cycles $Global:AlertHealthy"
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}
