# Datto RMM Local Admin Password Solution

<#
Quick script to run to find each enabled local admin on a given machine
#>

#####
# Environemntal Variables # Blank out for Datto RMM Inputs

$env:usrUDF = 14

######
# Code

$localAdmins = Get-LocalGroupMember –Name ‘Administrators’
$admins = @()

foreach ($admin in $localAdmins) {
    Write-Host "Name: $admin"
    $admins += $admin
}

$varUDFString = "$admins"




# Write to UDF
if ($env:usrUDF -ge 1) {    
    if ($varUDFString.length -gt 255) {
        # Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
else {
    Write-Host "- Not writing data to a UDF."
}

Write-Host $varUDFString

Exit 0