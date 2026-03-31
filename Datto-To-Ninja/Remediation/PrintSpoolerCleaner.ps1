#
## Template for Remediation Components for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Remediate and Clear Print Spooler" # Quick and easy name of Script to help identify
$ScriptType = "Remediation" # Monitoring // Remediation

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

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
    foreach ($Message in $messages) { $Message + ' `' }
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

### GATHER DIAGNOSTIC INFORMATION ###
$Global:DiagMsg += "[DIAG] Gathering current printer and print job status..."
try {
    # Get and log printer status
    $printers = Get-Printer -ErrorAction Stop
    if ($printers) {
        $Global:DiagMsg += "--- Found Printers ---"
        $Global:DiagMsg += $printers | Select-Object Name, PortName, DriverName, PrinterStatus | Out-String
    }
    else {
        $Global:DiagMsg += " - No printers were found on this system."
    }

    # Get and log print jobs for all printers
    $Global:DiagMsg += "--- Current Print Jobs ---"
    $allJobs = Get-PrintJob -ErrorAction SilentlyContinue
    if ($allJobs) {
        $Global:DiagMsg += $allJobs | Select-Object PrinterName, DocumentName, TotalPages, SubmittingUser, Status | Out-String
    }
    else {
        $Global:DiagMsg += " - No active print jobs found in any queue."
    }
}
catch {
    $Global:DiagMsg += "[WARN] Could not retrieve full printer/job list. The Print Spooler service may already be stopped or malfunctioning. Error: $($_.Exception.Message)"
}


### PERFORM REMEDIATION ###
$Global:DiagMsg += "[REMEDIATION] Attempting to clear the print spooler queue."
$spoolerDirectory = "$env:SystemRoot\System32\spool\PRINTERS"

# A try/catch/finally block ensures that the service is always restarted.
try {
    $spoolerService = Get-Service -Name Spooler -ErrorAction Stop
    if ($spoolerService.Status -ne 'Stopped') {
        $Global:DiagMsg += " - Stopping the Print Spooler service..."
        Stop-Service -InputObject $spoolerService -Force -ErrorAction Stop
        $spoolerService.WaitForStatus('Stopped', (New-TimeSpan -Seconds 30))
        $Global:DiagMsg += " - Service stopped successfully."
    }
    else {
        $Global:DiagMsg += " - Print Spooler service was already stopped."
    }
     
    $Global:DiagMsg += " - Clearing job files from '$spoolerDirectory'..."
    $spoolerFiles = Get-ChildItem -Path $spoolerDirectory -Include *.shd, *.spl -Recurse -ErrorAction SilentlyContinue
    if ($spoolerFiles) {
        Remove-Item -Path $spoolerFiles.FullName -Force -ErrorAction Stop
        $Global:DiagMsg += " - Successfully cleared $($spoolerFiles.Count) file(s) from the queue."
    }
    else {
        $Global:DiagMsg += " - No spooler files (*.shd, *.spl) found to clear."
    }
}
catch {
    $Global:DiagMsg += "[ERROR] An error occurred during the process: $($_.Exception.Message)"
}
finally {
    $Global:DiagMsg += " - Ensuring the Print Spooler service is running..."
    Start-Service -Name Spooler -ErrorAction SilentlyContinue
    $finalStatus = (Get-Service -Name Spooler).Status
    $Global:DiagMsg += " - Print Spooler service start attempt finished. Final status: $finalStatus"
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