# Requires Run as Administrator
# PowerShell 5.1 Compatible

Write-Host "--- STARTING DEEP MSI CLEANUP FOR ZOOM ---" -ForegroundColor Cyan

# 1. DEFINE THE DEEP INSTALLER HIVES
# These are the hidden hives where Windows Installer (MSI) tracks products.
# Keys here use "Packed GUIDs" (scrambled IDs), so we must search by ProductName.
$installerPaths = @(
    "HKLM:\SOFTWARE\Classes\Installer\Products",
    "HKLM:\SOFTWARE\Classes\Installer\Features",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products"
)

# 2. SEARCH AND DESTROY
foreach ($rootPath in $installerPaths) {
    if (Test-Path $rootPath) {
        Write-Host "Scanning: $rootPath" -ForegroundColor Gray
        
        # Get all subkeys (Product IDs)
        $keys = Get-ChildItem -Path $rootPath -ErrorAction SilentlyContinue

        foreach ($key in $keys) {
            # We attempt to read the ProductName property. 
            # Note: In 'UserData', the name is often inside a subkey called 'InstallProperties'.
            $productName = $null
            
            # Check direct property
            $prop = Get-ItemProperty -Path $key.PSPath -Name "ProductName" -ErrorAction SilentlyContinue
            if ($prop) { $productName = $prop.ProductName }

            # If not found, check InstallProperties subkey (common in UserData)
            if (-not $productName) {
                $subPath = Join-Path $key.PSPath "InstallProperties"
                if (Test-Path $subPath) {
                    $subProp = Get-ItemProperty -Path $subPath -Name "DisplayName" -ErrorAction SilentlyContinue
                    if ($subProp) { $productName = $subProp.DisplayName }
                }
            }

            # CHECK FOR ZOOM MATCH
            if ($productName -like "*Zoom*") {
                Write-Host "  [FOUND STUCK MSI ENTRY]" -ForegroundColor Yellow
                Write-Host "  Product: $productName"
                Write-Host "  Key: $($key.PSChildName)"
                
                # Nuke it
                Remove-Item -Path $key.PSPath -Recurse -Force
                Write-Host "  -> Registry Key Destroyed." -ForegroundColor Green
            }
        }
    }
}

# 3. CLEAN UP UPGRADE CODES
# This prevents the installer from detecting "Related Products"
Write-Host "Scanning UpgradeCodes..." -ForegroundColor Gray
$upgradePath = "HKLM:\SOFTWARE\Classes\Installer\UpgradeCodes"
if (Test-Path $upgradePath) {
    $codes = Get-ChildItem -Path $upgradePath -ErrorAction SilentlyContinue
    foreach ($code in $codes) {
        # This is harder to identify by name, but usually, if the Product was Zoom, 
        # the upgrade code values might reference the path.
        # However, deleting blindly is dangerous. 
        # We will look for values inside the key that point to a Zoom GUID.
        
        # A safer check: Look at the values inside the UpgradeCode. 
        # If the value name (which is a ProductCode) was deleted in step 2, we should delete this too.
        # For safety, we will skip this automated step to avoid breaking other apps, 
        # as Step 2 usually fixes Error 1714.
    }
}

Write-Host "--- DEEP CLEANUP COMPLETE ---" -ForegroundColor Cyan
Write-Host "Please attempt the WinGet install again."