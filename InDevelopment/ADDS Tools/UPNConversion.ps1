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

Write-Host
Write-Host "The following users need to be converted..."
Write-Host
Get-ADUser -Filter "UserPrincipalName -like '*$localUPN'" -Properties Enabled | Sort-Object Name | Format-Table Name, UserPrincipalName

$Answer = Read-Host "Would you like to migrate the user UPNs to the new Routable Domain?"
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
Write-Host "Full List of Proxy Addresses and UPNs:"
Write-Host
Get-ADUser -Filter * -Properties * | Select Name, ProxyAddress, UserPrincipalName 


$Answer = Read-Host "Do you need to modify the ProxyAddress Entires? Hitting Y will convert the ProxyAddresses to 'SMTP:_UPN_'. Only needs to be done once after the UPN has modified."
if ($Answer -eq 'y' -or $Answer -eq 'yes') {

    foreach ($ADuser in (Get-ADUser -Filter * -Properties mail, ProxyAddresses, UserPrincipalName)) {

        $ADuser.ProxyAddresses = ("SMTP:" + $ADuser.UserPrincipalName)
        $ADuser.mail = $ADuser.UserPrincipalName

        Set-ADUser -instance $ADuser

    }
}

Write-Host
Write-Host "Current Exchange 'msExchMailboxGuid' properties:"
Write-Host
get-ADuser -Filter * -Properties * | Select Name, msExchMailboxGuid

$Answer = Read-Host "Do you need to clear out the old Exchange Mailbox GUIDs? Only needs to be done once."
if ($Answer -eq 'y' -or $Answer -eq 'yes') {

    foreach ($user in (Get-ADUser -Filter *)) {

        get-aduser $user | set-aduser -clear msExchMailboxGuid, legacyexchangedn, msexchmailboxsecuritydescriptor, msexchpoliciesincluded, msexchrecipientdisplaytype, msexchrecipienttypedetails, msexchumdtmfmap, msexchuseraccountcontrol, msexchversion, showInAddressBook

    }

}

Write-Host
Write-Host "Current Exchange 'mailNickname' properties:"
Write-Host
get-ADuser -Filter * -Properties * | Select Name, mailNickname

$Answer = Read-Host "Do you need to modify the mailNickname to be the SamAccountName? Only needs to be done once."
if ($Answer -eq 'y' -or $Answer -eq 'yes') {

    foreach ($user in (Get-ADUser -Filter * -Properties mailNickname)) {

        $NewName = $user.SamAccountName
        get-aduser $NewName | Set-ADUser -Replace @{MailNickName = $NewName }
    }
}

Write-Host
Write-Host "Current adminCount properties:"
Write-Host
get-ADuser -Filter * -Properties * | Select Name, adminCount

$Answer = Read-Host "Do you need to clear out the AdminCount? You will not be able to SSPR if adminCount is set."
if ($Answer -eq 'y' -or $Answer -eq 'yes') {

    foreach ($user in (Get-ADUser -Filter *)) {

        get-aduser $user | set-aduser -clear adminCount

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