#
## DNS Filter Health Monitor for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "DNS Filter Monitor" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation

# What to Write if Alert is Healthy
# $Global:AlertHealthy = " | DNS Filter is Healthy" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
# There is also another palce to put NO ALERT Healthy messages down below, to try and capture more script info.

<###
DNS Filter Software Monitor by Alex Ivantsov
@Exploitacious
Alex@ivantsov.tech

Sounds an alert if DNS Filter has not checked in for over 24 hours or is not running.
Sounds alert and triggers uninstall process if agent is not healthy or unregistered from dashboard.
Provides option to automatically re-install DNSFilter (will be added in future revision)

- Queries the Registry under the Software / DNS Filter / LastAPISync and Registered key 
- Does logic...
- Restarts the service
- Performs an uninstall if anything is not perfect.
- Fires actionable alert through Datto RMM

- Deploy as a DattoRMM MONITOR
- Will return Alert and Diagnostic value if product was uninstalled or is missing

Facts:
- The correct version to be running is version 'DNS Agent', NOT DNSFilter Agent
- Reg Keys should only be in HKLM:Software\DNSAgent\Agent, nowhere else.

#>

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
#if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

<#
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

### Software To Discover
$ENV:softwareName = "DNS Agent"
$ENV:method = 'EQ'

#Reset Variables
$varCounter = 0
$Detection = @()
$DetectionLocation = ""
$DetectedData = @()

### Evaluate DNS Filter Agent Health
function EvalDNSFSync {
    # Requires $SyncDateTime variable to be defined 
    try {
        # Grab and convert the last sync Date / Time to PS 'datetime'
        $culture = [System.Globalization.CultureInfo]::InvariantCulture  
        $SyncDateTime = [datetime]::ParseExact($Global:LastSync, 'yyyy-MM-dd HH:mm:ss', $culture).ToString('dd/MM/yyyy hh:mm:ss tt')

        # Grab and compare the current Date / Time
        $CurrentDateTime = Get-Date -Format "dd/MM/yyyy hh:mm:ss tt"
        $Global:ElapsedTime = New-TimeSpan -Start $SyncDateTime -End $CurrentDateTime
        $Global:ElapsedHours = [math]::round($Global:ElapsedTime.TotalHours, 2)
    }
    catch {
        $Global:DiagMsg += "Something unnexptected happened when attempting to calculate sync elapsed time."
        $Global:Status = 2
    }

    If ($Global:ElapsedHours -ge 8) {
        $Global:DiagMsg += "Sync difference is greater than 8 hours. Diagnosing..."
        $Global:Status = 1
    }
    else {
        $Global:DiagMsg += "Last sync $Global:ElapsedHours hour(s) ago."
        $Global:Status = 0
    }
}

#check for software
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

#UninstallDNSFilter
function Uninstall-App {
    $Global:DiagMsg += "Uninstalling $($args[0])"
    foreach ($obj in Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") {
        $dname = $obj.GetValue("DisplayName")
        if ($dname -contains $args[0]) {
            $uninstString = $obj.GetValue("UninstallString")
            foreach ($line in $uninstString) {
                $found = $line -match '(\{.+\}).*'
                If ($found) {
                    $appid = $matches[1]
                    start-process "msiexec.exe" -arg "/X $appid /qb" -Wait
                    $Global:DiagMsg += "Successfully removed $appid"
                }
            }
        }
    }
    start-sleep 5
    Remove-Item -ErrorAction SilentlyContinue -Path "HKLM:\Software\DNSFilter" -Recurse
    Remove-Item -ErrorAction SilentlyContinue -Path "HKLM:\Software\DNSAgent" -Recurse
}

# Results for Diag
Write-Host
$Global:DiagMsg += "Detected: $($result.Detected)"
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

### Detection Result
$result = Check-SoftwareInstall -SoftwareName $ENV:softwareName -Method $ENV:method
###


#############################################

Write-Host " || DNS Filter Health Check || "
Write-Host "Check the alerts and diagnostics for full details and output"

$Global:DiagMsg += " || DNS Filter Health Check || "
$Global:DiagMsg += "Running Diagnostic on DNS Filter Agent"

#############################################

$DNSAExists = Test-Path "HKLM:\SOFTWARE\DNSAgent\Agent"
$DNSFExists = Test-Path "HKLM:\SOFTWARE\DNSFilter\Agent"

if ($DNSAExists -eq $DNSFExists) {
    $Global:DiagMsg += "Discovered both DNSF and DNSA Agents.."
    $Global:DiagMsg += "Agents are double-installed."
    $Global:Status = 3
}
else {
    if ($DNSAExists) {
        # Correct Version for MSP's
        $AgentVersion = Get-ItemPropertyValue "HKLM:\SOFTWARE\DNSAgent\Agent" -Name Version
        $Global:DiagMsg += "Correct DNS Agent is present. Version $AgentVersion"
    }
    if ($DNSFExists) {
        # Incorrect Version for MSP's
        $Global:DiagMsg += "Incorrect version (DNSF Agent) is present."
        $Global:Status = 2
    }
}

if ($Global:Status -le 1) {
    try {
        $Global:Registration = Get-ItemPropertyValue "HKLM:\SOFTWARE\DNSAgent\Agent" -Name Registered -ErrorAction Stop
        $Global:LastSync = Get-ItemPropertyValue "HKLM:\SOFTWARE\DNSAgent\Agent" -Name LastAPISync -ErrorAction Stop

        if ($Global:Registration -eq 1) {
            $Global:DiagMsg += "Dashboard Registration state is valid."
            $Global:Status = 0
        }
        else {
            $Global:DiagMsg += "Dashboard Registration is orphaned."
            $Global:Status = 1
        }

        if ($Global:LastSync.Length -le 0) {
            $Global:DiagMsg += "Unable to gather a 'last Sync Date'"
            $Global:Status = 1
        }
        else {
            EvalDNSFSync
        }
    }
    catch {
        # Software is not installed / Key unavailable.
        $Global:DiagMsg += "DNS Filter Software may not be installed. Diagnosing..."
        $Global:Status = 1
    }
}

## Write Output/Alert or Troubleshoot

if ($Global:Status -eq 3) {
    $Global:DiagMsg += "Uninstalling double-agents.."
    # Uninstall-App "DNSFilter Agent"
    # Uninstall-App "DNS Agent"
    # write-DRMMAlert "DNS Filter Agents are double-installed."
    write-DRMMDiag $Global:DiagMsg
    exit 1
}
elseif ($Global:Status -eq 2 -or $null) {
    $Global:DiagMsg += "Attempting uninstall and quitting.."
    #Uninstall-App "DNSFilter Agent"
    #Uninstall-App "DNS Agent"
    #write-DRMMAlert "Agent Troubled. Review diagnostic log."
    write-DRMMDiag $Global:DiagMsg
    exit 1
}
elseif ($Global:Status -eq 0) {
    $Global:DiagMsg += "DNSF Agent is healthy. Quitting.."
    write-DRMMAlert "Agent Healthy, last sync: $Global:ElapsedHours hour(s) ago."
    write-DRMMDiag $Global:DiagMsg
    exit 0
}

## If Status is 1, troubleshoot failures.
elseif ($Global:Status -eq 1) {

    # Evaluate DNSF Filter Service / Run uninstalls in case not found.
    try {
        $DNSAgentService = get-service "DNS Agent" -ErrorAction Stop
    } 
    # Failure to find DNS Agent Service..
    catch {
        $Global:DiagMsg += "Failure to find the 'DNS Agent' Service on this machine."
        $Global:DiagMsg += "Checking for 'DNS Filter Agent' Service instead, the incorrect version.."
        try {
            # Uninstall everything.
            $DNSFService = get-service "DNSFilter Agent" -ErrorAction Stop
            $Global:DiagMsg += "Incorrect version(s) found. Running Uninstall.."
            #Uninstall-App "DNSFilter Agent"
            #Uninstall-App "DNS Agent"
            write-DRMMAlert "Agent Troubled. Review diagnostic log."
            write-DRMMDiag $Global:DiagMsg
            exit 1
        }
        catch {
            # Abandon script if no services found.
            $Global:DiagMsg += "Unable to find any DNSF Agent Services on this machine. Quitting.."
            write-DRMMAlert "Agent Troubled. Review diagnostic log."
            write-DRMMDiag $Global:DiagMsg
            exit 1
        }
    }
            
    # If Services are running...
    if ($DNSAgentService.status -eq "Running") {
        # Service running but no sync date found. Restart service and re-try sync..
        $Global:DiagMsg += "Agent service reported good health. Restarting Service.."
        Restart-Servce $DNSAgentService
        Start-Sleep 5
        $Global:DiagMsg += "Service restarted. Re-evaluating Sync status.."
        try {
            # Evaluate the last-sync date again, quit if still not found.
            $Global:Registration = Get-ItemPropertyValue "HKLM:\SOFTWARE\DNSAgent\Agent" -Name Registered -ErrorAction Stop
            $Global:LastSync = Get-ItemPropertyValue "HKLM:\SOFTWARE\DNSAgent\Agent" -Name LastAPISync -ErrorAction Stop
            if ($Global:Registration -eq 1) {
                $Global:DiagMsg += "Dashboard Registration state is valid."
            }
            else {
                $Global:DiagMsg += "Dashboard Registration is orphaned."
                $Global:DiagMsg += "Still, unable to gather a valid Dashboard Registration. Uninstalling.."
                #Uninstall-App "DNSFilter Agent"
                #Uninstall-App "DNS Agent"
                write-DRMMAlert "Agent Troubled. Review diagnostic log."
                write-DRMMDiag $Global:DiagMsg
                exit 1
            }

            if ($Global:LastSync.Length -le 0) {
                $Global:DiagMsg += "Still, unable to gather a 'last Sync Date'. Uninstalling.."
                #Uninstall-App "DNSFilter Agent"
                #Uninstall-App "DNS Agent"
                write-DRMMAlert "Agent Troubled. Review diagnostic log."
                write-DRMMDiag $Global:DiagMsg
                exit 1
            }
            else {
                EvalDNSFSync
            }
            
        }
        catch {
            $Global:DiagMsg += "DNS Filter service is running but may be corrupt. Uninstalling.."
            #Uninstall-App "DNSFilter Agent"
            #Uninstall-App "DNS Agent"
            write-DRMMAlert "Agent Troubled. Review diagnostic log."
            write-DRMMDiag $Global:DiagMsg
            exit 1
        }
    }

    # DNS Filter Services are stopped or unknown..
    else {
        $Global:DiagMsg += "Agent service reported stopped or unknown. Re-starting Service.."
        try {
            Start-Servce $DNSAgentService -ErrorAction Stop
            Start-Sleep 5
            $Global:DiagMsg += "Service restarted. Re-evaluating Sync status.."
            try {
                # Evaluate the last-sync date again, quit if still not found.
                $Global:LastSync = Get-ItemPropertyValue "HKLM:\SOFTWARE\DNSAgent\Agent" -Name LastAPISync -ErrorAction Stop
                if ($Global:LastSync.Length -le 0) {
                    $Global:DiagMsg += "Still, unable to gather a 'last Sync Date'. Troubleshoot DNS Filter Service manually. Quitting.."
                    #Uninstall-App "DNSFilter Agent"
                    #Uninstall-App "DNS Agent"
                    write-DRMMAlert "Agent Troubled. Review diagnostic log."
                    write-DRMMDiag $Global:DiagMsg
                    exit 1
                }
                else {
                    EvalDNSFSync
                }
            }
            catch {
                # Uninstall if not able to re-start service.
                $Global:DiagMsg += "Unable to start service. DNS Filter service may be corrupt. Uninstalling.."
                #Uninstall-App "DNSFilter Agent"
                #Uninstall-App "DNS Agent"
                write-DRMMAlert "Agent Troubled. Review diagnostic log."
                write-DRMMDiag $Global:DiagMsg
                exit 1
            } 
        }
        catch {
            # Uninstall if not able to re-start service.
            $Global:DiagMsg += "Unable to start service. DNS Filter service may be corrupt. Uninstalling.."
            #Uninstall-App "DNSFilter Agent"
            #Uninstall-App "DNS Agent"
            write-DRMMAlert "Agent Troubled. Review diagnostic log."
            write-DRMMDiag $Global:DiagMsg
            exit 1
        }
    }

    ## Write Output and end.

    if ($Global:Status -eq 0) {
        $Global:DiagMsg += "DNSF Agent is healthy."
        write-DRMMAlert "Agent Healthy, last sync: $Global:ElapsedHours hour(s) ago."
        write-DRMMDiag $Global:DiagMsg
        exit 0
    }
    elseif ($Global:Status -eq 2 -or 1) {
        $Global:DiagMsg += "Failure to diagnose. DNS Filter service may be corrupt. Uninstalling.."
        #Uninstall-App "DNSFilter Agent"
        #Uninstall-App "DNS Agent"
        write-DRMMAlert "Agent Troubled. Review diagnostic log."
        write-DRMMDiag $Global:DiagMsg
        exit 1
    }

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
    write-DRMMAlert "No Alert Message Here $Global:AlertHealthy"
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}