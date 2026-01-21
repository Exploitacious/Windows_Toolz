# Script Title: Remediation - Reset Down Terminal Services Sessions
# Description: Detects RDP/Terminal Services sessions in a 'Down' state (often resulting from svchost crashes) and optionally resets them.

# Script Name and Type
$ScriptName = "Remediation - Reset Down Terminal Services Sessions"
$ScriptType = "Remediation"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# attemptRemediation (Checkbox): Set to 'true' to automatically run 'reset session' on found IDs.

# What to Write if Alert is Healthy
$Global:AlertHealthy = "No unstable 'Down' sessions detected. | Last Checked $Date"

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
    # 1. Configuration Setup
    # Cast the checkbox string 'true'/'false' to a real boolean
    if ($env:attemptRemediation -eq 'true') { $AttemptFix = $true } else { $AttemptFix = $false }
    
    $Global:DiagMsg += "Configuration: Attempt Remediation = $AttemptFix"

    # 2. Function to get Down sessions
    # Returns an array of PSObjects with SessionName and ID
    function Get-DownSessions {
        # Capture output as a single string to ensure consistent parsing
        $rawOutput = query session 2>&1 | Out-String
        
        # FIX: 'query session' can return exit codes other than 0 even on success in some environments.
        # We now check if the output looks valid (contains the header 'SESSIONNAME') before declaring failure.
        if ($LASTEXITCODE -ne 0 -and $rawOutput -notmatch "SESSIONNAME") {
            $Global:DiagMsg += "Error querying sessions. Exit Code: $LASTEXITCODE. Output: $rawOutput"
            return @()
        }
        
        $downSessions = @()
        
        # Parse output line by line.
        # Format usually: SESSIONNAME       USERNAME        ID  STATE   TYPE        DEVICE
        # Example Down:   rdp-tcp#12                        2   Down
        
        $lines = $rawOutput -split "`r`n|`n"
        foreach ($line in $lines) {
            # Trim whitespace to ensure clean matching
            $cleanLine = $line.Trim()
            
            # Check specifically for the word 'Down' surrounded by whitespace
            if ($cleanLine -match "\s+Down(\s+|$)") {
                # We use Regex to grab the ID. The ID is the digits immediately preceding the word "Down"
                # Pattern: capture digits (\d+), followed by whitespace \s+, followed by 'Down'
                if ($cleanLine -match "(\d+)\s+Down") {
                    $id = $matches[1]
                    $downSessions += [PSCustomObject]@{
                        RawLine = $cleanLine
                        ID      = $id
                    }
                }
            }
        }
        return $downSessions
    }

    # 3. Initial Scan
    $Global:DiagMsg += "Scanning for 'Down' sessions..."
    $stuckSessions = Get-DownSessions

    if ($stuckSessions.Count -eq 0) {
        $Global:DiagMsg += "No stuck sessions found during initial scan."
        $Global:customFieldMessage = "Healthy - No stuck sessions. ($Date)"
    }
    else {
        $count = $stuckSessions.Count
        $Global:DiagMsg += "CRITICAL: Found $count session(s) in 'Down' state:"
        $stuckSessions | ForEach-Object { $Global:DiagMsg += " - ID $($_.ID) [$($_.RawLine)]" }

        # 4. Remediation Logic
        if ($AttemptFix) {
            $Global:DiagMsg += "Remediation enabled. Attempting to reset sessions..."
            
            foreach ($session in $stuckSessions) {
                $Global:DiagMsg += "Executing: reset session $($session.ID)"
                try {
                    # 'reset session' usually produces no output on success, writes to stderr on fail
                    $resetResult = reset session $session.ID 2>&1 | Out-String
                    if ($LASTEXITCODE -eq 0) {
                        $Global:DiagMsg += "Command executed successfully."
                    }
                    else {
                        $Global:DiagMsg += "Command failed: $resetResult"
                    }
                }
                catch {
                    $Global:DiagMsg += "Exception resetting session $($session.ID): $_"
                }
            }

            # 5. Validation Scan
            Start-Sleep -Seconds 2
            $Global:DiagMsg += "Verifying removal..."
            $remainingSessions = Get-DownSessions

            if ($remainingSessions.Count -eq 0) {
                $Global:DiagMsg += "SUCCESS: All stuck sessions have been cleared."
                $Global:customFieldMessage = "Remediation Success: Cleared $count stuck session(s). ($Date)"
                # We do NOT alert here, because we fixed it.
            }
            else {
                $Global:DiagMsg += "FAILURE: $($remainingSessions.Count) session(s) remain stuck after reset attempt."
                $Global:AlertMsg = "Remediation Failed: $($remainingSessions.Count) RDP sessions remain in 'Down' state. | Last Checked $Date"
                $Global:customFieldMessage = "Remediation Failed. Stuck sessions remain. ($Date)"
            }
        }
        else {
            # Remediation disabled - Alert immediately
            $Global:DiagMsg += "Remediation is disabled. Alerting only."
            $Global:AlertMsg = "Detected $count RDP session(s) in 'Down' state. Remediation disabled. | Last Checked $Date"
            $Global:customFieldMessage = "Alert: $count stuck sessions found. ($Date)"
        }
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