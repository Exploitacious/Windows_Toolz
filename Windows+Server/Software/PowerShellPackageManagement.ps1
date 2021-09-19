

# Configure and Install Powershell Package Management

<#

    This script will install Powershell Package Management and all Package Providers 

#>

Install-Module PackageManagement -Force

Find-PackageProvider -Verbose | Install-PackageProvider -Verbose


