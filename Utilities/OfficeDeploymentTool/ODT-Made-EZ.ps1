<#
.SYNOPSIS
    A comprehensive script to customize and deploy Microsoft 365 Apps, Project, and Visio
    using the Office Deployment Tool (ODT).

.DESCRIPTION
    This script automates the entire process of creating a custom Microsoft 365 deployment.
    1.  The user defines all desired applications and settings in the "User Configuration" section.
    2.  The script downloads the latest ODT from Microsoft into a standard folder (C:\Temp\Office).
    3.  It extracts the ODT files (setup.exe).
    4.  It dynamically generates a detailed 'configuration.xml' file based on all user choices.
    5.  It starts the ODT setup process with the generated configuration and then exits,
        allowing the installer to run independently.

.AUTHOR
    Alex Ivantsov

.DATE
    August 28, 2025
#>

#------------------------------------------------------------------------------------
# --- User Configuration ---
# Modify the variables in this section to create your perfect Office installation.
#------------------------------------------------------------------------------------

# --- Core Application Suite ---
# Set the desired Microsoft 365 applications to $true to include them or $false to exclude them.
$InstallWord = $false
$InstallExcel = $true
$InstallPowerPoint = $false
$InstallOutlook = $false
$InstallOneNote = $false
$InstallTeams = $false
$InstallAccess = $false
$InstallPublisher = $false
$InstallSkypeForBusiness = $false # Note: The App ID is "Lync"

# --- OneDrive Settings ---
# Set to $true to actively remove both the modern OneDrive and legacy Groove (OneDrive for Business) clients.
$RemoveAllOneDriveClients = $true

# --- Additional Products ---
# Set these to $true to install Microsoft Project or Visio alongside the core suite.
$InstallProject = $false
$InstallVisio = $false

# --- Product IDs ---
# These are the official license identifiers. Change only if you have a specific license.
# "O365ProPlusRetail" = Microsoft 365 Apps for Business/Enterprise
# "O365HomePremRetail" = Microsoft 365 Home/Personal
$CoreSuiteProductID = "O365ProPlusRetail"
$ProjectProductID = "ProjectProRetail" # Or "ProjectStdRetail"
$VisioProductID = "VisioProRetail"     # Or "VisioStdRetail"


# --- Deployment Settings ---

# Specify the architecture. Valid options: "64" or "32".
$Architecture = "64"

# Specify the update channel. "Current", "MonthlyEnterprise", "SemiAnnualPreview", "SemiAnnual".
$UpdateChannel = "Current"

# To install from a local network share, provide the path (e.g., "\\server\share\office").
# Leave blank ($null) to download directly from the Microsoft CDN.
$SourcePath = $null

# To pin the installation to a specific version, enter the build number (e.g., "16.0.15601.20148").
# Leave blank ($null) to install the latest version available on your chosen channel.
$TargetVersion = $null


# --- Language Settings ---

# Provide a list of languages to install. The first language in the list will be the primary one.
# Format: "en-us", "es-es", "fr-fr", "de-de", etc.
$LanguageIDs = @(
    "en-us"
    # "es-es" # Example of adding a second language
)

# --- Advanced Behavior ---

# Automatically remove all older MSI (Windows Installer) versions of Office.
$RemoveOlderMSI = $true

# Set the display level for the installer. "Full" shows the installation progress; "None" is silent.
$DisplayLevel = "None"

# For use in Remote Desktop Services (RDS) or shared computer environments.
$EnableSharedComputerLicensing = $true

# Attempt to automatically activate the product.
$AutomaticallyActivate = $true


#------------------------------------------------------------------------------------
# --- Script Functions ---
# Do not modify the code below this line.
#------------------------------------------------------------------------------------

Function Initialize-ODTEnvironment {
    <#
    .SYNOPSIS
        Creates a directory for ODT files and downloads the tool.
    #>
    param (
        [string]$DownloadUrl,
        [string]$WorkDirectory
    )

    Write-Host "Initializing environment..." -ForegroundColor Cyan
    if (-not (Test-Path -Path $WorkDirectory)) {
        try {
            New-Item -Path $WorkDirectory -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Successfully created working directory: $WorkDirectory"
        }
        catch {
            Write-Error "Failed to create working directory. Please check permissions."
            Exit 1
        }
    }

    $odtDownloaderPath = Join-Path -Path $WorkDirectory -ChildPath "officedeploymenttool.exe"
    Write-Host "Downloading the Office Deployment Tool..."
    try {
        # Using PowerShell's WebClient for broader compatibility
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($DownloadUrl, $odtDownloaderPath)
        Write-Host "Download complete." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download the Office Deployment Tool from '$DownloadUrl'."
        Exit 1
    }
    return $odtDownloaderPath
}

Function Extract-ODTFiles {
    <#
    .SYNOPSIS
        Extracts the ODT setup.exe from the downloaded executable.
    #>
    param (
        [string]$DownloaderPath,
        [string]$ExtractionPath
    )

    Write-Host "Extracting ODT files..."
    try {
        $arguments = "/extract:$ExtractionPath /quiet /norestart"
        Start-Process -FilePath $DownloaderPath -ArgumentList $arguments -Wait -ErrorAction Stop
        Write-Host "Extraction complete." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to extract the Office Deployment Tool."
        Exit 1
    }
}

Function Generate-ConfigurationXML {
    <#
    .SYNOPSIS
        Builds the complete configuration.xml content based on all user settings.
    #>
    param (
        [hashtable]$Settings
    )

    Write-Host "Generating configuration.xml..."
    $xmlWriter = New-Object System.IO.StringWriter
    $xml = New-Object System.XML.XmlTextWriter $xmlWriter
    $xml.Formatting = 'Indented'

    # <Configuration>
    $xml.WriteStartElement("Configuration")

    # <Add ...>
    $xml.WriteStartElement("Add")
    $xml.WriteAttributeString("OfficeClientEdition", $Settings.Architecture)
    $xml.WriteAttributeString("Channel", $Settings.UpdateChannel)
    if (-not ([string]::IsNullOrEmpty($Settings.SourcePath))) {
        $xml.WriteAttributeString("SourcePath", $Settings.SourcePath)
    }
    if (-not ([string]::IsNullOrEmpty($Settings.TargetVersion))) {
        $xml.WriteAttributeString("Version", $Settings.TargetVersion)
    }

    # --- Core Office Suite Product ---
    $xml.WriteStartElement("Product")
    $xml.WriteAttributeString("ID", $Settings.CoreSuiteProductID)
    foreach ($lang in $Settings.LanguageIDs) {
        $xml.WriteStartElement("Language")
        $xml.WriteAttributeString("ID", $lang)
        $xml.WriteEndElement() # Language
    }
    
    # --- Exclude Apps Logic ---
    if (-not $Settings.InstallWord) { $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "Word"); $xml.WriteEndElement() }
    if (-not $Settings.InstallExcel) { $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "Excel"); $xml.WriteEndElement() }
    if (-not $Settings.InstallPowerPoint) { $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "PowerPoint"); $xml.WriteEndElement() }
    if (-not $Settings.InstallOutlook) { $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "Outlook"); $xml.WriteEndElement() }
    if (-not $Settings.InstallOneNote) { $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "OneNote"); $xml.WriteEndElement() }
    if (-not $Settings.InstallTeams) { $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "Teams"); $xml.WriteEndElement() }
    if (-not $Settings.InstallAccess) { $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "Access"); $xml.WriteEndElement() }
    if (-not $Settings.InstallPublisher) { $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "Publisher"); $xml.WriteEndElement() }
    if (-not $Settings.InstallSkypeForBusiness) { $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "Lync"); $xml.WriteEndElement() }
    
    # --- ADDED: OneDrive Exclusion Logic ---
    if ($Settings.RemoveAllOneDriveClients) {
        $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "OneDrive"); $xml.WriteEndElement() # Modern Client
        $xml.WriteStartElement("ExcludeApp"); $xml.WriteAttributeString("ID", "Groove"); $xml.WriteEndElement()   # Legacy Client
    }
    
    $xml.WriteEndElement() # Product (Core)

    # --- Visio Product (Optional) ---
    if ($Settings.InstallVisio) {
        $xml.WriteStartElement("Product")
        $xml.WriteAttributeString("ID", $Settings.VisioProductID)
        $xml.WriteStartElement("Language"); $xml.WriteAttributeString("ID", "MatchOS"); $xml.WriteEndElement()
        $xml.WriteEndElement() # Product (Visio)
    }

    # --- Project Product (Optional) ---
    if ($Settings.InstallProject) {
        $xml.WriteStartElement("Product")
        $xml.WriteAttributeString("ID", $Settings.ProjectProductID)
        $xml.WriteStartElement("Language"); $xml.WriteAttributeString("ID", "MatchOS"); $xml.WriteEndElement()
        $xml.WriteEndElement() # Product (Project)
    }

    $xml.WriteEndElement() # Add

    # --- Other Settings ---
    if ($Settings.RemoveOlderMSI) {
        $xml.WriteElementString("RemoveMSI", $null)
    }

    $xml.WriteStartElement("Display")
    $xml.WriteAttributeString("Level", $Settings.DisplayLevel)
    $xml.WriteAttributeString("AcceptEULA", "TRUE")
    $xml.WriteEndElement() # Display

    $sharedLicensingValue = "0"; if ($Settings.EnableSharedComputerLicensing) { $sharedLicensingValue = "1" }
    $xml.WriteStartElement("Property"); $xml.WriteAttributeString("Name", "SharedComputerLicensing"); $xml.WriteAttributeString("Value", $sharedLicensingValue); $xml.WriteEndElement()

    $autoActivateValue = "0"; if ($Settings.AutomaticallyActivate) { $autoActivateValue = "1" }
    $xml.WriteStartElement("Property"); $xml.WriteAttributeString("Name", "AUTOACTIVATE"); $xml.WriteAttributeString("Value", $autoActivateValue); $xml.WriteEndElement()

    $xml.WriteEndElement() # Configuration
    $xml.Close()

    Write-Host "Configuration generated successfully." -ForegroundColor Green
    return $xmlWriter.ToString()
}

Function Start-ODTDeployment {
    <#
    .SYNOPSIS
        Starts the Office Deployment Tool with the specified configuration file.
    #>
    param (
        [string]$SetupPath,
        [string]$ConfigPath
    )

    Write-Host "Starting the Microsoft 365 Apps deployment..." -ForegroundColor Cyan
    Write-Host "The Office installer will now take over. This script will exit."
    try {
        $arguments = "/configure `"$ConfigPath`""
        Start-Process -FilePath $SetupPath -ArgumentList $arguments -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to start the Office Deployment Tool process."
        Exit 1
    }
}

#------------------------------------------------------------------------------------
# --- Main Script Body ---
#------------------------------------------------------------------------------------

# --- Define Constants and Paths ---
$odtWorkDir = "C:\Temp\Office"
$odtSetupExe = Join-Path -Path $odtWorkDir -ChildPath "setup.exe"
$configXmlPath = Join-Path -Path $odtWorkDir -ChildPath "configuration.xml"
$odtDownloadUrl = "https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_19029-20136.exe"

# --- Collect All Settings ---
$configSettings = @{
    InstallWord                   = $InstallWord
    InstallExcel                  = $InstallExcel
    InstallPowerPoint             = $InstallPowerPoint
    InstallOutlook                = $InstallOutlook
    InstallOneNote                = $InstallOneNote
    InstallTeams                  = $InstallTeams
    InstallAccess                 = $InstallAccess
    InstallPublisher              = $InstallPublisher
    InstallSkypeForBusiness       = $InstallSkypeForBusiness
    RemoveAllOneDriveClients      = $RemoveAllOneDriveClients
    InstallProject                = $InstallProject
    InstallVisio                  = $InstallVisio
    CoreSuiteProductID            = $CoreSuiteProductID
    ProjectProductID              = $ProjectProductID
    VisioProductID                = $VisioProductID
    Architecture                  = $Architecture
    UpdateChannel                 = $UpdateChannel
    SourcePath                    = $SourcePath
    TargetVersion                 = $TargetVersion
    LanguageIDs                   = $LanguageIDs
    RemoveOlderMSI                = $RemoveOlderMSI
    DisplayLevel                  = $DisplayLevel
    EnableSharedComputerLicensing = $EnableSharedComputerLicensing
    AutomaticallyActivate         = $AutomaticallyActivate
}

# --- Execution Flow ---
$odtDownloader = Initialize-ODTEnvironment -DownloadUrl $odtDownloadUrl -WorkDirectory $odtWorkDir
Extract-ODTFiles -DownloaderPath $odtDownloader -ExtractionPath $odtWorkDir

$configFileContent = Generate-ConfigurationXML -Settings $configSettings
$configFileContent | Out-File -FilePath $configXmlPath -Encoding UTF8 -Force

if (Test-Path -Path $odtSetupExe) {
    Start-ODTDeployment -SetupPath $odtSetupExe -ConfigPath $configXmlPath
}
else {
    Write-Error "setup.exe not found in '$odtWorkDir'. Aborting."
    Exit 1
}

Write-Host "`nScript has finished. The Office Deployment Tool is running." -ForegroundColor Yellow
Write-Host "You can manually delete the '$odtWorkDir' folder after the installation is complete." -ForegroundColor Yellow

# --- End of Script ---