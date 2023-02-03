Import-Module ActiveDirectory
$users = Get-ADUser -Filter * -Properties *
$results = @()
foreach ($user in $users) {
    $userProperties = [ordered]@{}
    foreach ($property in $user.Properties.PropertyNames) {
        $value = $user.Properties[$property]
        if ($value) {
            $userProperties[$property] = $value
        }
    }
    $results += New-Object PSObject -Property $userProperties
}
$results | Export-Csv -Path C:\Users.Attributes.csv -NoTypeInformation


Import-Module ActiveDirectory
$users = Get-ADUser -Filter * -Properties *
$results = @()
foreach ($user in $users) {
    $userProperties = [ordered]@{}
    foreach ($property in $user.Properties.PropertyNames) {
        $value = $user.Properties[$property]
        if ($value) {
            $userProperties[$property] = $value
        }
    }
    $results += New-Object PSObject -Property $userProperties
}
$results | Export-Csv -Path C:\msExchAttributes.csv -NoTypeInformation