#bootup time monitor :: original by aaron e., datto labs :: augmented by seagull/build 1
$lastEvent = Get-WinEvent -FilterHashtable @{logname = "Microsoft-Windows-Diagnostics-Performance/Operational"; id = 100 } -MaxEvents 1

[xml]$lastEventXML = $lastEvent.toxml()
$lastEventBootTime = $lastEventXML.Event.EventData.Data | where-Object { $_.name -eq "BootTime" }
try {
    $lastEventBootTime = $lastEventBootTime."#text" / 1000
}
catch {
    write-host "<-Start Result->"
    write-host "X=ERROR: Could not gather boot time as an integer. Check diagnostic."
    write-host "<-End Result->"

    write-host "<-Start Diagnostic->"
    write-host "Could not gather device bootup time as an integer. Please report this error."
    write-host "LastEventBootTime: $lastEventBootTime"
    write-host "LastEventXML:"
    write-host $lastEventXML
    write-host "<-End Diagnostic->"

    exit 1
}

write-host "<-Start Result->"
write-host "BootTime=$([math]::Round($lastEventBootTime))"
write-host "<-End Result->"

if ($lastEventBootTime -gt $env:Threshold) {
    write-host "<-Start Diagnostic->"
    write-host "The boot time gathered by the monitor was $lastEventBootTime."
    write-host "The threshold given by the user was to alert if the boot time took longer than $env:Threshold."
    write-host "As one exceeds the other, an alert is being sounded."
    write-host "<-End Diagnostic->"
    exit 1
}