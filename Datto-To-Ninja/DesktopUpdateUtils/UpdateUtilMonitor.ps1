#
## Template for Scripting Component Monitors for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Manufacturer Update Utility Monitor" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation
$Date = get-date -Format "MM/dd/yyy hh:mm tt"

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Healthy: Update Utility Installed" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
# There is another place to put NO ALERT Healthy messages down below, to try and capture more script info.

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ##
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.

<#
This is a Datto RMM Monitoring Script. It checks the device manufacturer and verifies if the corresponding
update utility (e.g., Dell Command | Update, HP Image Assistant) is installed. If the utility is missing on
a supported manufacturer's device, it will raise an alert.
#>
# DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
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

try {
    # Get a list of all installed programs from the registry for both 32-bit and 64-bit applications
    $installedPrograms = @()
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($path in $registryPaths) {
        $installedPrograms += Get-ItemProperty $path -ErrorAction SilentlyContinue | Select-Object DisplayName
    }
    
    # Determine the computer manufacturer
    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    $Global:DiagMsg += "Detected Manufacturer: $manufacturer"
    
    # Define the application name to check for based on manufacturer
    $appNameToCheck = $null
    switch -Wildcard ($manufacturer) {
        "*Dell*" { $appNameToCheck = "Dell Command | Update" }
        "*LENOVO*" { $appNameToCheck = "Lenovo System Update" }
        "*HP*" { $appNameToCheck = "HP Image Assistant" }
        "*Microsoft*" { $appNameToCheck = "Surface Diagnostic Toolkit for Business" }
        default {
            $Global:DiagMsg += "Manufacturer '$manufacturer' is not supported by this monitor. No action required."
            $Global:varUDFString = "Unsupported Manufacturer"
        }
    }
    
    # If the manufacturer is supported, check if the application is installed
    if ($appNameToCheck) {
        $Global:DiagMsg += "Checking for the presence of '$appNameToCheck'."
        
        $appFound = $installedPrograms | Where-Object { $_.DisplayName -like "*$appNameToCheck*" }
        
        if ($appFound) {
            $Global:DiagMsg += "Success: '$appNameToCheck' was found installed."
            $Global:varUDFString = "Installed: $appNameToCheck"
            # No alert message is added, so the script will exit as Healthy
        }
        else {
            $Global:DiagMsg += "Alert: '$appNameToCheck' was NOT found."
            $Global:AlertMsg += "Missing Utility: $appNameToCheck is not installed on this $manufacturer device."
            $Global:varUDFString = "Missing: $appNameToCheck"
        }
    }
}
catch {
    $Global:DiagMsg += "An unexpected error occurred during check: $($_.Exception.Message)"
    $Global:AlertMsg += "Script Error: Failed to complete check. See diagnostic log."
    $Global:varUDFString = "Script Error"
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
    $healthyStatusMessage = "$Global:AlertHealthy | $($Global:varUDFString) | Last Checked $Date"
    write-DRMMAlert $healthyStatusMessage
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}