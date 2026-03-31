#Clear existing GPO configuration

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You need Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Exit
}

Remove-Item -Recurse -Path "$($ENV:windir)\System32\GroupPolicyUsers" -Force -ErrorAction silentlycontinue
Remove-Item -Recurse -Path "$($ENV:windir)\System32\GroupPolicy" -Force -ErrorAction silentlycontinue

Write-Host "Running GPUpdate to clear local policy cache." -ForegroundColor Green
gpupdate /force

#Write-Host "Starting GPEdit. Please create your policy." -ForegroundColor Green
#Start-Process "gpedit.msc"

#Exit