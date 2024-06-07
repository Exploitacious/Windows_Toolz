# Dell Open Manage Server Hardware Utility
# Created by Dell and Implemented by Alex Ivantsov
# https://github.com/dell/OpenManage-PowerShell-Modules
# https://github.com/exploitacious/

# Some Variables
# $monitorUser = "monitordrmm" #Set the username of the monitor user
# $monitorPW = "G4gQSuqxKm69" #Set the password for the iDRAC monitoring account


# Set Continuous Diagnostic Log. Use $Global:DiagMsg +=  to append to this running log.
$Global:DiagMsg = @()
$Global:AlertMsg = @()

# DattoRMM Alert Functions
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    Write-Host '<-End Diagnostic->'
}
function write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}



$output = racadm raid get pdisks -o -p SerialNumber, Status | Out-String

[regex]$pattern = '\r?\n(\w.+)\r?\n\s{3,}\w+.+= (.+?)\r?\n\s{3,}\w+.+= (.+?)\s'

$RACDisks = $pattern.Matches($output) | ForEach-Object { , $_.groups[1..3].value | ForEach-Object {
        [PSCustomObject]@{
            DeviceID     = $_[0]
            SerialNumber = $_[1]
            Status       = $_[2]
        }
    }
}




foreach ($disk in $RACDisks) {
    $Global:DiagMsg += $disk.DeviceID + " Status:" + $disk.Status
    
    if ($disk.status -ne "Ok") {
        $Global:AlertMsg += " Disk Status is NOT OK " + $disk.deviceID
    }
}


#END


if ($Global:AlertMsg) {
    write-DRMMAlert $Global:AlertMsg
    write-DRMMDiag $Global:DiagMsg
    Exit 1
}
else {
    write-DRMMAlert "Healthy"
    write-DRMMDiag $Global:DiagMsg
    Exit 0
}





<#
# Install and Update Nuget + Open Manage Module
# Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -ErrorAction Stop
$Modules = @(
    "NuGet"
    "DellOpenManage"
)
Foreach ($Module In $Modules) {
    $currentVersion = $null
    if ($null -ne (Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue)) {
        $currentVersion = (Get-InstalledModule -Name $module -AllVersions).Version
    }

    $CurrentModule = Find-Module -Name $module

    if ($null -eq $currentVersion) {
        $Global:DiagMsg += "$($CurrentModule.Name) - Installing $Module from PowerShellGallery. Version: $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)"
        try {
            Install-Module -Name $module -Force
        }
        catch {
            $Global:DiagMsg += "Something went wrong when installing $Module. Please uninstall and try re-installing this module. (Remove-Module, Install-Module) Details:"
            write-DRMMAlert "$_.Exception.Message"
        }
    }
    elseif ($CurrentModule.Version -eq $currentVersion) {
        $Global:DiagMsg += "$($CurrentModule.Name) is installed and ready. Version: ($currentVersion. Release date: $($CurrentModule.PublishedDate))"
    }
    elseif ($currentVersion.count -gt 1) {
        $Global:DiagMsg += "$module is installed in $($currentVersion.count) versions (versions: $($currentVersion -join ' | '))"
        $Global:DiagMsg += "Uninstalling previous $module versions and will attempt to update."
        try {
            Get-InstalledModule -Name $module -AllVersions | Where-Object { $_.Version -ne $CurrentModule.Version } | Uninstall-Module -Force
        }
        catch {
            $Global:DiagMsg += "Something went wrong with Uninstalling $Module previous versions. Please Completely uninstall and re-install this module. (Remove-Module) Details:"
            write-DRMMAlert "$_.Exception.Message"
        }
        
        $Global:DiagMsg += "$($CurrentModule.Name) - Installing version from PowerShellGallery $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)"  
    
        try {
            Install-Module -Name $module -Force
            $Global:DiagMsg += "$Module Successfully Installed"
        }
        catch {
            $Global:DiagMsg += "Something went wrong with installing $Module. Details:"
            write-DRMMAlert "$_.Exception.Message"
        }
    }
    else {       
        write-DRMMDiag "$($CurrentModule.Name) - Updating from PowerShellGallery from version $currentVersion to $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)" 
        try {
            Update-Module -Name $module -Force
            $Global:DiagMsg += -ForegroundColor $MessageColor "$Module Successfully Updated"
        }
        catch {
            $Global:DiagMsg += -ForegroundColor $ErrorColor "Something went wrong with updating $Module. Details:"
            write-DRMMAlert "$_.Exception.Message"
        }
    }
}


# Test RACADM
if (Get-Command racadm -errorAction SilentlyContinue) {
    
    racadm set idrac.users.7.username $monitorUser
    racadm set idrac.users.7.password $monitorPW
    racadm set iDRAC.Users.7.privilege 0x1ff
    racadm set idrac.users.7.enable 1
    $Global:DiagMsg += "Monitoring User has been confirmed"
}
else {
    write-DRMMAlert "RACADM not available. Check to make sure OMSA suite is up to date"
}


#######################
$localhostname = $env:computername
$Global:DiagMsg += "LocalHostname: $localhostname"
 

# Import and Connect Open Manage Module
Import-Module DellOpenManage
$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $monitorUser, $(ConvertTo-SecureString -Force -AsPlainText $monitorPW)
Connect-OMEServer 127.0.0.1 -Credentials $credentials -IgnoreCertificateWarning



#>
#End


