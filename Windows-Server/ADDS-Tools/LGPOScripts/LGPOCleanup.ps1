#Delete temporary working directory

$workingPath = "$($ENV:windir)\Temp\LGPO"
Remove-Item -Recurse -Force -Path $workingPath
