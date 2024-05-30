# System Modifications to Server 2022 with First-Time user logon script enabled

# Start Logging
$LogPrefix = "Log-WinTLS1011DeprecatedDisable-$Env:Computername-"
$LogDate = Get-Date -Format dd-MM-yyyy-HH-mm
$LogName = $LogPrefix + $LogDate + ".txt"
Start-Transcript -Path "C:\Windows\Temp\$LogName"



function Test-RegistryValue {

    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Name
    )

    try {
        $ItemProperty = Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Name -ErrorAction Stop
        if ($ItemProperty -eq "1") {
            return $true
        }
        else {
            return $false
        }
    }

    catch {
        return $false
    }
}


function Update-RegistryValue {

    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Name,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]$Exists
    )

    try {
        if ($Exists -eq $False) {
            New-ItemProperty -Path $Path -Name $Name -Value "0" -PropertyType "DWord" -ErrorAction Stop
            Write-Host "$Path\$Name has been created"
        }
        else {
            Set-ItemProperty -Path $Path -Name $Name -Value "0" -ErrorAction Stop
            Write-Host "$Path\$Name has been updated"
        }
        return $true
    }

    catch {
        return $false
    }
}


# Test Paths for TLS 1.0 and 1.1
$Paths = @("HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0", "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client", "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server", "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1", "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client", "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server")
foreach ($Path in $Paths) {
    $PathExists = Test-Path -Path $Path
    if ($PathExists -eq $False) {
        New-Item -Path $Path
    }
}

# Disable TLS 1.0 Client
$TLS10ClientKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client"
$TLS10ClientName = "Enabled"
$TLS10ClientExists = Test-RegistryValue -Path $TLS10ClientKey -Name $TLS10ClientName
Update-RegistryValue -Exists $TLS10ClientExists -Path $TLS10ClientKey -Name $TLS10ClientName

# Disable TLS 1.0 Server
$TLS10ServerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"
$TLS10ServerName = "Enabled"
$TLS10ServerExists = Test-RegistryValue -Path $TLS10ServerKey -Name $TLS10ServerName
Update-RegistryValue -Exists $TLS10ServerExists -Path $TLS10ServerKey -Name $TLS10ServerName

# Disable TLS 1.1 Client
$TLS11ClientKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"
$TLS11ClientName = "Enabled"
$TLS11ClientExists = Test-RegistryValue -Path $TLS11ClientKey -Name $TLS11ClientName
Update-RegistryValue -Exists $TLS11ClientExists -Path $TLS11ClientKey -Name $TLS11ClientName

# Disable TLS 1.1 Server
$TLS11ServerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"
$TLS11ServerName = "Enabled"
$TLS11ServerExists = Test-RegistryValue -Path $TLS11ServerKey -Name $TLS11ServerName
Update-RegistryValue -Exists $TLS11ServerExists -Path $TLS11ServerKey -Name $TLS11ServerName

# Enable TLS1.2
Write-Host "Enabling TLS 1.2"
New-Item 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -name 'SystemDefaultTlsVersions' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -name 'SchUseStrongCrypto' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -name 'SystemDefaultTlsVersions' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -name 'SchUseStrongCrypto' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -name 'Enabled' -value '1' -PropertyType 'DWord' -Force | Out-Null
New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -name 'DisabledByDefault' -value 0 -PropertyType 'DWord' -Force | Out-Null

# Enable Script-Block Logging for Powershell
Write-Host "Enabling PowerShell Logging..."
New-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1

# Disable IPv6 Stack
Write-Host "Disable IPv6 Stack"
Disable-NetAdapterBinding -Name "*" -ComponentID "ms_tcpip6"

# Disable Scheduled Tasks
Write-Host "Disabling Unneeded Scheduled Tasks..."
Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\ProgramDataUpdater" | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" | Out-Null
Disable-ScheduledTask -TaskName "Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" | Out-Null

## Enable 'Local Security Authority (LSA) protection'
# Forces LSA to run as Protected Process Light (PPL).
# If LSA isn't running as a protected process, attackers could easily abuse the low process integrity for attacks (such as Pass-the-Hash).
$RunAsPPLKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$RunAsPPLName = "RunAsPPL"
$RunAsPPLExists = Test-RegistryValue -Path $RunAsPPLKey -Name $RunAsPPLName
Update-RegistryValue -Exists $RunAsPPLExists -Path $RunAsPPLKey -Name $RunAsPPLName

## Enable 'Require domain users to elevate when setting a network's location'
# Determines whether to require domain users to elevate when setting a network's location.
# Selecting an incorrect network location may allow greater exposure of a system
$NC_StdDomainUserSetLocationKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections"
$NC_StdDomainUserSetLocationName = "NC_StdDomainUserSetLocation"
$NC_StdDomainUserSetLocationExists = Test-RegistryValue -Path $NC_StdDomainUserSetLocationKey -Name $NC_StdDomainUserSetLocationName
Update-RegistryValue -Exists $NC_StdDomainUserSetLocationExists -Path $NC_StdDomainUserSetLocationKey -Name $NC_StdDomainUserSetLocationName

## Disable the local storage of passwords and credentials
# Determines whether Credential Manager saves passwords or credentials locally for later use when it gains domain authentication.
# Locally cached passwords or credentials can be accessed by malicious code or unauthorized users.
$DisableDomainCredsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$DisableDomainCredsName = "DisableDomainCreds"
$DisableDomainCredsExists = Test-RegistryValue -Path $DisableDomainCredsKey -Name $DisableDomainCredsName
Update-RegistryValue -Exists $DisableDomainCredsExists -Path $DisableDomainCredsKey -Name $DisableDomainCredsName

## Set 'Account lockout threshold' to 1-10 invalid login attempts
# Determines the number of failed logon attempts before the account is locked. The number of failed logon attempts should be reasonably small to minimize the possibility of a successful password attack, while still allowing for honest errors made during a legitimate user logon. This security control is only assessed for machines with Windows 10, version 1709 or later.
# Setting an appropriate account lockout threshold helps prevents brute-force password attacks on the system.
Invoke-Command -ScriptBlock { net accounts /lockoutthreshold:5 }
Write-Host "Account lockout threadhold has been updated"


#####################################

# Enable Startup / Shutdown messages
Write-Host "Enabling Startup / Shutdown Messages..."
If ((Get-CimInstance -Class "Win32_OperatingSystem").ProductType -eq 1) {
	Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 1
}
Else {
	Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -ErrorAction SilentlyContinue
}

#### User Context Mods
# Disable Content-Delivery
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "FeatureManagementEnabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "OemPreInstalledAppsEnabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEnabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEverEnabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-314559Enabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353696Enabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContentEnabled" -Type DWord -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Type DWord -Value 0



#### Implement User First-Time Logon Script
If ( $EnableUserLogonScript -eq $true) { 
	Write-Host "Creating Directories 'C:\Scripts' and Copying files"
	mkdir "C:\Scripts" -ErrorAction SilentlyContinue
	Copy-Item "DebloatScript-HKCU.ps1" "C:\Scripts\DebloatScript-HKCU.ps1"
	Copy-Item "FirstLogon.bat" "C:\Scripts\FirstLogon.bat"
	Write-Host

	Write-Host -ForegroundColor $NotificationColor "Enabling Registry Keys to run Logon Scripton first use login"
	REG LOAD HKEY_Users\DefaultUser "C:\Users\Default\NTUSER.DAT"
	Set-ItemProperty -Path "REGISTRY::HKEY_USERS\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Run" -Name "FirstUserLogon" -Value "C:\Scripts\FirstLogon.bat" -Type "String"
	REG UNLOAD HKEY_Users\DefaultUser
}


# Stop Logging
Stop-Transcript