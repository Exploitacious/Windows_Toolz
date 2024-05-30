$VMName = Read-Host "Enter the VM Name of the machine you wish to whack. This script will forcibly kill the process running the machine."

$VmGUID = (Get-VM $VMName).id
$VMWMProc = (Get-WMIObject Win32_Process | Where-Object { $_.Name -match 'VMWP' -and $_.CommandLine -match $VmGUID })
Stop-Process ($VMWMProc.ProcessId) –Force