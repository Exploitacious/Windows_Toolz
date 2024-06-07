# Function to get UPS information using CIM
function Get-UPSInfo {
    try {
        # Query UPS data using CIM
        $upsInfo = Get-CimInstance -ClassName Win32_Battery
        return $upsInfo
    }
    catch {
        Write-Error "Failed to retrieve UPS data using CIM: $_"
        return $null
    }
}

# Function to generate the UPS report
function Generate-UPSReport {
    $upsInfo = Get-UPSInfo

    if ($upsInfo -eq $null) {
        return "No UPS device detected or CIM did not return any data."
    }

    # Extract relevant information
    $availability = $upsInfo.Availability
    $batteryStatus = $upsInfo.BatteryStatus
    $caption = $upsInfo.Caption
    $chemistry = $upsInfo.Chemistry
    $designVoltage = $upsInfo.DesignVoltage
    $deviceID = $upsInfo.DeviceID
    $estimatedChargeRemaining = $upsInfo.EstimatedChargeRemaining
    $estimatedRunTime = $upsInfo.EstimatedRunTime
    $name = $upsInfo.Name
    $status = $upsInfo.Status
    $systemName = $upsInfo.SystemName

    # Explanation of some codes
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

    # Create the report string
    $report = "UPS Report Summary:`n"
    $report += "Availability: $availability`n"
    $report += "Battery Status: $batteryStatus ($($batteryStatusExplanation[$batteryStatus]))`n"
    $report += "Caption: $caption`n"
    $report += "Chemistry: $chemistry ($($chemistryExplanation[$chemistry]))`n"
    $report += "Design Voltage: $designVoltage mV`n"
    $report += "Device ID: $deviceID`n"
    $report += "VA Rating: $vaRating`n"
    $report += "Estimated Charge Remaining: $estimatedChargeRemaining %`n"
    $report += "Estimated Run Time: $estimatedRunTime minutes`n"
    $report += "Name: $name`n"
    $report += "Status: $status`n"
    $report += "System Name: $systemName"

    return $report
}

# Main script logic
if (-not (Test-WMIC)) {
    Write-Error "WMIC is not available on this system."
    exit
}

# Get the UPS report
$UPSReport = Generate-UPSReport

# Output the report
Write-Output $UPSReport
