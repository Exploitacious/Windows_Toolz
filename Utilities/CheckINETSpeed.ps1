function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    Write-Host '<-End Diagnostic->'
} 
function write-DRRMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "Alert=$message"
    Write-Host '<-End Result->'
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.3") {
    write-DRRMAlert "Unsupported OS. Only Server 2012R2 and up are supported."
    exit 1
}


$maxpacketloss = $env:MaxPacketLoss #how much % packetloss until we alert. 
$MinimumDownloadSpeed = $ENV:MinDownloadSpeed #What is the minimum expected download speed in Mbit/ps
$MinimumUploadSpeed = $ENV:MinuploadSpeed #What is the minimum expected upload speed in Mbit/ps
#Latest version can be found at: https://www.speedtest.net/nl/apps/cli 
$DownloadURL = $ENV:SpeedtestURL
$DownloadLocation = "$($Env:ProgramData)\SpeedtestCLI"
try {
    $TestDownloadLocation = Test-Path $DownloadLocation
    if (!$TestDownloadLocation) { New-Item $DownloadLocation -ItemType Directory -Force }
    $TestDownloadLocationZip = Test-Path "$DownloadLocation\Speedtest.zip"
    if (!$TestDownloadLocationZip) { Invoke-WebRequest -UseBasicParsing -Uri $DownloadURL -OutFile "$($DownloadLocation)\speedtest.zip" }
    $TestDownloadLocationExe = Test-Path "$DownloadLocation\Speedtest.exe"
    if (!$TestDownloadLocationExe) { Expand-Archive "$($DownloadLocation)\speedtest.zip" -DestinationPath $DownloadLocation -Force }
}
catch {
    write-DRRMAlert "The download and extraction of SpeedtestCLI failed. Error: $($_.Exception.Message)"
    exit 1
}
$PreviousResults = if (Test-Path "$($DownloadLocation)\LastResults.txt") { Get-Content "$($DownloadLocation)\LastResults.txt" | ConvertFrom-Json }
$ErrorActionPreference = 'SilentlyContinue'
$SpeedtestResults = & "$($DownloadLocation)\speedtest.exe" --format=json --accept-license --accept-gdpr
$ErrorActionPreference = 'Continue'
$SpeedtestResults | Out-File "$($DownloadLocation)\LastResults.txt" -Force
$SpeedtestResults = $SpeedtestResults | ConvertFrom-Json

#creating object
[PSCustomObject]$SpeedtestObj = @{
    downloadspeed = [math]::Round($SpeedtestResults.download.bandwidth / 1000000 * 8, 2)
    uploadspeed   = [math]::Round($SpeedtestResults.upload.bandwidth / 1000000 * 8, 2)
    packetloss    = [math]::Round($SpeedtestResults.packetLoss)
    isp           = $SpeedtestResults.isp
    ExternalIP    = $SpeedtestResults.interface.externalIp
    InternalIP    = $SpeedtestResults.interface.internalIp
    UsedServer    = $SpeedtestResults.server.host
    ResultsURL    = $SpeedtestResults.result.url
    Jitter        = [math]::Round($SpeedtestResults.ping.jitter)
    Latency       = [math]::Round($SpeedtestResults.ping.latency)
}
$SpeedtestHealth = @()
#Comparing against previous result. Alerting is download or upload differs more than 20%.
if ($PreviousResults) {
    if ($PreviousResults.download.bandwidth / $SpeedtestResults.download.bandwidth * 100 -le 80) { $SpeedtestHealth += "Download speed difference is more than 20%" }
    if ($PreviousResults.upload.bandwidth / $SpeedtestResults.upload.bandwidth * 100 -le 80) { $SpeedtestHealth += "Upload speed difference is more than 20%" }
}

#Comparing against preset variables.
if ($SpeedtestObj.downloadspeed -lt $MinimumDownloadSpeed) { $SpeedtestHealth += "Download speed is lower than $MinimumDownloadSpeed Mbit/ps" }
if ($SpeedtestObj.uploadspeed -lt $MinimumUploadSpeed) { $SpeedtestHealth += "Upload speed is lower than $MinimumUploadSpeed Mbit/ps" }
if ($SpeedtestObj.packetloss -gt $MaxPacketLoss) { $SpeedtestHealth += "Packetloss is higher than $maxpacketloss%" }

if (!$SpeedtestHealth) {
    write-DRRMAlert "Healthy"
}
else {
    write-DRRMAlert "Unhealthy - Check Diagnostics data"
    write-DRMMDiag  @($SpeedtestHealth, $SpeedtestObj)
    exit 1
}