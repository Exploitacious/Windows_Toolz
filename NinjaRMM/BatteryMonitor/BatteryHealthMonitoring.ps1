# Script Title: Laptop & UPS Battery Monitoring
# Description: Monitors laptop battery health, cycle count, and degradation. Also checks for connected UPS devices (Lead Acid) and reports their status.

# Script Name and Type
$ScriptName = "Laptop & UPS Battery Monitoring"
$ScriptType = "Monitoring"
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# This section is for variables that are not meant to be configured via NinjaRMM script parameters.
$ReportPath = "C:\Temp\BatteryReport"
$ReportFile = "$ReportPath\Battery-Report.html"

## ORG-LEVEL EXPECTED VARIABLES ##
# This section is where we will list anything that will require 'Ninja-Property-Get' 
# (None for this script)

## CONFIG RMM VARIABLES ##
# Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# cycleCountThresh (Integer): Alert if Battery is greater than this many cycles. (Default: 100)
# degradeThresh (Integer): Alert if battery degradation is beyond this percentage. (Default: 10)


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

# Function to check if powercfg is available (from original script)
function Test-PowerCfg {
    try {
        $null = powercfg /? 2>$null
        return $true
    }
    catch {
        return $false
    }
}

# Script UID and intro messaging
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}

# Function to get UPS information (specifically Lead Acid batteries)
function Get-UPSInfo {
    try {
        # Query UPS data using CIM, filtering for Lead Acid (Chemistry=3)
        $upsInfo = Get-CimInstance -ClassName Win32_Battery -Filter "Chemistry = 3"
        return $upsInfo
    }
    catch {
        $Global:DiagMsg += "Failed to query for Win32_Battery with Chemistry=3: $($_.Exception.Message)"
        return $null
    }
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
    # --- Parameter Validation and Type Casting ---
    $Global:DiagMsg += "Validating RMM parameters."
    
    try {
        [int]$cycleCountThreshold = [int]$env:cycleCountThresh
        $Global:DiagMsg += "RMM Variable 'cycleCountThresh' set to: $cycleCountThreshold"
    }
    catch {
        $cycleCountThreshold = 100 # Default value
        $Global:DiagMsg += "Invalid or missing 'cycleCountThresh'. Reverting to default: $cycleCountThreshold"
    }

    try {
        [int]$degradeThreshold = [int]$env:degradeThresh
        $Global:DiagMsg += "RMM Variable 'degradeThresh' set to: $degradeThreshold"
    }
    catch {
        $degradeThreshold = 10 # Default value
        $Global:DiagMsg += "Invalid or missing 'degradeThresh'. Reverting to default: $degradeThreshold"
    }
    
    # --- Laptop Battery Logic ---
    
    # Create the directory if it doesn't exist
    if (-not (Test-Path -Path $ReportPath)) {
        $Global:DiagMsg += "Creating report directory: $ReportPath"
        $null = New-Item -ItemType Directory -Path $ReportPath
    }

    # Check if powercfg is available
    if (-not (Test-PowerCfg)) {
        $Global:AlertMsg += "powercfg.exe is not available on this system. Cannot check battery health."
    }
    else {
        $Global:DiagMsg += "powercfg.exe found. Generating battery report to: $ReportFile"
        
        # Generate the battery report
        powercfg /batteryreport /output $ReportFile /duration 1
        
        # Wait for the report to be generated
        Start-Sleep -Seconds 5

        if (Test-Path -Path $ReportFile) {
            # Extract and read the information from the battery report
            $reportContent = Get-Content -Path $ReportFile -Raw

            # Extract the information using regex
            $designCapacity = [regex]::Match($reportContent, 'DESIGN CAPACITY.*?(\d+,?\d*) mWh').Groups[1].Value -replace ',', ''
            $fullChargeCapacity = [regex]::Match($reportContent, 'FULL CHARGE CAPACITY.*?(\d+,?\d*) mWh').Groups[1].Value -replace ',', ''
            $cycleCountRaw = [regex]::Match($reportContent, 'CYCLE COUNT.*?(\d+)').Groups[1].Value # <-- Get the raw string
            $biosDate = [regex]::Match($reportContent, 'BIOS\s*.*?(\d{2}/\d{2}/\d{4})').Groups[1].Value

            # Fallback for empty values
            if (-not $designCapacity) { $designCapacity = 0 }
            if (-not $fullChargeCapacity) { $fullChargeCapacity = 0 }

            # Cast cycle count to integer *after* checking if it's empty
            [int]$cycleCount = 0
            if (-not $cycleCountRaw) {
                $cycleCount = 0
                $Global:DiagMsg += "Warning: Cycle Count was not found in the report. Defaulting to 0."
            }
            else {
                try {
                    $cycleCount = [int]$cycleCountRaw
                }
                catch {
                    $Global:DiagMsg += "Warning: Could not parse Cycle Count '$cycleCountRaw' as an integer. Defaulting to 0."
                    $cycleCount = 0
                }
            }

            # Calculate the degradation percentage
            $degradationPercentage = 0
            $remainingPercentage = 0
            
            if ($designCapacity -gt 0) {
                $degradationPercentage = [math]::Round((1 - ($fullChargeCapacity / $designCapacity)) * 100, 2)
                $remainingPercentage = 100 - $degradationPercentage
            }
            else {
                $Global:DiagMsg += "Warning: Design Capacity reported as 0. Cannot calculate degradation."
            }
           
            # Calculate the estimated battery age based on the BIOS date
            try {
                $biosDateTime = [datetime]::ParseExact($biosDate, 'MM/dd/yyyy', $null)
                $currentDateTime = Get-Date
                $batteryAgeDays = ($currentDateTime - $biosDateTime).Days
                $batteryAgeYears = [math]::Round($batteryAgeDays / 365, 2)
                $Global:DiagMsg += "Estimated Battery Age based on BIOS: $batteryAgeYears years ($batteryAgeDays days)"
            }
            catch {
                $Global:DiagMsg += "Could not parse BIOS date: $biosDate"
            }

            # Create report strings
            $Global:DiagMsg += "Battery Design Capacity: $designCapacity mWh"
            $Global:DiagMsg += "Current Max Charge Capacity: $fullChargeCapacity mWh"
            $Global:DiagMsg += "Estimated Battery Degradation: $degradationPercentage %"
            $Global:DiagMsg += "Max Battery Capacity: $remainingPercentage %"
            $Global:DiagMsg += "Lifetime Recharge Cycle Count: $cycleCount"

            # --- Test strings for Alerts ---
            if ($cycleCount -gt $cycleCountThreshold) {
                $Global:AlertMsg += "Battery has surpassed a Recharge Cycle Count of $cycleCountThreshold ($cycleCount cycles). "
                $Global:DiagMsg += "ALERT: Battery Health has surpassed the set limits of: $cycleCountThreshold total recharge cycles ($cycleCount)"
            }
            else {
                $Global:DiagMsg += "INFO: Lifetime Recharge Cycle Count ($cycleCount) is below threshold of $cycleCountThreshold"
            }

            if ($degradationPercentage -gt $degradeThreshold) {
                $Global:AlertMsg += "Battery has surpassed the degradation threshold of $degradeThreshold% ($degradationPercentage% degraded). "
                $Global:DiagMsg += "ALERT: The Battery has degraded beyond $degradeThreshold% ($degradationPercentage%)"
            }
            else {
                $Global:DiagMsg += "INFO: Estimated Battery Degradation ($degradationPercentage%) is below threshold of $degradeThreshold%"
            }

            # --- Set Custom Field Message (used for both Custom Field and Healthy Alert) ---
            $Global:customFieldMessage = "Battery is $remainingPercentage% of Original Capacity with $cycleCount Total Recharge Cycles. | Last Checked $Date"

        }
        else {
            $Global:AlertMsg += "Battery report file was not created at $ReportFile. "
            $Global:DiagMsg += "ERROR: Battery report file was not created."
        }
    }

    # --- UPS Monitoring Logic ---
    $Global:DiagMsg += "Checking for UPS devices (Win32_Battery Chemistry=3)..."
    $upsDevices = Get-UPSInfo

    if ($null -ne $upsDevices) {
        # Explanation of Battery codes
        $batteryStatusExplanation = @{
            1  = "Discharging"
            2  = "Charging"
            3  = "Fully Charged"
            4  = "Low"
            5  = "Critical"
            6  = "Charging and High"
            7  = "Charging and Low"
            8  = "Charging and Critical"
            9  = "Undefined"
            10 = "Partially Charged"
            11 = "Unknown" # Default
        }
        # Explanation of Chemistry codes
        $chemistryExplanation = @{
            1 = "Other"
            2 = "Unknown"
            3 = "Lead Acid"
            4 = "Nickel Cadmium"
            5 = "Nickel Metal Hydride"
            6 = "Lithium-ion"
            7 = "Zinc air"
            8 = "Lithium Polymer"
        }

        foreach ($ups in $upsDevices) {
            # Extract relevant information
            $batteryStatus = [int]$ups.BatteryStatus
            $chemistry = [int]$ups.Chemistry
            $deviceID = $ups.DeviceID
            $estimatedChargeRemaining = $ups.EstimatedChargeRemaining
            $estimatedRunTime = $ups.EstimatedRunTime
            $name = $ups.Name
            $status = $ups.Status

            # Extract numeric value from DeviceID and append "VA"
            # [FIXED] Corrected the syntax error "Unknown"V"
            $vaRating = if ($deviceID -match '\d+') { "$($matches[0])VA" } else { "Unknown VA" }
            
            # Get battery status explanation or default to "Unknown"
            $batteryStatusDesc = if ($batteryStatusExplanation.ContainsKey($batteryStatus)) { $batteryStatusExplanation[$batteryStatus] } else { $batteryStatusExplanation[11] }
            # Get chemistry explanation or default to "Unknown"
            $chemistryDesc = if ($chemistryExplanation.ContainsKey($chemistry)) { $chemistryExplanation[$chemistry] } else { $chemistryExplanation[2] }

            $Global:DiagMsg += "--- Found UPS: $name ---"
            $Global:DiagMsg += "Health: $status"
            $Global:DiagMsg += "Battery Status: $batteryStatus ($batteryStatusDesc)"
            $Global:DiagMsg += "Estimated Charge Remaining: $estimatedChargeRemaining %"
            $Global:DiagMsg += "Estimated Run Time: $estimatedRunTime minutes"
            $Global:DiagMsg += "Model: $name"
            $Global:DiagMsg += "VA Rating: $vaRating"
            $Global:DiagMsg += "Chemistry: $chemistry ($chemistryDesc)"
            $Global:DiagMsg += "Device ID: $deviceID"
            $Global:DiagMsg += "-----------------------"

            # Check UPS Status
            if ($status -ne "OK") {
                $Global:AlertMsg += "$chemistryDesc $vaRating UPS ($name) status is: $status. "
            }
            
            # Append to custom field message, checking if it's empty first
            if ($Global:customFieldMessage) {
                $Global:customFieldMessage += " | UPS ($name): $status, $batteryStatusDesc, $estimatedChargeRemaining%, $estimatedRunTime mins."
            }
            else {
                # If laptop check failed or didn't run, populate with UPS data
                $Global:customFieldMessage = "UPS ($name): $status, $batteryStatusDesc, $estimatedChargeRemaining%, $estimatedRunTime mins. | Last Checked $Date"
            }
        }
    }
    else {
        $Global:DiagMsg += "No UPS devices (Chemistry=3) found."
        # If the custom field is *still* empty, it means laptop check and UPS check found nothing.
        if (-not $Global:customFieldMessage) {
            $Global:customFieldMessage = "No laptop battery or UPS info found. | Last Checked $Date"
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
    # Trim trailing spaces from alert message
    write-RMMAlert ($Global:AlertMsg.Trim() + " | Last Checked $Date")
    write-RMMDiag $Global:DiagMsg
    Exit 1
}
else {
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"
    # If the script logic populated a custom message, use it. Otherwise, use the default healthy message.
    if ($Global:customFieldMessage) {
        write-RMMAlert $Global:customFieldMessage
    }
    else {
        write-RMMAlert $Global:AlertHealthy
    }
    write-RMMDiag $Global:DiagMsg
    Exit 0
}