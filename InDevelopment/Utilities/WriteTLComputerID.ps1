# $env:usrUDF = 13 # Use for testing

$Path = Get-ItemProperty HKLM:\SOFTWARE\ThreatLocker\ -Name ComputerID
$ID = $path.computerId
Write-Host $ID

New-ItemProperty -Path "HKLM:\SOFTWARE\CentraStage" -Name Custom$env:usrUDF -Value $ID -Force | Out-Null