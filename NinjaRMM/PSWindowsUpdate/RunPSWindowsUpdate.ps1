# Script Title: Automate PSWindowsUpdate
# Description: Automates the installation of the PSWindowsUpdate module and installs all available Windows Updates. Configures TLS 1.2 and PSGallery prerequisites automatically.

# Script Name and Type
$ScriptName = "Automate PSWindowsUpdate"
$ScriptType = "Remediation"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# Microsoft Update Service ID (Standard GUID)
$MicrosoftUpdateServiceId = "7971f918-a847-4430-9279-4a52d1efe18d"

## CONFIG RMM VARIABLES ##
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# targetModules (String): Comma-separated list of modules to ensure are installed. Default: "PSWindowsUpdate"
# registerMicrosoftUpdate (Checkbox): Set to true to register Microsoft Update Service (for Office, etc.). Default: true

if (-not $env:targetModules) { $env:targetModules = "PSWindowsUpdate" }
if (-not $env:registerMicrosoftUpdate) { $env:registerMicrosoftUpdate = "true" }

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Windows Update process completed successfully. | Last Checked $Date"

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

# --- HELPER FUNCTIONS ---

Function Initialize-Environment {
    $Global:DiagMsg += "--- Initializing Environment ---"

    # 1. Verify Admin Session
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Script is not running with Administrator privileges. Cannot proceed."
    }
    else {
        $Global:DiagMsg += "Administrator privileges confirmed."
    }

    # 2. Define and use TLS1.2 (Required for PSGallery)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Global:DiagMsg += "TLS 1.2 set successfully."
    }
    catch {
        throw "Failed to set TLS 1.2. Error: $($_.Exception.Message)"
    }
    
    # 3. Configure Providers and Repository
    $Global:DiagMsg += "Configuring PowerShell Gallery repository..."
    try {
        # CRITICAL FIX: Ensure NuGet provider is installed FIRST using -Force.
        # This prevents 'Register-PSRepository' from triggering an interactive prompt to install it later.
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            $Global:DiagMsg += "NuGet provider missing. Installing..."
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -ErrorAction Stop
            $Global:DiagMsg += "NuGet provider installed."
        }
        else {
            $Global:DiagMsg += "NuGet provider is present."
        }

        # Check if PSGallery is registered, if not, register it.
        if (-NOT (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
            Register-PSRepository -Default -ErrorAction Stop
            $Global:DiagMsg += "PSGallery repository has been registered."
        }

        # Set Trusted to avoid prompts during module installation
        if ((Get-PSRepository -Name 'PSGallery').InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop
            $Global:DiagMsg += "PSGallery repository has been set to 'Trusted'."
        }
    }
    catch {
        # Fallback: Sometimes just forcing the package provider again fixes weird registry states
        $Global:DiagMsg += "Standard config failed. Attempting fallback provider bootstrap..."
        try {
            Get-PackageProvider -Name NuGet -ForceBootstrap -Force -ErrorAction Stop
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop
        }
        catch {
            throw "Failed to configure PowerShell providers. Error: $($_.Exception.Message)"
        }
    }
}

Function Manage-PowerShellModules {
    param(
        [string[]]$ModuleList
    )
    $Global:DiagMsg += "--- Managing PowerShell Modules ---"

    foreach ($ModuleName in $ModuleList) {
        $ModuleName = $ModuleName.Trim()
        if ([string]::IsNullOrWhiteSpace($ModuleName)) { continue }

        $Global:DiagMsg += "Processing module: '$ModuleName'..."
        try {
            # Check if installed
            $InstalledModules = Get-InstalledModule -Name $ModuleName -AllVersions -ErrorAction SilentlyContinue

            if (-not $InstalledModules) {
                $Global:DiagMsg += "'$ModuleName' is not installed. Installing latest version..."
                # REMOVED: -AcceptLicense (Not supported on older PowerShellGet versions)
                Install-Module -Name $ModuleName -Force -AllowClobber -Scope AllUsers -ErrorAction Stop
                $Global:DiagMsg += "Successfully installed '$ModuleName'."
            }
            else {
                # If installed, check if update is needed
                # We find the module online ONLY if we already have it, to compare versions
                $GalleryModule = Find-Module -Name $ModuleName -ErrorAction Stop
                $LatestVersion = $GalleryModule.Version
                
                # Select the first version found (usually the latest loaded)
                $CurrentInstalled = $InstalledModules | Select-Object -ExpandProperty Version -First 1

                if ($CurrentVersion -lt $LatestVersion) {
                    $Global:DiagMsg += "Updating '$ModuleName' from version $CurrentVersion to $LatestVersion..."
                    # REMOVED: -AcceptLicense (Not supported on older PowerShellGet versions)
                    Install-Module -Name $ModuleName -Force -AllowClobber -Scope AllUsers -ErrorAction Stop
                    $Global:DiagMsg += "Successfully updated '$ModuleName'."
                }
                else {
                    $Global:DiagMsg += "'$ModuleName' is already up-to-date (Version: $CurrentVersion)."
                }
            }
        }
        catch {
            $Global:DiagMsg += "Error managing '$ModuleName': $($_.Exception.Message)"
            throw "Failed to manage critical module $ModuleName."
        }
    }
}

Function Invoke-WindowsUpdate {
    $Global:DiagMsg += "--- Starting Windows Update Process ---"

    # Import Module
    try {
        Import-Module PSWindowsUpdate -Force -ErrorAction Stop
        $Global:DiagMsg += "Successfully imported 'PSWindowsUpdate' module."
    }
    catch {
        throw "Failed to import 'PSWindowsUpdate'. Ensure it was installed correctly."
    }

    # Register Microsoft Update Service (if configured)
    if ([bool]::Parse($env:registerMicrosoftUpdate)) {
        if (-not (Get-WUServiceManager -ServiceID $MicrosoftUpdateServiceId -ErrorAction SilentlyContinue)) {
            Add-WUServiceManager -ServiceID $MicrosoftUpdateServiceId -Confirm:$false -ErrorAction SilentlyContinue
            $Global:DiagMsg += "Microsoft Update Service registered."
        }
    }

    # Run Updates
    $Global:DiagMsg += "Scanning and Installing Updates (IgnoreReboot=True)..."
    try {
        # Capture all output objects
        $RawResults = Install-WindowsUpdate -AcceptAll -ForceInstall -IgnoreReboot -ErrorAction Stop 
        
        if ($RawResults) {
            # 1. Deduplicate based on Title and Result to fix the "Triple Entry" issue
            $UniqueResults = $RawResults | Select-Object ComputerName, Result, KB, Title, Size -Unique

            # 2. Separate Successes from Failures
            $FailedItems = $UniqueResults | Where-Object { $_.Result -eq 'Failed' }
            $InstalledItems = $UniqueResults | Where-Object { $_.Result -eq 'Installed' }
            
            # 3. Log the clean table
            $Global:DiagMsg += ($UniqueResults | Format-Table -AutoSize | Out-String)

            # 4. Return complex status object for Main block to handle
            return @{
                TotalInstalled = @($InstalledItems).Count
                TotalFailed    = @($FailedItems).Count
                FailedKBs      = ($FailedItems.KB -join ", ")
            }
        }
        else {
            $Global:DiagMsg += "No updates were returned by the scan."
            return @{ TotalInstalled = 0; TotalFailed = 0 }
        }
    }
    catch {
        throw "Error during Install-WindowsUpdate: $($_.Exception.Message)"
    }
}

# --- MAIN EXECUTION ---
try {
    # 1. Environment Setup
    Initialize-Environment

    # 2. Module Management
    $ModuleArray = $env:targetModules -split ','
    Manage-PowerShellModules -ModuleList $ModuleArray

    # 3. Windows Update
    $UpdateStatus = Invoke-WindowsUpdate

    # 4. Status Logic (Detect Failures)
    if ($UpdateStatus.TotalFailed -gt 0) {
        # FAILURE SCENARIO
        $ErrorMessage = "Updates Failed: $($UpdateStatus.TotalFailed). Installed: $($UpdateStatus.TotalInstalled). Failed KBs: $($UpdateStatus.FailedKBs)"
        $Global:DiagMsg += "CRITICAL: $ErrorMessage"
        
        # Populate AlertMsg to trigger Exit 1
        $Global:AlertMsg = "$ErrorMessage | Last Checked $Date"
        $Global:customFieldMessage = "Partial Failure: $($UpdateStatus.TotalFailed) failed. ($Date)"
    }
    elseif ($UpdateStatus.TotalInstalled -gt 0) {
        # SUCCESS SCENARIO
        $Global:customFieldMessage = "Success: Installed $($UpdateStatus.TotalInstalled) updates. ($Date)"
        $Global:DiagMsg += "Successfully installed $($UpdateStatus.TotalInstalled) updates."
    }
    else {
        # NO UPDATES NEEDED
        $Global:customFieldMessage = "System up to date. No updates installed. ($Date)"
        $Global:DiagMsg += "System is already up to date."
    }

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed. Error: $($_.Exception.Message) | Last Checked $Date"
    $Global:customFieldMessage = "Script Error: $($_.Exception.Message) ($Date)"
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