# Set AD Site Link
Get-ADReplicationSiteLink -filter * | Set-ADReplicationSiteLink -ReplicationFrequencyInMinutes 15

# Add DNS Forwarders
$IPS = $ENV:DNSSERVERS -split ','
Set-DnsServerForwarder -IPAddress $IPS
Restart-Service DNS

# Set the default print dialog in Edge to be handled by Windows, NOT Edge
$VerbosePreference = "Continue"
If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\UseSystemPrintDialog")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\UseSystemPrintDialog" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "UseSystemPrintDialog" -Type DWord -Value $PrintDialog
get-process -Name *Edge* | Stop-Process


# Enable Script-Block Logging for Powershell
New-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -Force

# Enable TLS 1.2
New-Item 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -name 'SystemDefaultTlsVersions' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -name 'SchUseStrongCrypto' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -name 'SystemDefaultTlsVersions' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -name 'SchUseStrongCrypto' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null
Write-Host 'TLS 1.2 has been enabled.'


# Get SQL Instances
write-host "Get installed SQL Instances to Custom Field"
write-host "==============================="

$registryPath = "HKLM:\SOFTWARE\CentraStage"
$SQLinstances = Get-Service | ? { $_.Name -like "MSSQL*" } | foreach { $_.Name + ":" }
Set-Itemproperty -path $registryPath -name Custom$env:usrUDF -value "$SQLinstances"

write-host "Value set to UDF $env:usrUDF"
write-host "This is the data:"
write-host $SQLInstances


#grant/deny access to sys\spool\drivers (printNightmare) :: build 5/seagull :: based on trueSec's work, but not their code

switch -Regex ($env:usrChoice) {
    'Deny' {
        write-host "- Denying SYSTEM access to write to Spool\Drivers folder..."
        cmd /c "ICACLS `"$env:systemRoot\System32\spool\drivers`" /deny *S-1-1-0:F /inheritance:r" 2>&1>$null
    } 'Grant' {
        write-host "- Granting SYSTEM access to write to Spool\Drivers folder..."
        cmd /c "ICACLS `"$env:systemRoot\System32\spool\drivers`" /reset" 2>&1>$null
    } default {
        write-host "! ERROR: No option was set."
        exit 1
    }
}

switch -Regex ($env:usrRegistry) {
    'Patch' {
        write-host "- Updating Registry to use Microsoft's suggested mitigation values..."
        write-host ": Set HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint NoWarningNoElevationOnInstall to 0"
        cmd /c "reg add `"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint`" /v NoWarningNoElevationOnInstall /t REG_DWORD /d `"0`" /f"
        write-host ": Set HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint UpdatePromptSettings to 0"
        cmd /c "reg add `"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint`" /v UpdatePromptSettings /t REG_DWORD /d `"0`" /f"
        write-host "! NOTICE:"
        write-host "  These Registry settings can be superseded by a Group Policy setting."
        write-host "  Please scrutinise your Local Group Policy settings to ensure they are in line with Microsoft's suggested"
        write-host "  settings to mitigate this vulnerability. https://preview.tinyurl.com/kb5005010"
    } 'Revert' {
        write-host "- Reverting Registry to default values..."
        write-host ": Delete HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint NoWarningNoElevationOnInstall value"
        cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint`" /v NoWarningNoElevationOnInstall /f"
        write-host ": Delete HKLM\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint UpdatePromptSettings value"
        cmd /c "reg delete `"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint`" /v UpdatePromptSettings /f"
    } default {
        write-host "! ERROR: No Registry option was set."
        write-host "  You may need to delete and re-add this Component to see the new options."
        exit 1
    }
}

$host.ui.WriteErrorLine("===============================================================")
$host.ui.WriteErrorLine("Errors stating `"Cannot find Registry value`" can be ignored.")
$host.ui.WriteErrorLine("This means the Registry was already in `'default`' state when the script attempted to make it so.")

write-host "- Actions completed."