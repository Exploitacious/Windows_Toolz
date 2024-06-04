# Dell Open Manage Server Hardware Utility
# Power Supply Monitor Script
# Created by Alex Ivantsov @Exploitacious

# Set Continuous Diagnostic Log. Use $Global:DiagMsg +=  to append to this running log.
$Global:DiagMsg = @()
$Global:AlertMsg = @()

# DattoRMM Alert Functions
function write-DRMMDiag ($messages) {
    Write-Host '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    Write-Host '<-End Diagnostic->'
}
function write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "$message"
    Write-Host '<-End Result->'
}

# Initialize output variable
$output = ""

try {
    $output = racadm getsensorinfo | Out-String
    $Global:DiagMsg += "racadm command executed successfully."
}
catch {
    $Global:DiagMsg += "Error running racadm command: $_"
    $Global:AlertMsg += "Error Occurred - Scrutinize Diagnostic Log"
}

if ($output -eq "") {
    $Global:DiagMsg += "No output from racadm command."
    $Global:AlertMsg += "Error Occurred - Scrutinize Diagnostic Log"
}
elseif ($output -match "ERROR") {
    $Global:DiagMsg += "RACADM returned an error: $output"
    $Global:AlertMsg += "Error Occurred - Scrutinize Diagnostic Log"
}
else {
    $Global:DiagMsg += "Parsing racadm output..."

    # Use a regex pattern to find power supply status information
    $RACPowerSupplies = @()
    $lines = $output -split "`n"
    $inPowerSection = $false

    foreach ($line in $lines) {
        if ($line -match "Sensor Type : POWER") {
            $inPowerSection = $true
            continue
        }
        if ($inPowerSection -and $line -match "Sensor Type :") {
            $inPowerSection = $false
        }
        if ($inPowerSection -and $line -match "^\s*(PS\d+ Status)\s+(\w+)\s+(.*)$") {
            $RACPowerSupplies += [PSCustomObject]@{
                DeviceID = $matches[1]
                Status   = $matches[2]
            }
        }
    }

    foreach ($psu in $RACPowerSupplies) {
        $Global:DiagMsg += $psu.DeviceID.Split(" ")[0] + " Status: " + $psu.Status
        
        if ($psu.Status -ne "Present") {
            $Global:AlertMsg += "Power Supply " + $psu.DeviceID.Split(" ")[0] + " NOT OK"
            $Global:DiagMsg += "Power Supply Status is NOT OK: " + $psu.DeviceID.Split(" ")[0]
        }
    }
}

#END

if ($Global:AlertMsg) {
    write-DRMMAlert $Global:AlertMsg
    write-DRMMDiag $Global:DiagMsg
    Exit 1
}
else {
    write-DRMMAlert "Healthy"
    write-DRMMDiag $Global:DiagMsg
    Exit 0
}
