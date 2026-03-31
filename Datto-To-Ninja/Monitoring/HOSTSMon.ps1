#HOSTS monitor :: build 1/seagull :: original code by mat s., datto labs
 
if ((Get-ItemProperty -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime -gt $((Get-Date).AddDays(-1))) {
    write-host '<-Start Result->'
    write-host "X=HOSTS modified within the last 24 hours. Last modification @ $((Get-ItemProperty -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime)"
    write-host '<-End Result->'
    Exit 1
}
else {
    write-host '<-Start Result->'
    write-host "X=HOSTS not modified since $((Get-ItemProperty -Path "$env:SystemRoot\System32\drivers\etc\hosts" -Name LastWriteTime).LastWriteTime)"
    write-host '<-End Result->'
    Exit 0
}