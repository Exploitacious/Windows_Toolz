# Solarwinds begone!
# Created/Customized by Alex Ivantsov - alex@ivantsov.tech - Umbrella IT Solutions

# Solarwinds deploys 2 agent types via MSI, and multiple others via standard exe.
# Step one is to remove the MSI's, then the exe's and lastly delete any remaining folders.
# Enjoy!

write-host
write-host
write-host "SolarWhatever Product Uninstaller"
write-host "================================================="
write-host `r

$Installer = New-Object -ComObject WindowsInstaller.Installer
$InstallerProducts = $Installer.ProductsEx("", "", 7)
$InstalledProducts = ForEach ($Product in $InstallerProducts) {
    [PSCustomObject]@{
        ProductName   = $Product.InstallProperty("ProductName")
        Publisher     = $Product.InstallProperty("Publisher") 
        ProductCode   = $Product.ProductCode()
        VersionString = $Product.InstallProperty("VersionString")
    } 
} 

$NableProducts = $InstalledProducts | Where-Object Publisher -like "*N-Able*"

foreach ($item in $NableProducts) {

    $ProductID = $NableProducts.ProductCode
    $ProductName = $NableProducts.ProductName

    write-host "Uninstalling $ProductName ..."
    MsiExec.exe /X $ProductID /qn
    start-sleep -seconds 75

}


$SolarwindsFolders = (
        'C:\Program Files (x86)\MspPlatform\FileCacheServiceAgent',    
        'C:\Program Files (x86)\MspPlatform\RequestHandlerAgent',
        'C:\Program Files (x86)\MspPlatform\PME',
        'C:\Program Files (x86)\N-able Technologies\NablePatchCache',
        'C:\Program Files (x86)\N-able Technologies\PatchManagement',
        'C:\Program Files (x86)\N-able Technologies\Reactive',
        'C:\Program Files (x86)\N-able Technologies\Windows Agent',
        'C:\Program Files (x86)\N-able Technologies\Windows Software Probe',
        'C:\Program Files (x86)\SolarWinds MSP\Ecosystem Agent',
        'C:\Program Files\MspPlatform\FileCacheServiceAgent',    
        'C:\Program Files\MspPlatform\RequestHandlerAgent',
        'C:\Program Files\MspPlatform\PME',
        'C:\Program Files\N-able Technologies\NablePatchCache',
        'C:\Program Files\N-able Technologies\PatchManagement',
        'C:\Program Files\N-able Technologies\Reactive',
        'C:\Program Files\N-able Technologies\Windows Agent',
        'C:\Program Files\N-able Technologies\Windows Software Probe',
        'C:\Program Files\SolarWinds MSP\Ecosystem Agent'
)
    write-host "- Uninstalling N-Able Apps:"

foreach ($iteration in $SolarwindsFolders) {

    if (Test-Path -Path $iteration) {

        try { 
            
            start-process "$iteration\unins000.exe" -argumentList "/SILENT"
            write-host "Removing  $iteration..."
            start-sleep -seconds 45
            
        } catch {
                write-host "Deleting Folder(s)  $iteration"
                rmdir "$iteration" -recurse -force -ErrorAction SilentlyContinue
            }

        write-host "Deleting Folder(s)  $iteration"
        rmdir "$iteration" -recurse -force -ErrorAction SilentlyContinue

        }
    }

write-host
write-host "- Removing N-Able Folders:"

foreach ($Folder in (

       "C:\Program Files (x86)\SolarWinds MSP\",
       "C:\Program Files (x86)\N-able Technologies\",
       "C:\Program Files (x86)\MspPlatform\",
       "C:\Program Files\SolarWinds MSP\",
       "C:\Program Files\N-able Technologies\",
       "C:\Program Files\MspPlatform\"
        )
    )
    
    {
    if (Test-Path -Path $Folder) {
        write-host "Removing Folder  $Folder..."
        rmdir $Folder -recurse -force -ErrorAction SilentlyContinue
    }
    
}

foreach ($iteration in $Solarwinds) {
    if (Test-Path -Path $iteration) {
    
        write-host -ForegroundColor Red "$iteration is still present. Try running script again"

   }
}

  write-host "Script and removal is complete. Review any errors and manually inspect if needed"