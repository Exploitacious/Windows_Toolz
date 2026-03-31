function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End  Diagnostic->'
} function write-DRRMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.2") {
    write-DRRMAlert "Unsupported OS. Only Server 2012R2 and up are supported."
    exit 1
}

$FirewallState = @()
$FirewallProfiles = Get-NetFirewallProfile | Where-Object { ($_.Enabled -eq $false) -or ($_.Enabled -eq 0) }
If ($FirewallProfiles) { $FirewallState += "$($FirewallProfiles.name) Profile is disabled" }
$FirewallAllowed = Get-NetFirewallProfile | Where-Object { $_.DefaultInboundAction -eq "Allow" }
If ($FirewallAllowed) { $FirewallState += "$($FirewallAllowed.name) Profile is set to $($FirewallAllowed.DefaultInboundAction) inbound traffic" }

if (!$FirewallState) { write-DRRMAlert "healthy" } else { write-DRRMAlert $FirewallState ; write-DRMMDiag @($FirewallProfiles, $FirewallAllowed) ; exit 1 }