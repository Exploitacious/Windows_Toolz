# Function to check if WMIC is available
function Test-WMIC {
    try {
        $null = wmic /? 2>$null
        return $true
    }
    catch {
        return $false
    }
}
if (-not (Test-WMIC)) {
    $Global:AlertMsg += "WMIC is not available on this system."
    exit
}

# Function to get UPS information using CIM
function Get-UPSInfo {
    try {
        # Query UPS data using CIM
        $upsInfo = Get-CimInstance -ClassName Win32_Battery
        return $upsInfo
    }
    catch {
        $Global:AlertMsg += "Failed to retrieve UPS data using CIM: $_"
        return $null
    }
}

# Generate UPS report
$upsInfo = Get-UPSInfo
if ($null -eq $upsInfo) {
    return "No UPS device detected or CIM did not return any data."
}

# Extract relevant information
$availability = $upsInfo.Availability
$batteryStatus = [int]$upsInfo.BatteryStatus
$caption = $upsInfo.Caption
$chemistry = [int]$upsInfo.Chemistry
$designVoltage = $upsInfo.DesignVoltage
$deviceID = $upsInfo.DeviceID
$estimatedChargeRemaining = $upsInfo.EstimatedChargeRemaining
$estimatedRunTime = $upsInfo.EstimatedRunTime
$name = $upsInfo.Name
$status = $upsInfo.Status
$systemName = $upsInfo.SystemName
# Explanation of Battery codes
$batteryStatusExplanation = @{
    1 = "The battery is discharging."
    2 = "The battery is plugged in and charging."
    3 = "The battery is fully charged."
}
$chemistryExplanation = @{
    1 = "Other"
    2 = "Unknown"
    3 = "Lead Acid"
    4 = "Nickel Cadmium"
    5 = "Nickel Metal Hydride"
    6 = "Lithium-ion"
    7 = "Zinc Air"
    8 = "Lithium Polymer"
}
# Extract numeric value from DeviceID and append "VA"
$vaRating = if ($deviceID -match '\d+') { "$($matches[0])VA" } else { "Unknown" }
# Get battery status explanation or default to "Unknown"
$batteryStatusDesc = if ($batteryStatusExplanation.ContainsKey($batteryStatus)) { $batteryStatusExplanation[$batteryStatus] } else { "Unknown" }
# Get chemistry explanation or default to "Unknown"
$chemistryDesc = if ($chemistryExplanation.ContainsKey($chemistry)) { $chemistryExplanation[$chemistry] } else { "Unknown" }

# Create the report string
$Global:DiagMsg += "Availability: $availability"
$Global:DiagMsg += "Battery Status: $batteryStatus ($batteryStatusDesc)"
$Global:DiagMsg += "Caption: $caption"
$Global:DiagMsg += "Chemistry: $chemistry ($chemistryDesc)"
$Global:DiagMsg += "Design Voltage: $designVoltage mV"
$Global:DiagMsg += "Device ID: $deviceID"
$Global:DiagMsg += "VA Rating: $vaRating"
$Global:DiagMsg += "Estimated Charge Remaining: $estimatedChargeRemaining %"
$Global:DiagMsg += "Estimated Run Time: $estimatedRunTime minutes"
$Global:DiagMsg += "Name: $name"
$Global:DiagMsg += "Status: $status"
$Global:DiagMsg += "System Name: $systemName"



