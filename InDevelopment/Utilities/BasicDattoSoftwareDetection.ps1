<###
# Original Datto RMM Software Monitor chopped and screwed by Alex Ivantsov @Exploitacious

Sounds an alert if software identifying a known string IS or IS NOT discovered. 
Can be configured with a response Component to install the software in question. Drop in your software search term into the usrString Variable.

Env Strings for Testing, but otherwise only configured in Datto RMM:
$env:usrString = "SNAP"
$env:usrMethod = 'EQ'  # Use 'EQ' to Alert if FOUND, and 'NE' to Alert if MISSING.

To test:
Let's say you're looking for a specific Adobe install. Jump on a computer where you KNOW it's installed, and confirm the script will find exactly what you're looking for by doing the following:
Open Powershell and run this below piece of code, replacing the "$varString" variable with the name of whatever software you're looking for:

Get-ChildItem ("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE") | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName, $_.BrandName -match "$varString" }

Get as specific as you can with your searches. In case there are multiple results displayed for "adobe", try to search and match exactly what you're seeking - from the "BrandName" or "DisplayName" of the app displayed.
###>

function Check-SoftwareInstall {
    param (
        [string]$SoftwareName,
        [string]$Method
    )

    $varCounter = 0
    $Detection = @()
    $DetectionLocation = ""
    $DetectedData = @()

    # Registry paths to search
    $regPaths = @(
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE"
    )

    foreach ($regPath in $regPaths) {
        $foundItems = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | ForEach-Object { 
            Get-ItemProperty $_.PSPath 
        } | Where-Object { $_.DisplayName -match "$SoftwareName" -or $_.BrandName -match "$SoftwareName" }

        if ($foundItems) {
            foreach ($foundItem in $foundItems) {
                $varCounter++

                # Store the display name
                $Detection += $foundItem.DisplayName

                # Store the registry path where the software was found
                $DetectionLocation = $regPath

                # Capture relevant details about the software
                $DetectedData += [PSCustomObject]@{
                    DisplayName     = $foundItem.DisplayName
                    Publisher       = $foundItem.Publisher
                    Version         = $foundItem.DisplayVersion
                    InstallDate     = $foundItem.InstallDate
                    InstallLocation = $foundItem.InstallLocation
                    UninstallString = $foundItem.UninstallString
                    RegistryPath    = $regPath
                }
            }
        }
    }

    # Return detected state and relevant data
    if ($Method -eq 'EQ') {
        return @{
            Detected     = ($varCounter -ge 1)
            Location     = $DetectionLocation
            DetectedData = $DetectedData
        }
    }
    elseif ($Method -eq 'NE') {
        return @{
            Detected     = ($varCounter -lt 1)
            Location     = $DetectionLocation
            DetectedData = $DetectedData
        }
    }
    else {
        throw "Invalid method. Please use 'EQ' or 'NE'."
    }
}

# Example usage:
$softwareName = "SNAP"
$method = 'EQ'
$result = Check-SoftwareInstall -SoftwareName $softwareName -Method $method

Write-Host
Write-Host "Detected: $($result.Detected)" -ForegroundColor Blue
Write-Host
$result.DetectedData | ForEach-Object { 
    Write-Host "Display Name: $($_.DisplayName)"
    Write-Host "Publisher: $($_.Publisher)"
    Write-Host "Version: $($_.Version)"
    Write-Host "Install Date: $($_.InstallDate)"
    Write-Host "Install Location: $($_.InstallLocation)"
    Write-Host "Uninstall String: $($_.UninstallString)"
    Write-Host "Registry Path: $($_.RegistryPath)"
    Write-Host "`n"
}
