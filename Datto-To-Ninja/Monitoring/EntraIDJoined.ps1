<#
        .SYNOPSIS
            An example script used to determine if a Device is Azure AD Joined, Domain Joined, Hybrid AD Joined, On-premises DRS Joined or WorkGroup. 
            Writes Status to a user defined-field of your choice with option to add MS Tenant Info to the UDF if required

        .Notes
            Use this script in Datto RMM as is,
            View this page for more info on DSREGCMD - https://docs.microsoft.com/en-us/azure/active-directory/devices/troubleshoot-device-dsregcmd

 #>

# Set Variables for Script
$registryPath = "HKLM:\Software\CentraStage\"
$OutFolder = 'C:\Temp\'
$OutFile = 'dsregcmd.txt'
$num = $env:UDF


# Function to update UDF of device
function Write-Reg {

    IF ($env:MSTenantInfo -eq 'True' -and $MSTenantDets -ne $null) {
        New-ItemProperty -Path $registryPath -Name "Custom$num" -Value "$MSTenantDets" -PropertyType String -Force | Out-Null
        write-output "$MSTenantDets"
        exit
    }

    Else {
        New-ItemProperty -Path $registryPath -Name "Custom$num" -Value "$Results" -PropertyType String -Force | Out-Null
        write-output "$Results"
        exit
    }

}

# Check file location exist, if not create folder
If (!(Test-Path $OutFolder)) {
    New-Item -ItemType Directory -Force -Path $OutFolder
}

# dump DSREGCMD to txt file
dsregcmd /status > $OutFolder\$OutFile

#Set Variables based on Pattern Match
$AzureAdJoined = [bool](Select-String -Path C:\temp\dsregcmd.txt -Pattern "AzureAdJoined : YES")
$EnterpriseJoined = [bool](Select-String -Path C:\temp\dsregcmd.txt -Pattern "EnterpriseJoined : YES")
$DomainJoined = [bool](Select-String -Path C:\temp\dsregcmd.txt -Pattern "DomainJoined : YES")

### Deterime device Status ###

# Azure AD Joined
If ($AzureAdJoined -eq 'True' -and $EnterpriseJoined -ne 'True' -and $DomainJoined -ne 'True') {
    $Results = "Azure AD Joined"
    $Tenant = (Select-String -Path C:\temp\dsregcmd.txt -Pattern "TenantId :")
    $TenantID = $Tenant.line
    $TenantID = $TenantID -replace 'TenantId : ', ' ' -replace '\s'
    $MSTenant = (Select-String -Path C:\temp\dsregcmd.txt -Pattern "TenantName :")
    $TenantName = $MSTenant.line
    $TenantName = $TenantName -replace 'TenantName : ', ' ' -replace '\s'
    $MSTenantDets = $Results + " : " + $TenantName + " : " + $TenantID
    Write-Reg
}

# Domain Joined
If ($AzureAdJoined -ne 'True' -and $EnterpriseJoined -ne 'True' -and $DomainJoined -eq 'True') {
    $Results = "Domain Joined"
    Write-Reg
}

# Hybrid AD Joined
If ($AzureAdJoined -eq 'True' -and $EnterpriseJoined -ne 'True' -and $DomainJoined -eq 'True') {
    $Results = "Hybrid AD Joined"
    Write-Reg
}

# On Premise DRS Joined
If ($AzureAdJoined -ne 'True' -and $EnterpriseJoined -eq 'True' -and $DomainJoined -eq 'True') {
    $Results = "On-premises DRS Joined"
    Write-Reg
}

# Work Group Joined
If ($AzureAdJoined -ne 'True' -and $EnterpriseJoined -ne 'True' -and $DomainJoined -ne 'True') {
    $results = "WorkGroup Joined"
    Write-Reg
}