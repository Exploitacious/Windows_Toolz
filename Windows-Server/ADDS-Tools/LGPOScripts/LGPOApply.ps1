#Apply GPO configuration

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)][string] $LGPOPath = ""
)

Expand-Archive "$($ENV:windir)\Temp\LGPO\localPolicy.zip" "$($ENV:windir)\Temp\LGPO\localPolicy"

if ($LGPOPath -ne "")
{
    if (-not (Test-Path -LiteralPath $LGPOPath))
    {
        Write-Warning "Specified LGPO.exe path not found"
        Exit
    }
}

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You need Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Exit
}

$DownloadLocation = "$($ENV:windir)\Temp\LGPO"
if (-not (Test-Path -LiteralPath $DownloadLocation))
{
    New-Item -ItemType Directory -Force -Path $DownloadLocation -InformationAction SilentlyContinue
}

if (-not (Test-Path -LiteralPath $DownloadLocation))
{
    Write-Warning "Failed to create working directory: $DownloadLocation"
    Exit
}

$execute = $LGPOPath
if ($LGPOPath -eq "")
{
    $url = "https://portal.galacticscan.com/go/12/LGPO.exe"

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
}
$items = Get-ChildItem -Path "$($ENV:windir)\Temp\LGPO\localPolicy"
$ender = $items[0]
$ArchiveFilePath = "$($ENV:windir)\Temp\LGPO\localPolicy\" + $ender


if ($ArchiveFilePath -ne "" -and (Test-Path -LiteralPath $ArchiveFilePath))
{
    & $execute /g $ArchiveFilePath
}