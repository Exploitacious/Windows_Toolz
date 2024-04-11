# Dell Open Manage Server Hardware Utility
# Created by Dell and Implemented by Alex Ivantsov
# https://github.com/dell/OpenManage-PowerShell-Modules
# https://github.com/exploitacious/

# Some Variables
$MessageColor = "Green"
$AssessmentColor = "Yellow"
$ErrorColor = "Red"
$localhostname = HOSTNAME.EXE

$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "umbrella", $(ConvertTo-SecureString -Force -AsPlainText "!S3cur1ty!")



# Install and Update Nuget + Open Manage Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -ErrorAction Stop

$Modules = @(
    "Nuget"
    "DellOpenManage"
)

Foreach ($Module In $Modules) {
    $currentVersion = $null
    if ($null -ne (Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue)) {
        $currentVersion = (Get-InstalledModule -Name $module -AllVersions).Version
    }

    $CurrentModule = Find-Module -Name $module

    if ($null -eq $currentVersion) {
        Write-Host -ForegroundColor $AssessmentColor "$($CurrentModule.Name) - Installing $Module from PowerShellGallery. Version: $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)"
        try {
            Install-Module -Name $module -Force
        }
        catch {
            Write-Host -ForegroundColor $ErrorColor "Something went wrong when installing $Module. Please uninstall and try re-installing this module. (Remove-Module, Install-Module) Details:"
            Write-Host -ForegroundColor $ErrorColor "$_.Exception.Message"
        }
    }
    elseif ($CurrentModule.Version -eq $currentVersion) {
        Write-Host -ForegroundColor $MessageColor "$($CurrentModule.Name) is installed and ready. Version: ($currentVersion. Release date: $($CurrentModule.PublishedDate))"
    }
    elseif ($currentVersion.count -gt 1) {
        Write-Warning "$module is installed in $($currentVersion.count) versions (versions: $($currentVersion -join ' | '))"
        Write-Host -ForegroundColor $ErrorColor "Uninstalling previous $module versions and will attempt to update."
        try {
            Get-InstalledModule -Name $module -AllVersions | Where-Object { $_.Version -ne $CurrentModule.Version } | Uninstall-Module -Force
        }
        catch {
            Write-Host -ForegroundColor $ErrorColor "Something went wrong with Uninstalling $Module previous versions. Please Completely uninstall and re-install this module. (Remove-Module) Details:"
            Write-Host -ForegroundColor red "$_.Exception.Message"
        }
        
        Write-Host -ForegroundColor $AssessmentColor "$($CurrentModule.Name) - Installing version from PowerShellGallery $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)"  
    
        try {
            Install-Module -Name $module -Force
            Write-Host -ForegroundColor $MessageColor "$Module Successfully Installed"
        }
        catch {
            Write-Host -ForegroundColor $ErrorColor "Something went wrong with installing $Module. Details:"
            Write-Host -ForegroundColor red "$_.Exception.Message"
        }
    }
    else {       
        Write-Host -ForegroundColor $AssessmentColor "$($CurrentModule.Name) - Updating from PowerShellGallery from version $currentVersion to $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)" 
        try {
            Update-Module -Name $module -Force
            Write-Host -ForegroundColor $MessageColor "$Module Successfully Updated"
        }
        catch {
            Write-Host -ForegroundColor $ErrorColor "Something went wrong with updating $Module. Details:"
            Write-Host -ForegroundColor red "$_.Exception.Message"
        }
    }
}

# Import and Connect Open Manage Module
Import-Module DellOpenManage
Connect-OMEServer -Name $localhostname -Credentials $credentials -IgnoreCertificateWarning