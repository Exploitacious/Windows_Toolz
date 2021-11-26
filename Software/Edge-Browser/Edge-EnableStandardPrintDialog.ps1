# Set the default print dialog in Edge to be handled by Windows, NOT Edge

$VerbosePreference = "Continue"

If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\UseSystemPrintDialog")) {

    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\UseSystemPrintDialog" -Force | Out-Null

}

Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "UseSystemPrintDialog" -Type DWord -Value 1

get-process -Name *Edge* | Stop-Process