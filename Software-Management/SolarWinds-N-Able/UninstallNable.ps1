# Uninstall N-Able and N-Central stuffs
# Developed by: Alex Ivantsov

write-host "SolarWinds Windows Agent Uninstaller"
write-host "================================================="

# Silently Remove and Uninstall N-Able Agents

  ./"C:\Program Files (x86)\SolarWinds MSP\Ecosystem Agent\unins000.exe" /silent

  ./"C:\Program Files (x86)\MspPlatform\FileCacheServiceAgent\unins000.exe" /silent

  ./"C:\Program Files (x86)\MspPlatform\PME\unins000.exe" /silent

  ./"C:\Program Files (x86)\MspPlatform\RequestHandlerAgent\unins000.exe" /silent


function getGUID ($product, $vendor) {
set-content "msi.vbs" -value 'Set installer = CreateObject("WindowsInstaller.Installer")
On Error Resume Next'
add-content "msi.vbs" -value "strProductSearch = `"$product`""
add-content "msi.vbs" -value "strVendorSearch = `"$vendor`""
add-content "msi.vbs" -value 'For Each product In installer.ProductsEx("", "", 7)
    name = product.InstallProperty("ProductName")
    vendor = product.InstallProperty("Publisher")
    productcode = product.ProductCode
    If InStr(1, name, strProductSearch) > 0 then
        If InStr(1, vendor, strVendorSearch) > 0 then
            wscript.echo (productcode)
        End if
   End if
Next'

cscript /nologo msi.vbs
remove-item msi.vbs -force
}

if ([intptr]::Size -eq 4) {
    $varProgramFiles=$env:ProgramFiles
} else {
    $varProgramFiles=${env:ProgramFiles(x86)}
}

foreach ($guid in getGuid "Windows Agent" "N-able Technologies") {
    write-host "- Uninstalling $guid..."
    msiexec /X$guid /qn /norestart
}

foreach ($iteration in ('SolarWinds MSP\Ecosystem Agent','MspPlatform\FileCacheServiceAgent','MspPlatform\PME','MspPlatform\RequestHandlerAgent')) {
    start-sleep -seconds 30
    write-host "  $iteration..."
    start-process "$varProgramFiles\$iteration\unins000.exe" -argumentList "/SILENT"
}

# Perma-Remove Directories

    rmdir /Q /S "C:\Program Files (x86)\SolarWinds MSP\"

    rmdir /Q /S "C:\Program Files (x86)\N-able Technologies\"

    rmdir /Q /S "C:\Program Files (x86)\MspPlatform\"

