<#
.SYNOPSIS
Using Datto RMM, check machine for installation of DNSFilter Roaming Agent.
Either alert or write status dependant on the status.

.NOTES
Version 0.1 - Written by Lee Mackie
#>
function Write-DRMMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}

function Write-DRMMStatus ($message) {
    write-host '<-Start Result->'
    write-host "STATUS=$message"
    write-host '<-End Result->'
}

function Get-DNSFilterInstalled () {
    $Global:Installed = Test-Path "HKLM:\Software\DNSFilter\Agent" -ea SilentlyContinue
}

function Get-DNSFilterStatus () {
    $Global:DNSFilterAgent = Get-Service -name "DNSFilter Agent" -ea SilentlyContinue
}

Get-DNSFilterInstalled
if ($Installed -eq "true") {
    Write-Host "-- DNSFilter Roaming Client installed"
    Get-DNSFilterStatus
    if (!$DNSFilterAgent) {
        Write-DRMMAlert "DNSFilter Roaming Client service missing."
        Exit 1
    } elseif ($DNSFilterAgent.Status -eq "Running") {
        Write-Host "-- DNSFilter Roaming Client service running"
        Write-DRMMStatus "DNSFilter Roaming Client OK"
        Exit 0
    } else {
        Write-Host "-- DNSFilter Roaming Client service is NOT running"
        $DNSFilterAgent | Start-Service -ea SilentlyContinue
        Get-DNSFilterStatus
        if ($DNSFilterAgent.Status -eq "Stopped") {
            Write-Host "-- DNSFilter Roaming Client is NOT running and start request failed"
            Write-DRMMAlert "DNSFilter Roaming Client service is NOT running. Attempted restart of service failed."
            Exit 1
        } elseif ($DNSFilterAgent.Status -eq "Started") {
            Write-Host "-- DNSFilter Roaming Client restarted successfully"
            Write-DRMMStatus "DNSFilter Roaming Client restarted successfully and OK"
            Exit 0
        }
    }
}

Write-Host "-- DNSFilter Roaming Client NOT installed"
Write-DRMMAlert "DNSFilter Roaming Client NOT installed"
Exit 1