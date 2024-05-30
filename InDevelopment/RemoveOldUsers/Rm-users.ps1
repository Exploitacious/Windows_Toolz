


# Find Users
# $ProfileList = Get-CimInstance -ClassName Win32_UserProfile | select-object localPath, lastusetime

$OldUserList = Get-WmiObject win32_userprofile | Where-Object { $_.LastUseTime } | Where-Object { $_.ConvertToDateTime($_.LastUseTime) -lt [datetime]::Today.AddDays(-90) } 

$OldUserListCIM = Get-CimInstance win32_userprofile | Where-Object { $_.LastUseTIme } | Where-Object { $_.ConvertToDateTime($_.LastUseTIme) -lt [datetime]::Today.AddDays(-90) } 

Get-CimInstance win32_userprofile | Where-Object { (!$_.Special) -and ($_.LastUseTime -lt (Get-Date).AddDays(-30)) } | Remove-CimInstance

# | ForEach-Object{ $_.Delete()}

write-host 



# Remove Users

$user = Get-LocalUser -Name $Name -ErrorAction Stop

# Remove the user from the account database
Remove-LocalUser -SID $user.SID

# Remove the profile of the user (both, profile directory and profile in the registry)
Get-CimInstance -Class Win32_UserProfile | ? SID -eq $user.SID | Remove-CimInstance

            












$Threshold = -90

$ExcludedAccounts = @(, "default", "defaultuser0", "UmbrellaLA", "Public")
$UserProfileFolders = Get-ChildItem "$($env:SystemDrive)\Users" |
Where-Object { $_.LastWriteTime -lt ((Get-Date).AddDays($Threshold)) -and ($ExcludedAccounts -notcontains $_.Name) } |
Select-Object Name, FullName, LastWriteTime

function Check-SubFiles() {
    [CmdletBinding()]
    param (
        [string] $Path
    );

    $Children = Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue
    foreach ($child in $Children) {
        if ($child.LastWriteTime -gt ((Get-Date).AddDays($Threshold))) {
            #Write-Host $child
            return $false
        }
    }

    #Write-Host $child
    return $true
}

$WmiUserProfiles = Get-WmiObject Win32_UserProfile

$WmiUserProfiles | ForEach-Object {
    if (($UserProfileFolders | Select-Object -Expand FullName) -contains $_.LocalPath) {
        if (Check-SubFiles -Path $_.LocalPath) {
            write-host "Deleting User" $_.LocalPath
            $_.Delete()
        }
    }
}