#
## Template for Scripting Component Monitors for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Active Directory Audit" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation
$Date = get-date -Format "MM/dd/yyy hh:mm tt"

# What to Write if Alert is Healthy
$Global:AlertHealthy = " AD Audit Completed Successfully | Last Checked $Date" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
# There is another palce to put NO ALERT Healthy messages down below, to try and capture more script info.

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
$env:usrUDF = 16 # Which UDF to write to. Leave blank to Skip UDF writing.
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

try {
    # --- 1. Preparation ---
    $Global:DiagMsg += "Starting Modern Active Directory Audit..."
    
    # The number of days to look back to consider an object "active".
    [int]$LastLogonAgeDaysLimit = 30
    # The directory where all text file reports will be saved.
    [string]$OutputDirectory = "C:\Temp\ADSPLA"
    
    # Attempt to load the ActiveDirectory module.
    Import-Module ActiveDirectory -ErrorAction Stop
    $Global:DiagMsg += "Successfully loaded the ActiveDirectory module."

    # Create the output directory if it doesn't exist.
    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        $Global:DiagMsg += "Created output directory: $OutputDirectory"
    }
    
    $activityThreshold = (Get-Date).AddDays(-$LastLogonAgeDaysLimit)
    $reportTimestamp = Get-Date -Format "yyyy-MM-dd_HHmm"

    # --- 2. Data Collection ---
    $Global:DiagMsg += "Auditing users..."
    $allUsers = Get-ADUser -Filter * -Properties Created, LastLogonDate
    $activeUsers = $allUsers | Where-Object { $_.LastLogonDate -and $_.LastLogonDate -ge $activityThreshold }

    $Global:DiagMsg += "Auditing computers..."
    $allComputers = Get-ADComputer -Filter * -Properties Created, LastLogonDate
    $activeComputers = $allComputers | Where-Object { $_.LastLogonDate -and $_.LastLogonDate -ge $activityThreshold }

    $Global:DiagMsg += "Auditing domain infrastructure..."
    $domain = Get-ADDomain
    $forest = Get-ADForest
    $domainControllers = Get-ADDomainController -Filter *

    # --- 3. UDF & Summary String Generation ---
    # Construct the string for the UDF.
    $Global:varUDFString = "PDC: $($domain.PDCEmulator) | Active Users: $($activeUsers.Count) | Active Comps: $($activeComputers.Count)"
    
    # Construct the detailed summary for the diagnostic log.
    $summary = @"

--------------------------------------------------
          Active Directory Summary
--------------------------------------------------
Domain Information
  Domain Name:           $($domain.Name)
  Primary DC FQDN:       $($domain.PDCEmulator)
  Domain Level:          $($domain.DomainMode)
  Forest Level:          $($forest.ForestMode)

Object Counts
  Domain Controllers:    $($domainControllers.Count)
  Total User Accounts:   $($allUsers.Count) (Active: $($activeUsers.Count))
  Total Computer Accounts: $($allComputers.Count) (Active: $($activeComputers.Count))
--------------------------------------------------
"@
    # Add the summary to the diagnostic log.
    $Global:DiagMsg += $summary
    
    # --- 4. Report File Generation ---
    $Global:DiagMsg += "Generating reports to $OutputDirectory..."

    # Report 1: Active Users
    $userReportPath = Join-Path -Path $OutputDirectory -ChildPath "Active_Users_Report_$($reportTimestamp).txt"
    $userReportHeader = "Active User Report`nGenerated: $(Get-Date)`n`nTotal Active Users Found (Last $LastLogonAgeDaysLimit Days): $($activeUsers.Count)`n`n"
    $userTable = $activeUsers | Sort-Object Name | Select-Object Name, Created, LastLogonDate | Format-Table -AutoSize | Out-String
    ($userReportHeader + $userTable) | Set-Content -Path $userReportPath
    $Global:DiagMsg += "User report saved to: $userReportPath"

    # Report 2: Active Computers
    $computerReportPath = Join-Path -Path $OutputDirectory -ChildPath "Active_Computers_Report_$($reportTimestamp).txt"
    $computerReportHeader = "Active Computer Report`nGenerated: $(Get-Date)`n`nTotal Active Computers Found (Last $LastLogonAgeDaysLimit Days): $($activeComputers.Count)`n`n"
    $computerTable = $activeComputers | Sort-Object Name | Select-Object Name, Created, LastLogonDate | Format-Table -AutoSize | Out-String
    ($computerReportHeader + $computerTable) | Set-Content -Path $computerReportPath
    $Global:DiagMsg += "Computer report saved to: $computerReportPath"

    # Report 3: Domain Summary
    $domainReportPath = Join-Path -Path $OutputDirectory -ChildPath "Domain_Summary_Report_$($reportTimestamp).txt"
    $dcList = ($domainControllers.Name | Sort-Object | ForEach-Object { "  - $_" }) -join "`r`n"
    $domainReport = @"
# ==========================================================
#  Active Directory Domain Summary
#  Generated: $(Get-Date)
# ==========================================================

Domain Name:             $($domain.Name)
PDC Emulator Role Owner: $($domain.PDCEmulator)
Domain Functional Level: $($domain.DomainMode)
Forest Functional Level: $($forest.ForestMode)

Domain Controllers ($($domainControllers.Count) Found)
--------------------------------------------------
$($dcList)
"@
    $domainReport | Set-Content -Path $domainReportPath
    $Global:DiagMsg += "Domain report saved to: $domainReportPath"
    $Global:DiagMsg += "Audit complete."
}
catch {
    # This block will catch any critical errors, such as the AD module not being found.
    $errorMessage = "A critical error occurred: $($_.Exception.Message)"
    $Global:DiagMsg += $errorMessage
    $Global:AlertMsg += "AD Audit Failed: $($_.Exception.Message)"
}


######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {      
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString 
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
    # This provides a clean, informative status in the Datto RMM monitor view.
    write-DRMMAlert "Healthy | $($Global:varUDFString)"
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}