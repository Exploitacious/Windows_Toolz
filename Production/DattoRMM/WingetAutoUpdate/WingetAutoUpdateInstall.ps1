<#
 Install and Launch Winget Auto Update
https://github.com/Romanitho/Winget-AutoUpdate/blob/main/Sources/WAU/Winget-AutoUpdate-Install.ps1

Staging and Deployment for Datto RMM established by Alex Ivantsov @Exploitacious 

#>

### Refresh and Download the latest Winget Auto Update

$WAUPath = "C:\Temp\WAU_Latest"
$WAUurl = "https://github.com/Romanitho/Winget-AutoUpdate/zipball/master/"
$WAUFile = "$WAUPath\WAU_latest.zip"

# Refresh the directory to allow download and install of latest version
if ((Test-Path -Path $WAUPath)) {
    Remove-Item $WAUPath -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $WAUPath
}
else {
    New-Item -ItemType Directory -Path $WAUPath
}


# Download Winget AutoUpdate
Invoke-WebRequest -Uri $WAUurl -o $WAUFile
Expand-Archive $WAUFile -DestinationPath $WAUPath -Force
Remove-Item $WAUFile -Force

# Move Items around to remove extra directories
Move-Item "$WAUPath\Romanitho*\*" $WAUPath
Remove-Item "$WAUPath\Romanitho*\"


### Execute Winget Auto Update Installation
& "$WAUPath\Sources\WAU\Winget-AutoUpdate-Install.ps1" -Silent -InstallUserContext -NotificationLevel None -UpdatesAtLogon -UpdatesInterval Weekly -StartMenuShortcut -DoNotUpdate

<# Options for WAU Installation (from https://github.com/Romanitho/Winget-AutoUpdate)

-Silent
Install Winget-AutoUpdate and prerequisites silently.

-DoNotUpdate
Do not run Winget-AutoUpdate after installation. By default, Winget-AutoUpdate is run just after installation.

-DisableWAUAutoUpdate
Disable Winget-AutoUpdate update checking. By default, WAU auto updates if new version is available on Github.

-UseWhiteList
Use White List instead of Black List. This setting will not create the "excluded_apps.txt" but "included_apps.txt".

-ListPath
Get Black/White List from external Path (URL/UNC/Local/GPO) - download/copy to Winget-AutoUpdate installation location if external list is newer.
PATH must end with a Directory, not a File...
...if the external Path is an URL and the web host doesn't respond with a date/time header for the file (i.e GitHub) then the file is always downloaded!

If the external Path is a Private Azure Container protected by a SAS token (resourceURI?sasToken), every special character should be escaped at installation time.
It doesn't work to call Powershell in CMD to install WAU with the parameter:
-ListPath https://storagesample.blob.core.windows.net/sample-container?v=2023-11-31&sr=b&sig=39Up9jzHkxhUIhFEjEh9594DIxe6cIRCgOVOICGSP%3A377&sp=rcw
Instead you must escape every special character (notice the % escape too) like:
-ListPath https://storagesample.blob.core.windows.net/sample-container^?v=2023-11-31^&sr=b^&sig=39Up9jzHkxhUIhFEjEh9594DIxe6cIRCgOVOICGSP%%3A377^&sp=rcw

If -ListPath is set to GPO the Black/White List can be managed from within the GPO itself under Application GPO Blacklist/Application GPO Whitelist. Thanks to Weatherlights in #256 (reply in thread)!

-ModsPath
Get Mods from external Path (URL/UNC/Local/AzureBlob) - download/copy to mods in Winget-AutoUpdate installation location if external mods are newer.
For URL: This requires a site directory with Directory Listing Enabled and no index page overriding the listing of files (or an index page with href listing of all the Mods to be downloaded):

<ul>
<li><a  href="Adobe.Acrobat.Reader.32-bit-installed.ps1">Adobe.Acrobat.Reader.32-bit-installed.ps1</a></li>
<li><a  href="Adobe.Acrobat.Reader.64-bit-override.txt">Adobe.Acrobat.Reader.64-bit-override.txt</a></li>
<li><a  href="Notepad++.Notepad++-installed.ps1">Notepad++.Notepad++-installed.ps1</a></li>
<li><a  href="Notepad++.Notepad++-uninstalled.ps1">Notepad++.Notepad++-uninstalled.ps1</a></li>
</ul>
Validated on IIS/Apache.

Nota bene IIS :

The extension .ps1 must be added as MIME Types (text/powershell-script) otherwise it's displayed in the listing but can't be opened
Files with special characters in the filename can't be opened by default from an IIS server - config must be administrated: Enable Allow double escaping in 'Request Filtering'
For AzureBlob: This requires the parameter -AzureBlobURL to be set with an appropriate Azure Blob Storage URL including the SAS token. See -AzureBlobURL for more information.

-AzureBlobURL
Used in conjunction with the -ModsPath parameter to provide the Azure Storage Blob URL with SAS token. The SAS token must, at a minimum, have 'Read' and 'List' permissions. It is recommended to set the permisions at the container level and rotate the SAS token on a regular basis. Ensure the container reflects the same structure as found under the initial mods folder.

-InstallUserContext
Install WAU with system and user context executions.
Applications installed in system context will be ignored under user context.

-BypassListForUsers
Bypass Black/White list when run in user context.

-NoClean
Keep critical files when installing/uninstalling. This setting will keep "excluded_apps.txt", "included_apps.txt", "mods" and "logs" as they were.

-DesktopShortcut
Create a shortcut for user interaction on the Desktop to run task Winget-AutoUpdate

-StartMenuShortcut
Create shortcuts for user interaction in the Start Menu to run task Winget-AutoUpdate, open Logs and Web Help.

-NotificationLevel
Specify the Notification level: Full (Default, displays all notification), SuccessOnly (Only displays notification for success) or None (Does not show any popup).

-UpdatesAtLogon
Set WAU to run at user logon.

-UpdatesInterval
Specify the update frequency: Daily (Default), BiDaily, Weekly, BiWeekly, Monthly or Never. Can be set to 'Never' in combination with '-UpdatesAtLogon' for instance.

-UpdatesAtTime
Specify the time of the update interval execution time. Default 6AM.

-RunOnMetered
Force WAU to run on metered connections. May add cellular data costs on shared connexion from smartphone for example.

-MaxLogFiles
Specify number of allowed log files.
Default is 3 out of 0-99:
Setting MaxLogFiles to 0 don't delete any old archived log files.
Setting it to 1 keeps the original one and just let it grow.

-MaxLogSize
Specify the size of the log file in bytes before rotating.
Default is 1048576 = 1 MB (ca. 7500 lines)

-WAUinstallPath
Specify Winget-AutoUpdate installation location. Default: C:\ProgramData\Winget-AutoUpdate (Recommended to leave default).

-Uninstall
Remove scheduled tasks and scripts.

#>