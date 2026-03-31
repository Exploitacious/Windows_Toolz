## Set Veriables for the Meraki VPN and Easily Deploy it with a PS1 script. Will use split-tunneling, and will add a static route to your IP Tables

#Elevate Admin
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }


[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')

$VPNConnectionNameDS = "Name of VPN Connection that will show in Windows ex. 'ClientName-VPN'"
$VPNConnectionNameDST = "Connection Name"
$VPNServerAddressDS = "Publically routable IP Address or Domain"
$VPNServerAddressDST = "Server Address"
$VPNPreShrKeyDS = "Pre-Shared Key used for authentication"
$VPNPreShrKeyDST = "Pre-Shared Key"
$VPNInternalSubnetDS = "Add a static route to the internal subnet of the network you wish to be connected to. ex. '192.168.10.0/24'"
$VPNInternalSubnetDST = "Internal Subnet"

$VPNConnectionName = [Microsoft.VisualBasic.Interaction]::InputBox($VPNConnectionNameDS, $VPNConnectionNameDST) # Name of VPN Connection that will show in Windows ex. "ClientName-VPN"
$VPNServerAddress = [Microsoft.VisualBasic.Interaction]::InputBox($VPNServerAddressDS, $VPNServerAddressDST) # Publically routable IP Address or Domain
$VPNPreShrKey = [Microsoft.VisualBasic.Interaction]::InputBox($VPNPreShrKeyDS, $VPNPreShrKeyDST) # Pre-Shared Key used for authentication
$VPNInternalSubnet = [Microsoft.VisualBasic.Interaction]::InputBox($VPNInternalSubnetDS, $VPNInternalSubnetDST) # Add a static route to the internal subnet of the network you wish to be connected to. ex. '192.168.10.0/24'


Add-VpnConnection -AllUserConnection -Name $VPNConnectionName -ServerAddress $VPNServerAddress -TunnelType L2TP -EncryptionLevel Optional -L2tpPsk $VPNPreShrKey -AuthenticationMethod PAP -SplitTunneling -RememberCredential $True -Force

# VPN settings and go to IPv4 > Advanced > UNCHECK the box that says "Use default gateway of the VPN"

netsh interface ipv4 add route $VPNInternalSubnet $VPNConnectionName
# Disable-NetAdapterBinding -Name $VPNConnectionName -ComponentID ms_tcpip6 -PassThru