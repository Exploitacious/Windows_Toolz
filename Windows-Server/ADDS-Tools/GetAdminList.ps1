
Import-Module ActiveDirectory

$groups = Get-ADGroup -Properties * -Filter *
$table = @()
$user_record = @{
    "Group Name" = ""
    "Name"       = ""
    "Username"   = ""
}

foreach ($group in $groups) {

    $members = Get-ADGroupMember -identity $group -recursive | select name, samaccountname
    foreach ($member in $members) {
        if ($group -like "*admin*") {
            $user_record."Group Name" = $group
            $user_record."Name" = $member.name
            $user_record."UserName" = $member.samaccountname
            $user_record_obj = New-Object PSObject -property $user_record
            $table += $user_record_obj
        }
    }
}

$table | export-csv -Path "C:\ActiveDirectoryAdminInfo.csv" -NoTypeInformation
