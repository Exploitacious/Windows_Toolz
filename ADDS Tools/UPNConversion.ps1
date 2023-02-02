<#

Create a new Routable UPN Suffix and replace the users' UPN Suffixes.

Created by Alex Ivantsov - Alex@ivantsov.tech

#>


### Adds a new routable UPN and replaces the UPN Suffixes for all users with prompts for user input. Comment out the variable that prompt for entry
## and use these expicitly defined ones instead. 

# $LocalUPN =    Costanso.local
# $Routable UPN =   Costanso.com

## Comment out this entire Section if running Automated...

$LocalUPN = Read-Host "Enter the LOCAL UPN Suffix of this domain (Example: Cotanso.local) "  ## Comment this out if running automated
$RoutableUPN = Read-Host "Enter the new, Routable UPN suffix you wish to use (Example: Costanso.com)"  ## Comment this out if running automated

Write-Host -Foregroundcolor Yellow "Current UPN Suffixes available on this domain:"
Get-ADForest | fl UPNSuffixes

$Answer = Read-Host "Do you need to add the new, routable UPN Suffix? Y or N"
if ($Answer -eq 'y' -or $Answer -eq 'yes') {

    Get-ADForest | Set-ADForest -UPNSuffixes @{add = $RoutableUPN }

}
else {

    Write-Host -ForegroundColor Cyan "The following users will be converted..."
    Write-Host
    Get-ADUser -Filter "UserPrincipalName -like '*$localUPN'" -Properties Enabled | Sort-Object Name | Format-Table Name, UserPrincipalName

    $Answer = Read-Host "Continue and replace UPN Suffix? Y or N"
    if ($Answer -eq 'y' -or $Answer -eq 'yes') {

        $LocalUPNStar = "*" + $LocalUPN
        $LocalUPNAT = "@" + $LocalUPN
        $RoutableUPNAT = "@" + $RoutableUPN
        $LocalUsers = Get-ADUser -Filter "UserPrincipalName -like '$LocalUPNStar'" -Properties userPrincipalName -ResultSetSize $null
    
        $LocalUsers | foreach { $newUpn = $_.UserPrincipalName.Replace("$LocalUPNAT", "$RoutableUPNAT"); $_ | Set-ADUser -UserPrincipalName $newUpn }
        Write-Host
        Write-Host -foregroundcolor Green "UPN Suffixes have been replaced"

    }

    Write-Host
    Write-Host "Full List of UPNs:"
    Write-Host
    Get-ADUser -Filter * | Sort-Object Name | Format-Table Name, UserPrincipalName

}

$Answer = Read-Host "Do you need to add ProxyAddress Entires? This will convert the UPN to ProxyAddress. Only needs to be done once."
if ($Answer -eq 'y' -or $Answer -eq 'yes') {

    foreach ($user in (Get-ADUser -Filter * -Properties mail, ProxyAddresses, UserPrincipalName)) {

        $user.ProxyAddresses = ("SMTP:" + $user.UserPrincipalName)
        $user.mail = $user.UserPrincipalName

        Set-ADUser -instance $user

    }
}


## End of Script


<#       Un-Comment this section for running automated! Adjust only the variables above.

    $LocalUPNStar = "*" + $LocalUPN
    $LocalUPNAT = "@" + $LocalUPN
    $RoutableUPNAT = "@" + $RoutableUPN
    $LocalUsers = Get-ADUser -Filter "UserPrincipalName -like '$LocalUPNStar'" -Properties userPrincipalName -ResultSetSize $null
    $LocalUsers | foreach {$newUpn = $_.UserPrincipalName.Replace("$LocalUPNAT","$RoutableUPNAT"); $_ | Set-ADUser -UserPrincipalName $newUpn}

#>