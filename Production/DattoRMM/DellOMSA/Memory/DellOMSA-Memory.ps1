# Dell Open Manage Server Hardware Utility
# Memory Monitor Script
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

    # Use a simple approach to find memory status information
    $RACMemoryModules = @()
    $lines = $output -split "`n"
    $inMemorySection = $false

    foreach ($line in $lines) {
        if ($line -match "Sensor Type : MEMORY") {
            $inMemorySection = $true
            continue
        }
        if ($inMemorySection -and $line -match "Sensor Type :") {
            $inMemorySection = $false
        }
        if ($inMemorySection) {
            if ($line -match "\s*(DIMM \w+)\s+(Ok|Warning|Critical)\s+(Presence_Detected)") {
                $parts = $line -split "\s{2,}"
                $RACMemoryModules += [PSCustomObject]@{
                    SensorName = $parts[0].Trim()
                    Status     = $parts[1].Trim()
                    State      = $parts[2].Trim()
                }
            }
        }
    }

    # Count the total number of DIMMs in use
    $totalDIMMs = $RACMemoryModules.Count
    $Global:DiagMsg += "Total DIMMs in use: $totalDIMMs"
    
    foreach ($module in $RACMemoryModules) {
        if ($module.State -eq "Presence_Detected" -and $module.Status -eq "Ok") {
            $Global:DiagMsg += "$($module.SensorName) : Status $($module.Status)"
        }
        elseif ($module.State -eq "Presence_Detected" -and $module.Status -ne "Ok") {
            $Global:AlertMsg += " Memory Module Status is NOT OK: $($module.SensorName)"
            $Global:DiagMsg += "Memory Module Status is NOT OK: $($module.SensorName)"
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
