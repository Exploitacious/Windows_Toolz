# Script Title: Nodeware Agent Installation (Reliability Patch)
# Description: Downloads and installs the Nodeware agent using the provided Customer ID. Includes logic to ensure Ninja RMM CLI modules are imported correctly.

# Script Name and Type
$ScriptName = "Nodeware Agent Installation"
$ScriptType = "General"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ##
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# nodeWareCustomerID (Text): The unique Customer ID for silent installation.
# downloadUrl (Text): The download URL for the Nodeware MSI.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "Nodeware agent is installed and service is active. | Last Checked $Date"

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
    # 1. Ensure Ninja RMM Module is loaded
    if (-not (Get-Command "Ninja-Property-Set" -ErrorAction SilentlyContinue)) {
        $Global:DiagMsg += "Ninja-Property-Set not found. Attempting to import Ninja RMM module..."
        $NinjaModulePath = "$env:NINJARMMCLI"
        if (Test-Path $NinjaModulePath) {
            Import-Module $NinjaModulePath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            $Global:DiagMsg += "Module imported from $NinjaModulePath"
        }
        else {
            $Global:DiagMsg += "Warning: Ninja CLI path not found at $env:NINJARMMCLI. Falling back to env variables only."
        }
    }

    # 2. Retrieve Customer ID (Check env, then try Ninja-Property-Get)
    $custID = $env:nodeWareCustomerID
    if ([string]::IsNullOrWhiteSpace($custID)) {
        $Global:DiagMsg += "Customer ID not in environment. Attempting Ninja-Property-Get..."
        try { $custID = Ninja-Property-Get nodeWareCustomerID } catch { $Global:DiagMsg += "Failed to retrieve via Ninja-Property-Get." }
    }

    if ([string]::IsNullOrWhiteSpace($custID)) {
        throw "Required variable 'nodeWareCustomerID' is missing or empty."
    }
    $Global:DiagMsg += "Using Customer ID: $custID"

    # 3. Define Paths and Constants
    $url = if (-not [string]::IsNullOrEmpty($env:downloadUrl)) { $env:downloadUrl } else { 'https://downloads.nodeware.com/agent/windows/NodewareAgentSetup.msi' }
    $tempDir = [System.IO.Path]::Combine($env:TEMP, "NodewareInstallTemp")
    $msiPath = Join-Path $tempDir "NodewareAgentSetup.msi"
    $serviceName = "NodewareAgent"

    # 4. Check for existing installation
    if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
        $Global:DiagMsg += "Nodeware Agent service already exists. Skipping installation."
        $Global:customFieldMessage = "Nodeware agent already installed. ($Date)"
    }
    else {
        # 5. Create Temp Dir and Download
        if (-not (Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }
        
        $Global:DiagMsg += "Downloading MSI from $url"
        Invoke-WebRequest -Uri $url -OutFile $msiPath -UseBasicParsing
        
        if (Test-Path $msiPath) {
            $Global:DiagMsg += "Starting Silent Installation..."
            $ArgumentList = "/i `"$msiPath`" /q CUSTOMERID=$custID"
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $ArgumentList -Wait -PassThru
            
            # Verify Service Presence
            if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
                $Global:DiagMsg += "Installation successful. Service '$serviceName' is present."
                $Global:customFieldMessage = "Nodeware agent installed successfully. ($Date)"
            }
            else {
                $Global:AlertMsg = "Installation finished (Exit Code: $($process.ExitCode)) but service '$serviceName' not found. | $Date"
                $Global:customFieldMessage = "Installation failed (Service missing). ($Date)"
            }
        }
        else {
            throw "Failed to download MSI to $msiPath"
        }
    }
}
catch {
    $Global:DiagMsg += "Execution Error: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed. Check diagnostics. | $Date"
    $Global:customFieldMessage = "Script failed: $($_.Exception.Message | Select-Object -First 1) ($Date)"
}
finally {
    if (Test-Path $tempDir) {
        $Global:DiagMsg += "Cleaning up temporary files..."
        Remove-Item -Path $tempDir -Force -Recurse -ErrorAction SilentlyContinue
    }
}

######## End of Script ###########
##################################
##################################

# Write to Custom Field
if ($env:customFieldName) {
    try {
        Ninja-Property-Set -Name $env:customFieldName -Value $Global:customFieldMessage
    }
    catch {
        $Global:DiagMsg += "Critical: Could not write to Custom Field '$($env:customFieldName)'."
    }
}

if ($Global:AlertMsg) {
    write-RMMAlert $Global:AlertMsg
    write-RMMDiag $Global:DiagMsg
    Exit 1
}
else {
    write-RMMAlert $Global:AlertHealthy
    write-RMMDiag $Global:DiagMsg
    Exit 0
}