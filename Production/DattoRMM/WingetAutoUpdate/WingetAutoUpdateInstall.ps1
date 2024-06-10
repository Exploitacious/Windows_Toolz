# Winget Auto Update and App Compliance
# Created by Alex Ivantsov @Exploitacious

function write-DRMMDiag ($messages) {
    Write-Host '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
}
function write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "STATUS=$message"
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
$Global:AlertHealthy = "WinGetAutoUpdate | Initiated $Date" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
### $APIEndpoint = "https://prod-36.westus.logic.azure.com:443/workflows/6c032a1ca84045b9a7a1436864ecf696/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=c-dVa333HMzhWli_Fp_4IIAqaJOMwFjP2y5Zfv4j_zA"
$Global:DiagMsg += "Script UID: " + $ScriptUID
# Verify/Elevate Admin Session. Comment out if not needed.
#### if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }
##################################
##################################
######## Start of Script #########


# Apps to Install Requires WinGet to be installed, or the switch enabled for automatically installing WinGet
$Global:DiagMsg += "Installing Winget, Winget Auto-Update, and required apps..."
Start-Sleep 3

# Verify/Elevate Admin Session.
# if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

$InstallPrograms = @(
    "Company Portal"
    "9N0DX20HK701" # Windows Terminal
    "9NRX63209R7B" # Outlook (NEW) for Windows
    "Adobe.Acrobat.Reader.64-bit"
    "7zip.7zip"
    "Zoom.Zoom"
    "Microsoft.Teams" # Microsoft Teams (New)
)

# Install WinGet, Update Apps, and Install Specified Apps

### Refresh and Download the latest Winget Auto Update
$WAUPath = "C:\Temp\WAU_Latest"
$WAUurl = "https://github.com/Romanitho/Winget-AutoUpdate/zipball/master/"
$WAUFile = "$WAUPath\WAU_latest.zip"
# Refresh the directory to allow download and install of latest version
if ((Test-Path -Path $WAUPath)) {
    Remove-Item $WAUPath -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $WAUPath
}
else {
    New-Item -ItemType Directory -Path $WAUPath
}

# Download Winget AutoUpdate
Invoke-WebRequest -Uri $WAUurl -o $WAUFile
Expand-Archive $WAUFile -DestinationPath $WAUPath -Force
Remove-Item $WAUFile -Force

# Move Items around to remove extra directories
Move-Item "$WAUPath\Romanitho*\*" $WAUPath
Remove-Item "$WAUPath\Romanitho*\"

### Execute Winget + Auto Update Installation
# & "$WAUPath\Sources\WAU\Winget-AutoUpdate-Install.ps1" -Silent -InstallUserContext -NotificationLevel None -UpdatesAtLogon -UpdatesInterval Daily -DoNotUpdate

$Global:DiagMsg += "Winget Auto-Update Installed."

# Verify Winget
$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
if ($ResolveWingetPath) {
    $WingetPath = $ResolveWingetPath[-1].Path
}
else {
    $Global:DiagMsg += "! ERROR: Unable to locate WinGet installation. Please install WinGet first."
    write-host "! ERROR: Unable to locate WinGet installation. Please install WinGet first."
    exit 1
}

# Install Required Apps
$Global:DiagMsg += "Installing Applications..."
Foreach ($NewApp in $InstallPrograms) {

    Write-Host
    Write-Host "Searching for $NewApp"
    $Global:DiagMsg += "Searching for " + $NewApp

    $listApp = winget list --exact -q $NewApp --accept-source-agreements --accept-package-agreements

    if (![String]::Join("", $listApp).Contains($NewApp)) {
        Write-Host "Verifying $NewApp"
        $Global:DiagMsg += "Verifying and Updating " + $NewApp

        start-process "$ResolveWingetPath\winget.exe" -argumentlist "upgrade $NewApp" -Wait -NoNewWindow
        #winget install -e -h --accept-source-agreements --accept-package-agreements --id $NewApp 
    }
    else {
        Write-Host "$NewApp already installed."
        $Global:DiagMsg += $NewApp + " - already installed."
    }
}

Write-Host "Finished! Press Enter to exit"
$Global:DiagMsg += "Finished! Press Enter to exit"
Write-Host
Write-Host

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