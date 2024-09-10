#
## Software Detection Monitor for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

### Examples Usage (DRMM Variables - Blank out in production component)
#$ENV:softwareName = "SNAPAGENT"
#$ENV:method = 'EQ'

# Script Name and Type
$ScriptName = "Software Detection Monitor" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation

# What to Write if Alert is Healthy
$Global:AlertHealthy = "$ENV:softwareName | Last Checked $Date" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
# There is also another palce to put NO ALERT Healthy messages down below, to try and capture more script info.

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

<#
Sounds an alert if software identifying a known string IS or IS NOT discovered. 
Can be configured with a response Component to install the software in question. Drop in your software search term into the usrString Variable.

Env Strings for Testing, but otherwise only configured in Datto RMM:
$env:usrString = "SNAP"
$env:usrMethod = 'EQ'  # Use 'EQ' to Alert if FOUND, and 'NE' to Alert if MISSING.

To test:
Let's say you're looking for a specific Adobe install. Jump on a computer where you KNOW it's installed, and confirm the script will find exactly what you're looking for by doing the following:
Open Powershell and run this below piece of code, replacing the "$varString" variable with the name of whatever software you're looking for:

Get-ChildItem ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE") | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName, $_.BrandName -match "$varString" }

Get as specific as you can with your searches. In case there are multiple results displayed for "adobe", try to search and match exactly what you're seeking - from the "BrandName" or "DisplayName" of the app displayed.

This is a Datto RMM Monitoring Script, used to deliver a result such as "Healthy" or "Not Healthy", in order to trigger the creation of tickets, etc.

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

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
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########

#Reset Variables
$varCounter = 0
$Detection = @()
$DetectionLocation = ""
$DetectedData = @()

function Check-SoftwareInstall {
    param (
        [string]$ENV:softwareName,
        [string]$ENV:method
    )

    # Registry paths to search
    $regPaths = @(
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE"
    )

    foreach ($regPath in $regPaths) {
        $foundItems = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | ForEach-Object { 
            Get-ItemProperty $_.PSPath 
        } | Where-Object { $_.DisplayName -match "$ENV:softwareName" -or $_.BrandName -match "$ENV:softwareName" }

        if ($foundItems) {
            foreach ($foundItem in $foundItems) {
                $varCounter++

                # Store the display name
                $Detection += $foundItem.DisplayName

                # Store the registry path where the software was found
                $DetectionLocation = $regPath

                # Capture relevant details about the software
                $DetectedData += [PSCustomObject]@{
                    DisplayName     = $foundItem.DisplayName
                    Publisher       = $foundItem.Publisher
                    Version         = $foundItem.DisplayVersion
                    InstallDate     = $foundItem.InstallDate
                    InstallLocation = $foundItem.InstallLocation
                    UninstallString = $foundItem.UninstallString
                    RegistryPath    = $regPath
                }
            }
        }
    }

    # Return detected state and relevant data
    if ($ENV:method -eq 'EQ') {
        return @{
            Detected     = ($varCounter -ge 1)
            Location     = $DetectionLocation
            DetectedData = $DetectedData
        }
    }
    elseif ($ENV:method -eq 'NE') {
        return @{
            Detected     = ($varCounter -ge 1)
            Location     = $DetectionLocation
            DetectedData = $DetectedData
        }
    }
    else {
        throw "Invalid method. Please use 'EQ' or 'NE'."
    }
}

# Results for Diag
Write-Host
$Global:DiagMsg += "`nDetected: $($result.Detected)"
Write-Host
$result.DetectedData | ForEach-Object { 
    $Global:DiagMsg += "Display Name: $($_.DisplayName)"
    $Global:DiagMsg += "Publisher: $($_.Publisher)"
    $Global:DiagMsg += "`nVersion: $($_.Version)"
    $Global:DiagMsg += "Install Date: $($_.InstallDate)"
    $Global:DiagMsg += "Install Location: $($_.InstallLocation)"
    $Global:DiagMsg += "Uninstall String: $($_.UninstallString)"
    $Global:DiagMsg += "Registry Path: $($_.RegistryPath)"
}

# Results for Alert
if ($result.Detected) {
    # If software is detected
    if ($ENV:method -eq 'EQ') {
        # If method is EQ and software is detected, all is good. No alert needed.
        $Global:DiagMsg += "Detected software: $ENV:softwareName - all is good. No alert needed."
    }
    elseif ($ENV:method -eq 'NE') {
        # If method is NE and software is detected, alert because it shouldn't be there.
        $Global:DiagMsg += "Software '$ENV:softwareName' was detected, but it should not be installed."
        $Global:AlertMsg = "Detected software: $ENV:softwareName | Last Checked $Date"
    }
}
else {
    # If software is not detected
    if ($ENV:method -eq 'EQ') {
        # If method is EQ and software is NOT detected, alert because it should be installed.
        $Global:DiagMsg += "Software '$ENV:softwareName' was not detected, but it should be installed."
        $Global:AlertMsg = "Missing software: $ENV:softwareName | Last Checked $Date"
    }
    elseif ($ENV:method -eq 'NE') {
        # If method is NE and software is NOT detected, all is good. No alert needed.
        $Global:DiagMsg += "Software: $ENV:softwareName - not detected, as expected. No alert needed."
    }
}


### Result
$result = Check-SoftwareInstall -SoftwareName $ENV:softwareName -Method $ENV:method
Write-Host $varCounter
###


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
    write-DRMMAlert " $Global:AlertHealthy"
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}