#Make sure PS is in Admin/elevate mode.

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

Write-Host "DNSFilter Removal Tool"

# Remove DNS Filter ---
Write-Host "Uninstalling..."
function Uninstall-App {
    Write-Output "Uninstalling $($args[0])"
    foreach($obj in Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") {
        $dname = $obj.GetValue("DisplayName")
        if ($dname -contains $args[0]) {
            $uninstString = $obj.GetValue("UninstallString")
            foreach ($line in $uninstString) {
                $found = $line -match '(\{.+\}).*'
                If ($found) {
                    $appid = $matches[1]
                    Write-Output $appid
                    start-process "msiexec.exe" -arg "/X $appid /qb" -Wait
                }
            }
        }
    }
}
Uninstall-App "DNSFilter Agent"
Uninstall-App "DNS Agent"

start-sleep 3

Write-Host "Removing Registry Keys..."

Remove-Item -ErrorAction SilentlyContinue -Path "HKLM:\Software\DNSFilter" -Recurse
Remove-Item -ErrorAction SilentlyContinue -Path "HKLM:\Software\DNSAgent" -Recurse
 