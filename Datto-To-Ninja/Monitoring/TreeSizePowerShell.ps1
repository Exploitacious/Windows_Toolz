<# get largest files on disk :: build 34/seagull, june 24 :: thanks jim d., datto labs
   script variables: usrString/str :: usrBoolean/bln :: @usrStringSITE/str

   this script previously pulled from other sources, but has since been re-written in toto with new and original logic.
   this logic is the property of Datto, Inc. and is, like all datto RMM Component scripts unless otherwise explicitly stated, the 
   copyrighted property of Datto, Inc.; it may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, 
   even with modifications applied, for any reason. this includes on reddit, on discord, or as part of other RMM tools. 
   PCSM and VSAX stand as exceptions to this rule.
   	
   the moment you edit this script it becomes your own risk and support will not provide assistance with it.#>

write-host "Get Largest Files and Folders on Disk"
write-host "====================================="
write-host ": Date:     $(get-date)"
write-host ": Hostname: $env:COMPUTERNAME"

$varEpoch = [int][double]::Parse((Get-Date -UFormat %s))

#drive detection
$arrWMICheck = @()
Get-WmiObject -Class Win32_logicaldisk | ? { $_.DriveType -eq 2 -or $_.DriveType -eq 3 } | ? { $_.FreeSpace } | % { $arrWMICheck += $($_.DeviceID -replace ":", "") }

if (!$env:usrDrives) {
    write-host ": Drives:   None specified (using C:)"
    $arrDrives = @("C")
}
elseif ($env:usrDrives -match 'ALL') {
    $arrDrives = $arrWMICheck
    write-host ": Drives:   $($arrDrives -as [string])"
}
else {
    $arrDrives = @()
    $arrLocalCheck = (($env:usrDrives -replace ",", "" -replace " ", "" -replace ":", "").ToUpper()).ToCharArray()
    write-host ": Drives:   $($arrLocalCheck -as [string])"
    foreach ($iteration in $arrLocalCheck) {
        if (($arrWMICheck -as [string]) -match $iteration) {
            $arrDrives += $iteration
        }
        else {
            write-host "! ERROR:    Cannot check drive $iteration`: -- Drive letter not populated"
            write-host "            (Remember: this Component cannot parse Network Drives)"
        }
    }
}

write-host ": Depth:    $env:usrDepth"

#depth detection
if ($env:usrDepth -notmatch '^\d+$') {
    write-host "! ERROR:    Depth not an integer. Setting to default (25)."
    $env:usrDepth = 25
}

write-host ": Reports:  $PWD\(CSV Files)"
write-host "============================================================================================================="
write-host ": NOTICE:   As this Component typically takes well over 60 seconds to complete, tickets will be unable to"
write-host "            gather the StdOut below as response output. Reports are saved locally on the device instead."
write-host "============================================================================================================="
write-host `r

#empty array check
if (($arrDrives | Measure-Object).count -eq 0) {
    write-host "! ERROR: No Drives are marked for scanning."
    write-host "  Exiting..."
    exit 1
}

foreach ($varDriveLetter in $arrDrives) {
    #disk info
    write-host "= Disk Info:"
    $varDisk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$varDriveLetter`:'" | Select-Object Size, FreeSpace
    write-host ": Target Drive: $varDriveLetter`:"
    write-host ": Capacity:     $("{0:N0}" -f ($varDisk.Size / 1GB)) GB"
    write-host ": Free space:   $("{0:N0}" -f ($varDisk.FreeSpace / 1GB)) GB / $("{0:N0}" -f ($varDisk.FreeSpace / 1MB)) MB"
    write-host `r

    #list largest childfree subfolders
    write-host "= Largest sub-folders on drive:"
    write-host "  (Folders containing on-demand sync entities may be listed erroneously)"

    $arrFolders = @{}
    $arrFoldersFinal = @{}

    #enumerate root folders :: we have to do it this way otherwise the query risks being intercepted, you tell me why
    gci "$varDriveLetter`:\" -Force -ea 0 | ? { ($_.PSIsContainer) } | % {
        try {
            $varDir = $_.FullName
            gci $_.FullName -Recurse -Directory -force -Exclude "*SubStr*" -ea 1 | ? { -not (gci $_.FullName -Directory -force -ea 1) } | ? { $_.Length -gt 0 } | % {
                $varDir = $_.FullName
                $arrFolders[$varDir] = $((gci $varDir -force -ea 1 | Measure-Object Length -Sum).sum) / 1MB
            }
        }
        catch {
            write-host "! NOTICE: Unable to poll $varDir."
        }
    }

    #enumerate subfolders
    if ($arrFolders.count -gt 0) {
        #loop through folders largest-first, remove reparse points, and add the first twenty-five legitimate entries to arrFoldersFinal
        $arrFolders.GetEnumerator() | sort-object -descending -Property Value | % {
            $varEntry = $_.name
            while ($arrFoldersFinal.Count -lt 25) {
                #since this is a loop, do the termination bit first
                if ($varEntry -match ':\\$') {
                    $arrFoldersFinal[$_.Name] = [math]::Round($_.value, 2)
                    return
                }

                #check to see if the folder itself is a reparse point
                if ((gp $varEntry).attributes -as [string] -match "Reparse") {
                    $host.ui.WriteErrorLine("- Directory [$varEntry] is a reparse point. Ignoring.")
                    return
                }

                #resolve the folder back one to perform the same check again
                $varEntry = "$varEntry\.." | resolve-path
            }
        }

        #output our beautiful list
        $arrFoldersFinal.getEnumerator() | sort -descending -property Value | ft @{e = "Name"; n = "Directory Path"; width = 105 }, @{e = "Value"; n = "Size/MB"; width = 10 }
    }
    else {
        write-host ": No folders on the root of this drive."
    }

    #sizes of files
    write-host "= Largest Files on Disk:"
    write-host "  System Files, and empty files shown in Explorer for synching on-demand, omitted."
    write-host "  Use this in conjunction with the previous table to find parent folders containing large files."
    $varFileTable = Get-ChildItem -path "$varDriveLetter`:\*" -recurse -ErrorAction SilentlyContinue | ? { $_.Attributes.ToString() -NotLike "*ReparsePoint*" } | ? { ((Get-ItemProperty -literalpath $_.FullName -ErrorAction SilentlyContinue).attributes -band [io.fileAttributes]::Offline) -as [int] -ne 4096 } | ? { $_.GetType().Name -eq "FileInfo" } | ? { $_.Length -gt 10MB } | sort-Object -property length -Descending | Select-Object @{Name = "Size/MB"; Expression = { "{0:N0}" -f ($_.Length / 1MB) } }, FullName -first $env:usrDepth
    $varFileTable | ft -AutoSize @{n = 'Size/MB'; e = { $_.'Size/MB' }; align = 'right' }, @{n = 'File Path'; e = { $_.'FullName' } }

    #write this to the UDF string
    $varUDFString += "[$varDriveLetter`: #1] $(($varFileTable | Select-Object -First 1).FullName) :: $(($varFileTable | Select-Object -First 1).'Size/MB')MB "

    #produce CSVs :: june 2024
    $varFileTable | select FullName, "Size/MB" | export-csv -NoTypeInformation -Path "$PWD\fileTable-$varDriveLetter-$varEpoch.csv"
    $arrFoldersFinal.GetEnumerator() | select Name, Value | export-csv -NoTypeInformation -Path "$PWD\directoryTable-$varDriveLetter-$varEpoch.csv"
    write-host "============================================================================================================="
    write-host `r
}

@"
PLEASE NOTE:
The logic used for displaying folders can only be so precise when displaying results as a textual digest.
A single folder which contains both multiple medium-size files AND smaller sub-folders, for example, may be
omitted from this scan under certain circumstances.
If, after addressing the most obvious causes of space depletion, the disk still appears full, it may be worth
logging into the system and consulting a graphical tool like TreeSize for a second opinion.
=============================================================================================================
"@ | write-host

if ($env:usrUDF -ge 1) {
    write-host "- Largest file for each drive written as a string to UDF $env:usrUDF."
    if ($varUDFString.length -gt 255) {
        set-itemProperty -path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
        write-host "  (It had to be truncated, though.)"
    }
    else {
        set-itemProperty -path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
else {
    write-host "- Not writing data to a UDF."
}