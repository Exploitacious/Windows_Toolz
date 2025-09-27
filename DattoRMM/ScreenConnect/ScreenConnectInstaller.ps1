

# 
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Install or Verify ConnectWise ScreenConnect" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:ConnectWiseControlPublicKeyThumbprint = 'PASTE_THUMBPRINT_HERE' # Public key thumbprint from your ScreenConnect instance.
#$env:ConnectWiseControlBaseUrl = 'https://screenconnect.yourdomain.com/' # Base URL of your ScreenConnect server
#$env:ConnectWiseControlInstallerUrl = 'https://screenconnect.yourdomain.com/Bin/ScreenConnect.ClientSetup.exe?e=Access&h=...&p=...&k=...' # Full URL to the EXE installer
#$env:usrUDF = '1' # RMM Custom Field (UDF) number to store the join link.
#$env:ExpectedCertificateSubject = 'CN=DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1' # Expected CN of the installer's signing certificate subject.
#$env:ExpectedCertificateThumbprint = '7B0F360B775F76C94A12CA48445AA2D2A875701C' # Expected thumbprint of the intermediate signing certificate.
#$env:APIEndpoint = "" # Optional: API Endpoint for sending results.

<#
This Script is a Remediation compoenent, meaning it performs only one task with a log of granular detail. These task results can be added back ito tickets as time entries using the API. 

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########



### Script Goes Here ###
#------------------------------------------------------------------------------------#
#                                  FUNCTIONS                                         #
#------------------------------------------------------------------------------------#

Function Test-ScreenConnectInstallation {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Thumbprint
    )

    $serviceRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($Thumbprint)"

    $Global:DiagMsg += "- Checking for existing ScreenConnect installation..."
    if (Test-Path -Path $serviceRegistryPath) {
        $Global:DiagMsg += "  [INFO] A matching ScreenConnect service was found."
        return $true
    }
    else {
        $Global:DiagMsg += "  [INFO] No matching ScreenConnect service was found."
        return $false
    }
}

Function Set-RmmJoinLink {
    param (
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        [Parameter(Mandatory = $true)]
        [string]$Thumbprint,
        [Parameter(Mandatory = $true)]
        [string]$UdfNumber
    )

    $Global:DiagMsg += "- Attempting to create RMM join link..."
    try {
        $serviceRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($Thumbprint)"
        
        $imagePath = (Get-ItemProperty -Path $serviceRegistryPath -Name 'ImagePath').ImagePath
        $match = [regex]::Match($imagePath, '(&s=[a-f0-9\-]{36})')

        if ($match.Success) {
            $sessionGuid = $match.Groups[1].Value.Replace('&s=', '')
            $joinLinkUrl = "$($BaseUrl.TrimEnd('/'))/Host#Access///$sessionGuid/Join"
            
            # Populate the global UDF variable. The template handles writing it to the registry.
            $Global:varUDFString = $joinLinkUrl
            
            $Global:DiagMsg += "  [SUCCESS] Join link prepared for RMM UDF #$UdfNumber."
            $Global:DiagMsg += "  Link: $joinLinkUrl"
        }
        else {
            $Global:DiagMsg += "[WARNING] Could not extract session GUID from service path: $imagePath"
        }
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to create the RMM join link. Error details:"
        $Global:DiagMsg += "[ERROR] $($_.Exception.Message)"
    }
}

Function Get-Installer {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InstallerUrl,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $Global:DiagMsg += "- Downloading installer..."
    $decodedUrl = $InstallerUrl -replace '&amp;', '&'
    $Global:DiagMsg += "  [INFO] Download URL: $decodedUrl"

    # Set security protocol to TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    try {
        $webClient = New-Object -TypeName System.Net.WebClient
        $webClient.DownloadFile($decodedUrl, $DestinationPath)

        if (Test-Path -Path $DestinationPath) {
            $Global:DiagMsg += "  [SUCCESS] Installer downloaded to: $DestinationPath"
            return $true
        }
        else {
            $Global:DiagMsg += "[ERROR] Download completed but the file could not be found at the destination."
            return $false
        }
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to download the installer. Please check the URL and network/firewall settings."
        $Global:DiagMsg += "[ERROR] $($_.Exception.Message)"
        return $false
    }
}

Function Test-InstallerSignature {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$CertSubject,
        [Parameter(Mandatory = $true)]
        [string]$CertThumbprint
    )

    $Global:DiagMsg += "- Verifying installer's digital signature..."
    try {
        $signature = Get-AuthenticodeSignature -FilePath $FilePath
        if ($signature.Status -ne 'Valid') {
            $Global:DiagMsg += "[ERROR] The digital signature is invalid. Status: $($signature.Status). The file may be corrupt or tampered with."
            return $false
        }
        $Global:DiagMsg += "  [OK] Signature status is valid."

        $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
        $chain.Build($signature.SignerCertificate) | Out-Null
        $intermediateCert = $chain.ChainElements | ForEach-Object { $_.Certificate } | Where-Object { $_.Subject -match [regex]::Escape($CertSubject) }

        if (-not $intermediateCert) {
            $Global:DiagMsg += "[ERROR] Could not find the expected intermediate certificate with subject '$CertSubject'."
            return $false
        }

        if ($intermediateCert.Thumbprint -ne $CertThumbprint) {
            $Global:DiagMsg += "[ERROR] Certificate thumbprint mismatch! The installer may be signed by an untrusted entity."
            $Global:DiagMsg += "  Expected: $CertThumbprint"
            $Global:DiagMsg += "  Actual:   $($intermediateCert.Thumbprint)"
            return $false
        }
        $Global:DiagMsg += "  [OK] Certificate thumbprint matches expected value."
        $Global:DiagMsg += "  [SUCCESS] Digital signature verification passed."
        return $true
    }
    catch {
        $Global:DiagMsg += "[ERROR] An unexpected error occurred during signature verification."
        $Global:DiagMsg += "[ERROR] $($_.Exception.Message)"
        return $false
    }
}

Function Install-ScreenConnect {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $Global:DiagMsg += "- Installing ScreenConnect client..."
    $arguments = '/s /qn' # Silent and quiet installation flags

    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $arguments -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            $Global:DiagMsg += "  [SUCCESS] Installation process completed successfully."
            $Global:DiagMsg += "  Waiting 10 seconds for service registration..."
            Start-Sleep -Seconds 10
        }
        else {
            $Global:DiagMsg += "[ERROR] Installation process finished with a non-zero exit code: $($process.ExitCode). Check installation logs for details."
        }
    }
    catch {
        $Global:DiagMsg += "[ERROR] Failed to start the installation process."
        $Global:DiagMsg += "[ERROR] $($_.Exception.Message)"
    }
}

#------------------------------------------------------------------------------------#
#                                  MAIN SCRIPT                                       #
#------------------------------------------------------------------------------------#

$Global:DiagMsg += "ConnectWise ScreenConnect Deployment Script"
$Global:DiagMsg += "==========================================="

# Construct the full path for the installer file
$installerFullPath = Join-Path -Path $env:TEMP -ChildPath 'ScreenConnect.ClientSetup.exe'

# --- Step 1: Check if ScreenConnect is already installed ---
if (Test-ScreenConnectInstallation -Thumbprint $env:ConnectWiseControlPublicKeyThumbprint) {
    # If it's installed, just create the RMM link.
    Set-RmmJoinLink -BaseUrl $env:ConnectWiseControlBaseUrl -Thumbprint $env:ConnectWiseControlPublicKeyThumbprint -UdfNumber $env:usrUDF
    $Global:DiagMsg += "[COMPLETE] ScreenConnect is already installed. RMM link updated."
}
else {
    $Global:DiagMsg += "[INFO] ScreenConnect not found. Proceeding with installation."

    # --- Step 2: Download the installer ---
    if (-not (Get-Installer -InstallerUrl $env:ConnectWiseControlInstallerUrl -DestinationPath $installerFullPath)) {
        $Global:DiagMsg += "[FATAL] Halting script due to download failure."
        return 
    }

    # --- Step 3: Validate the installer's signature ---
    if (-not (Test-InstallerSignature -FilePath $installerFullPath -CertSubject $env:ExpectedCertificateSubject -CertThumbprint $env:ExpectedCertificateThumbprint)) {
        $Global:DiagMsg += "[FATAL] CRITICAL: Installer validation failed. The file will be removed."
        $Global:DiagMsg += "[FATAL] This security check protects your environment from potentially malicious code."
        Remove-Item -Path $installerFullPath -Force -ErrorAction SilentlyContinue
        return
    }

    # --- Step 4: Install ScreenConnect ---
    Install-ScreenConnect -FilePath $installerFullPath

    # --- Step 5: Verify installation and create link ---
    if (Test-ScreenConnectInstallation -Thumbprint $env:ConnectWiseControlPublicKeyThumbprint) {
        $Global:DiagMsg += "[SUCCESS] New installation has been confirmed."
        Set-RmmJoinLink -BaseUrl $env:ConnectWiseControlBaseUrl -Thumbprint $env:ConnectWiseControlPublicKeyThumbprint -UdfNumber $env:usrUDF
    }
    else {
        $Global:DiagMsg += "[ERROR] Installation process finished, but the new service could not be verified. Please check manually."
    }

    # --- Step 6: Cleanup ---
    $Global:DiagMsg += "- Cleaning up downloaded files..."
    if (Test-Path -Path $installerFullPath) {
        Remove-Item -Path $installerFullPath -Force -ErrorAction SilentlyContinue
        $Global:DiagMsg += "  [INFO] Installer file removed."
    }
}

$Global:DiagMsg += "==========================================="
$Global:DiagMsg += "Script execution finished."


######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {    
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF: " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Info to be sent to into JSON POST to API Endpoint (Optional)
$APIinfoHashTable = @{
    'CS_PROFILE_UID' = $env:CS_PROFILE_UID
    'Script_Diag'    = $Global:DiagMsg
    'Script_UID'     = $ScriptUID
}
#######################################################################
### Exit script with proper Datto diagnostic and API Results.
# Add Script Result and POST to API if an Endpoint is Provided
if ($null -ne $env:APIEndpoint) {
    $Global:DiagMsg += " - Sending Results to API"
    Invoke-WebRequest -Uri $env:APIEndpoint -Method POST -Body ($APIinfoHashTable | ConvertTo-Json) -ContentType "application/json"
}
# Exit with writing diagnostic back to the ticket / remediation component log
write-DRMMDiag $Global:DiagMsg
Exit 0
