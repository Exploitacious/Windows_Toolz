# Download file from URL and optionally install it if it's an EXE or MSI
# Written by Jon North, Datto, October 2020. Improved December 2020

Function Write-ExitMessage ($ExitMessage) {
    $host.ui.WriteErrorLine("$ExitMessage")
    exit 1
}

function Start-DRMMInstall ($InstallerPath, $ArgList) {
    Write-Output "Command: $InstallerPath $ArgList"
    if ($ArgList) { Start-Process "$InstallerPath" -ArgumentList "$ArgList" -Wait } else { Start-Process "$InstallerPath" -Wait }
    if ($LASTEXITCODE) { Write-ExitMessage "$Filename install failed`r`nExit message: $_`r`n$($Error[0].Exception.InnerException.InnerException.Message)" }
}

# Validate variables
if (($env:DownloadURL -eq "") -or ($env:DownloadURL -eq $null)) { Write-ExitMessage "No download URL has been set. Cannot download file." }
if (($env:TargetFolder -eq "") -or ($env:TargetFolder -eq $null)) { Write-ExitMessage "No target folder has been set. Cannot download file." }
If (-not (Test-Path "$env:TargetFolder")) { Write-ExitMessage "Target folder $env:TargetFolder not found. Cannot download file." }

if (($env:Filename -eq "") -or ($env:Filename -eq $null)) {
    $Filename = $env:DownloadURL.split('/')[-1]
    $FileExtension = $Filename.split('.')[-1]
    if ($Filename -eq $FileExtension) { Write-ExitMessage "No filename has been set and cannot be determined from URL. Cannot download file." }
}
else {
    $Filename = $env:Filename
    $FileExtension = $Filename.split('.')[-1]
    if ($Filename -eq $FileExtension) { Write-ExitMessage "No file extension has been set in the filename. Cannot download file." }
}

Write-Output "Filename determined as $Filename"

if (($env:OverwriteFile -eq "false") -and (Test-Path "$env:TargetFolder\$Filename")) { Write-ExitMessage "$env:TargetFolder\$Filename`r`nalready exists and OvewrwriteFile set to false. Cannot download file." }

# Attempt download
Write-Output "Downloading file $Filename from`r`n$env:DownloadURL`r`nto $env:TargetFolder..."
$DownloadStart = Get-Date
try { (New-Object System.Net.WebClient).DownloadFile("$env:DownloadURL", "$env:TargetFolder\$Filename") }
catch { Write-ExitMessage "File download failed`r`nExit message: $_`r`n$($Error[0].Exception.InnerException.InnerException.Message)" }
Write-Output "File $Filename downloaded to $env:TargetFolder"
Write-Output "File download completed in $((Get-Date).Subtract($DownloadStart).Seconds) seconds`r`n"

# Attempt to launch, if selected, with parameters, if configured
if ($env:InstallFile -eq "true") {
    Write-Output "Attempting to install $Filename..."
    $InstallStart = Get-Date
    switch ($FileExtension) {
        "exe" { Start-DRMMInstall "$env:TargetFolder\$Filename" $env:Parameters }
        "msi" {
            if ($env:Parameters | Select-String "/i") { Start-DRMMInstall "msiexec.exe" "/i `"$env:TargetFolder\$Filename`" $($env:Parameters.Replace('/i',''))" }
            else { Start-DRMMInstall "msiexec.exe" "`"$env:TargetFolder\$Filename`" $env:Parameters" }
        }  
        default { Write-ExitMessage "Cannot launch file $Filename; this is a $FileExtension file not an exe or msi" }
    }
    Write-Output "$Filename install completed in $((Get-Date).Subtract($InstallStart).Seconds) seconds"
}
exit
