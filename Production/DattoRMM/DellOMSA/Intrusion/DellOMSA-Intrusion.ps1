# Dell Open Manage Server Hardware Utility
# Intrusion Monitor Script
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

    # Use a simple approach to find intrusion status information
    $RACIntrusions = @()
    $lines = $output -split "`n"
    $inIntrusionSection = $false

    foreach ($line in $lines) {
        if ($line -match "Sensor Type : INTRUSION") {
            $inIntrusionSection = $true
            continue
        }
        if ($inIntrusionSection -and $line -match "Sensor Type :") {
            $inIntrusionSection = $false
        }
        if ($inIntrusionSection) {
            if ($line -match "System Board Intrusion") {
                $parts = $line -split "\s{2,}"
                $RACIntrusions += [PSCustomObject]@{
                    Name      = "System Board Intrusion"
                    Intrusion = $parts[1].Trim() # Assuming Intrusion is the second element
                    Status    = $parts[2].Trim() # Assuming Status is the third element
                }
            }
        }
    }
    
    foreach ($intrusion in $RACIntrusions) {
        $Global:DiagMsg += $intrusion.Name + " : " + $intrusion.Intrusion + " : " + $intrusion.Status
        
        if ($intrusion.Intrusion -ne "Closed" -or $intrusion.Status -ne "Power ON") {
            $Global:AlertMsg += "System Board Intrusion Alert"
            $Global:DiagMsg += $intrusion.Name + " is NOT OK "
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
