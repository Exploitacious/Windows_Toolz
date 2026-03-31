#Created by: Chris Eichermueller
#Modified by: seagull/build 6
#Checks Blocklist services to see if the external IP address has been blacklisted.

$wc = new-object System.Net.WebClient
$ip = $wc.DownloadString("http://myexternalip.com/raw")

$reversedIP = ($IP -split '\.')[3..0] -join '.'

$blacklistServers = @(
    'b.barracudacentral.org'
    'spam.rbl.msrbl.net'
    'zen.spamhaus.org'
    'bl.deadbeef.com'
    'bl.spamcop.net'
    'blackholes.five-ten-sg.com'
    'blacklist.woody.ch'
    'bogons.cymru.com'
    'cbl.abuseat.org'
    'combined.abuse.ch'
    'combined.rbl.msrbl.net'
    'db.wpbl.info'
    'dnsbl-1.uceprotect.net'
    'dnsbl-2.uceprotect.net'
    'dnsbl-3.uceprotect.net'
    'dnsbl.cyberlogic.net'
    'dnsbl.inps.de'
    'dnsbl.sorbs.net'
    'drone.abuse.ch'
    'drone.abuse.ch'
    'duinv.aupads.org'
    'dul.dnsbl.sorbs.net'
    'dul.ru'
    'dyna.spamrats.com'
    'dynip.rothen.com'
    'http.dnsbl.sorbs.net'
    'images.rbl.msrbl.net'
    'ips.backscatterer.org'
    'korea.services.net'
    'misc.dnsbl.sorbs.net'
    'noptr.spamrats.com'
    'ohps.dnsbl.net.au'
    'omrs.dnsbl.net.au'
    'orvedb.aupads.org'
    'osps.dnsbl.net.au'
    'osrs.dnsbl.net.au'
    'owfs.dnsbl.net.au'
    'owps.dnsbl.net.au'
    'pbl.spamhaus.org'
    'phishing.rbl.msrbl.net'
    'probes.dnsbl.net.au'
    'proxy.block.transip.nl'
    'psbl.surriel.com'
    'rbl.interserver.net'
    'rdts.dnsbl.net.au'
    'relays.bl.kundenserver.de'
    'relays.nether.net'
    'residential.block.transip.nl'
    'ricn.dnsbl.net.au'
    'rmst.dnsbl.net.au'
    'sbl.spamhaus.org'
    'short.rbl.jp'
    'smtp.dnsbl.sorbs.net'
    'socks.dnsbl.sorbs.net'
    'spam.abuse.ch'
    'spam.dnsbl.sorbs.net'
    'spam.spamrats.com'
    'spamlist.or.kr'
    'spamrbl.imp.ch'
    't3direct.dnsbl.net.au'
    'ubl.lashback.com'
    'ubl.unsubscore.com'
    'virbl.bit.nl'
    'virus.rbl.jp'
    'virus.rbl.msrbl.net'
    'web.dnsbl.sorbs.net'
    'wormrbl.imp.ch'
    'xbl.spamhaus.org'
    'zombie.dnsbl.sorbs.net'
)

<#
2020
19th april:   'dnsbl.ahbl.org', 'tor.ahbl.org'
19th may:     'tor.dnsbl.sectoor.de', 'torserver.tor.dnsbl.sectoor.de'
6th june:     'bl.spamcannibal.org'
3rd march:    'bl.emailbasura.org'
16th nov:     'proxy.bl.gweep.ca'
              'relays.bl.gweep.ca'
2024
2nd january:  'dnsbl.njabl.org'

2025
7th march:    'ix.dnsbl.manitu.net'
6th october:  'cdl.anti-spam.org.cn'
#>

$blacklistedOn = @()

foreach ($server in $blacklistServers) {
    $fqdn = "$reversedIP.$server"
    try {
        $null = [System.Net.Dns]::GetHostEntry($fqdn)
        $blacklistedOn += $server
    }
    catch { 
        #"nothing?"
    }
}

if ($blacklistedOn.Count -gt 0) {
    write-host "<-Start Result->"
    write-host "Status=$IP is blacklisted on the following servers: $($blacklistedOn -join ', ')"
    write-host "<-End Result->"
    exit 1
}
else {
    write-host "<-Start Result->"
    write-host "Status=OK"
    write-host "<-End Result->"
    exit 0
}