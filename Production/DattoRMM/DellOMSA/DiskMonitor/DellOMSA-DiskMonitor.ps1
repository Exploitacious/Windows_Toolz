# Dell Open Manage Server Hardware Utility
# Created by Dell and Implemented by Alex Ivantsov
# https://github.com/dell/OpenManage-PowerShell-Modules
# https://github.com/exploitacious/

# Set Continuous Diagnostic Log. Use $Global:DiagMsg +=  to append to this running log.
$Global:DiagMsg = @()
$Global:AlertMsg = @()

# DattoRMM Alert Functions
function write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    Write-Host '<-End Diagnostic->'
}
function write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "$message"
    Write-Host '<-End Result->'
}



$output = racadm raid get pdisks -o -p SerialNumber, Status | Out-String

[regex]$pattern = '\r?\n(\w.+)\r?\n\s{3,}\w+.+= (.+?)\r?\n\s{3,}\w+.+= (.+?)\s'

$RACDisks = $pattern.Matches($output) | ForEach-Object { , $_.groups[1..3].value | ForEach-Object {
        [PSCustomObject]@{
            DeviceID     = $_[0]
            SerialNumber = $_[1]
            Status       = $_[2]
        }
    }
}




foreach ($disk in $RACDisks) {
    $Global:DiagMsg += $disk.DeviceID + " Status:" + $disk.Status
    
    if ($disk.status -ne "Ok") {
        $Global:AlertMsg += " Disk Status is NOT OK " + $disk.deviceID
    }
}


#END


if ($Global:AlertMsg) {
    write-DRMMAlert $Global:AlertMsg# Dell Open Manage Server Hardware Utility
    # Disk Monitor Script
    # Created by Dell and Implemented by Alex Ivantsov
    # https://github.com/dell/OpenManage-PowerShell-Modules
    # https://github.com/exploitacious/
    
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
        $output = racadm raid get pdisks -o -p SerialNumber, Status | Out-String
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
    
        # Use a regex pattern to find disk status information
        [regex]$pattern = '\r?\n(\w.+)\r?\n\s{3,}\w+.+= (.+?)\r?\n\s{3,}\w+.+= (.+?)\s'
    
        $RACDisks = $pattern.Matches($output) | ForEach-Object {
            [PSCustomObject]@{
                DeviceID     = $_.Groups[1].Value.Trim()
                SerialNumber = $_.Groups[2].Value.Trim()
                Status       = $_.Groups[3].Value.Trim()
            }
        }
    
        foreach ($disk in $RACDisks) {
            $Global:DiagMsg += "$($disk.DeviceID.Split(':')[0]) : Status $($disk.Status) : S/N - $($disk.SerialNumber)"
            
            if ($disk.Status -ne "Ok") {
                $Global:AlertMsg += " Disk Status is NOT OK: " + $disk.DeviceID
                $Global:DiagMsg += "Disk Status is NOT OK: " + $disk.DeviceID
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
    
    write-DRMMDiag $Global:DiagMsg
    Exit 1
}
else {
    write-DRMMAlert "Healthy"
    write-DRMMDiag $Global:DiagMsg
    Exit 0
}
