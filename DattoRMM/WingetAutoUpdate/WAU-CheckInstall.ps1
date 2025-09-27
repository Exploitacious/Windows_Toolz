# 
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Install and Run WinGet AutoUpdate" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
#$env:APIEndpoint = "https://prod-36.westus.logic.azure.com:443/workflows/6c032a1ca84045b9a7a1436864ecf696/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=c-dVa333HMzhWli_Fp_4IIAqaJOMwFjP2y5Zfv4j_zA"
#$env:usrUDF = 14 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

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



function Get-InstalledSoftware {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $registryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $installed = @()

    foreach ($path in $registryPaths) {
        try {
            $entries = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            foreach ($entry in $entries) {
                $matchDisplayName = $entry.DisplayName -and $entry.DisplayName -like "*$Name*"
                $matchPublisher = $entry.Publisher -and $entry.Publisher -like "*$Name*"

                if ($matchDisplayName -or $matchPublisher) {
                    $installed += [PSCustomObject]@{
                        Name         = $entry.DisplayName
                        Version      = $entry.DisplayVersion
                        Publisher    = $entry.Publisher
                        InstallDate  = $entry.InstallDate
                        RegistryPath = $path
                    }
                }
            }
        }
        catch {
            # Skip broken registry entries
        }
    }

    # Filter out any nulls, just in case
    $installed = $installed | Where-Object { $_ -ne $null }

    if (-not $installed) {
        $Global:DiagMsg += "No software found matching name '$Name'."
    }

    return $installed
}

function InstallWingetAutoUpdate {
    ### Download and install the latest Winget Auto Update
    # Set WAU Variables
    $WAUPath = "C:\Temp\Romanitho-WindowsAutoUpdate"
    $repo = "Romanitho/Winget-AutoUpdate"
    $apiUrl = "https://api.github.com/repos/$repo/releases/latest"

    # Test and Create Path
    if ((Test-Path -Path $WAUPath)) {
        Remove-Item $WAUPath -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $WAUPath
    }
    else {
        New-Item -ItemType Directory -Path $WAUPath
    }

    # GitHub blocks requests without a User-Agent header
    $response = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "AnythingReally" }

    # Find the .msi asset (you can filter differently if needed)
    $asset = $response.assets | Where-Object { $_.name -like "*.msi" } | Select-Object -First 1

    if ($null -ne $asset) {
        $downloadUrl = $asset.browser_download_url
        $Global:DiagMsg += "Latest MSI URL: $downloadUrl"

        # Optional: Download it
        Invoke-WebRequest -Uri $downloadUrl -OutFile "$WAUPath\WAU_latest.msi"
    }
    else {
        $Global:DiagMsg += "No MSI asset found in the latest release."
        Write-Error "No MSI asset found in the latest release."
    }

    ### Execute Winget Auto Update Silent Installation
    & "$WAUPath\WAU_latest.msi" /qn RUN_WAU=YES STARTMENUSHORTCUT=1 NOTIFICATIONLEVEL=None
    $Global:DiagMsg += "Winget-AutoUpdate installed successfully."
    $Global:DiagMsg += "Check Update Logs located at: C:\Program Files\Winget-AutoUpdate\logs"
}

if (-not (Get-InstalledSoftware -Name "Winget-AutoUpdate")) {
    InstallWingetAutoUpdate
}
else {
    $Global:DiagMsg += "Winget-AutoUpdate is already installed. No action needed."
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