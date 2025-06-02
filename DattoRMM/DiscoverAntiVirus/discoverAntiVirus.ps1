#
## Template for Scripting Component Monitors for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Check for Primary AV or EDR" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation
$Date = get-date -Format "MM/dd/yyy hh:mm tt"

# What to Write if Alert is Healthy
$Global:AlertHealthy = " | Last Checked $Date" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
# There is also another palce to put NO ALERT Healthy messages down below, to try and capture more script info.

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
$env:usrUDF = 12 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

<#
This is a Datto RMM Monitoring Script, used to deliver a result such as "Healthy" or "Not Healthy", in order to trigger the creation of tickets, etc.

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
function write-DRMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:AlertMsg = @() # Combined Alert message. If left blank, will not trigger Alert status. Use " $Global:AlertMsg += " to append messages to be alerted on in Datto.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########




function Get-ProtectionSummary {

    # --- pull data ----------------------------------------------------------
    $av = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct |
    Select-Object @{n = 'Name'; e = { $_.displayName } },
    @{n = 'StateHex'; e = { ('{0:X6}' -f $_.productState) } }

    $senseSvc = Get-Service -Name Sense -ErrorAction SilentlyContinue
    $mdeOn = $false
    
    if ($senseSvc -and $senseSvc.Status -eq 'Running') { $mdeOn = $true }
    else {
        $key = 'HKLM:\SOFTWARE\Microsoft\Sense'
        if (Test-Path $key) {
            $state = (Get-ItemProperty $key -Name OnboardingState -ErrorAction SilentlyContinue).OnboardingState
            if ($state -eq 3) { $mdeOn = $true }
        }
    }

    $primary = $av | Select-Object -First 1
    switch ($true) {
        { $mdeOn } { $level = 'Microsoft Defender for Endpoint (full MDE)' ; break }
        { $primary.Name -like '*Defender*' } { $level = 'Default Windows Defender (non MDE)'            ; break }
        default { $level = "Third-party AV - $($primary.Name)" }
    }

    # --- build result object -----------------------------------------------
    $summary = [PSCustomObject]@{
        Level            = $level
        SenseService     = $senseSvc.Status        # Null if service absent
        SenseOnboarding  = $(if ($mdeOn) { 'Onboarded' } else { 'No' })
        SecurityCenterAV = ($av | ForEach-Object { "$($_.Name) [0x$($_.StateHex)]" }) -join '; '
    }

    # --- splat object properties into variables in the *caller’s* scope ----
    foreach ($prop in $summary.PSObject.Properties) {
        Set-Variable -Name $prop.Name -Value $prop.Value -Scope 1   # 1 = parent scope
    }
}

# --- Launch it ---------------------------------------------------------------
Get-ProtectionSummary   # emits the table and seeds the variables to be used...

# --- Report to RMM ---

Write-Host

$Global:DiagMsg += "Windows AV 'Sense' Security Service: $SenseService"
$Global:DiagMsg += "Security Center AV Found: $SecurityCenterAV"
$Global:DiagMsg += "Microsoft Defender for Endpoint 'Sense' Tenant: $SenseOnboarding"

if ($level -eq 'Microsoft Defender for Endpoint (full MDE)') {
    $Global:DiagMsg += "Results Found: Found active MDE with Sense fully onboarded."
    $Global:varUDFString += "$Level | Last Checked $Date"
}
else {
    $Global:AlertMsg = "Results Found: $Level"
    $Global:varUDFString += "$Level | Last Checked $Date"
}



######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {    
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF :" + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Exit script with proper Datto alerting, diagnostic and API Results.
#######################################################################
if ($Global:AlertMsg) {
    # If your AlertMsg has value, this is how it will get reported.
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-DRMMAlert $Global:AlertMsg
    write-DRMMDiag $Global:DiagMsg

    # Exit 1 means DISPLAY ALERT
    Exit 1
}
else {
    # If the AlertMsg variable is blank (nothing was added), the script will report healthy status with whatever was defined above.
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"

    ##### You may alter the NO ALERT Exit Message #####
    write-DRMMAlert "Fully Onboarded MDE Found $Global:AlertHealthy"
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}