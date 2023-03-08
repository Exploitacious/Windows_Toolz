<###
DNS Filter Software Monitor by Alex Ivantsov

Sounds an alert if DNS Filter has not checked in for over 24 hours or is not running.
Sounds alert and triggers uninstall process if agent is not healthy or unregistered from dashboard.
Provides option to automatically re-install DNSFilter (will be added in future revision)

- Queries the Registry under the Software / DNS Filter / LastAPISync and Registered key 
- Does logic...
- Restarts the service
- Performs an uninstall if anything is not perfect.
- Fires actionable alert through Datto RMM

Facts:
- The correct version to be running is version 'DNS Agent', NOT DNSFilter Agent
- Reg Keys should only be in HKLM:Software\DNSAgent\Agent, nowhere else.

#>

# Verify Admin Session
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

# Automatic Reinstall? Comment this out for Datto RMM Component
$Global:Reinstall = $True

# Set Diagnostic Log & Status
$Global:DiagMsg = @()
$Global:Status = 0
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    Write-Host '<-End Diagnostic->'
}
function write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "Alert=$message"
    Write-Host '<-End Result->'
}

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
        $Global:DiagMsg += "Something unnexptected happened. Check the last sync time manually and make sure you can 'get-Date' with Powershell"
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

#############################################

Write-Host "DNS Filter Health Check"

$Global:DiagMsg += "Running Diagnostic on DNS Filter Agent"

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

## Write Output or Troubleshoot

if ($Global:Status -eq 2 -or $null) {
    $Global:DiagMsg += "Failure to diagnose. Attempting uninstall and quitting.."
    Uninstall-App "DNSFilter Agent"
    Uninstall-App "DNS Agent"
    write-DRMMAlert "Agent Troubled. Review diagnostic log."
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
            Uninstall-App "DNSFilter Agent"
            Uninstall-App "DNS Agent"
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
                Uninstall-App "DNSFilter Agent"
                Uninstall-App "DNS Agent"
                write-DRMMAlert "Agent Troubled. Review diagnostic log."
                write-DRMMDiag $Global:DiagMsg
                exit 1
            }

            if ($Global:LastSync.Length -le 0) {
                $Global:DiagMsg += "Still, unable to gather a 'last Sync Date'. Uninstalling.."
                Uninstall-App "DNSFilter Agent"
                Uninstall-App "DNS Agent"
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
            Uninstall-App "DNSFilter Agent"
            Uninstall-App "DNS Agent"
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
                    Uninstall-App "DNSFilter Agent"
                    Uninstall-App "DNS Agent"
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
                Uninstall-App "DNSFilter Agent"
                Uninstall-App "DNS Agent"
                write-DRMMAlert "Agent Troubled. Review diagnostic log."
                write-DRMMDiag $Global:DiagMsg
                exit 1
            } 
        }
        catch {
            # Uninstall if not able to re-start service.
            $Global:DiagMsg += "Unable to start service. DNS Filter service may be corrupt. Uninstalling.."
            Uninstall-App "DNSFilter Agent"
            Uninstall-App "DNS Agent"
            write-DRMMAlert "Agent Troubled. Review diagnostic log."
            write-DRMMDiag $Global:DiagMsg
            exit 1
        }
    }

    ## Write Output and end

    if ($Global:Status -eq 0) {
        $Global:DiagMsg += "DNSF Agent is healthy."
        write-DRMMAlert "Agent Healthy, last sync: $Global:ElapsedHours hour(s) ago."
        write-DRMMDiag $Global:DiagMsg
        exit 0
    }
    elseif ($Global:Status -eq 2 -or 1) {
        $Global:DiagMsg += "Failure to diagnose. DNS Filter service may be corrupt. Uninstalling.."
        Uninstall-App "DNSFilter Agent"
        Uninstall-App "DNS Agent"
        write-DRMMAlert "Agent Troubled. Review diagnostic log."
        write-DRMMDiag $Global:DiagMsg
        exit 1
    }

}