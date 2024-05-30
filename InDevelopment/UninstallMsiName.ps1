# Written by Colby Bouma
# This script attempts to search the registry for the GUID of the specified application and uninstall it with MsiExec
# 
# https://github.com/Colby-PDQ/Uninstall-Packages/blob/master/Scripts/Uninstall-MSI-By-Name.ps1

#Requires -Version 3

<#
[CmdletBinding()]
param (
    
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ApplicationName,
    
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ApplicationPublisher,

    [Parameter(Mandatory = $false)]
    [switch]
    $JustGUID = $false

)

#>

$ApplicationName = "*Passportal*"
$ApplicationPublisher = "N-Able"



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
                Write-Host -ForegroundColor Green "Uninstalling" + $ProductInfo.DisplayName + $ProductInfo.Version
                # Start-Process -Wait -FilePath "MsiExec.exe" -ArgumentList "/X $($ProductInfo.GUID) /qn /norestart"

            }

        }

    }

}

if ( -not $EntryFound ) {

    Write-Host "Unable to find a match for '$ApplicationName'"
    # Exit 20

}