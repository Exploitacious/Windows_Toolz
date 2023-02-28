<#
        Quick script to run to find each enabled local admin on a given machine
#>

#####
# Environemntal Variables # Blank out for Datto RMM Inputs
$env:usrUDF = 14

######
# Code

$localAdmins = $null
$varUDFString = $null
$localAdmins = Get-LocalGroupMember -Name "Administrators"

$Stringify = $localAdmins.Name | Out-String -Stream -Width 255

foreach ( $item in $Stringify ) { 
    $varUDFString += "$item, "
}

# write-host $varUDFString.GetType()

# Write to UDF
if ($env:usrUDF -ge 1) {    
    if ($varUDFString.length -gt 255) {
        Write-Host $varUDFString
        # Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        Write-Host $varUDFString
        # Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
else {
    write-Host "- not writing to UDF"
}

exit 0