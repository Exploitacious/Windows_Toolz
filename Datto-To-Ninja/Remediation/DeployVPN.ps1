$Settings = @{
    name                  = $ENV:VPNName
    alluserconnection     = [boolean]([int]$ENV:AllUsersConnection)
    ServerAddress         = $ENV:ServerAddress
    TunnelType            = $ENV:TunnelType #Can be: Automatic, Ikev2, L2TP, PPTP,SSTP.
    SplitTunneling        = [boolean]([int]$ENV:SplitTunnel)
    UseWinLogonCredential = [boolean]([int]$ENV:UseWinLogonCreds)
    #There's a lot more options to set/monitor. Investigate for your own settings.
}
$VPN = Get-VPNconnection -name $($Settings.name) -AllUserConnection -ErrorAction SilentlyContinue
if (!$VPN) {
    Add-VPNconnection @Settings -verbose
}
else {
    Set-VpnConnection @settings -Verbose
}