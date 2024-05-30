<###
# Original Datto RMM Software Monitor chopped and screwed by Alex Ivantsov @Exploitacious

Sounds an alert if software identifying a known string IS or IS NOT discovered. 
Can be configured with a response Component to install the software in question. Drop in your software search term into the usrString Variable.

Env Strings for Testing, but otherwise only configured in Datto RMM:
$env:usrString = "SNAP"
$env:usrMethod = 'EQ'  # Use 'EQ' to Alert if FOUND, and 'NE' to Alert if MISSING.

To test:
Let's say you're looking for a specific Adobe install. Jump on a computer where you KNOW it's installed, and confirm the script will find exactly what you're looking for by doing the following:
Open Powershell and run this below piece of code, replacing the "$varString" variable with the name of whatever software you're looking for:

Get-ChildItem ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE") | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName, $_.BrandName -match "$varString" }

Get as specific as you can with your searches. In case there are multiple results displayed for "adobe", try to search and match exactly what you're seeking - from the "BrandName" or "DisplayName" of the app displayed.
###>

$varString = $env:usrString
$varCounter = 0
$varAlert = 1

$Detection = Get-ChildItem ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE") | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName, $_.BrandName -match "$varString" } | Select-Object

if ($Null -ne $Detection) {
    $varCounter ++
}
else {
    $varCounter = 0
}

if ($env:usrMethod -match 'EQ') {
    if ($varCounter -ge 1) {
        $varExitString = "Software $varString is installed. "
        $varAlert = 1
    }
    else {
        $varExitString = "Software $varString is not installed. "
        $varAlert = 0
    }
}
elseif ($env:usrMethod -match 'NE') {
    if ($varCounter -lt 1) {
        $varExitString = "Software $varString is not installed. "
        $varAlert = 1
    }
    else {
        $varExitString = "Software $varString is installed. "
        $varAlert = 0
    }
}
else {
    exit 1
}

Write-Host "$varExitString"
