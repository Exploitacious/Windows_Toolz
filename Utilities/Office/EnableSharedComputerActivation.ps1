# Define the target registry configuration
$regPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$regName = "SharedComputerLicensing"
$regValue = "1"
$regType = "String"

try {
    # Check if the target registry key exists. If not, create it.
    # This prevents errors if Office isn't installed or the key is missing.
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
        Write-Host "Created registry path: $regPath"
    }

    # Get the current value of the property, if it exists.
    $currentValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue

    # Compare the current value with the desired value.
    # If it's missing or incorrect, set it to the correct value.
    if ($null -eq $currentValue -or $currentValue.$regName -ne $regValue) {
        Write-Host "Shared Computer Activation not enabled or misconfigured. Setting it now..."
        Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Type $regType -Force
        Write-Host "Successfully enabled Shared Computer Activation."
    }
    else {
        Write-Host "Shared Computer Activation is already enabled. No action needed."
    }
}
catch {
    # Catch any potential errors, such as permissions issues.
    $errorMessage = $_.Exception.Message
    Write-Error "Failed to configure Shared Computer Activation. Error: $errorMessage"
    # Exit with a non-zero status code to indicate failure to automation systems.
    exit 1
}

# Exit with a success status code.
exit 0