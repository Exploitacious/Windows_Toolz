
# $varTerm = Read-Host "Enter Search Term"

$varterm = "T"

Get-ChildItem ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE") | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName, $_.BrandName -match "$varTerm" } | Format-Table DisplayName, Publisher, DisplayVersion, EstimatedSize, BrandName
