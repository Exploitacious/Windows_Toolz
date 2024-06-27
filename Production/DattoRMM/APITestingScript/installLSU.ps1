# 
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Install Lenovo System Update" # Quick and easy name of Script to help identify
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

Function GenRANDString ([Int]$CharLength, [Char[]]$CharSets = "ULNS") {
    $Chars = @()
    $TokenSet = @()
    If (!$TokenSets) {
        $Global:TokenSets = @{
            U = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                # Upper case
            L = [Char[]]'abcdefghijklmnopqrstuvwxyz'                                # Lower case
            N = [Char[]]'0123456789'                                                # Numerals
            S = [Char[]]'!"#%&()*+,-./:;<=>?@[\]^_{}~'                             # Symbols
        }
    }
    $CharSets | ForEach-Object {
        $Tokens = $TokenSets."$_" | ForEach-Object { If ($Exclude -cNotContains $_) { $_ } }
        If ($Tokens) {
            $TokensSet += $Tokens
            If ($_ -cle [Char]"Z") { $Chars += $Tokens | Get-Random }             #Character sets defined in upper case are mandatory
        }
    }
    While ($Chars.Count -lt $CharLength) { $Chars += $TokensSet | Get-Random }
    ($Chars | Sort-Object { Get-Random }) -Join ""                                #Mix the (mandatory) characters and output string
};
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 15 UN # Generate random UID for script
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########

function Check-SoftwareInstall {
    param (
        [string]$SoftwareName,
        [string]$Method
    )

    $varCounter = 0

    $Detection = Get-ChildItem ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE") | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName, $_.BrandName -match "$SoftwareName" } | Select-Object

    if ($Null -ne $Detection) {
        $varCounter ++
    }
    else {
        $varCounter = 0
    }

    if ($Method -eq 'EQ') {
        return $varCounter -ge 1
    }
    elseif ($Method -eq 'NE') {
        return $varCounter -lt 1
    }
    else {
        throw "Invalid method. Please use 'EQ' or 'NE'."
    }
}

$System = Get-WmiObject WIN32_ComputerSystem  

$Global:DiagMsg += "Checking Manufacturer..."
if ($System.Manufacturer -match "Lenovo") {
    $Global:DiagMsg += "Computer reported Manufacturer as " + $System.Manufacturer + " " + $System.Model
    
    # Params:
    $softwareName = "Lenovo System Update"
    $method = 'EQ'
    $Global:DiagMsg += "Checking for Software Install..."
    $SoftwareResult = Check-SoftwareInstall -SoftwareName $softwareName -Method $method

    if (!$SoftwareResult) {
        $Global:DiagMsg += "Starting Installation and Updates."
        $Global:DiagMsg += "Setting up directories and downloading items for deployment..."
    
        New-Item -Path "c:\" -Name "Temp" -ItemType "directory" -Force
        Invoke-Webrequest -Uri https://download.lenovo.com/pccbbs/thinkvantage_en/system_update_5.07.0131.exe -OutFile 'C:\Temp\LenovoUpdate.exe'
    
        $Global:DiagMsg += "Installing System Update..."
        C:\Temp\LenovoUpdate.exe /VERYSILENT /NORESTART

        $Global:DiagMsg += "Lenovo System Update Installed."
    }
    else {
        $Global:DiagMsg += "Lenovo System Update is already Installed."
    }
}
else {
    $Global:DiagMsg += "Computer reported as " + $System.Manufacturer + " " + $System.Model
    $Global:DiagMsg += "Skipping all Lenovo Installation and updates."
}

$Global:DiagMsg += "Completed all steps."



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