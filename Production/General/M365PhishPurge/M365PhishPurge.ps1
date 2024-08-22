## M365 Phish Purge
# Automated Email search and removal with Power + M365 Compliance Center 

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "This script requires PowerShell 5.1 or later. Your version is $($PSVersionTable.PSVersion). Please upgrade PowerShell and try again." -ForegroundColor Red
    exit
}

# Verify/Elevate Admin Session.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit 
}

Write-Host "         .___  ___.  ____      __    _____     .______    __    __   __       _______. __    __                 "
Write-Host "         |   \/   | |___ \    / /   | ____|    |   _  \  |  |  |  | |  |     /       ||  |  |  |                "
Write-Host "         |  \  /  |   __) |  / /_   | |__      |  |_)  | |  |__|  | |  |    |   (----'|  |__|  |                "
Write-Host "         |  |\/|  |  |__ <  | '_ \  |___ \     |   ___/  |   __   | |  |     \   \    |   __   |                "
Write-Host "         |  |  |  |  ___) | | (_) |  ___) |    |  |      |  |  |  | |  | .----)   |   |  |  |  |                "
Write-Host "         |__|  |__| |____/   \___/  |____/     | _|      |__|  |__| |__| |_______/    |__|  |__|                "
Write-Host "                                                                                                                "
Write-Host "     ___      .__   __. .__   __.  __   __    __   __   __          ___   .___________.  ______   .______       "
Write-Host "    /   \     |  \ |  | |  \ |  | |  | |  |  |  | |  | |  |        /   \  |           | /  __  \  |   _  \      "
Write-Host "   /  ^  \    |   \|  | |   \|  | |  | |  |__|  | |  | |  |       /  ^  \ '---|  |----'|  |  |  | |  |_)  |     "
Write-Host "  /  /_\  \   |  . '  | |  . '  | |  | |   __   | |  | |  |      /  /_\  \    |  |     |  |  |  | |      /      "
Write-Host " /  _____  \  |  |\   | |  |\   | |  | |  |  |  | |  | |  '----./  _____  \   |  |     |  '--'  | |  |\  \----. "
Write-Host "/__/     \__\ |__| \__| |__| \__| |__| |__|  |__| |__| |_______/__/     \__\  |__|      \______/  | _| '._____| "
Write-Host "                                                                                                                "
Write-Host
Write-Host "Created by Alex Ivantsov @Exploitacious"
Write-Host
Write-Host

# Specify the log file path
$logFile = Join-Path $PSScriptRoot "PurgeOp_$(Get-Date -Format 'yyyyMMdd_HH-mm').log"

# Function to write log messages
function Write-Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

# Function to display the log file contents
function Display-LogFile {
    param (
        [string]$logFile
    )

    if (Test-Path $logFile) {
        Write-Host
        Write-Host "Search and Purge Operations Completed" -ForegroundColor Green
        Write-Host "=================="
        Get-Content -Path $logFile | ForEach-Object { Write-Host $_ }
        Write-Host "=================="
        Write-Host "Log file path: $logFile"
    }
    else {
        Write-Host "Log file not found: $logFile"
    }
}

# Load required assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to create and show the GUI
function Show-InputBoxDialog([string]$message, [string]$title, [string]$defaultText) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.Size = New-Object System.Drawing.Size(400, 450)
    $form.StartPosition = 'CenterScreen'

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(380, 40)
    $label.Text = $message
    $form.Controls.Add($label)

    $subjectTextBox = New-Object System.Windows.Forms.TextBox
    $subjectTextBox.Location = New-Object System.Drawing.Point(10, 70)
    $subjectTextBox.Size = New-Object System.Drawing.Size(360, 20)
    $subjectTextBox.Text = "Enter subject (required)"
    $form.Controls.Add($subjectTextBox)

    $fromTextBox = New-Object System.Windows.Forms.TextBox
    $fromTextBox.Location = New-Object System.Drawing.Point(10, 100)
    $fromTextBox.Size = New-Object System.Drawing.Size(360, 20)
    $fromTextBox.Text = "Enter sender email (optional)"
    $form.Controls.Add($fromTextBox)

    $toTextBox = New-Object System.Windows.Forms.TextBox
    $toTextBox.Location = New-Object System.Drawing.Point(10, 130)
    $toTextBox.Size = New-Object System.Drawing.Size(360, 20)
    $toTextBox.Text = "Enter recipient email (optional)"
    $form.Controls.Add($toTextBox)

    $sentDatePicker = New-Object System.Windows.Forms.DateTimePicker
    $sentDatePicker.Location = New-Object System.Drawing.Point(10, 160)
    $sentDatePicker.Size = New-Object System.Drawing.Size(360, 20)
    $form.Controls.Add($sentDatePicker)

    $purgeTypeComboBox = New-Object System.Windows.Forms.ComboBox
    $purgeTypeComboBox.Location = New-Object System.Drawing.Point(10, 190)
    $purgeTypeComboBox.Size = New-Object System.Drawing.Size(360, 20)
    $purgeTypeComboBox.Items.Add("SoftDelete")
    $purgeTypeComboBox.Items.Add("HardDelete")
    $purgeTypeComboBox.SelectedIndex = 0
    $form.Controls.Add($purgeTypeComboBox)

    $blockSenderCheckBox = New-Object System.Windows.Forms.CheckBox
    $blockSenderCheckBox.Location = New-Object System.Drawing.Point(10, 220)
    $blockSenderCheckBox.Size = New-Object System.Drawing.Size(360, 20)
    $blockSenderCheckBox.Text = "Add sender to blocklist"
    $form.Controls.Add($blockSenderCheckBox)

    $instructionsLabel = New-Object System.Windows.Forms.Label
    $instructionsLabel.Location = New-Object System.Drawing.Point(10, 250)
    $instructionsLabel.Size = New-Object System.Drawing.Size(380, 80)
    $instructionsLabel.Text = "Instructions:`r`n- Subject is required`r`n- Sender and recipient are optional`r`n- Select the date the email was received`r`n- Choose purge type (Soft/Hard Delete)`r`n- Check the box to add sender to blocklist"
    $form.Controls.Add($instructionsLabel)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75, 340)
    $okButton.Size = New-Object System.Drawing.Size(75, 23)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(150, 340)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 23)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return @{
            Subject     = $subjectTextBox.Text
            From        = $fromTextBox.Text
            To          = $toTextBox.Text
            SentDate    = $sentDatePicker.Value.ToString("MM/dd/yyyy")
            PurgeType   = $purgeTypeComboBox.SelectedItem
            BlockSender = $blockSenderCheckBox.Checked
        }
    }
    else {
        return [System.Windows.Forms.DialogResult]::Cancel
    }
}

# Function to add sender to blocklist
function Add-SenderToBlocklist($senderEmail) {
    try {
        # Create a new blocked sender entry
        New-TenantAllowBlockListItems -ListType Sender -Block -Entries $senderEmail -NoExpiration
        Write-Log "Sender $senderEmail has been added to the blocklist."
    }
    catch {
        Write-Log "Failed to add sender to blocklist: $_"
    }
}

# Function to display detailed search results
function Display-SearchResults($searchName) {
    $searchResults = Get-ComplianceSearch -Identity $searchName
    Write-Host "`nDetailed Search Results:"
    Write-Log "Total Items Found: $($searchResults.Items)"
    Write-Host "Locations Searched: $($searchResults.NumberOfMailboxesProcessed)"
    
    $contentMatchQuery = $searchResults.ContentMatchQuery
    Write-Log "Search Query: $contentMatchQuery"

    # Get more details about the found items
    $statistics = $searchResults | Select-Object -ExpandProperty SearchStatistics | ConvertFrom-Json
    if ($statistics.ExchangeBinding.SuccessResults) {
        $exchangeStats = $statistics.ExchangeBinding.SuccessResults | Select-Object -First 1
        Write-Log "`nTop Locations with Results:"
        foreach ($location in $exchangeStats.LocationsWithResults) {
            Write-Log "- $($location.Name): $($location.ItemsInLocation) item(s)"
        }
    }
}

# Function to confirm email deletion
function Confirm-EmailDeletion($searchName, $purgeType) {
    $purgeAction = Get-ComplianceSearchAction -Identity "${searchName}_Purge"
    $purgedItemCount = $purgeAction.Results -replace '.*Items removed: ([0-9]+).*', '$1'
    
    Write-Host "`nPurge Confirmation:"
    Write-Log "Purge Type: $purgeType"
    Write-Log "Items Purged: $purgedItemCount"
    
    if ($purgeType -eq "HardDelete") {
        Write-Log "Items have been permanently deleted and are not recoverable."
    }
    else {
        Write-Log "Items have been moved to the Recoverable Items folder and can be restored by users or administrators."
    }
}

# Module Update Function
function Update-Module {
    param (
        [string]$Module
    )
    
    $modulesSummary = @()
    $currentVersion = $null
    if ($null -ne (Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue)) {
        $currentVersion = (Get-InstalledModule -Name $module -AllVersions | Sort-Object Version -Descending)[0].Version
    }

    $CurrentModule = Find-Module -Name $module

    $status = "Unknown"
    $version = "N/A"

    Write-Host "Checking status of module: $Module"

    if ($Module -eq "ExchangeOnlineManagement") {
        $minimumVersion = [System.Version]"3.2"
        if ($currentVersion -lt $minimumVersion -or $null -eq $currentVersion) {
            Write-Host "Status: ExchangeOnlineManagement module is not installed or below the minimum required version ($minimumVersion)."
            Write-Host "Uninstalling any existing versions and installing the latest version."
            
            try {
                if ($null -ne $currentVersion) {
                    Uninstall-Module -Name $Module -AllVersions -Force
                    Write-Host "Successfully uninstalled existing versions of ExchangeOnlineManagement."
                }
                
                Install-Module -Name $Module -Force -AllowClobber
                $newVersion = (Get-InstalledModule -Name $Module).Version
                Write-Host "Successfully installed ExchangeOnlineManagement version $newVersion."
                $status = "Updated"
                $version = $newVersion
            }
            catch {
                Write-Host "Status: Update failed"
                Write-Host "Something went wrong with uninstalling or installing ExchangeOnlineManagement. Details:"
                Write-Host -ForegroundColor red "$($_.Exception.Message)"
                $status = "Update Failed"
            }
            
            $modulesSummary += [PSCustomObject]@{
                Module  = $Module
                Status  = $status
                Version = $version
            }
            return $modulesSummary
        }
    }

    if ($null -eq $currentVersion) {
        Write-Host "Status: Not installed"
        Write-Host "$($CurrentModule.Name) - Installing $Module from PowerShellGallery. Version: $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)"
        try {
            Install-Module -Name $module -Force
            $status = "Installed"
            $version = $CurrentModule.Version
            Write-Host "Status: Successfully installed version $version"
        }
        catch {
            Write-Host "Status: Installation failed"
            Write-Host "Something went wrong when installing $Module. Please uninstall and try re-installing this module. (Remove-Module, Install-Module) Details:"
            Write-Host "$($_.Exception.Message)"
            $status = "Installation Failed"
        }
    }
    elseif ($CurrentModule.Version -eq $currentVersion) {
        Write-Host "Status: Up to date"
        Write-Host "$($CurrentModule.Name) is installed and up to date. Version: $currentVersion. Release date: $($CurrentModule.PublishedDate)"
        $status = "Up to Date"
        $version = $currentVersion
    }
    elseif ((Get-InstalledModule -Name $module -AllVersions).Count -gt 1) {
        Write-Host "Status: Multiple versions detected"
        $allVersions = (Get-InstalledModule -Name $module -AllVersions).Version -join ' | '
        Write-Warning "$module is installed in multiple versions (versions: $allVersions)"
        Write-Host "Uninstalling previous $module versions and will attempt to update."
        try {
            Get-InstalledModule -Name $module -AllVersions | Where-Object { $_.Version -ne $CurrentModule.Version } | Uninstall-Module -Force
            Write-Host "Successfully uninstalled previous versions"
        }
        catch {
            Write-Host "Status: Uninstallation of previous versions failed"
            Write-Host "Something went wrong with Uninstalling $Module previous versions. Please Completely uninstall and re-install this module. (Remove-Module) Details:"
            Write-Host -ForegroundColor red "$($_.Exception.Message)"
            $status = "Uninstallation Failed"
            $modulesSummary += [PSCustomObject]@{
                Module  = $Module
                Status  = $status
                Version = $version
            }
            return $modulesSummary
        }
        
        Write-Host "$($CurrentModule.Name) - Installing latest version from PowerShellGallery $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)"  
    
        try {
            Install-Module -Name $module -Force
            Write-Host "Status: Successfully updated to version $($CurrentModule.Version)"
            $status = "Updated"
            $version = $CurrentModule.Version
        }
        catch {
            Write-Host "Status: Update failed"
            Write-Host "Something went wrong with installing $Module. Details:"
            Write-Host -ForegroundColor red "$($_.Exception.Message)"
            $status = "Update Failed"
        }
    }
    else {       
        Write-Host "Status: Update available"
        Write-Host "$($CurrentModule.Name) - Updating from PowerShellGallery from version $currentVersion to $($CurrentModule.Version). Release date: $($CurrentModule.PublishedDate)" 
        try {
            Update-Module -Name $module -Force
            Write-Host "Status: Successfully updated to version $($CurrentModule.Version)"
            $status = "Updated"
            $version = $CurrentModule.Version
        }
        catch {
            Write-Host "Status: Update failed"
            Write-Host "Something went wrong with updating $Module. Details:"
            Write-Host -ForegroundColor red "$($_.Exception.Message)"
            $status = "Update Failed"
        }
    }

    $modulesSummary += [PSCustomObject]@{
        Module  = $Module
        Status  = $status
        Version = $version
    }

    return $modulesSummary
}

# Module Connect Funciton
function Advanced-ConnectModule {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("ExchangeOnline", "IPPSSession")]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential
    )

    Write-Host

    try {
        # Define a mapping of friendly names to actual module names
        $moduleMapping = @{
            "ExchangeOnline" = "ExchangeOnlineManagement"
            "IPPSSession"    = "ExchangeOnlineManagement"  # IPPSSession is also part of ExchangeOnlineManagement
        }

        $actualModuleName = $moduleMapping[$ModuleName]

        # Check if the module is installed
        if (-not (Get-Module -ListAvailable -Name $actualModuleName)) {
            Write-Host "Module $actualModuleName is not installed. Attempting to install..." -ForegroundColor Yellow
            try {
                Install-Module -Name $actualModuleName -Force -AllowClobber -Scope CurrentUser
                Write-Host "Successfully installed $actualModuleName module." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to install $actualModuleName module. Please install it manually and try again. Error: $_" -ForegroundColor Red
                return $false
            }
        }

        # Import the module
        Import-Module $actualModuleName -ErrorAction Stop
        $moduleVersion = (Get-Module $actualModuleName).Version
        Write-Host "$actualModuleName module version $moduleVersion imported successfully." -ForegroundColor Green
        Write-Host

        # Connect to the module
        switch ($ModuleName) {
            "ExchangeOnline" {
                Write-Host
                Write-Host
                Write-Host -ForegroundColor Yellow "Please satisfy MFA"
                Write-Host
                Connect-ExchangeOnline -UserPrincipalName $Credential.UserName -ShowBanner:$false -ErrorAction Stop
                # Test the connection by running a simple query
                $testResult = Get-AcceptedDomain | Where-Object { $_.Default -eq $true } | Select-Object -ExpandProperty DomainName
                if (-not $testResult) {
                    throw "Unable to retrieve primary domain name."
                }
                Write-Host "Successfully connected to Exchange Online. Primary domain: $testResult" -ForegroundColor Green
                Write-Host
            }
            "IPPSSession" {
                Connect-IPPSSession -UserPrincipalName $Credential.UserName -ShowBanner:$false -ErrorAction Stop
                # Test the connection by running a simple query
                $testResult = Get-OrganizationConfig | Select-Object -ExpandProperty Identity
                if (-not $testResult) {
                    throw "Unable to retrieve domain. Module may not be functional"
                }
                Write-Host "Successfully connected to Compliance Center. Microsoft Domain: $testResult" -ForegroundColor Green
                Write-Host
            }
        }

        return $true
    }
    catch {
        Write-Host "Error connecting to $ModuleName : $_" -ForegroundColor Red
        return $false
    }
}

# Main logic for Search and Purge
function Start-PhishPurgeProcess {
    try {
        # Show input dialog and get search criteria
        $searchCriteria = Show-InputBoxDialog -message "Enter search criteria for malicious emails:" -title "Malicious Email Search"

        if ($searchCriteria -eq [System.Windows.Forms.DialogResult]::Cancel) {
            Write-Host -ForegroundColor Red "Operation cancelled by user."
            exit
        }

        # The rest of your logic
        # Construct content match query (simplified)
        $contentMatchQuery = "subject:`"$($searchCriteria.Subject)`""
        if ($searchCriteria.From -ne "Enter sender email (optional)") {
            $contentMatchQuery += " AND from:$($searchCriteria.From)"
        }

        # Create a unique name for the compliance search
        $searchName = "MaliciousEmail-" + (Get-Date).ToString("yyyyMMddHHmmss")

        # Create and start the compliance search
        Write-Log "Creating and starting compliance search..."
        Write-Host
        New-ComplianceSearch -Name $searchName -ExchangeLocation All -ContentMatchQuery $contentMatchQuery
        Start-ComplianceSearch -Identity $searchName

        # Wait for the search to complete
        Write-Host "Checking status every 5 seconds..."
        Write-Host
        do {
            Start-Sleep -Seconds 5
            $searchStatus = (Get-ComplianceSearch -Identity $searchName).Status
            Write-Host "Search status: $searchStatus"
        } while ($searchStatus -ne "Completed")

        # Display detailed search results
        Display-SearchResults $searchName

        # Prompt user for confirmation before purging
        Write-Host
        $confirmation = Read-Host "Do you want to proceed with purging these items? (Y/N)"
        if ($confirmation -eq 'Y') {
            # Create and start the purge action
            Write-Host
            Write-Host "Starting purge action..."
            New-ComplianceSearchAction -SearchName $searchName -Purge -PurgeType $searchCriteria.PurgeType

            # Wait for the purge to complete
            Write-Host "Purge Started. Checking status every 5 seconds..."
            Write-Host
            do {
                Start-Sleep -Seconds 5
                $purgeStatus = (Get-ComplianceSearchAction -Identity "${searchName}_Purge").Status
                Write-Host "Purge status: $purgeStatus"
            } while ($purgeStatus -ne "Completed")

            # Confirm email deletion
            Confirm-EmailDeletion $searchName $searchCriteria.PurgeType
        }
        else {
            Write-Host "Purge operation cancelled by user."
        }

        # Add sender to blocklist if option was selected
        $blockList = @()
        if ($searchCriteria.BlockSender -and $searchCriteria.From -ne "Enter sender email (optional)") {
            $blockList += $searchCriteria.From
        }

        # Allow user to add more email addresses to the block list
        do {
            Write-Host
            $additionalEmail = Read-Host "Enter any additional email addresseses to block. One at a time, pressing Enter after every address. (or press Enter to finish)"
            if ($additionalEmail -ne "") {
                $blockList += $additionalEmail
            }
        } while ($additionalEmail -ne "")

        if ($blockList.Count -gt 0) {
            Write-Host
            $blockConfirmation = Read-Host "Do you want to add the following email(s) to the blocklist? `n$($blockList -join ", ")`n(Y/N)"
            if ($blockConfirmation -eq 'Y') {
                foreach ($email in $blockList) {
                    Write-Log "Adding Email $email to Global Blocklist"
                    Add-SenderToBlocklist $email
                }
            }
            else {
                Write-Host "Sender blocking cancelled by user."
            }
        }
    }
    catch {
        Write-Host "An error occurred: $_"
    }
    Write-Host
}

############################################
# Main Script Execution
############################################

# Disconnect any active sessions
Get-PSSession | Remove-PSSession
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue

# Update Modules
Write-Host "Checking Modules..."   
Update-Module "ExchangeOnlineManagement"
Update-Module "AIPService"

# Get Creds and Log In
Write-Host
Write-Host
Write-Host -ForegroundColor Yellow "You may need to use an account with CA bypassed if your device is not registered in Azure/Intune"
Write-Host
Write-Host -ForegroundColor Green "       -= Please Enter the Global Admin Credentials for the M365 Tenant =-  "
Write-Host
Write-Host
try {
    $Credential = Get-Credential -ErrorAction Stop
}
catch {
    Write-Host -ForegroundColor Red "Credentials not entered. Exiting..."
    Read-Host ":"
    exit
}

# Connect to Security & Compliance Center and Exchange Online
if (Advanced-ConnectModule -ModuleName "ExchangeOnline" -Credential $Credential) {
    Write-Host "Exchange Online connection successful. Ready to continue." -ForegroundColor Green
}
else {
    Write-Host -ForegroundColor Red "Exchange Admin Center Connection Unsuccessful. Exiting..."
    Read-Host ":"
    exit
}

if (Advanced-ConnectModule -ModuleName "IPPSSession" -Credential $Credential) {
    Write-Host "Compliance Center connection successful. Ready to continue." -ForegroundColor Green
}
else {
    Write-Host -ForegroundColor Red "Compliance Center Connection Unsuccessful. Exiting..."
    Read-Host ":"
    exit
}

Write-Host
Write-Host "There should be no errors thus far. If you see any red, please exit the script with Ctrl-C and try again."

$Answer = Read-Host "Ready to continue? Y/N"
if ($Answer -eq 'Y' -or $Answer -eq 'yes') {
    Write-Host
    Write-Host

    # Loop over Search and Purge process as long as the user needs
    do {
        Start-PhishPurgeProcess

        $repeat = Read-Host "Do you want to perform another search and purge operation on the same tenant? ( Y / N )"
    } while ($repeat -eq 'Y')

}



# Disconnect any active sessions
Get-PSSession | Remove-PSSession
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Write-Host
Display-LogFile $logFile
Write-Host
Write-Host "Script execution completed. Use the above output to paste into the ticket before closing it."
Read-Host "All sessions have been disconnected. Press any key to EXIT"