Write-Host "Closing Teams in order to clear cache"
try {
    Get-Process -ProcessName Teams | Stop-Process -Force
    Start-Sleep -Seconds 5
    Write-Host "Teams is now closed"
}
catch {
    echo $_
}
# Now clean temp file locations
try {
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\application cache\cache" | Remove-Item -Recurse
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\blob_storage" | Remove-Item -Recurse
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\databases" | Remove-Item -Recurse
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\cache" | Remove-Item -Recurse
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\gpucache" | Remove-Item -Recurse
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\Indexeddb" | Remove-Item -Recurse
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\Local Storage" | Remove-Item -Recurse
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams\tmp" | Remove-Item -Recurse
 
}
catch {
    echo $_
}

 
# Teams cache is now cleaned
write-host "Cleaned up Teams Cache"


$ButtonType = [System.Windows.MessageBoxButton]::ok
$MessageboxTitle = “Operation Complete”
$Messageboxbody = “Teams cleanup is complete, you can now re-open Microsoft Teams.”
[System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType)