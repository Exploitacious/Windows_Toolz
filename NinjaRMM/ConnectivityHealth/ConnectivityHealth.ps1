# Script Title: Connectivity Health Monitor
# Description: Tests connectivity to a list of hard-coded and/or custom-defined domains and IPs. Reports status to a multi-line custom field.

# Script Name and Type
$ScriptName = "Connectivity Health Monitor"
$ScriptType = "Monitoring"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
$env:runHardCodedChecks = 'true' # (Checkbox, Default: true): Set to 'true' to run all hard-coded app health checks.
# runCustomCheck (Checkbox, Default: false): Set to 'true' to run the custom check defined below.
# customCheckName (Text): The name for the custom check (e.g., "Client VPN").
# customCheckEndpoints (Text): A comma-separated list of domains or IPs (e.g., "vpn.client.com, 10.50.1.1").

# Target multi-line custom field
$env:CustomFieldName = 'vendorConnectivityHealthReport'

######## App Profile Definitions #########

# Define App Profiles List (Match the Profile Definitions Variable Names)
$HardCodedAppsToScan = @(
    'BlackPointSnap',
    'ThreatLocker'
)

$BlackPointSnap = @( # Blackpoint Snap Agent
    'agent.sega.production.snap.bpcyber.com',
    'agent.siem.production.snap.bpcyber.com',
    'agent.bpsnap.com',
    'agent-sega-production-snap.bpcyber.net',
    'tenant-agent-update-production-black.s3.us-east-1.amazonaws.com'
)

$ThreatLocker = @( # ThreatLocker
    'threatlocker.com',
    'api.threatlocker.com',
    'portal.threatlocker.com'
)

# What to Write if Alert is Healthy
$Global:AlertHealthy = "System state is nominal. | Last Checked $Date"

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

# --- Script-Specific Functions ---

# --- Script-Specific Functions ---

function Test-EndpointConnectivity {
    [CmdletBinding()]
    param (
        [string]$Endpoint
    )

    # Clean up endpoint string
    $target = $Endpoint.Trim()

    # Check for CIDR notation or web paths
    if ($target -like '*/*') {
        # Check for FQDNs with paths (e.g., myapp.com/login)
        if ($target -match '\.com/|\.net/|\.org/|\.io/') {
            $Global:DiagMsg += "Endpoint '$target' appears to be a URL. Testing the domain part only."
            $target = ($target -split '/')[0]
        }
        # Handle IP-based CIDR notation
        else {
            $Global:DiagMsg += "Endpoint '$target' is in CIDR notation."
            $target = ($target -split '/')[0]
            $Global:DiagMsg += "NOTE: Will only test the provided network address '$target', not the entire IP range."
        }
    }
    
    $Global:DiagMsg += "$target"

    # --- 1. Primary Test: TCP Port 443 (HTTPS) ---
    # This is the most important test for modern web services.
    # The function's success depends *only* on this.
    try {
        $Global:DiagMsg += "> Checking TCP Port 443 on '$target'..."
        # -WarningAction SilentlyContinue suppresses common DNS-related warnings
        $result443 = Test-NetConnection -ComputerName $target -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        
        if ($result443) {
            $Global:DiagMsg += "[Success] TCP Port 443 is OPEN on $target"
            return $true
        }
        else {
            $Global:DiagMsg += "[FAILURE] TCP Port 443 is closed or unreachable on $target"
        }
    }
    catch {
        # This catches DNS resolution failures or other critical errors
        $Global:DiagMsg += "[FAILURE] Could not test Port 443 on $target. Error: $($_.Exception.Message | Out-String)"
    }

    # --- 2. Fallback Test: ICMP (Ping) ---
    # If 443 fails, we still return $false, but we check ICMP for extra diagnostics.
    $Global:DiagMsg += "> Checking ICMP (Ping) on '$target' as a secondary diagnostic..."
    try {
        $resultICMP = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction Stop
        
        if ($resultICMP) {
            $Global:DiagMsg += "[Success] Port 443 failed, but ICMP SUCCEEDED."
        }
        else {
            $Global:DiagMsg += "[FAILURE] Port 443 FAILED, and ICMP (Ping) FAILED. The service may be using another port."
        }
    }
    catch {
        $Global:DiagMsg += "[FAILURE] Port 443 FAILED, and ICMP (Ping) also FAILED. Error: $($_.Exception.Message | Out-String)"
    }
    
    # If we got this far, the primary 443 check failed.
    return $false
}

##################################
##################################
######## Start of Script #########

try {
    # --- 1. Parse RMM Variables ---
    [bool]$runHardCodedChecks = $env:runHardCodedChecks -eq 'true'
    [bool]$runCustomCheck = $env:runCustomCheck -eq 'true'
    $customCheckName = $env:customCheckName
    $customCheckEndpoints = $env:customCheckEndpoints

    $Global:DiagMsg += "Run Hard-Coded Checks: $runHardCodedChecks"
    $Global:DiagMsg += "Run Custom Check: $runCustomCheck"

    # --- 2. Build Master List of Checks ---
    $allChecksToRun = [System.Collections.Specialized.OrderedDictionary]::new()
    $overallStatus = @() # Array to hold formatted result strings
    $totalFailures = 0

    if ($runHardCodedChecks) {
        $Global:DiagMsg += "Adding hard-coded checks..."
        $Global:DiagMsg += ""
        foreach ($appName in $HardCodedAppsToScan) {
            try {
                $endpoints = Get-Variable -Name $appName -ValueOnly -ErrorAction Stop
                if ($endpoints -and $endpoints.GetType().IsArray) {
                    $allChecksToRun[$appName] = $endpoints
                    $Global:DiagMsg += "Added profile '$appName' with $($endpoints.Count) endpoints."
                }
                else {
                    $Global:DiagMsg += "Hard-coded profile '$appName' is empty or not an array. Skipping."
                }
            }
            catch {
                $Global:DiagMsg += "Could not find hard-coded variable '$appName'. Skipping. Error: $($_.Exception.Message)"
            }
        }
    }

    if ($runCustomCheck -and $customCheckName -and $customCheckEndpoints) {
        $Global:DiagMsg += "Adding custom check '$customCheckName'..."
        $endpointList = $customCheckEndpoints -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        if ($endpointList.Count -gt 0) {
            $allChecksToRun[$customCheckName] = $endpointList
            $Global:DiagMsg += "Added profile '$customCheckName' with $($endpointList.Count) endpoints."
        }
        else {
            $Global:DiagMsg += "Custom check '$customCheckName' had no valid endpoints. Skipping."
        }
    }
    elseif ($runCustomCheck) {
        $Global:DiagMsg += "Run Custom Check was 'true' but 'customCheckName' or 'customCheckEndpoints' was empty. Skipping custom check."
    }

    # --- 3. Execute Checks ---
    if ($allChecksToRun.Count -gt 0) {
        foreach ($appName in $allChecksToRun.Keys) {
            $endpoints = $allChecksToRun[$appName]
            $Global:DiagMsg += ""
            $Global:DiagMsg += "--- Processing App: $appName ---"
            
            $successCount = 0
            $failCount = 0

            foreach ($endpoint in $endpoints) {
                if (Test-EndpointConnectivity -Endpoint $endpoint) {
                    $successCount++
                }
                else {
                    $failCount++
                }
            }

            # Format the result string for this app
            if ($failCount -gt 0) {
                $totalFailures += $failCount
                if ($successCount -gt 0) {
                    $overallStatus += "--- $appName : $failCount Failed, $successCount Successful"
                }
                else {
                    $overallStatus += "--- $appName : $failCount Failed"
                }
            }
            else {
                $overallStatus += "--- $appName : All Successful ($successCount)"
            }
        }

        # --- 4. Build Final Report ---
        if ($totalFailures -gt 0) {
            $Global:AlertMsg = "Connection Failures Detected. See report. | Last Checked $Date"
            $header = "Connection Failures Detected | Last Checked $Date"
        }
        else {
            $header = "All Connections Healthy | Last Checked $Date"
        }

        # Combine header and status lines. Use `n (newline) for the multi-line field.
        $Global:customFieldMessage = "$header`n$($overallStatus -join "`n")"
    
    }
    else {
        $Global:DiagMsg += "No checks were configured to run."
        $Global:customFieldMessage = "No connectivity checks were configured to run. | Last Checked $Date"
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
if ($env:CustomFieldName) {
    $Global:DiagMsg += ""
    $Global:DiagMsg += "Attempting to write to Custom Field '$($env:CustomFieldName)'."
    try {
        # The `n newline characters in the message will be respected by the multi-line field.
        Ninja-Property-Set -Name $env:CustomFieldName -Value $Global:customFieldMessage
        $Global:DiagMsg += "Successfully updated Custom Field."
    }
    catch {
        $Global:DiagMsg += "Error writing to Custom Field '$($env:CustomFieldName)': $($_.Exception.Message)"
    }
}
else {
    $Global:DiagMsg += "Global:CustomFieldName was not set. Skipping update."
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