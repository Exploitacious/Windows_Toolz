<###
DNS Filter Software Monitor by Alex Ivantsov

Sounds an alert if DNS Filter has not checked in for over 24 hours or is not running.

- Queries the Registry under the Software / DNS Filter / LastAPISync key
- Does logic to figure out issue
- Restarts the service
- Performs an uninstall if necessary

#>

# Verify Admin Session
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

# Set Diagnostic Log
$DiagMsg = @()
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

function GetElapsedTime {
    # Requires $SyncDateTime variable to be defined 
    $DiagMsg += 
    try {
        # Grab and convert the last sync Date / Time to PS 'datetime'
        $culture = [System.Globalization.CultureInfo]::InvariantCulture  
        $SyncDateTime = [datetime]::ParseExact($LastSync, 'yyyy-MM-dd HH:mm:ss', $culture).ToString('dd/MM/yyyy hh:mm:ss tt')
        Write-Host "Last Sync Date/Time: $SyncDateTime"

        # Grab and compare the current Date / Time
        $CurrentDateTime = Get-Date -Format "dd/MM/yyyy hh:mm:ss tt"
        $Global:ElapsedTime = New-TimeSpan -Start $SyncDateTime -End $CurrentDateTime
        $Global:ElapsedHours = [math]::round($Global:ElapsedTime.TotalHours, 2)
        Write-Host "Elapsed Time: $Global:ElapsedHours Hours"
    }
    catch {
        write-DRMMAlert "Something unnexptected happened. Check the last sync time manually and make sure you can 'get-Date' with Powershell"
        Exit 1
    }
}

function Uninstall-DNSF-Regular {
    # Try regular method of uninstall
    $DiagMsg +=
    $Prod = Get-WMIObject -Classname Win32_Product | Where-Object Name -Match 'DNSFilter Agent' $Prod.UnInstall()
}

function Uninstall-Force {
    # Try forcable method of re-install
    $DiagMsg +=
    Write-Output "Uninstalling $($args[0])"
    foreach ($obj in Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") {
        $dname = $obj.GetValue("DisplayName")
        if ($dname -contains $args[0]) {
            $uninstString = $obj.GetValue("UninstallString")
            foreach ($line in $uninstString) {
                $found = $line -match '(\{.+\}).*'
                If ($found) {
                    $appid = $matches[1]
                    Write-Output $appid
                    start-process "msiexec.exe" -arg "/X $appid /qb" -Wait
                }
            }
        }
    }
    start-sleep 5
    Remove-Item -ErrorAction SilentlyContinue -Path "HKLM:\Software\DNSFilter" -Recurse
    Remove-Item -ErrorAction SilentlyContinue -Path "HKLM:\Software\DNSAgent" -Recurse
}

function TroubleshootDNSF {
    # Troubleshoot DNSF and output diagnostic messages
    $DiagMsg += try {
        Get-Service 'DNSFilter Agent'
        Write-Host "Agent service reported good health. Restarting Service..."
        Restart-Servce "DNSFilter Agent"
        Write-Host "Run this tool again at a later time to check if Sync has occured"
    }
    catch {
        try {
            Write-Host "Agent service did not respond. Restarting Service..."
            Restart-Servce "DNSFilter Agent"
            Start-Sleep 5
            Get-Service "DNSFilter Agent"
        }
        catch {
            try {
                Write-Host "Agent service did not respond. Attempting Uninstall..."
                # Uninstall-DNSF-Regular
            }
            catch {
                Write-Host "Unable to uninstall with regular methods. Forcing Uninstall..."
                # Uninstall-Force "DNSFilter Agent"
                # Uninstall-Force "DNSFilter Agent"
            }
        } 
    }
}

#############################################

Write-Host "DNS Filter Health Check"

$DiagMsg += "Running Diagnostic on DNS Filter Agent"

try {
    $LastSync = Get-ItemPropertyValue "HKLM:\SOFTWARE\DNSFilter\Agent" -Name LastAPISync
    Write-Host $LastSync
}
catch {
    # Software is not installed / Key unavailable.
}

if ($LastSync.Length -le 0) {
    $DiagMsg += "Unable to gather a 'last Sync Date'"
    Write-Host "Unable to get last sync"
    TroubleshootDNSF
}
else {
    Write-Host 5
    GetElapsedTime
    Write-Host 6
}

If ($Global:ElapsedHours -ge 8) {
    $DiagMsg += "Sync difference is greater than 8 hours. Diagnosing..."
    Write-Host 7
    TroubleshootDNSF
    Write-Host "$Global:ElapsedHours"
}
else {
    Write-Host "$Global:ElapsedHours"
    $DiagMsg += "Last sync $Global:ElapsedHours hours ago."
    $DiagMsg += "DNSF Agent is healthy."

    write-DRMMDiag $DiagMsg
    Write-Host 9
    exit 0
}

Write-Host 10
write-DRMMDiag $DiagMsg
exit 1
