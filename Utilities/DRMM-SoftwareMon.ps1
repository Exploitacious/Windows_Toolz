#software monitor :: build 10/seagull :: thanks to alex b. :: PS2.0 compat or die trying

if ($env:usrSearch -match 'Custom') {
    $varString = $env:usrString
}
else {
    $varString = $env:usrSearch
}

$arrRecords = @()
$varCounter = 0
$varString.split() | ForEach-Object {
    $varTerm = $_.replace("=", " ")
    #add a new psCustomObject for the software being searched for, to which each search will commit data
    $arrRecords += @{Record = [psCustomObject]@{Name = "$varTerm"; Value = 0 } }
    ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE") | ForEach-Object {
        if (Get-ChildItem -Path $_ | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName, $_.BrandName -match "$varTerm" } | Select-Object DisplayName) {
            $varDiscovery++
            $arrRecords[$varCounter].Record.value++
        }
    }
    $varCounter++
}

#reset the counter
Remove-Variable -Name varCounter
$varCounter = 0
$varAlert = 0

#catch awkward upgrades
if (!$env:usrMethod) {
    $varExitString += "ALERT: Please update monitor settings to include usrMethod setting. Using default value of 'alert if not found'."
    $env:usrMethod = "NE"
}

#loop through our records and respond accordingly
while ($true) {
    if (!($arrRecords[$varCounter].Record.name)) {
        #we're done here
        break
    }

    if ($env:usrMethod -match 'EQ') {
        if ($arrRecords[$varCounter].Record.value -ge 1) {
            $varExitString += "Software `'$($arrRecords[$varCounter].Record.name)`' is installed. "
            $varAlert = 1
        }
        else {
            $varExitString += "Software `'$($arrRecords[$varCounter].Record.name)`' is not installed. "
        }
    }
    elseif ($env:usrMethod -match 'NE') {
        if ($arrRecords[$varCounter].Record.value -lt 1) {
            $varExitString += "Software `'$($arrRecords[$varCounter].Record.name)`' is not installed. "
            $varAlert = 1
        }
        else {
            $varExitString += "Software `'$($arrRecords[$varCounter].Record.name)`' is installed. "
        }
    }
    else {
        exit 1
    }
    $varCounter++
}

Write-Host '<-Start Result->'
Write-Host "X=$varExitString"
Write-Host '<-End Result->'
exit $varAlert