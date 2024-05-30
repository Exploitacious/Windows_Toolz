# Teams Classic Removal Script

# Verify/Elevate Admin Session. Comment out if not needed.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

function Uninstall-TeamsClassic($TeamsPath) {
    try {
        $process = Start-Process -FilePath "$TeamsPath\Update.exe" -ArgumentList "--uninstall /s" -PassThru -Wait -ErrorAction STOP

        if ($process.ExitCode -ne 0) {
            Write-Error "Uninstallation failed with exit code $($process.ExitCode)."
        }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

# Remove Teams Machine-Wide Installer
Write-Host "Removing Teams Machine-wide Installer"
$ApplicationName = "Teams Machine-Wide Installer"
$ApplicationPublisher = "Microsoft Corporation"

# Determine OS architecture
$SoftwareList = @("SOFTWARE")
if ( ( Get-Ciminstance Win32_OperatingSystem ).OSArchitecture -eq "64-bit" ) {
    $SoftwareList += "SOFTWARE\Wow6432Node"
}
$EntryFound = $false
ForEach ( $Software in $SoftwareList ) {
    # Grab the Uninstall entry from the Registry
    $RegistryPath = "HKLM:\$Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $UninstallRegistryObjects = Get-ItemProperty "$RegistryPath" | Where-Object DisplayName -Like "$ApplicationName"
    $ProductInfo = @{}
    # Set these to a default value in case the Uninstall entry is invalid or missing
    $ProductInfo.DisplayName = "Unknown"
    $ProductInfo.GUID = "Unknown"
    $ProductInfo.InstallLocation = "Unknown"
    $ProductInfo.Version = "Unknown"
    # Check the Uninstall entry
    if ( $UninstallRegistryObjects ) {
        $EntryFound = $true
        ForEach ( $UninstallRegristryObject in $UninstallRegistryObjects ) {
            # Make sure the Publisher matches (supports wildcards)
            if ( $UninstallRegristryObject.Publisher -like "$ApplicationPublisher" ) {
                $ProductInfo.DisplayName = $UninstallRegristryObject.DisplayName
                $ProductInfo.GUID = $UninstallRegristryObject.PSChildName
                $ProductInfo.InstallLocation = $UninstallRegristryObject.InstallLocation
                $ProductInfo.Version = $UninstallRegristryObject.DisplayVersion
            }
            else {
                Write-Host "The Publisher does not match!"
                $UninstallRegristryObject
                # Exit 10
            }
            # Only output the GUID
            if ( $JustGUID ) {
                $ProductInfo.GUID -replace "[{}]", ""
            }
            else {
                "GUID             --- $($ProductInfo.GUID)"
                "Install Location --- $($ProductInfo.InstallLocation)"
                "Uninstalling     --- $($ProductInfo.DisplayName) $($ProductInfo.Version)"
                # Uninstall
                Write-Host -ForegroundColor Green "Uninstalling" $ProductInfo.DisplayName $ProductInfo.Version
                Start-Process -Wait -FilePath "MsiExec.exe" -ArgumentList "/X $($ProductInfo.GUID) /qn /norestart"
            }
        }
    }
}
if ( -not $EntryFound ) {
    Write-Host "Unable to find a match for '$ApplicationName'"
    # Exit 20
}
# Get all Users
$AllUsers = Get-ChildItem -Path "$($ENV:SystemDrive)\Users"

# Process all Users
foreach ($User in $AllUsers) {
    Write-Host "Processing user: $($User.Name)"

    # Locate installation folder
    $localAppData = "$($ENV:SystemDrive)\Users\$($User.Name)\AppData\Local\Microsoft\Teams"
    $programData = "$($env:ProgramData)\$($User.Name)\Microsoft\Teams"

    if (Test-Path "$localAppData\Current\Teams.exe") {
        Write-Host "  Uninstall Teams for user $($User.Name)"
        Uninstall-TeamsClassic -TeamsPath $localAppData
    }
    elseif (Test-Path "$programData\Current\Teams.exe") {
        Write-Host "  Uninstall Teams for user $($User.Name)"
        Uninstall-TeamsClassic -TeamsPath $programData
    }
    else {
        Write-Host "  Teams installation not found for user $($User.Name)"
    }
}

# Remove old Teams folders and icons
$TeamsFolder_old = "$($ENV:SystemDrive)\Users\*\AppData\Local\Microsoft\Teams"
$TeamsIcon_old = "$($ENV:SystemDrive)\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Teams*.lnk"
Get-Item $TeamsFolder_old | Remove-Item -Force -Recurse
Get-Item $TeamsIcon_old | Remove-Item -Force -Recurse