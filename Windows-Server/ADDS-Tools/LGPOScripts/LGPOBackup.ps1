#Backup existing GPO configuration


If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You need Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Exit
}

$backupPath = "$($ENV:windir)\Temp\LGPO"

if (-not (Test-Path -LiteralPath $backupPath))
{
    New-Item -ItemType Directory -Force -Path $backupPath  -InformationAction SilentlyContinue
}

$backupPath = $backupPath + "\localPolicy"
if (Test-Path -LiteralPath $backupPath)
{
    Remove-Item -Recurse -Force -Path $backupPath
}

if (Test-Path -LiteralPath $backupPath)
{
    Write-Warning "Failure removing existing temporary backup directory $($backupPath)"
    Exit
}

New-Item -ItemType Directory -Force -Path $backupPath -InformationAction SilentlyContinue

if (-not (Test-Path -LiteralPath $backupPath))
{
    Write-Warning "Failure creating temporary backup directory $($backupPath)"
    Exit
}

#Backup the Group Policies with the LGPO commands
#$gpuPath = "$($ENV:windir)\System32\GroupPolicyUsers"
#$gpPath = "$($ENV:windir)\System32\GroupPolicy"


$url = "https://portal.galacticscan.com/go/12/LGPO.exe"
$DownloadLocation = "$($ENV:windir)\Temp\LGPO"
$execute = $DownloadLocation + "\LGPO.exe"

if (-not (Test-Path -LiteralPath $execute))
{
    Invoke-WebRequest -Uri $url -OutFile $execute
}
    
if (-not (Test-Path -LiteralPath $execute))
{
    Write-Warning "Failed to download LGPO.exe"
    Exit
}


if ($execute -ne "" -and (Test-Path -LiteralPath $execute))
{
    & $execute /b $backupPath
}

if ((Get-ChildItem -File -Path $backupPath -Recurse | Measure-Object).Count -eq 0)
{
    Write-Warning "There doesn't appear to be anything to backup"
}
else
{
Compress-Archive -Path "$backupPath\*" -DestinationPath $backupPath -CompressionLevel Optimal -Force
}

Remove-Item -Path $backupPath -Recurse -Force