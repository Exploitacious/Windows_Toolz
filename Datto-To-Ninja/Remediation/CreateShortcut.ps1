<# make a url on the desktop :: build 7/seagull may 2024
   script variables: usrURL/string usrShortcutName/string
   
   this script, like all datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc.;
   it may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for 
   any reason. this includes on reddit, on discord, or as part of other RMM tools. PCSM and VSAX stand as exceptions to this rule.
      	
   the moment you edit this script it becomes your own risk and support will not provide assistance with it.#>

write-host "Create a URL shortcut on all Users' Desktops"
write-host "================================================"
write-host "- URL:  $env:usrURL"
write-host "- Name: $env:usrShortcutName"

#set the table
write-host "- Enumerating Users..."
$arrUser = @{}
[int]$varCounter = 0

$arrUserSID = @{}
$arrUserLoaded = @()

gci "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" | % { Get-ItemProperty $_.PSPath } | ? { $_.PSChildName -match '^S-1-5-21-' } | % {
    $varObject = New-Object PSObject
    $varObject | Add-Member -MemberType NoteProperty -Name "Username" -Value "$(split-path $_.ProfileImagePath -Leaf)"
    $varObject | Add-Member -MemberType NoteProperty -Name "ImagePath" -Value "$($_.ProfileImagePath)"
    $arrUserSID += @{$($_.PSChildName) = $varObject }
}

#enumerate hku, only show user sids. from here, show entries that aren't in the arruser table we just populated.
$arrUserSID.Keys | ? { $_ -notin $(gci "Registry::HKEY_USERS" | % { $_.name } | % { split-path $_ -leaf }) } | % {
    #load this user's hive
    write-host "- User $($arrUserSID[$_].Username) is not logged in; loading hive..."
    cmd /c "reg load `"HKU\$($_)`" `"$($arrUserSID[$_].ImagePath)\NTUSER.DAT`"" 2>&1>$null
    if (!$?) {
        write-host "! ERROR: Could not load Registry hive for user $($arrUserSID[$_].Username) (Check StdErr)."
        cmd /c "reg load `"HKU\$($_)`" `"$($arrUserSID[$_].ImagePath)\NTUSER.DAT`""
        write-host "  Execution cannot continue."
        exit 1
    }
    $arrUserLoaded += $_
}

$arrUser = @{}
[int]$varCounter = 0

#loop through all users with profile data and get localised strings and desktop locations for each
if ($env:usrPublic -match 'true') {
    #preamble
    write-host "- Component has been instructed to make a single shortcut in the PUBLIC directory (usrPublic option)."
    write-host "  This will produce a single shortcut in the Public Desktop folder which will reflect on all Desktops."
    write-host "  If one user deletes this shortcut it will disappear for all users of the system."
    #do the do
    $varObject = New-Object PSObject
    $varObject | Add-Member -MemberType NoteProperty -Name "Desktop" -Value "$((get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -Name Public).Public)\Desktop"
    $arrUser += @{$varCounter = $varObject }
}
else {
    gci "Registry::HKEY_USERS" -ea 0 | ? { $_.Name -match 'S-1-5-21' -and $_.Name -match '[0-9]$' } | % {
        $varObject = New-Object PSObject
        $varObject | Add-Member -MemberType NoteProperty -Name "Desktop" -Value "$((get-itemProperty "Registry::$($_.Name)\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" -name Desktop).Desktop)"
        $arrUser += @{$varCounter = $varObject }
        $varCounter++
    }
}

#unload user hives
$arrUserLoaded | % {
    [gc]::Collect()
    start-sleep -seconds 3
    cmd /c "reg unload `"HKU\$($_)`"" 2>&1>$null
    if (!$?) {
        write-host "! ERROR: Could not unload Registry hive for SID $($_) (Check StdErr)."
        cmd /c "reg unload `"HKU\$($_)`""
    }
}

#display the table
write-host ": User Desktop directories have been collected. Final table:"
$arrUser.values | ft

#furnish the .URL
$varURLContents = @"
[{000214A0-0000-0000-C000-000000000046}]
Prop3=19,11
[InternetShortcut]
IDList=
URL=$env:usrURL
"@

#for each user in the array, create the .URL file
$arrUser.Values | % {
    New-Item -ItemType File -Path $_.Desktop -Name "$env:usrShortcutName.url" -Value $varURLContents -Force | out-null
}

write-host "================================================"
write-host "- Shortcuts have been created."