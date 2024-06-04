# Dell Open Manage Server Hardware Utility
# Processor Monitor Script
# Created by Alex Ivantsov @Exploitacious

# Set Continuous Diagnostic Log. Use $Global:DiagMsg += to append to this running log.
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

    # Use a simple approach to find processor sensor status information
    $RACProcessorSensors = @()
    $lines = $output -split "`n"
    $inProcessorSection = $false

    foreach ($line in $lines) {
        if ($line -match "Sensor Type : PROCESSOR") {
            $inProcessorSection = $true
            continue
        }
        if ($inProcessorSection -and $line -match "Sensor Type :") {
            $inProcessorSection = $false
        }
        if ($inProcessorSection) {
            if ($line -match "\s*(CPU\d+ Status)\s+(Ok|Warning|Critical)\s+(Presence_Detected|Absent|Degraded)") {
                $parts = $line -split "\s{2,}"
                $RACProcessorSensors += [PSCustomObject]@{
                    Name   = $parts[0].Trim() -replace " Status", ""
                    Status = $parts[1].Trim()
                    State  = $parts[2].Trim()
                }
            }
        }
    }
    
    foreach ($sensor in $RACProcessorSensors) {
        $Global:DiagMsg += "$($sensor.Name) : $($sensor.Status)"
        
        if ($sensor.Status -ne "Ok") {
            $Global:AlertMsg += " Processor Sensor Status is NOT OK: $($sensor.Name)"
            $Global:DiagMsg += "Processor Sensor Status is NOT OK: $($sensor.Name)"
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
