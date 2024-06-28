Import-Module $env:SyncroModule

<#
.SYNOPSIS
   Installs browser hardening settings for Chrome and (some for) Edge per baseline configuration below.
.DESCRIPTION
   Sets browser policies for a security baseline that can help avoid user error and vulnerabilities.
.INSTRUCTIONS
   Change the variables below in the "settings" section to your liking for your baseline.  Do not edit anything below that.
   The settings below are my recommended settings; but feel free to customize.
#>

<# ######################## SETTINGS ######################################### #>

<# Don't allow geolocation data to be sent to websites by default
("DefaultGeolocationSetting" policy) #>

$defaultDenyGeo = "true"


<# Don't allow websites to send push notifications - leaving it set to false allows
the user to set one way or the other, setting to true forces notifications to be disabled.
("DefaultNotificationsSetting" policy) #>

$notificationsDisabled = "false"


<# Disable the Flash plugin (note, does not uninstall, just disables)
("DefaultPluginsSetting" policy) #>

$disableFlash = "true"


<# Deny access to serial ports (no reason a standard user should need this)
("DefaultSerialGuardSetting" policy) #>

$denySerial = "true"


<# Don't allow websites to access nearby Bluetooth devices 
("DefaultWebBluetoothGuardSetting" policy) #>

$denyBluetooth = "true"


<# Don't allow websites to ask to access connected USB devices
("DefaultWebUsbGuardSetting" policy) #>

$denyUSB = "true"



<# Disable Google Cast
(Inverse of "EnableMediaRouter" policy) #>

$disableCast = "false"


<# Disable Cross Origin Auth Prompts (Important to stop CSRF and XSS attacks)
(Inverse of "AllowCrossOriginAuthPrompt" policy - setting to false leaves defaults) #>

$disableCOAP = "true"


<# Disallow outdated plugins (setting to false will prompt user instead of default disable)
************ Chrome Only ************
("AllowOutdatedPlugins" policy) #>

$disableOutdated = "true"


<# Controls whether the user can sign in to the browser.  0 = disable sign-in,
1 = enable sign in (default), 2 = Force sign in.
("BrowserSignin" policy) #>

$browserSignin = "1"


<# Restrict accounts to domain
("RestrictSigninToPattern" policy) #>

$restrictAccountDomain = "false"
$allowedAccountDomain = "example.com"



<# Disable Safe Browsing Override
************ Chrome Only ************
("DisableSafeBrowsingProceedAnyway" policy #>

$disableSBoverride = "true"


<# Don't allow users to override SSL certificate warnings.  This is important to avoid MitM attacks.
("SSLErrorOverrideAllowed" policy #>
$disallowSSLoverride = "true"


<# Enforce DNSoverHTTPS (uses Cloudflare DoH)
************ Chrome Only ************
("DnsOverHttpsMode" policy) #>

$forceDoH = "true"


<# Block potentially dangerous downloads
("DownloadRestrictions" policy) #>

$blockDangerousDownload = "true"


<# Disable Proxy Server
("ProxySettings" policy) #>

$disableProxy = "true"


<# Require modern version of TLS - tls1 will allow for most compatability; but
tls1.1 will be more secure.
("SSLVersionMin" policy) #>

$restrictTLS = "true"
<# Valid options: tls1, tls1.1, tls1.2 #>
$tlsVersion = "tls1"


<# Disable built-in password storage
("PasswordManagerEnabled" policy) #>

$disableSavePassword = "true"


<# Disable address autofill
("AutofillAddressEnabled policy) #>

$disableAddressAutofill = "false"

<# Disable payment autofill
("AutofillCreditCardEnabled") #>

$disablePayment = "false"


<# Disable access to settings page
(URLBlocklist policy) #>

$disableSettings = "false"





<# Comma seperated list of automatically installed browser extensions IDs
Note that if you set this policy and then later remove an extension, it will be
automatically removed from all computers that previously received the policy.
To disable, simply remove all IDs from the list.
("ExtensionInstallForcelist" policy) 

To get extension IDs, browse to the extension in the Chrome Web Store, then grab
the seemingly random string at the end of the url before the question mark
(if there is a question mark, otherwise just the random string at the end) 

Will only work on Chrome if running W10 pro on a domain or enrolled in Chrome Browser Cloud Management
Will only work on Edge if running W10 pro on a domain.

Chrome Extensions are (in order):
Ublock_Origin,HTTPSeverywhere,Microsoft_Defender_Browser_Protection #>

$installedExtensions = "cjpalhdlnbpafiamejdnhcphjbkeiagm,gcbommkclmclpchllfjekcdonpmejbdp,bkbeeeffjjeopflfhgeknacdieedcoml"

<# Edge Extensions are (in order):
Ublock_Origin,HTTPSeverywhere,Microsoft_Defender_Browser_Protection #>

$installedExtensionsEdge = "odfafepnkmbhccpbejgmiehpchacaeak,fchjpkplmbeeeaaogdbhjbgbknjobohb"


<# Block non-whitelisted browser extensions
("ExtensionInstallBlocklist" policy) #>

$blockExtensions = "true"


<# Whitelisted extensions to exclude from the block set above.
Followed by List of whitelisted extension IDs (One per line, descriptor at the beginning - 
doesn't matter what the descriptor is as long as it's there and doesn't include a colon until the end)
("ExtensionInstallAllowlist" policy) #>

$setAllowList = "true"

<# Chrome extensions: #>

$allowedExtensions = @"
Ublock Origin:cjpalhdlnbpafiamejdnhcphjbkeiagm
HTTPSeverywhere:gcbommkclmclpchllfjekcdonpmejbdp
Microsoft Defender Browser Protection:bkbeeeffjjeopflfhgeknacdieedcoml
FlowCrypt:bnjglocicdkmhmoohhfkfkbbkejdhdgc
Google Docs Offline:ghbmnnjooekpmoecnnnilnnbdlolhkhi
IT Glue Chrome Extension:mlhdnjepakdfdaabohjgegnomlgeejep
LastPass:hdokiejnpimakedhajhdlcegeplioahd
Multi Email Forward by CloudHQ:baebodhfcfpnmnpnnheadibijemdlmip
Pay by Privacy.com:hmgpakheknboplhmlicfkkgjipfabmhp
Privacy Badger:pkehgijcmpdhfbdbbnkijodmdjhbjlgp
security.txt:enhcidlgmnmolephljjhbgfnjlfjnimd
Social Fixer for Facebook:ifmhoabcaeehkljcfclfiieohkohdgbb
Wappalyzer:gppongmhjkpfnbhagpmjfkannfbllamg
Google Docs:aohghmighlieiainnegkcijnfilokake
Google Sheets:felcaaldnbdncclmgdcncolpebgiejap
Google Slides:aapocclcgogkmnckokdopfmhonfmgoek
Adobe Acrobat:efaidnbmnnnibpcajpcglclefindmkaj
Google Translate:aapbdbdomjkkjkaonfhkkikfgjllcleb
Microsoft Teams Screen Sharing:dhheiegalgcabbcobinipgmhepkkeidk
Skype:lifbcibllhkdhoafpjfnlhfpfgnpldfl
Zoom Scheduler:kgjfgplpablkjnlkjmjdecgdpfankdle
Google Hangouts:nckgahadagoaajjgafhacjanaoiihapd
Microsoft Office:ndjpnladcallmjemlbaebfadecfhkepb
Google Keep:lpcaedmchfhocbbapmcbpinfpgnhiddi
Vimeo Record:ejfmffkmeigkphomnpabpdabfddeadcb
The Great Suspender:klbibkeccnjlkjkiokjodocebajanakg
Calendy:cbhilkcodigmigfbnphipnnmamjfkipp
Bitwarden:nngceckbapebfimnlniiiahkandclblb
KeePassXC:oboonakemofpalcgghocfoadofidjkkk
Toggl Track:oejgccbfbmkkpaidnkphaiaecficdnfn
Keeper Password Manager:bfogiafebfohielmmehodmfbbebbbpei
1Password X:aeblfdkhhhdcdjpifhhbdiojplfjncoa
1Password Extension:aomjjhallfgjeglblehebfpbcfeobpgk
Dashlane:fdjamakpfbbddfjaooikfcpapjohcfmg
Roboform:pnlccmojcmeohlpggmfnbbiapkmbliob
Myki:bmikpgodpkclnkgmnpphehdgcimmided
GoToMeeting for Google Calendar:gaonpiemcjiihedemhopdoefaohcjoch
BlueJeans for Google Calendar:iedelpfmeejalepbpmmfbfnfoeojohpp
CiscoWebex:ifbdadgbpalmagalacllfaflfakmfkac
OneLogin:ioalpmibngobedobkmbhgmadaphocjdn
Okta Browser Plugin:glnpjglilkicbckjpbgcfkogebgllemb
"@

<# Edge allowed extensions: #>
$allowedExtensionsEdge = @"
Ublock Origin:odfafepnkmbhccpbejgmiehpchacaeak
HTTPSeverywhere:fchjpkplmbeeeaaogdbhjbgbknjobohb
LastPass:bbcinlkgjjkejfdpemiealijmmooekmp
Privacy Badger:mkejgcgkdlddbggjhhflekkondicpnop
security.txt:hfhegbhdofjdepaelheapbihjlhkaofj
Social Fixer for Facebook:bhaooomeolkdacolgpkfbfookhomkbei
Wappalyzer:mnbndgmknlpdjdnjfmfcdjoegcckoikn
Zoom Scheduler:gdndpilddmlahjjcfmknlmindbklnbel
Bitwarden:jbkfoedolllekgbhcbcoahefnbanhhlh
KeePassXC:pdffhmdngciaglkoonimfcmckehcpafo
Keeper Password Manager:mpfckamfocjknfipmpjdkkebpnieooca
Keeper Second Ext:lfochlioelphaglamdcakfjemolpichk
1Password X:dppgmdbiimibapkepcbdbmkaabgiofem
Dashlane:gehmmocbbkpblljhkekmfhjpfbkclbph
Roboform:ljfpcifpgbbchoddpjefaipoiigpdmag
Myki:nofkfblpeailgignhkbnapbephdnmbmn
Okta Browser Plugin:ncoafaeidnkeafiehpkfoeklhajkpgij
"@


<# ########### END SETTINGS NO FURTHER MODIFICATION NEEDED ################## #>


$ChromeRegistryBase = "HKLM:\Software\Policies\Google\Chrome"
$EdgeRegistryBase = "HKLM:\Software\Policies\Microsoft\Edge"

function Set-Val {
    $rPath = $args[0]
    $Name = $args[1]
    $type = $args[2]
    $value = $args[3]
    
    if (Test-Path $rPath) {
        New-ItemProperty -Path $rPath -Name $Name -Value $value -PropertyType $type -Force | Out-Null
    }
    else {
        New-Item -Path $rPath -Force | Out-Null
        New-ItemProperty -Path $rPath -Name $Name -Value $value -PropertyType $type -Force | Out-Null
    }
}

function Test-RegistryValue($regkey, $name) {
    $exists = Get-ItemProperty -Path "$regkey" -Name "$name" -ErrorAction SilentlyContinue
    If (($exists -ne $null) -and ($exists.Length -ne 0)) {
        Return $true
    }
    Return $false
}

function Del-Val {
    $rPath = $args[0]
    $Name = $args[1]
    if (Test-RegistryValue($rPath, $Name)) {
        Remove-ItemProperty -Path $rPath -Name $Name
    }
}

function Del-Key {
    $rPath = $args[0]
    if (Test-Path $rPath) {
        Remove-Item -Path $rPath -Recurse
    }
}

if ($defaultDenyGeo -eq "true") {
    Set-Val $ChromeRegistryBase DefaultGeolocationSetting DWord 0x00000001
    Set-Val $EdgeRegistryBase DefaultGeolocationSetting DWord 0x00000002
}
else {
    Del-Val $ChromeRegistryBase DefaultGeoLocationSetting
    Del-Val $EdgeRegistryBase DefaultGeolocationSetting
}


if ($notificationsDisabled -eq "true") {
    Set-Val $ChromeRegistryBase DefaultNotificationsSetting DWord 0x00000002
    Set-Val $EdgeRegistryBase DefaultNotificationsSetting DWord 0x00000002
}
else {
    Del-Val $ChromeRegistryBase DefaultNotificationsSetting
    Del-Val $EdgeRegistryBase DefaultNotificationsSetting
}


if ($disableFlash -eq "true") {
    Set-Val $ChromeRegistryBase DefaultPluginsSetting DWord 0x00000002
    Set-Val $EdgeRegistryBase DefaultPluginsSetting DWord 0x00000002
}
else {
    Del-Val $ChromeRegistryBase DefaultPluginsSetting
    Del-Val $EdgeRegistryBase DefaultPluginsSetting
}


if ($denySerial -eq "true") {
    Set-Val $ChromeRegistryBase DefaultSerialGuardSetting DWord 0x00000002
    Set-Val $EdgeRegistryBase DefaultSerialGuardSetting DWord 0x00000002
}
else {
    Del-Val $ChromeRegistryBase DefaultSerialGuardSetting
    Del-Val $EdgeRegistryBase DefaultSerialGuardSetting
}


if ($denyBluetooth -eq "true") {
    Set-Val $ChromeRegistryBase DefaultWebBluetoothGuardSetting DWord 0x00000002
    Set-Val $EdgeRegistryBase DefaultWebBluetoothGuardSetting DWord 0x00000002
}
else {
    Del-Val $ChromeRegistryBase DefaultWebBluetoothGuardSetting
    Del-Val $EdgeRegistryBase DefaultWebBluetoothGuardSetting
}


if ($denyUSB -eq "true") {
    Set-Val $ChromeRegistryBase DefaultWebUsbGuardSetting DWord 0x00000002
    Set-Val $EdgeRegistryBase DefaultWebUsbGuardSetting DWord 0x00000002
}
else {
    Del-Val $ChromeRegistryBase DefaultWebUsbGuardSetting
    Del-Val $EdgeRegistryBase DefaultWebUsbGuardSetting
}


if ($disableCast -eq "true") {
    Set-Val $ChromeRegistryBase EnableMediaRouter DWord 0x00000000
    Set-Val $EdgeRegistryBase EnableMediaRouter DWord 0x00000000
}
else {
    Del-Val $ChromeRegistryBase EnableMediaRouter
    Del-Val $EdgeRegistryBase EnableMediaRouter
}


if ($disableCOAP -eq "true") {
    Set-Val $ChromeRegistryBase AllowCrossOriginAuthPrompt DWord 0x00000000
    Set-Val $EdgeRegistryBase AllowCrossOriginAuthPrompt DWord 0x00000000
}
else {
    Del-Val $ChromeRegistryBase AllowCrossOriginAuthPrompt
    Del-Val $EdgeRegistryBase AllowCrossOriginAuthPrompt
}



if ($disableOutdated -eq "true") {
    Set-Val $ChromeRegistryBase AllowOutdatedPlugins DWord 0x00000000
}
else {
    Del-Val $ChromeRegistryBase AllowOutdatedPlugins
}


if (($browserSignin -eq "0") -or ($browserSignin -eq "1") -or ($browserSignin -eq "2")) {
    Set-Val $ChromeRegistryBase BrowserSignin DWord $browserSignin
    Set-Val $EdgeRegistryBase BrowserSignin DWord $browserSignin
}
else {
    Del-Val $ChromeRegistryBase BrowserSignin
    Del-Val $EdgeRegistryBase BrowserSignin
}


if ($restrictAccountDomain -eq "true") {
    Set-Val $ChromeRegistryBase RestrictSigninToPattern String .*@$allowedAccountDomain
    Set-Val $EdgeRegistryBase RestrictSigninToPattern String .*@$allowedAccountDomain
}
else {
    Del-Val $ChromeRegistryBase RestrictSigninToPattern
    Del-Val $EdgeRegistryBase RestrictSigninToPattern
}


if ($disableSBoverride -eq "true") {
    Set-Val $ChromeRegistryBase DisableSafeBrowsingProceedAnyway DWord 0x00000001
}
else {
    Del-Val $ChromeRegistryBase DisableSafeBrowsingProceedAnyway
}


if ($disallowSSLoverride -eq "true") {
    Set-Val $ChromeRegistryBase SSLErrorOverrideAllowed DWord 0x00000000
    Set-Val $EdgeRegistryBase SSLErrorOverrideAllowed DWord 0x00000000
}
else {
    Del-Val $ChromeRegistryBase SSLErrorOverrideAllowed
    Del-Val $EdgeRegistryBase SSLErrorOverrideAllowed
}


if ($forceDoH -eq "true") {
    Set-Val $ChromeRegistryBase DnsOverHttpsMode String secure
    Set-Val $ChromeRegistryBase DnsOverHttpsTemplates String https://cloudflare-dns.com/dns-query { ?dns }
}
else {
    Del-Val $ChromeRegistryBase DnsOverHttpsMode
    Del-Val $ChromeRegistryBase DnsOverHttpsTemplates
}


if ($blockDangerousDownload -eq "true") {
    Set-Val $ChromeRegistryBase DownloadRestrictions DWord 0x00000002
    Set-Val $EdgeRegistryBase DownloadRestrictions DWord 0x00000002
}
else {
    Del-Val $ChromeRegistryBase DownloadRestrictions
    Del-Val $EdgeRegistryBase
}


if ($disableProxy -eq "true") {
    Set-Val $ChromeRegistryBase ProxySettings String @'
{
 "ProxyMode": "direct",
 "ProxyPacUrl": "",
 "ProxyServer": "",
 "ProxyBypassList": ""
}
'@
    Set-Val $EdgeRegistryBase ProxySettings String @'
{
 "ProxyMode": "direct",
 "ProxyPacUrl": "",
 "ProxyServer": "",
 "ProxyBypassList": ""
}
'@
}
else {
    Del-Val $ChromeRegistryBase ProxySettings
    Del-Val $EdgeRegistryBase ProxySettings
}


if ($restrictTLS -eq "true") {
    Set-Val $ChromeRegistryBase SSLVersionMin String $tlsVersion
    Set-Val $EdgeRegistryBase SSLVersionMin String $tlsVersion
}
else {
    Del-Val $ChromeRegistryBase SSLVersionMin
    Del-Val $EdgeRegistryBase
}


if ($disableSavePassword -eq "true") {
    Set-Val $ChromeRegistryBase PasswordManagerEnabled DWord 0x00000000
    Set-Val $EdgeRegistryBase PasswordManagerEnabled DWord 0x00000000
}
else {
    Del-Val $ChromeRegistryBase PasswordManagerEnabled
    Del-Val $EdgeRegistryBase PasswordManagerEnabled
}

if ($disableAddressAutofill -eq "true") {
    Set-Val $ChromeRegistryBase AutofillAddressEnabled DWord 0x00000000
    Set-Val $EdgeRegistryBase AutofillAddressEnabled DWord 0x00000000
}
else {
    Del-Val $ChromeRegistryBase AutofillAddressEnabled
    Del-Val $EdgeRegistryBase AutofillAddressEnabled
}

if ($disablePayment -eq "true") {
    Set-Val $ChromeRegistryBase AutofillCreditCardEnabled DWord 0x00000000
    Set-Val $EdgeRegistryBase AutofillCreditCardEnabled DWord 0x00000000
}
else {
    Del-Val $ChromeRegistryBase AutofillCreditCardEnabled
    Del-Val $EdgeRegistryBase AutofillCreditCardEnabled
}


if ($installedExtensions -ne "") {
        
    Del-Key $ChromeRegistryBase\ExtensionInstallForcelist
    
    $cCount = ($installedExtensions.ToCharArray() | Where-Object { $_ -eq ',' } | Measure-Object).Count
    $arr = $installedExtensions.Split(",")
    
    For ($i = 0; $i -le $cCount; $i++) {
        $n = $i + 1
        Set-Val $ChromeRegistryBase\ExtensionInstallForcelist $n String $arr[$i]
    }
    
    Del-Key $EdgeRegistryBase\ExtensionInstallForcelist
    
    $cCountE = ($installedExtensionsEdge.ToCharArray() | Where-Object { $_ -eq ',' } | Measure-Object).Count
    $arrE = $installedExtensionsEdge.Split(",")
    
    For ($ie = 0; $ie -le $cCountE; $ie++) {
        $ne = $ie + 1
        Set-Val $EdgeRegistryBase\ExtensionInstallForcelist $ne String $arrE[$ie]
    }
    
    
}
else {
    Del-Key $ChromeRegistryBase\ExtensionInstallForcelist
    Del-Key $EdgeRegistryBase\ExtensionInstallForcelist
}


if ($blockExtensions -eq "true") {
    Set-Val $ChromeRegistryBase\ExtensionInstallBlocklist 1 String "*"
    Set-Val $EdgeRegistryBase\ExtensionInstallBlocklist 1 String "*"
}
else {
    Del-Key $ChromeRegistryBase\ExtensionInstallBlocklist
    Del-Key $EdgeRegistryBase\ExtensionInstallBlocklist
}



if ($setAllowList -eq "true") {
        
    Del-Key $ChromeRegistryBase\ExtensionInstallAllowlist
    Del-Key $EdgeRegistryBase\ExtensionInstallAllowlist
    
    $arr = $allowedExtensions.Split([environment]::NewLine)
    $cCount = $arr.Count
    
    For ($i = 0; $i -lt $cCount; $i++) {
        $n = $i + 1
        $id = $arr[$i].Split(":")[1]
        Set-Val $ChromeRegistryBase\ExtensionInstallAllowlist $n String $id
    }
    
    
    
    $arrE = $allowedExtensionsEdge.Split([environment]::NewLine)
    $cCountE = $arrE.Count
    
    For ($ie = 0; $ie -lt $cCountE; $ie++) {
        $ne = $ie + 1
        $ide = $arrE[$ie].Split(":")[1]
        Set-Val $EdgeRegistryBase\ExtensionInstallAllowlist $ne String $ide
    }
    
}
else {
    Del-Key $ChromeRegistryBase\ExtensionInstallAllowlist
    Del-Key $EdgeRegistryBase\ExtensionInstallAllowlist
}

if ($disableSettings -eq "true") {
    Set-Val $ChromeRegistryBase\URLBlocklist 1 REG_SZ chrome://settings
    Set-Val $EdgeRegistryBase\URLBlocklist 1 REG_SZ edge://settings
}
else {
    Del-Val $ChromeRegistryBase\URLBlocklist 1
    Del-Val $EdgeRegistryBase\URLBlocklist 1
}


Log-Activity -Message "Applied Browser Hardening settings to Chrome and Edge" -EventName "Cyber Hardening"