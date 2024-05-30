#-------------------------------------------------------------------------------------------
# ScriptName  : FolderSizeReport.ps1
# Description : Combining robocopy and Powershell to Report folders size while avoiding the
#               long Path file error
# Version     : 1.0 
# Note        : Original script can be found at learn-powershell.net 
#-------------------------------------------------------------------------------------------

$data = Get-ChildItem 'c:\windows\System32'
$data | foreach {
    $item = $_.FullName
    $params = New-Object System.Collections.Arraylist
    $params.AddRange(@("/L", "/S", "/NJH", "/BYTES", "/FP", "/NC", "/NDL", "/TS", "/XJ", "/R:0", "/W:0"))
    $countPattern = "^\s{3}Files\s:\s+(?<Count>\d+).*"
    $sizePattern = "^\s{3}Bytes\s:\s+(?<Size>\d+(?:\.?\d+)).*"
    $return = robocopy $item NULL $params
    If ($return[-5] -match $countPattern) {
        $Count = $matches.Count
    }
    If ($Count -gt 0) {
        If ($return[-4] -match $sizePattern) {
            $Size = $matches.Size
        }
    }
    Else {
        $Size = 0
    }

    $object = New-Object PSObject -Property @{

        FullName = $item
        Count    = [int]$Count
        Size     = ([math]::Round($Size / 1GB, 2))

    }

    $object.pstypenames.insert(0, 'IO.Folder.Foldersize')
    Write-host "$($object.FullName);$($object.Count);$($object.Size) GB;$($_.LastAccessTime);$($_.LastWriteTime)"
    $Size = $Null

}