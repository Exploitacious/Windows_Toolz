# Script Title: ConnectWise ScreenConnect Agent Deployment
# Description: Installs or verifies the ConnectWise ScreenConnect (Control) agent. Downloads the installer, validates its signature, installs silently, and writes a direct join link to a specified Custom Field.

# Script Name and Type
$ScriptName = "ConnectWise ScreenConnect Agent Deployment"
$ScriptType = "Remediation" # Can also be "General"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the overall status to.
# joinLinkCustomFieldName (Text): The name of the Text Custom Field to store the ScreenConnect join link.
# $env:installerUrl = '' # The full URL to the ScreenConnect agent installer (.exe).
# $env:baseUrl = '' # The base URL of your ScreenConnect instance (e.g., https://remote.mycompany.com).
# $env:servicePublicKeyThumbprint = '' # The public key thumbprint from your installer URL (the 'k=' parameter).
# expectedCertSubject (Text): The expected subject of the installer's digital signature certificate (e.g., CN="ConnectWise, LLC", O="ConnectWise, LLC", L=Tampa, S=Florida, C=US).
# expectedCertThumbprint (Text): The expected thumbprint of the intermediate certificate that signed the installer.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "ScreenConnect agent deployment completed successfully. | Last Checked $Date"

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

try {
    #region Functions
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
            [string]$JoinLinkFieldName
        )

        $Global:DiagMsg += "- Attempting to create and set ScreenConnect join link..."
        if (-not $JoinLinkFieldName) {
            $Global:DiagMsg += "  [INFO] RMM variable 'joinLinkCustomFieldName' not provided. Skipping join link update."
            return
        }

        try {
            $serviceRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($Thumbprint)"
            $imagePath = (Get-ItemProperty -Path $serviceRegistryPath -Name 'ImagePath').ImagePath
            $match = [regex]::Match($imagePath, '(&s=[a-f0-9\-]{36})')

            if ($match.Success) {
                $sessionGuid = $match.Groups[1].Value.Replace('&s=', '')
                $joinLinkUrl = "$($BaseUrl.TrimEnd('/'))/Host#Access///$sessionGuid/Join"
                
                $Global:DiagMsg += "  [INFO] Attempting to write join link to Custom Field '$JoinLinkFieldName'."
                Ninja-Property-Set -Name $JoinLinkFieldName -Value $joinLinkUrl
                $Global:DiagMsg += "  [SUCCESS] Join link written to RMM Custom Field."
            }
            else {
                $Global:DiagMsg += "  [WARNING] Could not extract session GUID from service path: $imagePath"
            }
        }
        catch {
            $Global:DiagMsg += "  [ERROR] Failed to set the RMM join link. Error: $($_.Exception.Message)"
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
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        try {
            Invoke-WebRequest -Uri $decodedUrl -OutFile $DestinationPath -UseBasicParsing
            if (Test-Path -Path $DestinationPath) {
                $Global:DiagMsg += "  [SUCCESS] Installer downloaded to: $DestinationPath"
                return $true
            }
            else {
                $Global:DiagMsg += "  [ERROR] Download completed but the file could not be found at the destination."
                return $false
            }
        }
        catch {
            $Global:DiagMsg += "  [ERROR] Failed to download the installer. Please check the URL and network/firewall settings."
            $Global:DiagMsg += "  [ERROR] $($_.Exception.Message)"
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
                $Global:DiagMsg += "  [ERROR] The digital signature is invalid. Status: $($signature.Status). The file may be corrupt or tampered with."
                return $false
            }
            $Global:DiagMsg += "  [OK] Signature status is valid."

            $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
            $chain.Build($signature.SignerCertificate) | Out-Null
            $intermediateCert = $chain.ChainElements | ForEach-Object { $_.Certificate } | Where-Object { $_.Subject -match [regex]::Escape($CertSubject) }

            if (-not $intermediateCert) {
                $Global:DiagMsg += "  [ERROR] Could not find the expected intermediate certificate with subject '$CertSubject'."
                return $false
            }

            if ($intermediateCert.Thumbprint -ne $CertThumbprint) {
                $Global:DiagMsg += "  [ERROR] Certificate thumbprint mismatch! The installer may be signed by an untrusted entity."
                $Global:DiagMsg += "    Expected: $CertThumbprint"
                $Global:DiagMsg += "    Actual:   $($intermediateCert.Thumbprint)"
                return $false
            }
            $Global:DiagMsg += "  [OK] Certificate thumbprint matches expected value."
            $Global:DiagMsg += "  [SUCCESS] Digital signature verification passed."
            return $true
        }
        catch {
            $Global:DiagMsg += "  [ERROR] An unexpected error occurred during signature verification."
            $Global:DiagMsg += "  [ERROR] $($_.Exception.Message)"
            return $false
        }
    }

    Function Install-ScreenConnect {
        param (
            [Parameter(Mandatory = $true)]
            [string]$FilePath
        )
        $Global:DiagMsg += "- Installing ScreenConnect client via MSI..."
        try {
            $msiArgs = "/i `"$FilePath`" /qn"
            $Global:DiagMsg += "  [INFO] Executing: msiexec.exe $msiArgs"
            
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
            
            # MSI installers often return 0 for success. Other codes might indicate success with a required reboot.
            # We will treat 0 as the only success code for simplicity.
            if ($process.ExitCode -eq 0) {
                $Global:DiagMsg += "  [SUCCESS] Installation process completed successfully."
                $Global:DiagMsg += "  Waiting 15 seconds for service registration..."
                Start-Sleep -Seconds 15
            }
            else {
                $Global:DiagMsg += "  [ERROR] Installation process finished with a non-zero exit code: $($process.ExitCode). Check MSI logs for details."
            }
        }
        catch {
            $Global:DiagMsg += "  [ERROR] Failed to start the installation process."
            $Global:DiagMsg += "  [ERROR] $($_.Exception.Message)"
        }
    }
    #endregion Functions

    # --- Main Script Logic ---
    $Global:DiagMsg += "==========================================="
    $installerFullPath = Join-Path -Path $env:TEMP -ChildPath 'ScreenConnect.ClientSetup.msi'

    # Step 1: Check existing installation
    if (Test-ScreenConnectInstallation -Thumbprint $env:servicePublicKeyThumbprint) {
        Set-RmmJoinLink -BaseUrl $env:baseUrl -Thumbprint $env:servicePublicKeyThumbprint -JoinLinkFieldName $env:joinLinkCustomFieldName
        $Global:DiagMsg += "[COMPLETE] ScreenConnect is already installed. RMM link updated."
        $Global:customFieldMessage = "ScreenConnect already installed. Join link verified. ($Date)"
    }
    else {
        $Global:DiagMsg += "[INFO] ScreenConnect not found. Proceeding with installation."

        # Step 2: Download
        if (-not (Get-Installer -InstallerUrl $env:installerUrl -DestinationPath $installerFullPath)) {
            $Global:AlertMsg = "Failed to download the ScreenConnect installer. See diagnostics for details. | Last Checked $Date"
            $Global:customFieldMessage = "Installation failed: Download error. ($Date)"
            throw "Download failed."
        }

        # Step 3: Validate Signature (Optional)
        if ($env:expectedCertSubject -and $env:expectedCertThumbprint) {
            $Global:DiagMsg += "[INFO] Certificate subject and thumbprint provided. Proceeding with signature validation."
            if (-not (Test-InstallerSignature -FilePath $installerFullPath -CertSubject $env:expectedCertSubject -CertThumbprint $env:expectedCertThumbprint)) {
                $Global:AlertMsg = "CRITICAL: ScreenConnect installer signature verification failed. Halting installation. | Last Checked $Date"
                $Global:customFieldMessage = "Installation failed: Invalid signature. ($Date)"
                throw "Signature validation failed."
            }
        }
        else {
            $Global:DiagMsg += "[INFO] Certificate subject and/or thumbprint not provided. Skipping signature validation."
        }

        # Step 4: Install
        Install-ScreenConnect -FilePath $installerFullPath

        # Step 5: Verify & Create Link
        if (Test-ScreenConnectInstallation -Thumbprint $env:servicePublicKeyThumbprint) {
            $Global:DiagMsg += "[SUCCESS] New installation has been confirmed."
            Set-RmmJoinLink -BaseUrl $env:baseUrl -Thumbprint $env:servicePublicKeyThumbprint -JoinLinkFieldName $env:joinLinkCustomFieldName
            $Global:customFieldMessage = "ScreenConnect installed successfully. Join link created. ($Date)"
        }
        else {
            $Global:AlertMsg = "Installation process finished, but the new service could not be verified. | Last Checked $Date"
            $Global:customFieldMessage = "Installation failed: Post-install verification error. ($Date)"
            throw "Post-install verification failed."
        }
    }
    $Global:DiagMsg += "==========================================="
    $Global:DiagMsg += "Script execution finished successfully."

}
catch {
    $errorMsg = $_.Exception.Message | Out-String
    # If we threw an exception on purpose, the alert messages are already set.
    if (-not $Global:AlertMsg) {
        $Global:DiagMsg += "An unexpected error occurred: $errorMsg"
        $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
        $Global:customFieldMessage = "Script failed with an error. ($Date)"
    }
}
finally {
    # Final Cleanup
    if (Test-Path -Path $installerFullPath) {
        $Global:DiagMsg += "- Cleaning up downloaded files..."
        Remove-Item -Path $installerFullPath -Force -ErrorAction SilentlyContinue
        $Global:DiagMsg += "  [INFO] Installer file removed."
    }
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