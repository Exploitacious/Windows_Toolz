write-host "Approximate System Install Date from directories"          #build 5/seagull
write-host "======================================================"
write-host "This Component uses the date of earliest folder creation in the Program Files directories to approximate"
write-host "the time Windows was first installed on this device (not counting Feature Updates, upgrades, etc)."
write-host "It is not presented as an exact science but rather as an alternative should other methods fail."
write-host "======================================================"

$varDates = foreach ($folder in ($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    gci $folder | ? { ($_.PSIsContainer) } | % { $_.CreationTime }
}

$varDate = $varDates | sort | select -first 1

write-host "- Date as native:  $varDate"
write-host "- Format selected: $env:usrPreference"

switch -regex ($env:usrPreference) {
    '^YYYY$' {
        $varDateFormatted = get-date $($varDate | sort | select -first 1) -Format "yyyy"
    } '^DDMMYYYY$' {
        $varDateFormatted = get-date $($varDate | sort | select -first 1) -Format "dd/MM/yyyy"
    } '^MMDDYYYY$' {
        $varDateFormatted = get-date $($varDate | sort | select -first 1) -Format "MM/dd/yyyy"
    } '^Epoch$' {
        $varDateFormatted = ((get-date $($varDate | sort | select -first 1) -UFormat %s) -as [string]).split("\.")[0]
    } default {
        write-host "! ERROR: No input supplied."
        write-host "  Please report this issue."
        exit 1
    }
}

write-host "- Date in format:  $varDateFormatted"
write-host "- UDF to write to: $env:usrUDF"
write-host "======================================================"

if ($env:usrUDF -ge 1) {
    Set-ItemProperty "HKLM:\Software\CentraStage" -Name "Custom$env:usrUDF" -Value "$varDateFormatted"
    write-host "- UDF written."
}
else {
    write-host "- Not writing a UDF."
}