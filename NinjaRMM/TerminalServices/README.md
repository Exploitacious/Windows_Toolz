# How To
This script should be used along with a monitoring condition for a crashing terminal services sessions.

``
Windows Event: Application Error
Code: 1000
"svchost.exe_TermService"
``

## Setup
Run the script as a remediation action. You can choose to create a ticket and grab more details from the custom info field, or automatically attempt a remediation. Warning: Automatic remediation will kill the downed user session and unsaved work may be lost.

## Output
An example of output you should expect with this script:

``
Action completed: Run Reset Down Terminal Services Sessions Result: SUCCESS Output: Action: Run Reset Down Terminal Services Sessions, Result: Success

<-Start Result->
STATUS=No unstable 'Down' sessions detected. | Last Checked 01/21/2026 11:18 AM
<-End Result->

<-Start Diagnostic->
Script Type: Remediation `
Script Name: Remediation - Reset Down Terminal Services Sessions `
Script UID: NER9PI5GW8UMMQ7F2N9C `
Executed On: 01/21/2026 11:18 AM `
Configuration: Attempt Remediation = True `
Scanning for 'Down' sessions... `
No stuck sessions found during initial scan. `
Attempting to write 'Healthy - No stuck sessions. (01/21/2026 11:18 AM)' to Custom Field 'remoteDesktopSessions'. `
Successfully updated Custom Field. `
Leaving Script with Exit Code 0 (No Alert) `
<-End Diagnostic->
``
