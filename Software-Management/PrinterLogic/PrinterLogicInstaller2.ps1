# Script Title: Application Deployment - Printer Logic Client
# Description: Installs the Printer Logic agent using Organization-level custom fields for Home URL and Auth Code. Optionally applies browser registry fixes.

# Script Name and Type
$ScriptName = "Application Deployment - Printer Logic Client"
$ScriptType = "Remediation" 
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

##################################
######## Pre-Flight Setup ########
# CRITICAL: Bypass execution policy for this process only to ensure Ninja modules load.
try {
    Write-Host "Setting Process Execution Policy to Bypass..."
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
    
    # Explicitly import the Ninja module now that policy is bypassed
    if (Get-Module -ListAvailable -Name NJCliPSh) {
        Import-Module NJCliPSh -ErrorAction SilentlyContinue
        Write-Host "Successfully loaded NinjaRMM Module (NJCliPSh)."
    }
}
catch {
    Write-Host "Warning: Could not set Execution Policy or Import Module. $($_.Exception.Message)"
}
##################################

## HARD-CODED VARIABLES ##
# Base working directory for downloads
$WorkDir = "C:\Temp\"
# The hard-coded name of the field specified in instructions, used if $env:customFieldName is not provided
$DefaultInfoField = "softwarePrinterLogicInfo" 
# Installer constants
$InstallerURL = "https://downloads.printercloud.com/client/setup/PrinterInstallerClient.msi"
$InstallerName = "PrinterInstallerClient.msi"

## ORG-LEVEL EXPECTED VARIABLES ##
# printerLogicHomeUrl
# printerLogicOrgAuthCode

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to. (Default: softwarePrinterLogicInfo)
# BrowserDirectExe (Checkbox): Set to 'true' to enable NativeHostsExecutablesLaunchDirectly registry keys for Chrome/Edge.
# FreshInstall (Checkbox): Set to 'true' to force a fresh install even if Printer Logic is already installed.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Printer Logic deployment completed successfully. | Last Checked $Date"

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
##################################
######## Start of Script #########

# Function: Retrieve Organization Variables
function Get-OrgVariables {
    $Global:DiagMsg += "Retrieving Organization Custom Fields..."
    
    # DEFINED LOCALLY TO PREVENT SCOPE LOSS
    $TargetField_HomeURL = "printerLogicHomeUrl"
    $TargetField_AuthCode = "printerLogicOrgAuthCode"

    # --- Attempt 1: Standard Global Custom Field Get ---
    $Global:DiagMsg += "Attempt 1: Retrieving via Standard Property Get for '$TargetField_HomeURL' and '$TargetField_AuthCode'..."
    
    try {
        $HomeURL = (Ninja-Property-Get -Name $TargetField_HomeURL).Value
        $AuthCode = (Ninja-Property-Get -Name $TargetField_AuthCode).Value
    }
    catch {
        $Global:DiagMsg += "Standard Get failed: $($_.Exception.Message)"
    }

    # --- Attempt 2: CLI Direct Fallback (If Method 1 returns empty) ---
    # Sometimes the wrapper fails but the CLI works for Org fields.
    if (-not $HomeURL) {
        $Global:DiagMsg += "Variable '$TargetField_HomeURL' missing via standard get. Attempting direct CLI..."
        try { $HomeURL = & "$env:NINJARMMCLI" get $TargetField_HomeURL 2>$null } catch {}
    }
    if (-not $AuthCode) {
        $Global:DiagMsg += "Variable '$TargetField_AuthCode' missing via standard get. Attempting direct CLI..."
        try { $AuthCode = & "$env:NINJARMMCLI" get $TargetField_AuthCode 2>$null } catch {}
    }

    # --- Attempt 3: Organization Documentation (Last Resort) ---
    if (-not $HomeURL) {
        $Global:DiagMsg += "Checking 'Default' Org Documentation for '$TargetField_HomeURL'..."
        try {
            $HomeURL = Ninja-Property-Docs-Get -TemplateName "Default" -DocumentName "Default" -AttributeName $TargetField_HomeURL
        }
        catch { $Global:DiagMsg += "Docs Get failed for URL." }
    }

    if (-not $AuthCode) {
        $Global:DiagMsg += "Checking 'Default' Org Documentation for '$TargetField_AuthCode'..."
        try {
            $AuthCode = Ninja-Property-Docs-Get -TemplateName "Default" -DocumentName "Default" -AttributeName $TargetField_AuthCode
        }
        catch { $Global:DiagMsg += "Docs Get failed for Auth Code." }
    }

    # --- Final Validation ---
    $Global:DiagMsg += "Result HomeURL: $(if ($HomeURL) {'FOUND'} else {'MISSING'})"
    $Global:DiagMsg += "Result AuthCode: $(if ($AuthCode) {'FOUND'} else {'MISSING'})"

    if (-not $HomeURL -or -not $AuthCode) {
        return $null
    }
    
    return @{ HomeURL = $HomeURL; AuthCode = $AuthCode }
}

# Function: Check if PrinterLogic is Installed
function Test-PrinterLogicInstalled {
    $Global:DiagMsg += "Checking for existing Printer Logic installation..."
    if (Get-Service -Name "PrinterInstallerLauncher" -ErrorAction SilentlyContinue) {
        $Global:DiagMsg += "Printer Logic service found."
        return $true
    }
    $Global:DiagMsg += "Printer Logic service not found."
    return $false
}

# Function: Remove Printer Logic (Cleanup)
function Remove-PrinterLogic {
    $Global:DiagMsg += "Initiating 'Fresh Install' cleanup protocol..."

    # Process Management
    $processPrefixes = @("PrinterInstaller", "PrinterLogic")
    $Global:DiagMsg += "Stopping PrinterLogic processes..."
    foreach ($processPrefix in $processPrefixes) {
        $processes = Get-Process "${processPrefix}*" -ErrorAction SilentlyContinue
        if ($processes) {
            $processes | Stop-Process -Force
            $Global:DiagMsg += "Stopped processes: $($processes.Name -join ', ')"
        }
    }

    # Service Management
    $Global:DiagMsg += "Removing PrinterLogic services..."
    $launcherService = Get-WmiObject -Class Win32_Service -Filter "Name='PrinterInstallerLauncher'" -ErrorAction SilentlyContinue
    if ($null -ne $launcherService) {
        $launcherService.delete() | Out-Null
        $Global:DiagMsg += "Service 'PrinterInstallerLauncher' deleted."
    }

    # File System Management
    $InstallDir = "C:\Program Files (x86)\Printer Properties Pro"
    $Global:DiagMsg += "Deleting PrinterLogic installation from disk..."
    if (Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
        $Global:DiagMsg += "Directory '$InstallDir' removed."
    }

    # Registry Management
    $Global:DiagMsg += "Cleaning registry keys..."
    
    # --- Fix for "Error applying transforms" (GPO Remnant) ---
    $Global:DiagMsg += "Scanning for GPO 'Transforms' remnants..."
    $installerProductsPath = "HKLM:\SOFTWARE\Classes\Installer\Products"
    if (Test-Path $installerProductsPath) {
        try {
            Get-ChildItem -Path $installerProductsPath | ForEach-Object {
                $productName = (Get-ItemProperty -Path $_.PSPath -Name "ProductName" -ErrorAction SilentlyContinue).ProductName
                if ($productName -eq "Printer Installer Client") {
                    $Global:DiagMsg += "Found Product Key: $($_.PSChildName)"
                    if (Get-ItemProperty -Path $_.PSPath -Name "Transforms" -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $_.PSPath -Name "Transforms" -Force -ErrorAction SilentlyContinue
                        $Global:DiagMsg += "SUCCESS: Removed 'Transforms' value from $($_.PSChildName)."
                    }
                }
            }
        }
        catch { $Global:DiagMsg += "Warning during Transform scan: $($_.Exception.Message)" }
    }
    # ----------------------------------------------------------------

    $regKeys = @(
        "HKLM:\SOFTWARE\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKLM:\SOFTWARE\Classes\Installer\Products\8580ED9ADDD9B1E40B142CAA09CDFB47",
        "HKLM:\SOFTWARE\Classes\PPPiPrinterfile",
        "HKLM:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin",
        "HKLM:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin.1",
        "HKLM:\SOFTWARE\Classes\printerlogicidp",
        "HKLM:\SOFTWARE\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKLM:\SOFTWARE\Classes\WOW6432Node\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKLM:\SOFTWARE\Classes\WOW6432Node\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKLM:\SOFTWARE\WOW6432Node\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\WOW6432Node\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin_x86_64",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A9DE0858-9DDD-4E1B-B041-C2AA90DCBF74}",
        "HKLM:\SOFTWARE\WOW6432Node\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKLM:\SOFTWARE\WOW6432Node\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin",
        "HKLM:\SOFTWARE\WOW6432Node\PPP",
        "HKLM:\SYSTEM\CurrentControlSet\Services\PrinterInstallerLauncher",
        "HKLM:\SOFTWARE\PrinterLogic",
        "HKLM:\SOFTWARE\PPP",
        "HKCU:\SOFTWARE\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKCU:\SOFTWARE\Classes\Installer\Products\8580ED9ADDD9B1E40B142CAA09CDFB47",
        "HKCU:\SOFTWARE\Classes\PPPiPrinterfile",
        "HKCU:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin",
        "HKCU:\SOFTWARE\Classes\PrinterLogic.PrinterInstallerClientPlugin.1",
        "HKCU:\SOFTWARE\Classes\printerlogicidp",
        "HKCU:\SOFTWARE\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKCU:\SOFTWARE\Classes\WOW6432Node\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKCU:\SOFTWARE\Classes\WOW6432Node\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKCU:\SOFTWARE\WOW6432Node\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\WOW6432Node\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\Microsoft\Edge\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\Chromium\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin_x86_64",
        "HKCU:\SOFTWARE\WOW6432Node\Classes\CLSID\{95986c55-6a68-5ef1-8753-fb2f1040a350}",
        "HKCU:\SOFTWARE\WOW6432Node\Classes\TypeLib\{7D2DA2E1-1CD1-53A3-8153-CA0B344D6930}",
        "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A9DE0858-9DDD-4E1B-B041-C2AA90DCBF74}",
        "HKCU:\SOFTWARE\WOW6432Node\Mozilla\NativeMessagingHosts\com.printerlogic.host.native.client",
        "HKCU:\SOFTWARE\WOW6432Node\MozillaPlugins\printerlogic.com/PrinterInstallerClientPlugin",
        "HKCU:\SOFTWARE\WOW6432Node\PPP",
        "HKCU:\SYSTEM\CurrentControlSet\Services\PrinterInstallerLauncher",
        "HKCU:\SOFTWARE\PrinterLogic",
        "HKCU:\SOFTWARE\PPP"
    )

    $regKeysRemoved = 0
    foreach ($key in $regKeys) {
        if (Test-Path $key) {
            try {
                Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
                $regKeysRemoved++
            }
            catch {
                $Global:DiagMsg += "Failed to remove key $key : $($_.Exception.Message)"
            }
        }
    }
    $Global:DiagMsg += "Registry cleanup complete. Removed $regKeysRemoved keys."
}

# Function: Download Installer
function Invoke-DownloadInstaller {
    if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null }
    $DestPath = Join-Path -Path $WorkDir -ChildPath $InstallerName
    
    $Global:DiagMsg += "Downloading installer from $InstallerURL..."
    try {
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($InstallerURL, $DestPath)
        if (Test-Path $DestPath) { return $DestPath }
    }
    catch {
        throw "Download failed: $($_.Exception.Message)"
    }
    throw "Download failed: File not found after download attempt."
}

# Function: Run Installer
function Install-PrinterLogic ($InstallerPath, $HomeURL, $AuthCode) {
    $Arguments = "/i `"$InstallerPath`" /qn HOMEURL=$HomeURL AUTHORIZATION_CODE=$AuthCode"
    $Global:DiagMsg += "Executing MSI..."
    
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    
    if ($Process.ExitCode -eq 0) { return "Success" }
    elseif ($Process.ExitCode -eq 3010) { return "RebootRequired" }
    else { throw "MSI Installer returned error code: $($Process.ExitCode)" }
}

# Function: Apply Registry Fixes
function Set-BrowserRegistryFix {
    $Global:DiagMsg += "Applying Browser Native Host execution fixes..."
    $registryChanges = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "NativeHostsExecutablesLaunchDirectly" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "NativeHostsExecutablesLaunchDirectly" }
    )

    $AppliedCount = 0
    foreach ($reg in $registryChanges) {
        if (-not (Test-Path $reg.Path)) {
            New-Item -Path $reg.Path -Force | Out-Null
            $Global:DiagMsg += "Created Key: $($reg.Path)"
        }
        try {
            New-ItemProperty -Path $reg.Path -Name $reg.Name -Value 1 -PropertyType DWORD -Force | Out-Null
            $Global:DiagMsg += "Set $($reg.Name) to 1 in $($reg.Path)"
            $AppliedCount++
        }
        catch {
            $Global:DiagMsg += "Failed to set $($reg.Name) in $($reg.Path): $($_.Exception.Message)"
        }
    }
    return $AppliedCount
}

# Main Execution Flow
try {
    # Initialize defaults
    if (-not $env:customFieldName) { $env:customFieldName = $DefaultInfoField }
    
    # 1. Determine Initial State
    $IsInstalled = Test-PrinterLogicInstalled
    $OrgVars = Get-OrgVariables
    $ActionTaken = @()

    # 2. Handle Fresh Install Logic
    if ($env:FreshInstall -eq 'true') {
        $Global:DiagMsg += "Fresh Install Selected. Forcing cleanup."
        Remove-PrinterLogic
        $IsInstalled = $false # Force state to not installed so we proceed to install
        $ActionTaken += "Fresh Install (Cleaned)"
    }

    # 3. Install if Missing (or if just cleaned)
    if (-not $IsInstalled) {
        if ($OrgVars) {
            $InstallerPath = Invoke-DownloadInstaller
            $InstallResult = Install-PrinterLogic -InstallerPath $InstallerPath -HomeURL $OrgVars.HomeURL -AuthCode $OrgVars.AuthCode
            
            if ($InstallResult -eq "Success") { $ActionTaken += "Installed Successfully" }
            elseif ($InstallResult -eq "RebootRequired") { $ActionTaken += "Installed (Reboot Pending)" }
            
            # Update state for next step
            $IsInstalled = $true 
        }
        else {
            $Global:customFieldMessage = "Skipped: Org Missing PrinterLogic Config."
            $Global:DiagMsg += "Organization not configured. Skipping install."
        }
    }
    else {
        $ActionTaken += "Already Installed"
    }

    # 4. Apply Registry Fixes (Only if installed now or previously)
    if ($IsInstalled -and ($env:BrowserDirectExe -eq 'true')) {
        Set-BrowserRegistryFix | Out-Null
        $ActionTaken += "Applied Registry Fixes"
    }
    elseif ($env:BrowserDirectExe -eq 'true' -and -not $IsInstalled) {
        $Global:DiagMsg += "Skipping Registry Fixes because PrinterLogic is not installed."
    }

    # 5. Final Status Composition
    if ($Global:customFieldMessage -eq "") {
        if ($ActionTaken.Count -gt 0) {
            $Global:customFieldMessage = "$($ActionTaken -join ', ') ($Date)"
        }
        else {
            $Global:customFieldMessage = "Verified Installed. No actions taken. ($Date)"
        }
    }
}
catch {
    $Global:DiagMsg += "CRITICAL ERROR: $($_.Exception.Message)"
    $Global:AlertMsg = "Script Failure: $($_.Exception.Message) | Last Checked $Date"
    $Global:customFieldMessage = "Error: $($_.Exception.Message)"
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