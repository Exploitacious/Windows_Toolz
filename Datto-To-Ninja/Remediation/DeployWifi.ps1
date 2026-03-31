<# deploy wifi profile :: build 2/seagull, july 2024
   script variables: SSID, PSK

   this script was licensed from kelvin tegelaar/cyberdrain for use exclusively with datto rmm.
   the script has since been adjusted by datto labs.
   both the script and its adjustments are the property of datto, inc. and may not be redistributed.
   the original, AGPL3-licence script is available here: https://www.cyberdrain.com/automating-with-powershell-deploying-wifi-profiles/
   	
   the moment you edit this script it becomes your own risk and support will not provide assistance with it.#>

write-host "Deploy WiFi Profile"
write-host "========================================="

$varPSK = [System.Security.SecurityElement]::Escape($ENV:PSK)
$varGUID = New-Guid
$varHex = ($env:SSID.ToCharArray() | % { [System.String]::Format("{0:X}", [System.Convert]::ToUInt32($_)) }) -join ""

write-host "- SSID: $env:SSID"

@"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$env:SSID</name>
    <SSIDConfig>
        <SSID>
            <hex>$varHex</hex>
            <name>$env:SSID</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$varPSK</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@ | out-file "$ENV:TEMP\$varGUID.SSID"
 
netsh wlan add profile filename="$ENV:TEMP\$varGUID.SSID" user=all
 
remove-item "$ENV:TEMP\$varGUID.SSID" -Force
write-host "- Actions completed."