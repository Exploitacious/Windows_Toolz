#
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Install Manufacturer Update Utility" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ##
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.

<#
This Script is a Remediation compoenent. It identifies the computer's manufacturer and, if it is Dell, HP, Lenovo, Microsoft Surface, or Fujitsu,
it will download and silently install the corresponding vendor-specific update management utility.
#>
# DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
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

try {
    # Determine the computer manufacturer
    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    $Global:DiagMsg += "Detected Manufacturer: $manufacturer"
    $Global:varUDFString = "Detected Manufacturer: $manufacturer"
    
    # Define a temporary path for downloads
    $tempPath = $env:TEMP
    
    # Use a switch statement to handle different manufacturers
    switch -Wildcard ($manufacturer) {
        "*Dell*" {
            $Global:DiagMsg += "Dell system detected. Preparing to install Dell Command | Update."
            $downloadUrl = "https://dl.dell.com/FOLDER13309588M/2/Dell-Command-Update-Windows-Universal-Application_C8JXV_WIN64_5.5.0_A00_01.EXE"
            $installerPath = Join-Path -Path $tempPath -ChildPath "DellCommandUpdate.exe"
            $processToRun = $installerPath
            $installArgs = "/s /acceptULA=yes"
            $appName = "Dell Command | Update"
        }
        "*LENOVO*" {
            $Global:DiagMsg += "Lenovo system detected. Preparing to install Lenovo System Update."
            $downloadUrl = "https://download.lenovo.com/pccbbs/thinkvantage_en/system_update_5.08.02.25.exe"
            $installerPath = Join-Path -Path $tempPath -ChildPath "LenovoSystemUpdate.exe"
            $processToRun = $installerPath
            $installArgs = "/VERYSILENT /NORESTART"
            $appName = "Lenovo System Update"
        }
        "*HP*" {
            $Global:DiagMsg += "HP system detected. Preparing to install HP Image Assistant."
            $downloadUrl = "https://ftp.hp.com/pub/softpaq/sp152501-153000/sp152661.exe"
            $installerPath = Join-Path -Path $tempPath -ChildPath "HPImageAssistant.exe"
            $processToRun = $installerPath
            $installArgs = "/S /v/qn"
            $appName = "HP Image Assistant"
        }
        "*Microsoft*" {
            $Global:DiagMsg += "Microsoft Surface device detected. Preparing to install Surface Diagnostic Toolkit for Business."
            $downloadUrl = "https://download.microsoft.com/download/528d8510-5b01-42a9-a02e-5eb82dc7ac50/Surface_Diagnostic_Toolkit_for_Business_v2.239.250501.msi"
            $installerPath = Join-Path -Path $tempPath -ChildPath "SurfaceDiagnosticToolkit.msi"
            $processToRun = "msiexec.exe"
            $installArgs = "/i `"$installerPath`" /qn"
            $appName = "Surface Diagnostic Toolkit for Business"
        }
        default {
            $Global:DiagMsg += "Manufacturer '$manufacturer' is not supported by this script. No action taken."
            # Set variable to null to skip download/install steps
            $downloadUrl = $null
        }
    }

    # Proceed if a supported manufacturer was found
    if ($downloadUrl) {
        $Global:DiagMsg += "Downloading $appName from $downloadUrl..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
        
        if (Test-Path $installerPath) {
            $Global:DiagMsg += "Download successful."
            # Handle ZIP file for Fujitsu
            if ($installerPath -like "*.zip") {
                $Global:DiagMsg += "Extracting archive..."
                Expand-Archive -Path $installerPath -DestinationPath $unzipPath -Force
                $Global:DiagMsg += "Archive extracted to $unzipPath."
            }
            
            $Global:DiagMsg += "Installing $appName silently... (Process: $processToRun Args: $installArgs)"
            Start-Process -FilePath $processToRun -ArgumentList $installArgs -Wait -PassThru
            $Global:DiagMsg += "$appName installation process completed."
        }
        else {
            $Global:DiagMsg += "Error: Failed to download the installer."
        }
    }
}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
}
finally {
    # Clean up the downloaded installer file(s) and extracted folders if they exist
    if ($installerPath -and (Test-Path $installerPath)) {
        Remove-Item -Path $installerPath -Force -Recurse
        $Global:DiagMsg += "Cleanup: Removed path $installerPath."
    }
    if ($unzipPath -and (Test-Path $unzipPath)) {
        Remove-Item -Path $unzipPath -Force -Recurse
        $Global:DiagMsg += "Cleanup: Removed directory $unzipPath."
    }
}


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
#######################################################################
### Exit script with proper Datto diagnostic and API Results.
# Exit with writing diagnostic back to the ticket / remediation component log
write-DRMMDiag $Global:DiagMsg
Exit 0