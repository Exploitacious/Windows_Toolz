## Module Standalone Updater.
# Update all existing Modules, plus install the latest versions of the M365 Management PowerShell Modules.
Clear-Host
Write-Host 
Write-Host " .______     _______.   .___  ___.   ______    _______   __    __   __       _______  "
Write-Host " |   _  \   /       |   |   \/   |  /  __  \  |       \ |  |  |  | |  |     |   ____| "
Write-Host " |  |_)  | |   (----'   |  \  /  | |  |  |  | |  .--.  ||  |  |  | |  |     |  |__    "
Write-Host " |   ___/   \   \       |  |\/|  | |  |  |  | |  |  |  ||  |  |  | |  |     |   __|   "
Write-Host " |  |   .----)   |      |  |  |  | |  '--'  | |  '--'  ||  '--'  | |  '----.|  |____  "
Write-Host " | _|   |_______/       |__|  |__|  \______/  |_______/  \______/  |_______||_______| "
Write-Host "                                                                                      "
Write-Host "     __    __  .______    _______       ___   .___________. _______ .______           "
Write-Host "    |  |  |  | |   _  \  |       \     /   \  |           ||   ____||   _  \          "
Write-Host "    |  |  |  | |  |_)  | |  .--.  |   /  ^  \ '---|  |----'|  |__   |  |_)  |         "
Write-Host "    |  |  |  | |   ___/  |  |  |  |  /  /_\  \    |  |     |   __|  |      /          "
Write-Host "    |  '--'  | |  |      |  '--'  | /  _____  \   |  |     |  |____ |  |\  \----.     "
Write-Host "     \______/  | _|      |_______/ /__/     \__\  |__|     |_______|| _| '._____|     "
Write-Host "                                                                                      "
write-host
write-host " Created by Alex Ivantsov @Exploitacious "
write-host
Write-Host

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "This script requires PowerShell 5.1 or later. Your version is $($PSVersionTable.PSVersion). Please upgrade PowerShell and try again." -ForegroundColor Red
    exit
}

# Verify/Elevate Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

$modulesSummary = @()

$Answer = Read-Host "Install, Update and Clean Up all PoswerShell modules? Y/N"
if ($Answer -eq 'Y' -or $Answer -eq 'yes') {

    Write-Host
    Write-Host "Checking for Installed Modules..."

    $Modules = @(
        "ExchangeOnlineManagement",
        "MSOnline",
        "AzureADPreview",
        "MSGRAPH",
        "Microsoft.Graph",
        "AIPService",
        "MicrosoftTeams",
        "Microsoft.Online.SharePoint.PowerShell"
    )
    
    $installedModules = Get-InstalledModule * | Select-Object -ExpandProperty Name
    
    $Modules += $installedModules

    Write-Host
    Write-Host "Updating All and Installing M365 Modules..."
    Write-Host
    Write-Host

    Foreach ($Module In $Modules) {
        Write-Host
        $currentVersion = $null
        if ($null -ne (Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue)) {
            $currentVersion = (Get-InstalledModule -Name $module -AllVersions).Version
        }

        $CurrentModule = Find-Module -Name $module

        $status = "Unknown"
        $version = "N/A"

        if ($null -eq $currentVersion) {
            Write-Host "$($CurrentModule.Name) - Installing $Module from PowerShellGallery. Version: $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)"
            try {
                Install-Module -Name $module -Force
                $status = "Installed"
                $version = $CurrentModule.Version
            }
            catch {
                Write-Host "Something went wrong when installing $Module. Please uninstall and try re-installing this module. (Remove-Module, Install-Module) Details:"
                Write-Host "$_.Exception.Message"
                $status = "Installation Failed"
            }
        }
        elseif ($CurrentModule.Version -eq $currentVersion) {
            Write-Host "$($CurrentModule.Name) is installed and ready. Version: ($currentVersion. Release date: $($CurrentModule.PublishedDate))"
            $status = "Up to Date"
            $version = $currentVersion
        }
        elseif ($currentVersion.count -gt 1) {
            Write-Warning "$module is installed in $($currentVersion.count) versions (versions: $($currentVersion -join ' | '))"
            Write-Host "Uninstalling previous $module versions and will attempt to update."
            try {
                Get-InstalledModule -Name $module -AllVersions | Where-Object { $_.Version -ne $CurrentModule.Version } | Uninstall-Module -Force
            }
            catch {
                Write-Host "Something went wrong with Uninstalling $Module previous versions. Please Completely uninstall and re-install this module. (Remove-Module) Details:"
                Write-Host -ForegroundColor red "$_.Exception.Message"
                $status = "Uninstallation Failed"
            }
        
            Write-Host "$($CurrentModule.Name) - Installing version from PowerShellGallery $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)"  
    
            try {
                Install-Module -Name $module -Force
                Write-Host "$Module Successfully Installed"
                $status = "Updated"
                $version = $CurrentModule.Version
            }
            catch {
                Write-Host "Something went wrong with installing $Module. Details:"
                Write-Host -ForegroundColor red "$_.Exception.Message"
                $status = "Update Failed"
            }
        }
        else {       
            Write-Host "$($CurrentModule.Name) - Updating from PowerShellGallery from version $currentVersion to $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)" 
            try {
                Update-Module -Name $module -Force
                Write-Host "$Module Successfully Updated"
                $status = "Updated"
                $version = $CurrentModule.Version
            }
            catch {
                Write-Host "Something went wrong with updating $Module. Details:"
                Write-Host -ForegroundColor red "$_.Exception.Message"
                $status = "Update Failed"
            }
        }

        $modulesSummary += [PSCustomObject]@{
            Module  = $Module
            Status  = $status
            Version = $version
        }
    }

    Write-Host
    Write-Host "Check the modules listed in the verification above. If you see any errors, please check the module(s) or restart the script to try and auto-fix."
    Write-Host
    Write-Host "Re-run this script as many times as necessary until all modules are correctly installed and up to date."
    Write-Host
} 

Read-Host "Script execution completed. Please review the summaries above for any issues. Press Enter to continue"