function write-DRRMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.3") {
    write-DRRMAlert "Unsupported OS. Only Server 2012R2 and up are supported."
    exit 1
}
try {
    $VSSLog = Get-EventLog -logname Application -Source VSS | Where-Object { (Get-Date $_.TimeWritten) -gt ((Get-Date).AddHours(-2)) }
}
catch {
    $ScriptError = "Query Failed: $($_.Exception.Message)"
}
foreach ($logentry in $VSSLog) {
    if ($logentry.EntryType -eq "Warning") { $VSSStatus += "`nVSS Snapshot at at $($logentry.TimeGenerated) has a warning" }
    if ($logentry.EntryType -eq "Error") { $VSSStatus += "`nVSS Snapshot at at $($logentry.TimeGenerated) has an error" }
}
if (!$VSSStatus) { write-DRRMAlert "Healthy" } else { write-DRRMAlert "$VSSStatus" ; exit 1 }



<#
# Service Control: Volume Shadow Copy (VSS) Service Defaults

sc config VSS start= demand

sc config VSS obj= LocalSystem

#>