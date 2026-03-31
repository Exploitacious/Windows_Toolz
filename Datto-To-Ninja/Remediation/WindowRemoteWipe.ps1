<# remote wipe windows :: REDUX build 2/seagull, february 2025
   script variables: wipeMethod/sel; verification/str

   this script, like all datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc.;
   it may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for 
   any reason. this includes on reddit, on discord, or as part of other RMM tools. PCSM is the one exception to this rule.
   	
   the moment you edit this script it becomes your own risk and support will not provide assistance with it.#>

write-host "Remote Wipe Windows"
write-host "================================="

if ([int](get-wmiObject win32_operatingSystem buildNumber).buildNumber -lt 10240) {
    write-host "! ERROR: Only Windows 10+ devices supported."
    exit 1
}

if ($env:Verification -ne 'Permanently wipe this device') {
    write-host "! ERROR: Please enter 'Permanently wipe this device' in the Verification variable field."
    exit 1
}

write-host "- Issuing Remote Wipe command for device $env:COMPUTERNAME."
write-host "  The command will be saved as a Scheduled Task and run in two minutes' time so this Job can conclude."
write-host "  If the device remains connected beyond this point, ensure third-party software has not intercepted"
write-host "  the scheduled task's PowerShell script and prevented it from running."
write-host "================================="

@'
$varParams = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
$varParams.Add([Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In"))
(New-CimSession).InvokeMethod("root\cimv2\mdm\dmmap", $(Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_RemoteWipe" -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'"), "doWipeMethod", $varParams)
'@ | out-file deviceWipe.ps1

schtasks /create /sc hourly /tn "RMM-DeviceWipe" /tr "powershell -executionpolicy bypass -file \`"$PWD\deviceWipe.ps1\`"" /st $(([DateTime]::Now.AddMinutes(3)).ToString("HH:mm")) /et $(([DateTime]::Now.AddMinutes(5)).ToString("HH:mm")) /ru SYSTEM /f /z | out-null

write-host "- Scheduled task created."
write-host "  Name:    RMM-DeviceWipe"
write-host "  Created: [$([DateTime]::Now)]"
write-host "  Runs at: [$([DateTime]::Now.AddMinutes(3))]."
write-host "  This device should be wiped shortly."