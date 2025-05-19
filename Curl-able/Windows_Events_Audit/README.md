# WindowsEventsToCSVTimeline

A simple Powershell script to collect Windows Event Logs from a host and parse them into one CSV Timeline.

### Getting Started

Collect All of the Logs!

OneClick Launch:

```
.\Gather-LogsToTimeLine.ps1 -output "c:\Logs"

#Now copy your log files back to your analysis system
```

Parse All of the Logs!

```
.\Parse-LogsToTimeLine.ps1 -LogFolder "C:\Logs" -outputfile MyTimeline.csv
```

### Additional Options

```
Get-Help .\Gather-LogsToTimeLine.ps1 -Full
Get-Help .\Parse-LogsToTimeLine.ps1 -Full
```
