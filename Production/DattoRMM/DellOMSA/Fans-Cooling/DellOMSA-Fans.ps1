# Dell Open Manage Server Hardware Utility
# Fan Monitor Script
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

    # Use a regex pattern to find fan status information
    $RACFans = @()
    $lines = $output -split "`n"
    $inFanSection = $false

    foreach ($line in $lines) {
        if ($line -match "Sensor Type : FAN") {
            $inFanSection = $true
            continue
        }
        if ($inFanSection -and $line -match "Sensor Type :") {
            $inFanSection = $false
        }
        if ($inFanSection -and $line -match "^\s*(System Board Fan\d+[A-Z])\s+(\w+)\s+(\d+RPM)\s*(.*)$") {
            $RACFans += [PSCustomObject]@{
                Name    = $matches[1].Trim()
                Status  = $matches[2].Trim()
                Reading = $matches[3].Trim()
            }
        }
    }
    
    foreach ($fan in $RACFans) {
        $Global:DiagMsg += $fan.Name + " : " + $fan.Status + " : " + $fan.Reading
        
        if ($fan.Status -ne "Ok") {
            $Global:AlertMsg += "Fan " + $fan.Name + " NOT OK"
            $Global:DiagMsg += "Fan Status is NOT OK: " + $fan.Name
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
