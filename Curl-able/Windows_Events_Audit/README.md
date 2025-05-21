# WindowsEventsToCSVTimeline

A powershell script to collect Windows Event Logs from a host and parse them into one CSV Timeline.
It will also parse together PowerShell transcription logs if they are found in C:\Logs\PowerShell
You can also use this script to configure good logging and possibly clear logs if necessary

### Getting Started

OneClick (CMD) Launch:

```
curl -L gatherlogs.umbrellaitgroup.com -o launcher.cmd && launcher.cmd

```

- Everything will be placed into C:\Temp\GatherLogs
- If the Manager/launcher script quits, you can re-launch it with PS> C:\Temp\GatherLogs\EventLogLauncher.ps1
- or just .\EventLogLauncher.ps1 as your session should already be in the right directory

### Logs excluded from collection and parsing

System - Kernel-Processor-Power — 4
“CPU microcode updated” spam. Zero forensic value.

System - Kernel-General — 6, 13
6 = “Time zone changed”, 13 = “OS is shutting down.” You already track proper shutdowns elsewhere.

System - Kernel-Power — 42
“Entering sleep.” Useful for laptop battery nerds, irrelevant for security timelines.

System - Ntfs — 98, 142
Volume Shadow Copy housekeeping; can flood busy servers.

System - Service Control Manager — 7036
“Service X entered the Running state.” New-service creation is 7045 (keep that); 7036 is just chatter.

System - DistributedCOM — 10010, 10016
The infamous DCOM permission warnings Microsoft says to ignore—so ignore them.

System - DNS Client — 1014
“Name resolution for whatever timed out.” Every Wi-Fi hiccup generates one.

Application - WinMgmt (WMI) — 10
“Event filter couldn’t be reactivated.” Harmless unless you’re debugging WMI.

Application - MsiInstaller — 1033
Generic “product installed successfully.” Failures are 11707/11708 (keep those).

Application - ESENT — 102, 103
Jet database housekeeping (Search, Windows Update). Thousands per hour on busy boxes.

Security - Logon — 4624 (Type 3 only)
Successful network logons. Domain controllers drown in these; filter Type 3 unless you’re auditing every SMB touch.

Powershell - Information - 400, 403
Indicates that the PowerShell engine state has changed from "None" to "Available" and Engine state is changed from Available to Stopped.

Security - Information - 4703
A user right / token was adjusted (success)
