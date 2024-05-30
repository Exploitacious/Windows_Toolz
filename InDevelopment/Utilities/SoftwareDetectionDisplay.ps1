
# $varTerm = Read-Host "Enter Search Term"

$varterm = "DNSFilter"

Get-ChildItem ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE") | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName, $_.BrandName -match "$varTerm" } | Select-Object | Format-Table DisplayName, PSChildName, Publisher, DisplayVersion, EstimatedSize, BrandName
