<###
# Software Monitor chopped and screwed by Alex Ivantsov

Sounds an alert if software identifying a known string is not discovered. 
Can be configured with a response Component to install the software in question. Drop in your software search term into the usrString Variable

#>
# Env Strings for Testing:
# $env:usrString = "SNAP"
# $env:usrMethod = 'EQ'

$varString = $env:usrString

###

$varCounter = 0


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
