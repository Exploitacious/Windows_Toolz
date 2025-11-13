# Script Title: Monitor Active Network Connections (IP Watchlist)
# Description: Monitors active TCP connections for specific IP addresses, wildcards (e.g., 192.168.1.*), or IP ranges. Alerts if a match is found.

# Script Name and Type
$ScriptName = "Monitor Active Network Connections (IP Watchlist)"
$ScriptType = "Monitoring"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ##
# targetIPs (Text): Comma-separated list of IPs to watch for (e.g., "192.168.1.*, 10.0.0.1-10.0.0.5").
# customFieldName (Text): The name of the Text Custom Field to write the status to.

# Testing
# $env:targetIPs = "1.1.1.1"

# What to Write if Alert is Healthy
$Global:AlertHealthy = "No connections found to target IPs. | Last Checked $Date"

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

# Helper Function: Convert IP to Integer for Range Comparison
function Convert-IpToInt {
    param ([string]$IpAddress)
    try {
        $Bytes = [System.Net.IPAddress]::Parse($IpAddress).GetAddressBytes()
        if ([System.BitConverter]::IsLittleEndian) { [Array]::Reverse($Bytes) }
        return [System.BitConverter]::ToUInt32($Bytes, 0)
    }
    catch {
        return $null
    }
}

# Helper Function: Test if an IP matches our criteria
function Test-IsTargetIP {
    param (
        [string]$RemoteIP,
        [string[]]$Targets
    )

    foreach ($Target in $Targets) {
        $CleanTarget = $Target.Trim()
        
        # 1. Handle Wildcards (e.g., 192.168.1.*)
        if ($CleanTarget -like "*`**") {
            if ($RemoteIP -like $CleanTarget) { return $true }
        }
        # 2. Handle Ranges (e.g., 192.168.1.10-192.168.1.50)
        elseif ($CleanTarget -match "-") {
            $RangeParts = $CleanTarget -split "-"
            if ($RangeParts.Count -eq 2) {
                $StartIP = Convert-IpToInt -IpAddress $RangeParts[0].Trim()
                $EndIP = Convert-IpToInt -IpAddress $RangeParts[1].Trim()
                $CheckIP = Convert-IpToInt -IpAddress $RemoteIP

                if ($StartIP -ne $null -and $EndIP -ne $null -and $CheckIP -ne $null) {
                    if ($CheckIP -ge $StartIP -and $CheckIP -le $EndIP) { return $true }
                }
            }
        }
        # 3. Handle Exact Match
        else {
            if ($RemoteIP -eq $CleanTarget) { return $true }
        }
    }
    return $false
}

try {
    # Validate Input
    if (-not $env:targetIPs) {
        throw "Variable 'targetIPs' is empty. Please configure a list of IPs, ranges, or wildcards."
    }

    $Global:DiagMsg += "Parsing Target List: $($env:targetIPs)"
    $TargetList = $env:targetIPs -split ","

    $Global:DiagMsg += "Scanning active TCP connections..."
    
    # Get only Established or Listening connections (usually we care about Established for outbound monitoring)
    # Adjust State filter if you need to see 'TimeWait' or 'Listening' as well.
    $AllConnections = Get-NetTCPConnection -ErrorAction SilentlyContinue

    $DetectedConnections = @()

    foreach ($Conn in $AllConnections) {
        # Skip loopback if desired, but checking everything is safer
        if (-not [string]::IsNullOrWhiteSpace($Conn.RemoteAddress)) {
            if (Test-IsTargetIP -RemoteIP $Conn.RemoteAddress -Targets $TargetList) {
                
                # Gather Process Info
                $ProcessName = "Unknown"
                $ProcessPath = "N/A"
                $CommandLine = "N/A"

                if ($Conn.OwningProcess -eq 0) {
                    $ProcessName = "System/Idle"
                }
                else {
                    try {
                        $procInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($Conn.OwningProcess)" -ErrorAction Stop
                        if ($procInfo) {
                            $ProcessName = $procInfo.Name
                            $ProcessPath = $procInfo.ExecutablePath
                            $CommandLine = $procInfo.CommandLine
                        }
                    }
                    catch {
                        # Fallback
                        $procObj = Get-Process -Id $Conn.OwningProcess -ErrorAction SilentlyContinue
                        if ($procObj) {
                            $ProcessName = $procObj.ProcessName
                            $ProcessPath = "Access Denied/Exited"
                        }
                    }
                }

                # Create Result Object
                $DetectedConnections += [PSCustomObject]@{
                    LocalAddress  = $Conn.LocalAddress
                    LocalPort     = $Conn.LocalPort
                    RemoteAddress = $Conn.RemoteAddress
                    RemotePort    = $Conn.RemotePort
                    State         = $Conn.State
                    PID           = $Conn.OwningProcess
                    ProcessName   = $ProcessName
                    Path          = $ProcessPath
                    CommandLine   = $CommandLine
                }
            }
        }
    }

    if ($DetectedConnections.Count -gt 0) {
        $Global:DiagMsg += "CRITICAL: Found $($DetectedConnections.Count) connection(s) matching target criteria."
        
        # Format details for the Alert output
        $ReportString = $DetectedConnections | Format-List | Out-String
        $Global:DiagMsg += $ReportString

        $Global:AlertMsg = "ALERT: Found $($DetectedConnections.Count) active connection(s) to blocked/watched IPs! | Last Checked $Date"
        $Global:customFieldMessage = "Alert: $($DetectedConnections.Count) target connections found. ($Date)"
    }
    else {
        $Global:DiagMsg += "Scan Complete. No matching connections found."
        $Global:customFieldMessage = "Healthy. No target connections found. ($Date)"
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