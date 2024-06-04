# Dell Open Manage Server Hardware Utility
# Battery Monitor Script
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
    
    foreach ($battery in $RACBatteries) {
        $Global:DiagMsg += $battery.Name + " : " + $battery.Status
        
        if ($battery.Status -ne "Ok" -and $battery.Status -ne "Present") {
            $Global:AlertMsg += $battery.Name + " Reporting NOT OK"
            $Global:DiagMsg += "Battery Status is NOT OK: " + $battery.Name
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
