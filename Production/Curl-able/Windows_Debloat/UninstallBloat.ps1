# Automated Bloat Removal
Write-Host -ForegroundColor Green "Automated Bloat Removal for MSI and Appx"
Start-Sleep 3

## Pre-Reqs
# Verify/Elevate Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }
# Determine OS architecture
$SoftwareList = @("SOFTWARE")
if ( ( Get-Ciminstance Win32_OperatingSystem ).OSArchitecture -eq "64-bit" ) {
    $SoftwareList += "SOFTWARE\Wow6432Node"
}

## Variables
$EntryFound = $false

# Appx Bloat list
$AppxBloatList = @(
    "*562882FEEB491*" # Code Writer from Actipro Software LLC
    "*549981C3F5F10*" # Microsoft Cortana
    "*ActiproSoftware*"
    "*Alexa*"
    "*AIMeetingManager*"
    "*AdobePhotoshopExpress*"
    "*Advertising*"
    "*ArmouryCrate*"
    "*Asphalt*"
    "*ASUSPCAssistant*"
    "*AutodeskSketchBook*"
    "*BingNews*"
    "*BingSports*"
    "*BingTranslator*"
    "*BingWeather*"
    "*BubbleWitch3Saga*"
    "*CandyCrush*"
    "*Casino*"
    "*COOKINGFEVER*"
    "*CyberLink*"
    "*Disney*"
    "*Dolby*"
    "*DrawboardPDF*"
    "*Duolingo*"
    "*ElevocTechnology*"
    "*EclipseManager*"
    "*Facebook*"
    "*FarmVille*"
    "*Fitbit*"
    "*flaregames*"
    "*Flipboard*"
    "*GamingApp*"
    "*GamingServices*"
    "*GetHelp*"
    "*Getstarted*"
    "*HPPrinter*"
    "*iHeartRadio*"
    "*Instagram*"
    "*Keeper*"
    "*king.com*"
    "*Lenovo*"
    "*Lens*"
    "*LinkedInforWindows*"
    "*MarchofEmpires*"
    "*McAfee*"
    "*Messaging*"
    "*MirametrixInc*"
    "*Microsoft3DViewer*"
    "*MicrosoftOfficeHub*"
    "*MicrosoftSolitaireCollection*"
    "*Minecraft*"
    "*MixedReality*"
    "*MSPaint*" # This is Paint 3D, NOT the old-school MSPaint
    "*Netflix*"
    "*NetworkSpeedTest*"
    "*News*"
    "*OneConnect*"
    "*PandoraMediaInc*"
    "*People*"
    "*PhototasticCollage*"
    "*PicsArt-PhotoStudio*"
    "*Plex*"
    "*PolarrPhotoEditor*"
    "*PPIProjection*"
    "*Print3D*"
    "*Royal Revolt*"
    "*ScreenSketch*"
    "*Shazam*"
    "*SkypeApp*"
    "*SlingTV*"
    "*Spotify*"
    "*StickyNotes*"
    "*Sway*"
    "*MicrosoftTeams*"
    "*TheNewYorkTimes*"
    "*TuneIn*"
    "*Twitter*"
    "*Wallet*"
    "*WebExperience*" # This is the Windows 11 Widgets BS Microsof thas thrown in to the new OS. Remove Widgets entirely.
    "*Whiteboard*"
    "*WindowsAlarms*"
    "*windowscommunicationsapps*"
    "*WindowsFeedbackHub*"
    "*WindowsMaps*"
    "*WindowsSoundRecorder*"
    "*WinZip*"
    "*Wunderlist*"
    "*Xbox.TCUI*"
    "*XboxApp*"
    "*XboxGameOverlay*"
    "*XboxGamingOverlay*"
    "*XboxIdentityProvider*"
    "*XboxSpeechToTextOverlay*"
    "*XING*"
    "*YourPhone*"
    "*ZuneMusic*"
    "*ZuneVideo*"
    "*TikTok*"
    "*ESPN*"
    "*Messenger*"
    "*Clipchamp*"
    "*whatsApp*"
    "*Prime*"
    "*Family*"
    "*copilot*"
    "*Mahjong*"
    "*viber*"
    "*Sidia*"

)
# MSI Based Classic Bloat List
$MsiBloatList = @(
    "*mcafee*"
    "*livesafe*"
    "*Passportal*"
)

# Uninstall Appx Bloat
foreach ($AppxBloat in $AppxBloatList) {

    Write-Host Searching and Removing Package $AppxBloat for All Users
    Get-AppxPackage -Name $AppxBloat -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue -Verbose
						
    Write-Host Searching and Removing Package $AppxBloat for Current User
    Get-AppxPackage -Name $AppxBloat | Remove-AppxPackage -ErrorAction SilentlyContinue -Verbose

    Write-Host Searching and Removing Package $AppxBloat for Provision Package
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $AppxBloat | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue -Verbose
}
# Wait for Bloatware to finish uninstalling
Write-Host "Waiting for Appx De-Bloat Jobs to Complete..."
$i = 20 #Seconds
do {
    Write-Host $i
    Sleep 1
    $i--
} while ($i -gt 0)


# MSI Uninstall Script
foreach ($MsiBloat in $MsiBloatList ) {
    ForEach ( $Software in $SoftwareList ) {
        # Grab the Uninstall entry from the Registry
        $RegistryPath = "HKLM:\$Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $UninstallRegistryObjects = Get-ItemProperty "$RegistryPath" | Where-Object DisplayName -Like "$MsiBloat"
        $ProductInfo = @{}
        # Set these to a default value in case the Uninstall entry is invalid or missing
        $ProductInfo.DisplayName = $MsiBloat
        $ProductInfo.GUID = "Unknown"
        $ProductInfo.InstallLocation = "Unknown"
        $ProductInfo.Version = "Unknown"
        # Check the Uninstall entry
        if ( $UninstallRegistryObjects ) {
            $EntryFound = $true
            ForEach ( $UninstallRegristryObject in $UninstallRegistryObjects ) {
                <# Removed to skip Publisher Matching
            # Make sure the Publisher matches (supports wildcards)
            if ( $UninstallRegristryObject.Publisher -like "$AppxBloatlicationPublisher" ) {
                $ProductInfo.DisplayName = $UninstallRegristryObject.DisplayName
                $ProductInfo.GUID = $UninstallRegristryObject.PSChildName
                $ProductInfo.InstallLocation = $UninstallRegristryObject.InstallLocation
                $ProductInfo.Version = $UninstallRegristryObject.DisplayVersion
            } else {
                Write-Host "The Publisher does not match!"
                $UninstallRegristryObject
                # Exit 10
            }#>
                # Only output the GUID
                if ( $JustGUID ) {
                    $ProductInfo.GUID -replace "[{}]", ""
                }
                else {
                    "GUID             --- $($ProductInfo.GUID)"
                    "Install Location --- $($ProductInfo.InstallLocation)"
                    # Uninstall
                    Write-Host -ForegroundColor Green "Uninstalling" $ProductInfo.DisplayName $ProductInfo.Version
                    Start-Process -Wait -FilePath "MsiExec.exe" -ArgumentList "/X $($ProductInfo.GUID) /qn /norestart"
                    # Wait for Bloatware to finish uninstalling
                    Write-Host "Waiting for " $ProductInfo.DisplayName " to uninstall..."
                    $i = 20 #Seconds
                    do {
                        Write-Host $i
                        Sleep 1
                        $i--
                    } while ($i -gt 0)
                }
            }
        }
    }
    if ( -not $EntryFound ) {
        Write-Host "No match for '$MsiBloat'"
        # Exit 20
    }
}
