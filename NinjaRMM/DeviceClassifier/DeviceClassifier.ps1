# Script Title: Windows Device & Role Classification
# Description: Detects the Windows device type (Physical/Virtual, Server/Workstation) and identifies installed roles based on running services.

# Script Name and Type
$ScriptName = "Windows Device & Role Classification"
$ScriptType = "Monitoring" # Or "Remediation", "General", etc.
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the device status to.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Device classification successful. | Last Checked $Date"

# Log/Diagnostic Messaging
function write-RMMDiag ($messages) {
    Write-Host "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
$Global:DiagMsg = @()

# Alert Messaging
function write-RMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
$Global:AlertMsg = @()

# RMM Custom Field.
$Global:customFieldMessage = @()

# Script UID and intro messaging
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
$ScriptUID = GenRANDString 20
$Global:DiagMsg += "Script Type: $ScriptType"
$Global:DiagMsg += "Script Name: $ScriptName"
$Global:DiagMsg += "Script UID: $ScriptUID"
$Global:DiagMsg += "Executed On: $Date"

##################################
### Supporting Functions
##################################

function Get-DeviceType {
    $Global:DiagMsg += ""
    $Global:DiagMsg += "Running device type classification..."
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $osCaption = $osInfo.Caption
        # ProductType 1 = Workstation, 2 = Domain Controller, 3 = Server
        $isServerOS = $osInfo.ProductType -gt 1
        $Global:DiagMsg += "Is Server OS (by ProductType): $isServerOS"
        $Global:DiagMsg += "OS Caption: $osCaption"

        # Specific check for AVD/Multisession SKUs
        $isAVDOrMultiSession = $osCaption -match 'Virtual Desktops' -or $osCaption -match 'Multi-session'
        if ($isAVDOrMultiSession) {
            $Global:DiagMsg += "AVD/Multisession SKU detected."
        }

        $model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
        $isVM = $model -match 'Virtual|VMware|Hyper-V|KVM|VirtualBox'
        $Global:DiagMsg += "Is VM: $isVM (Model: $model)"
        
        $isHyperVHost = $false
        if (Get-Service -Name 'vmms' -ErrorAction SilentlyContinue) {
            $isHyperVHost = $true
        }
        $Global:DiagMsg += "Is Hyper-V Host (vmms service running): $isHyperVHost"

        if ($isVM) {
            if ($isAVDOrMultiSession) {
                # Explicitly AVD/Multi-session, always class as Virtual Desktop
                return "Azure Virtual Desktop"
            }
            elseif ($isServerOS) {
                # Is a VM and a server OS (and not AVD), so it's a Virtual Server
                return "Virtual Server"
            }
            else {
                # Is a VM and a workstation OS
                return "Virtual Desktop"
            }
        }
        else {
            # It's a Physical machine
            if ($isServerOS) {
                if ($isHyperVHost) {
                    return "HV Host Server"
                }
                else {
                    return "Physical Server"
                }
            }
            else {
                return "Workstation Hardware"
            }
        }
    }
    catch {
        $Global:DiagMsg += "Error in Get-DeviceType: $($_.Exception.Message)"
        return "Unknown"
    }
}

function Get-DeviceRoles {
    $Global:DiagMsg += "Running device role detection..."
    $roles = @()
    try {
        # Get all running services by display name
        $services = Get-Service | Where-Object { $_.Status -eq 'Running' } | Select-Object -ExpandProperty DisplayName
        # Get all file shares
        $shares = Get-CimInstance -ClassName Win32_Share -ErrorAction SilentlyContinue
        
        # --- NEW: Use Get-WindowsFeature for robust Server Role detection (if available) ---
        if (Get-Command -Name Get-WindowsFeature -ErrorAction SilentlyContinue) {
            $Global:DiagMsg += "Server OS detected, checking Windows Features."
            $features = Get-WindowsFeature | Where-Object { $_.InstallState -eq 'Installed' } | Select-Object -ExpandProperty Name
            
            if ($features -contains 'AD-Domain-Services') { $roles += 'ADC' }
            if ($features -contains 'DNS') { $roles += 'DNS' }
            if ($features -contains 'DHCP') { $roles += 'DHCP' }
            if ($features -contains 'Hyper-V') { $roles += 'HyperV' }
            if ($features -contains 'Web-Server') { $roles += 'IIS' } # IIS
            if ($features -contains 'File-Services') { $roles += 'File' }
            if ($features -contains 'Print-Services') { $roles += 'Print' }
            if ($features -contains 'NPS') { $roles += 'NPS' }
            if ($features -contains 'RemoteAccess') { $roles += 'RRAS' }
            if ($features -contains 'AD-Certificate') { $roles += 'ADCertSvc' }
            if ($features -contains 'ADFS-Federation') { $roles += 'ADFS' }
            if ($features -contains 'Fax') { $roles += 'Fax' }
            if ($features -contains 'WINS') { $roles += 'WINS' }
            if ($features -contains 'RDS-Licensing') { $roles += 'Lic' }
            if ($features -contains 'RDS-Gateway' -or $features -contains 'RDS-Web-Access' -or $features -contains 'RDS-Connection-Broker' -or $features -contains 'RDS-Host') {
                if ('RDS' -notin $roles) { $roles += 'RDS' }
            }
        }
        else {
            $Global:DiagMsg += "Non-Server OS or Core install, falling back to service/registry checks for roles."
            # --- Fallback Core Windows Services (from original) ---
            if ($services -match 'Hyper-V Virtual Machine Management' -and 'HyperV' -notin $roles) { $roles += 'HyperV' }
            if ($services -match 'DNS Server' -and 'DNS' -notin $roles) { $roles += 'DNS' }
            if (($services -match 'DHCP Server' -or $services -match 'DHCP-Server') -and 'DHCP' -notin $roles) { $roles += 'DHCP' }
            if ($services -match 'Windows Internet Name Service' -and 'WINS' -notin $roles) { $roles += 'WINS' }
            if ($services -match 'Network Policy Server' -and 'NPS' -notin $roles) { $roles += 'NPS' }
            if ($services -match 'Routing and Remote Access' -and 'RRAS' -notin $roles) { $roles += 'RRAS' }
            if ($services -match 'Fax' -and 'Fax' -notin $roles) { $roles += 'Fax' }
            if ($services -match 'World Wide Web Publishing Service' -and 'IIS' -notin $roles) { $roles += 'IIS' }
            if ($services -match 'Active Directory Federation Services' -and 'ADFS' -notin $roles) { $roles += 'ADFS' }
            if ($services -match 'Active Directory Certificate Services' -and 'ADCertSvc' -notin $roles) { $roles += 'ADCertSvc' }
            if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 2 -and 'ADC' -notin $roles) { $roles += 'ADC' } # ProductType 2 = DC
        }

        # --- SQL / Databases ---
        if ($services -match 'SQL Server \(' -or $services -match 'MSSQL') { $roles += 'SQL' }
        if ($services -match 'MySQL') { $roles += 'MySQL' } 
        if ($services -match 'postgresql') { $roles += 'PostgreSQL' } 
        if ($services -match 'MongoDB') { $roles += 'MongoDB' } 
        if ($services -match 'Pervasive' -or $services -match 'Actian Zen') { $roles += 'Pervasive/ActianDB' } 

        # --- Exchange ---
        if ($services -match 'Microsoft Exchange Information Store') { $roles += 'Exchange' }
        if ($services -match 'Microsoft Exchange MTA Stacks') { $roles += 'MTA' }
        if ($services -match 'Microsoft Exchange IMAP4') { $roles += 'IMAP4' }
        if ($services -match 'Microsoft Exchange POP3') { $roles += 'POP3' }

        # --- PDC Emulator Role (Handle netdom failure) ---
        if ('ADC' -in $roles) {
            # Only check for PDC if it's a DC
            try { $fsmo = netdom query fsmo -ErrorAction Stop } catch { $fsmo = "" }
            if ($fsmo -match 'PDC' -and $fsmo -match $env:COMPUTERNAME) { $roles += 'PDC' }
        }

        # --- Other Web / App Services ---
        if ($services -match 'ColdFusion') { $roles += 'ColdFusion' }
        if ($services -match 'MSSQL\$SHAREPOINT' -or $services -match 'SharePoint Timer') { $roles += 'SharePoint' }
        if ($services -match 'Simple Mail Transfer Protocol') { $roles += 'SMTP' }
        if ($services -match 'Apache') { $roles += 'Apache' } 
        if ($services -match 'nginx') { $roles += 'nginx' } 
        
        # --- Backup Solutions ---
        if ($services -match 'Backup Exec Server') { $roles += 'Backup Exec' }
        if ($services -match 'Backup Exec Continuous Protection') { $roles += 'BECP' }
        if ($services -match 'Arcserve Job Engine' -or $services -match 'BrightStor Job Engine') { $roles += 'Arcserve' }
        if ($services -match 'AppAssure Core') { $roles += 'Appassure' }
        if ($services -match 'Rapid Recovery Core') { $roles += 'RapRecov' }
        if ($services -match 'Veeam Backup') { $roles += 'Veeam' }
        if ($services -match 'Veeam Distribution Service' -or $services -match 'Veeam Broker Service') { if ('Veeam' -notin $roles) { $roles += 'Veeam' } }
        if ($services -match 'Acronis') { $roles += 'Acronis' } 
        if ($services -match 'ShadowProtect') { $roles += 'ShadowProtect' } 

        # --- Citrix ---
        if ($services -match 'Independent Management Architecture') { $roles += 'Citrix' }
        if ($services -match 'Secure Gateway') { $roles += 'Citrix SG' }
        if ($services -match 'Citrix StoreFront') { $roles += 'Citrix SF' }
        if ($services -match 'Web Interface') { $roles += 'Citrix WI' }

        # --- Terminal Services / RDS ---
        if ('RDS' -notin $roles) {
            # Only check if feature detection failed
            if ($services -match 'Terminal Services' -or $services -match 'Remote Desktop Services') {
                $roles += 'RDS'
            }
            try {
                $tsReg = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'TSAppCompat' -ErrorAction SilentlyContinue
                if ($tsReg -and $tsReg.TSAppCompat -eq 1 -and 'RDS' -notin $roles) { $roles += 'RDS' }
            }
            catch {}
        }
        if ($services -match 'Terminal Server Licensing' -or $services -match 'Remote Desktop Licensing') {
            if ('Lic' -notin $roles) { $roles += 'Lic' }
        }
        
        # --- Other LOB / Edge ---
        if ($services -match 'BlackBerry') { $roles += 'BES' }
        if ($services -match 'Microsoft ISA Server Control') { $roles += 'ISA' }
        if ($services -match 'QuickBooksDB' -or $services -match 'QBCFMonitorService') { $roles += 'QuickBooksDB' }
        if ($services -like '3CX*') { $roles += '3CX' }
        if ($services -match 'Sage' -or $services -match 'Timberline') { $roles += 'Sage/Timberline' }

        if ($services -like '3CX*') { $roles += '3CX' }

        # --- OS Version Specific ---
        if ((Get-CimInstance -ClassName Win32_OperatingSystem).Caption -match 'Small Business') { $roles += 'SBS' }
        if ((Get-CimInstance -ClassName Win32_OperatingSystem).Caption -match 'Essentials') { $roles += 'Essentials' }

        # --- AV Management Consoles ---
        if ($services -match 'Symantec System Center') { $roles += 'SymantecAV Mgmt' }
        if ($services -match 'AVG TCP Server Service') { $roles += 'AVG Mgmt' }
        if ($services -match 'Symantec Embedded Database') { $roles += 'SymantecEP Mgmt' }
        if ($services -match 'Sophos Management Service') { $roles += 'Sophos Mgmt' }
        if ($services -match 'ESET PROTECT Server' -or $services -match 'ESET RA HTTP Server') { $roles += 'ESET Mgmt' }

        # --- File/Print Services (Fallback if Get-WindowsFeature failed) ---
        if ($shares) {
            if ('Print' -notin $roles) {
                if ($shares.Name -contains 'print$' -or $shares.Description -match 'Spooled') {
                    $roles += 'Print'
                }
            }
            if ('File' -notin $roles) {
                $fileShares = $shares | Where-Object { $_.Type -eq 0 -and $_.Name -notin ('C$', 'D$', 'E$', 'F$', 'G$', 'ADMIN$', 'IPC$') }
                if ($fileShares) {
                    $roles += 'File'
                }
            }
        }
        
        # --- Misc Infrastructure ---
        if ($services -match 'Cluster Service' -and 'ClusSvc' -notin $roles) { $roles += 'ClusSvc' }
        if ($services -match 'OpenVPNService') { $roles += 'OpenVPN' } 
        if ($services -match 'WireGuard') { $roles += 'WireGuard' } 
        if ($services -match 'PRTG Core Server Service') { $roles += 'PRTG' }
        if ($services -match 'ADSync' -or $services -match 'Microsoft Entra Connect') { $roles += 'Entra ID Sync' }
        if ($services -match 'UniFi Network Application' -or $services -match 'UniFi Controller') { $roles += 'UniFi Controller' }

    }
    catch {
        $Global:DiagMsg += "Error in Get-DeviceRoles: $($_.Exception.Message)"
    }
    
    if ($roles.Count -eq 0) {
        return "General Purpose"
    }
    else {
        # Return roles sorted alphabetically and joined
        return (($roles | Sort-Object) -join ' ; ')
    }
}

##################################
##################################
######## Start of Script #########

try {
    # 1. Determine Device Type
    $deviceType = Get-DeviceType
    $Global:DiagMsg += "Detected Device Type: $deviceType"

    # 2. Determine Device Roles
    $deviceRoles = Get-DeviceRoles
    $Global:DiagMsg += "Detected Device Roles: $deviceRoles"

    # 3. Format final status string
    $finalStatus = "$deviceType | $deviceRoles | Last Checked $Date"
    
    # 4. Set global variables for output
    $Global:customFieldMessage = $finalStatus
    # This script's "Healthy" state is just reporting the data successfully
    $Global:AlertHealthy = "Device classification successful. | Last Checked $Date"

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
    $Global:customFieldMessage = "Script failed with an error. ($Date)"
}


######## End of Script ###########
##################################
##################################

# Write the collected information to the specified Custom Field before exiting.
if ($env:customFieldName) {
    $Global:DiagMsg += "Attempting to write '$($Global:customFieldMessage)' to Custom Field '$($env:customFieldName)'."
    try {
        Ninja-Property-Set -Name $env:customFieldName -Value $Global:customFieldMessage
        $Global:DiagMsg += "Successfully updated Custom Field."
    }
    catch {
        $Global:DiagMsg += "Error writing to Custom Field '$($env:customFieldName)': $($_.Exception.Message)"
    }
}
else {
    $Global:DiagMsg += "Custom Field name not provided in RMM variable 'customFieldName'. Skipping update."
}

if ($Global:AlertMsg) {
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-RMMAlert $Global:AlertMsg
    write-RMMDiag $Global:DiagMsg
    Exit 1
}
else {
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"
    write-RMMAlert $Global:AlertHealthy
    write-RMMDiag $Global:DiagMsg
    Exit 0
}