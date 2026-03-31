<#
.SYNOPSIS
    Interactively installs specific versions of QuickBooks Desktop and the QuickBooks Tool Hub.
.DESCRIPTION
    This script provides a menu-driven interface for users to select an installation type
    (Workstation or Server), choose a QuickBooks version from a predefined list, and
    install it using either a provided license or a temporary evaluation license.
    It downloads all installers directly from Intuit and handles required dependencies.
.NOTES
    Author:  Alex Ivantsov
    Date:    August 28, 2025
    Version: 1.1
#>

#------------------------------------------------------------------------------------
# --- USER-CONFIGURABLE VARIABLES ---
#------------------------------------------------------------------------------------

# This array holds the QuickBooks versions available for installation.
# To add a new version, find its download URL and product number from Intuit's website
# and add a new [PSCustomObject] entry to the list below following the same format.
$QBVersions = @(
    # QuickBooks Pro
    [PSCustomObject]@{Name = 'QuickBooks Pro 2023'; ProductNumber = '401228'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2023/Latest/QuickBooksProSub2023.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Pro 2022'; ProductNumber = '917681'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2022/Latest/QuickBooksProSub2022.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Pro 2021'; ProductNumber = '222750'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2021/Latest/QuickBooksPro2021.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Pro 2020'; ProductNumber = '748990'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2020/Latest/QuickBooksPro2020.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Pro 2019'; ProductNumber = '102058'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2019/Latest/QuickBooksPro2019.exe' }

    # QuickBooks Premier
    [PSCustomObject]@{Name = 'QuickBooks Premier 2023'; ProductNumber = '757611'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2023/Latest/QuickBooksPremierSub2023.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Premier 2022'; ProductNumber = '747060'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2022/Latest/QuickBooksPremier2022.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Premier 2021'; ProductNumber = '622091'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2021/Latest/QuickBooksPremier2021.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Premier 2020'; ProductNumber = '247211'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2020/Latest/QuickBooksPremier2020.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Premier 2019'; ProductNumber = '355957'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2019/Latest/QuickBooksPremier2019.exe' }

    # QuickBooks Enterprise
    [PSCustomObject]@{Name = 'QuickBooks Enterprise 24'; ProductNumber = '045169'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2024/Latest/QuickBooksEnterprise24.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Enterprise 23'; ProductNumber = '916783'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2023/Latest/QuickBooksEnterprise23.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Enterprise 22'; ProductNumber = '029966'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2022/Latest/QuickBooksEnterprise22.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Enterprise 21'; ProductNumber = '176962'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2021/Latest/QuickBooksEnterprise21.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Enterprise 20'; ProductNumber = '194238'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2020/Latest/QuickBooksEnterprise20.exe' }

    # QuickBooks Enterprise Accountant
    [PSCustomObject]@{Name = 'QuickBooks Enterprise 23 - Accountant'; ProductNumber = '334562'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2023/Latest/QuickBooksEnterprise23.exe' }
    [PSCustomObject]@{Name = 'QuickBooks Enterprise 22 - Accountant'; ProductNumber = '884649'; URL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/2022/Latest/QuickBooksEnterprise22.exe' }
)

#------------------------------------------------------------------------------------
# --- HELPER & SYSTEM FUNCTIONS ---
#------------------------------------------------------------------------------------

Function Confirm-IsAdmin {
    <#
    .SYNOPSIS
        Checks if the script is running with Administrator privileges and exits if not.
    #>
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "This script must be run with Administrator privileges. Please re-launch as an Administrator."
        Start-Sleep -Seconds 5
        exit 1
    }
}

Function Set-ExecutionEnvironment {
    <#
    .SYNOPSIS
        Configures PowerShell settings for script execution (TLS 1.2, Progress Bar).
    #>
    $ProgressPreference = 'SilentlyContinue'
    try {
        if ([Net.ServicePointManager]::SecurityProtocol -notcontains 'Tls12') {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        }
    }
    catch {
        Write-Warning "Could not set TLS 1.2 protocol. Downloads may fail."
    }
}

Function Install-XPSDocumentWriter {
    <#
    .SYNOPSIS
        Installs the "Microsoft XPS Document Writer" feature required for QuickBooks PDF functions.
    #>
    try {
        $XPSFeature = Get-WindowsOptionalFeature -Online -FeatureName 'Printing-XPSServices-Features' -ErrorAction Stop
        if ($XPSFeature.State -eq 'Disabled') {
            Write-Host "Installing required PDF components (Microsoft XPS Document Writer)..." -ForegroundColor Yellow
            Enable-WindowsOptionalFeature -Online -FeatureName 'Printing-XPSServices-Features' -All -NoRestart | Out-Null
            Write-Host "Component installation complete." -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Unable to install the Microsoft XPS Document Writer feature. QuickBooks PDF functions may not work correctly."
        Write-Warning "Error: $($_.Exception.Message)"
    }
}

#------------------------------------------------------------------------------------
# --- INSTALLATION FUNCTIONS ---
#------------------------------------------------------------------------------------

Function Install-QuickBooks {
    <#
    .SYNOPSIS
        Handles the download and silent installation of the selected QuickBooks version.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$QuickBooks,

        [Parameter(Mandatory = $true)]
        [String]$LicenseNumber
    )

    $installerName = ($QuickBooks.URL -Split '/')[-1]
    $tempInstallerPath = Join-Path -Path $env:TEMP -ChildPath $installerName

    try {
        # Download the installer directly from Intuit's servers.
        Write-Host "Downloading $($QuickBooks.Name) installer..." -ForegroundColor Cyan
        Write-Host "URL: $($QuickBooks.URL)"
        Invoke-WebRequest -Uri $QuickBooks.URL -OutFile $tempInstallerPath

        # Perform the silent installation.
        Write-Host "Installing... This may take several minutes." -ForegroundColor Yellow
        $arguments = "-s -a QBMIGRATOR=1 MSICOMMAND=/s QB_PRODUCTNUM=$($QuickBooks.ProductNumber) QB_LICENSENUM=$LicenseNumber"
        Start-Process -FilePath $tempInstallerPath -ArgumentList $arguments -Wait -NoNewWindow
        
        Write-Host "$($QuickBooks.Name) installation complete." -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred during the installation of $($QuickBooks.Name)."
        Write-Error $_.Exception.Message
    }
    finally {
        # Clean up the temporary installer file.
        if (Test-Path -Path $tempInstallerPath) {
            Remove-Item $tempInstallerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

Function Install-ToolHub {
    <#
    .SYNOPSIS
        Handles the download and silent installation of the QuickBooks Tool Hub.
    #>
    $ToolHubURL = 'https://dlm2.download.intuit.com/akdlm/SBD/QuickBooks/QBFDT/QuickBooksToolHub.exe'
    $installerName = ($ToolHubURL -Split '/')[-1]
    $tempInstallerPath = Join-Path -Path $env:TEMP -ChildPath $installerName

    try {
        # Download the installer directly from Intuit.
        Write-Host "Downloading QuickBooks Tool Hub installer..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $ToolHubURL -OutFile $tempInstallerPath
        
        # Perform the silent installation.
        Write-Host "Installing Tool Hub... This may take a moment." -ForegroundColor Yellow
        Start-Process -FilePath $tempInstallerPath -ArgumentList '/S /v/qn' -Wait -NoNewWindow

        Write-Host "QuickBooks Tool Hub installation complete." -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred during the installation of the Tool Hub."
        Write-Error $_.Exception.Message
    }
    finally {
        # Clean up the temporary installer file.
        if (Test-Path -Path $tempInstallerPath) {
            Remove-Item $tempInstallerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

#------------------------------------------------------------------------------------
# --- INTERACTIVE & WORKFLOW FUNCTIONS ---
#------------------------------------------------------------------------------------

Function Get-UserLicenseNumber {
    <#
    .SYNOPSIS
        Prompts the user to enter a license or use a default evaluation license.
    #>
    do {
        $choice = Read-Host "`nDo you have a QuickBooks License Number to enter? (Y/N)"
    } until ($choice -match '^[YN]$')

    if ($choice -eq 'Y') {
        do {
            $license = Read-Host "Please enter the License Number (e.g., 1234-5678-9012-345)"
            if ([string]::IsNullOrWhiteSpace($license)) {
                Write-Warning "License Number cannot be empty. Please try again."
            }
        } until (-not [string]::IsNullOrWhiteSpace($license))
        return ($license -replace '[- ]', '')
    }
    else {
        Write-Host "Using temporary evaluation license: 0000-0000-0000-000" -ForegroundColor Yellow
        return '000000000000000'
    }
}

Function Get-UserQuickBooksSelection {
    <#
    .SYNOPSIS
        Displays a menu of available QuickBooks versions and returns the user's selection.
    #>
    Write-Host "`nPlease choose a QuickBooks version to install:" -ForegroundColor White
    
    for ($i = 0; $i -lt $QBVersions.Count; $i++) {
        Write-Host (" {0,3}. {1}" -f ($i + 1), $QBVersions[$i].Name)
    }
    Write-Host "   B. Back to Main Menu"

    do {
        $choice = Read-Host "Enter your selection (1-$($QBVersions.Count)) or B"
        if ($choice -eq 'B' -or $choice -eq 'b') { return $null }
        
        if (($choice -match '^\d+$') -and ([int]$choice -ge 1) -and ([int]$choice -le $QBVersions.Count)) {
            $isValid = $true
        }
        else {
            $isValid = $false
            Write-Warning "Invalid selection. Please enter a number between 1 and $($QBVersions.Count)."
        }
    } until ($isValid)

    return $QBVersions[[int]$choice - 1]
}

Function Start-QuickBooksInstallationWorkflow {
    <#
    .SYNOPSIS
        A helper function that orchestrates the interactive steps for a QuickBooks installation.
    .RETURNS
        $true if installation proceeds, $false if user cancels.
    #>
    $qbSelection = Get-UserQuickBooksSelection
    if (-not $qbSelection) { return $false } # User selected 'Back'

    $licenseNumber = Get-UserLicenseNumber
    Write-Host "`nPreparing to install $($qbSelection.Name)..."
    Install-XPSDocumentWriter
    Install-QuickBooks -QuickBooks $qbSelection -LicenseNumber $licenseNumber
    return $true
}

Function Show-MainMenu {
    <#
    .SYNOPSIS
        Displays the main menu of the script.
    #>
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "       QuickBooks Desktop & Tool Hub Installer"
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host
    Write-Host "Please select the installation type:"
    Write-Host "   1. QuickBooks Desktop (Workstation/Client only)"
    Write-Host "   2. QuickBooks Desktop + Tool Hub (Server/Full Install)"
    Write-Host "   3. QuickBooks Tool Hub only"
    Write-Host "   Q. Quit"
    Write-Host
    return (Read-Host "Please enter your choice")
}

#------------------------------------------------------------------------------------
# --- SCRIPT EXECUTION ---
#------------------------------------------------------------------------------------

# Run initial system checks and prepare the environment.
Confirm-IsAdmin
Set-ExecutionEnvironment

# Main script loop to display the menu until the user quits.
do {
    $menuSelection = Show-MainMenu
    
    switch ($menuSelection) {
        '1' {
            # Workstation Install
            Start-QuickBooksInstallationWorkflow | Out-Null
        }
        
        '2' {
            # Server Install
            $installCompleted = Start-QuickBooksInstallationWorkflow
            if ($installCompleted) {
                Write-Host "`nQuickBooks installation is complete. Now proceeding with Tool Hub installation." -ForegroundColor Cyan
                Install-ToolHub
            }
        }

        '3' {
            # Tool Hub Only
            Write-Host "`nPreparing to install QuickBooks Tool Hub..."
            Install-ToolHub
        }

        'Q' {
            Write-Host "Exiting script."
        }

        default {
            Write-Warning "Invalid option. Please try again."
        }
    }
    
    # Pause to allow the user to see the results before returning to the menu.
    if ($menuSelection -ne 'Q') {
        Write-Host "`nPress Enter to return to the main menu..."
        Read-Host | Out-Null
    }

} while ($menuSelection -ne 'Q')