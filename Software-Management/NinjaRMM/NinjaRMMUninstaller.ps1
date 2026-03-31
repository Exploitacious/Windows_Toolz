# Script Title: Uninstall Ninja RMM Agent (Self-Destruct) v2
# Description: identifying the uninstall string, creating a time-delayed background task to perform the removal, and exiting gracefully to allow logs to upload.

# Script Name and Type
$ScriptName = "Uninstall Ninja RMM Agent (Self-Destruct) v2"
$ScriptType = "Remediation" 
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
$TempDir = "C:\Temp"
$DestructScriptName = "NinjaSelfDestruct.ps1"
$LogFile = "$TempDir\NinjaUninstall.log"

## ORG-LEVEL EXPECTED VARIABLES ##
# None

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Uninstall sequence initiated. Agent will be removed in 60 seconds. | Last Checked $Date"

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
    $Global:DiagMsg += "Starting removal preparation..."

    # 1. Locate the Uninstall String in Registry
    $RegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $NinjaApp = Get-ItemProperty $RegPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*NinjaRMMAgent*" } | Select-Object -First 1

    if (-not $NinjaApp) {
        $Global:DiagMsg += "NinjaRMMAgent not found in registry. It may already be uninstalled."
        $Global:customFieldMessage = "Agent not found. Removal skipped. ($Date)"
        # Success state as the goal (no agent) is met
    }
    else {
        $Global:DiagMsg += "Found NinjaRMMAgent: $($NinjaApp.DisplayName)"
        $Global:DiagMsg += "Raw Uninstall String: $($NinjaApp.UninstallString)"

        # 2. Parse the Uninstall Command and Arguments
        $UninstallCommand = ""
        $Arguments = ""

        if ($NinjaApp.UninstallString -match "MsiExec.exe") {
            # MSI Logic
            if ($NinjaApp.UninstallString -match "\{.*\}") {
                $Guid = $Matches[0]
                $UninstallCommand = "MsiExec.exe"
                $Arguments = "/X $Guid /qn /norestart"
                $Global:DiagMsg += "Detected MSI Installer. GUID: $Guid"
            }
            else {
                throw "Detected MSI but could not parse GUID."
            }
        }
        else {
            # EXE/Custom Logic (Handles NinjaRMMAgent.exe and InnoSetup)
            
            # Robust parsing: Extract content inside quotes if present, otherwise take up to first space
            # The Ninja string is typically: "C:\...\NinjaRMMAgent.exe" -uninstall
            
            if ($NinjaApp.UninstallString -match '^"(.*?)".*') {
                # Matches: "path/to/exe" -args
                $UninstallCommand = $Matches[1]
                
                # Check if there are arguments after the quotes
                if ($NinjaApp.UninstallString.Length -gt ($Matches[1].Length + 2)) {
                    $ExistingArgs = $NinjaApp.UninstallString.Substring($Matches[1].Length + 2).Trim()
                }
                else {
                    $ExistingArgs = ""
                }
            }
            else {
                # No quotes, split by space (fallback)
                $Split = $NinjaApp.UninstallString -split " ", 2
                $UninstallCommand = $Split[0]
                if ($Split.Count -gt 1) { $ExistingArgs = $Split[1] } else { $ExistingArgs = "" }
            }

            # Ninja Specific Argument Logic
            if ($UninstallCommand -like "*NinjaRMMAgent.exe") {
                # Ensure we have the uninstall flag, add silent flags if supported/needed.
                # NinjaRMMAgent.exe -uninstall is standard. 
                if ($ExistingArgs -notmatch "-uninstall") {
                    $Arguments = "$ExistingArgs -uninstall"
                }
                else {
                    $Arguments = $ExistingArgs
                }
                # Force-add silent flag just in case
                $Arguments = "$Arguments -quiet" 
            }
            else {
                # Generic EXE fallback
                $Arguments = "$ExistingArgs /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /quiet"
            }
            
            $Global:DiagMsg += "Detected EXE Installer."
            $Global:DiagMsg += "Parsed Path: $UninstallCommand"
            $Global:DiagMsg += "Parsed Args: $Arguments"
        }

        # 3. Create the Detached Killer Script
        # Using Single Quotes (@') prevents variable expansion, so we can write PowerShell code safely.
        # We use -f format operator to inject our variables.
        
        if (-not (Test-Path $TempDir)) {
            New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        }

        $DestructScriptPath = Join-Path -Path $TempDir -ChildPath $DestructScriptName
        
        # Note: We escape the format placeholders {0} and {1} inside the script content logic 
        # by simply using them as arguments for the outer -f
        
        $ScriptTemplate = @'
Start-Sleep -Seconds 60
$LogFile = "{0}"
$Cmd = "{1}"
$Args = "{2}"

function Write-Log ($Text) {{
    $Date = Get-Date
    Add-Content -Path $LogFile -Value "[$Date] $Text"
}}

try {{
    Write-Log "Stopping NinjaRMMAgent Service..."
    Stop-Service -Name "NinjaRMMAgent" -Force -ErrorAction SilentlyContinue
    
    Write-Log "Executing Uninstall Command: $Cmd $Args"
    $Proc = Start-Process -FilePath $Cmd -ArgumentList $Args -Wait -Passthru -ErrorAction Stop
    
    Write-Log "Uninstallation Process Finished with Exit Code: $($Proc.ExitCode)"
}}
catch {{
    Write-Log "Error: $($_.Exception.Message)"
}}
'@
        
        # Inject the actual paths into the template
        # {0} = LogFile, {1} = UninstallCommand, {2} = Arguments
        $ScriptContent = $ScriptTemplate -f $LogFile, $UninstallCommand, $Arguments
        
        Set-Content -Path $DestructScriptPath -Value $ScriptContent
        $Global:DiagMsg += "Created delayed removal script at: $DestructScriptPath"

        # 4. Launch the Detached Process
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$DestructScriptPath`"" -WindowStyle Hidden
        
        $Global:DiagMsg += "Detached process launched. Countdown started (60s)."
        $Global:customFieldMessage = "Uninstall Scheduled. ($Date)"
    }
}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
    $Global:customFieldMessage = "Script failed with an error. ($Date)"
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