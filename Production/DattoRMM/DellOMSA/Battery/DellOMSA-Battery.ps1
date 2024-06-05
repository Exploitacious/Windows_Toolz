# Dell Open Manage Server Hardware Utility
# Battery Monitor Script
# Created by Alex Ivantsov @Exploitacious

#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}
function write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "$message"
    Write-Host '<-End Result->'
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
# Extra Info and Variables
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:AlertMsg = @() # Combined Alert message. If left blank, will not trigger Alert status. Use " $Global:AlertMsg += " to append messages to be alerted on in Datto.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 15 UN # Generate random UID for script
$Date = get-date -Format "MM/dd/yyy hh:mm tt"
$System = Get-WmiObject WIN32_ComputerSystem  
#$OS = Get-CimInstance WIN32_OperatingSystem 
#$Core = Get-WmiObject win32_processor 
#$GPU = Get-WmiObject WIN32_VideoController  
#$Disk = get-WmiObject win32_logicaldisk
$Global:AlertHealthy = "$Global:totalBatts Healhty Batteries | Last Checked $Date" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
### $APIEndpoint = "https://prod-36.westus.logic.azure.com:443/workflows/6c032a1ca84045b9a7a1436864ecf696/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=c-dVa333HMzhWli_Fp_4IIAqaJOMwFjP2y5Zfv4j_zA"
$Global:DiagMsg += "Script UID: " + $ScriptUID
# Verify/Elevate Admin Session. Comment out if not needed.
#### if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }
##################################
##################################
######## Start of Script #########

# Initialize output variable
$output = ""

try {
    $output = racadm getsensorinfo | Out-String
    $Global:DiagMsg += "racadm command executed successfully."
}
catch {
    $Global:DiagMsg += "Error running racadm command: $_"
    $Global:AlertMsg += "Error Occurred - Scrutinize Diagnostic Log"
    $Global:DiagMsg += "Attempting to Restart iDRAC... if this continues happening, please check the server's iDRAC."
    racadm racreset
}

if ($output -eq "") {
    $Global:AlertMsg += "Error Occurred - Scrutinize Diagnostic Log"
    $Global:DiagMsg += "No output from racadm command ; or RACADM has failed."
    $Global:DiagMsg += "Attempting to Restart iDRAC... if this continues happening, please check the server's iDRAC."
    racadm racreset
}
elseif ($output -match "ERROR") {
    $Global:DiagMsg += "RACADM returned an error: $output"
    $Global:AlertMsg += "Error Occurred - Scrutinize Diagnostic Log"
    $Global:DiagMsg += "Attempting to Restart iDRAC... if this continues happening, please check the server's iDRAC."
    racadm racreset
}
else {
    $Global:DiagMsg += "Parsing racadm output..."

    # Use a simple approach to find battery status information
    $RACBatteries = @()
    $lines = $output -split "`n"
    $inBatterySection = $false

    foreach ($line in $lines) {
        if ($line -match "Sensor Type : BATTERY") {
            $inBatterySection = $true
            continue
        }
        if ($inBatterySection -and $line -match "Sensor Type :") {
            $inBatterySection = $false
        }
        if ($inBatterySection) {
            if ($line -match "System Board CMOS Battery") {
                $parts = $line -split "\s{2,}"
                $RACBatteries += [PSCustomObject]@{
                    Name   = "System Board CMOS Battery"
                    Status = $parts[1].Trim() # Assuming status is the second element after splitting by two or more spaces
                }
            }
            elseif ($line -match "PERC\d+ ROMB Battery") {
                $parts = $line -split "\s{2,}"
                $RACBatteries += [PSCustomObject]@{
                    Name   = "PERC ROMB Battery"
                    Status = $parts[1].Trim() # Assuming status is the second element after splitting by two or more spaces
                }
            }
        }
    }

    # Count the total number of Batteries in use
    $Global:totalBatts = $RACBatteries.Count
    $Global:DiagMsg += "Total Batteries in use: $totalBatts"
    
    foreach ($battery in $RACBatteries) {
        $Global:DiagMsg += $battery.Name + " : " + $battery.Status
        
        if ($battery.Status -ne "Ok" -and $battery.Status -ne "Present") {
            $Global:AlertMsg += $battery.Name + " Reporting NOT OK"
            $Global:DiagMsg += "Battery Status is NOT OK: " + $battery.Name
        }
    }
}

######## End of Script #########
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
else {
    # Write to diaglog
    # $Global:DiagMsg += " - not writing to UDF"
}
### Info sent to into JSON POST to API Endpoint (Optional)
$InfoHashTable = @{
    'CS_ACCOUNT_UID'  = $env:CS_ACCOUNT_UID
    'CS_PROFILE_DESC' = $env:CS_PROFILE_DESC
    'CS_PROFILE_NAME' = $env:CS_PROFILE_NAME
    'CS_PROFILE_UID'  = $env:CS_PROFILE_UID
    'Script_Diag'     = $Global:DiagMsg
    'Script_UID'      = $ScriptUID
    'Date_Time'       = $Date
    'Comp_Model'      = $System.Model 
    'Comp_Make'       = $System.Manufacturer 
    'Comp_Hostname'   = $System.Name
    'Comp_LastUser'   = $System.UserName
    ########################################
    #'CS_CC_HOST'            = $env:CS_CC_HOST
    #'CS_CC_PORT1'           = $env:CS_CC_PORT1
    #'CS_CSM_ADDRESS'        = $env:CS_CSM_ADDRESS
    #'CS_DOMAIN'             = $env:CS_DOMAIN
    #'CS_PROFILE_PROXY_TYPE' = $env:CS_PROFILE_PROXY_TYPE
    #'CS_WS_ADDRESS'         = $env:CS_WS_ADDRESS
    #'Local_Admin_PW'        = $env:UDF_1
    #'Bitlocker_TPMStatus'   = $env:UDF_2
    #'Windows_Activation'    = $env:UDF_3
    #'DRMM_Agent_Health'     = $env:UDF_4
    #'Patch_Policy_Status'   = $env:UDF_5
    #'WU_Service_Health'     = $env:UDF_6
    #'Ext_WU_Details'        = $env:UDF_7
    #'Azure_AD_Status'       = $env:UDF_8
    #'Windows_Keys_Found'    = $env:UDF_9
    #'Office_Keys_Found'     = $env:UDF_10
    #'Server_Roles'          = $env:UDF_11
    #'Log4J_Detection'       = $env:UDF_12
    #'TL_ComputerID'         = $env:UDF_13
    #'Local_Admins_Present'  = $env:UDF_14
    #'UDF_30'                = $env:UDF_30
    #'Comp_CPU_Cores'        = $Core.NumberOfCores 
    #'Comp_CPU_Model'        = $Core.Caption 
    #'Comp_Ram'              = $System.TotalPhysicalMemory 
    #'Comp_GPU'              = $GPU.Caption 
    #'Comp_OSD'              = $OS.InstallDate 
    #'Comp_OS'               = $OS.Caption 
}
### Exit script with proper Datto alerting, diagnostic and API Results.
if ($Global:AlertMsg) {
    # Add Script Result and POST to API if an Endpoint is Provided
    if ($null -ne $APIEndpoint) {
        $Global:DiagMsg += " - Sending Results to API"
        $InfoHashTable.add("Script_Result", "$Global:AlertMsg")
        Invoke-WebRequest -Uri $APIEndpoint -Method POST -Body ($InfoHashTable | ConvertTo-Json) -ContentType "application/json"
    }
    # If your AlertMsg has value, this is how it will get reported.
    write-DRMMAlert $Global:AlertMsg
    write-DRMMDiag $Global:DiagMsg

    # Exit 1 means DISPLAY ALERT
    Exit 1
}
else {
    # Add Script Result and POST to API if an Endpoint is Provided
    if ($null -ne $APIEndpoint) {
        $Global:DiagMsg += " - Sending Results to API"
        $InfoHashTable.add("Script_Result", "$Global:AlertHealthy")
        Invoke-WebRequest -Uri $APIEndpoint -Method POST -Body ($InfoHashTable | ConvertTo-Json) -ContentType "application/json"
    }
    # If the AlertMsg variable is blank (nothing was added), the script will report healthy status with whatever was defined above.
    write-DRMMAlert $Global:AlertHealthy
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}