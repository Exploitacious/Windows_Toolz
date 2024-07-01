# Load required assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to create and show the GUI
function Show-InputBoxDialog([string]$message, [string]$title, [string]$defaultText) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.Size = New-Object System.Drawing.Size(400, 400)
    $form.StartPosition = 'CenterScreen'

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(380, 20)
    $label.Text = $message
    $form.Controls.Add($label)

    $subjectTextBox = New-Object System.Windows.Forms.TextBox
    $subjectTextBox.Location = New-Object System.Drawing.Point(10, 50)
    $subjectTextBox.Size = New-Object System.Drawing.Size(360, 20)
    $subjectTextBox.Text = "Enter subject"
    $form.Controls.Add($subjectTextBox)

    $fromTextBox = New-Object System.Windows.Forms.TextBox
    $fromTextBox.Location = New-Object System.Drawing.Point(10, 80)
    $fromTextBox.Size = New-Object System.Drawing.Size(360, 20)
    $fromTextBox.Text = "Enter sender (optional)"
    $form.Controls.Add($fromTextBox)

    $toTextBox = New-Object System.Windows.Forms.TextBox
    $toTextBox.Location = New-Object System.Drawing.Point(10, 110)
    $toTextBox.Size = New-Object System.Drawing.Size(360, 20)
    $toTextBox.Text = "Enter recipient (optional)"
    $form.Controls.Add($toTextBox)

    $sentDatePicker = New-Object System.Windows.Forms.DateTimePicker
    $sentDatePicker.Location = New-Object System.Drawing.Point(10, 140)
    $sentDatePicker.Size = New-Object System.Drawing.Size(360, 20)
    $form.Controls.Add($sentDatePicker)

    $purgeTypeComboBox = New-Object System.Windows.Forms.ComboBox
    $purgeTypeComboBox.Location = New-Object System.Drawing.Point(10, 170)
    $purgeTypeComboBox.Size = New-Object System.Drawing.Size(360, 20)
    $purgeTypeComboBox.Items.Add("SoftDelete")
    $purgeTypeComboBox.Items.Add("HardDelete")
    $purgeTypeComboBox.SelectedIndex = 0
    $form.Controls.Add($purgeTypeComboBox)

    $blockSenderCheckBox = New-Object System.Windows.Forms.CheckBox
    $blockSenderCheckBox.Location = New-Object System.Drawing.Point(10, 200)
    $blockSenderCheckBox.Size = New-Object System.Drawing.Size(360, 20)
    $blockSenderCheckBox.Text = "Add sender to blocklist"
    $form.Controls.Add($blockSenderCheckBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75, 280)
    $okButton.Size = New-Object System.Drawing.Size(75, 23)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(150, 280)
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
        return $null
    }
}

# Function to add sender to blocklist
function Add-SenderToBlocklist($senderEmail) {
    try {
        # Create a new blocked sender entry
        New-TenantAllowBlockListItems -ListType Sender -Block -Entries $senderEmail -NoExpiration

        Write-Host "Sender $senderEmail has been added to the blocklist."
    }
    catch {
        Write-Host "Failed to add sender to blocklist: $_"
    }
}

# Main script execution
try {
    # Connect to Security & Compliance Center and Exchange Online
    Import-Module ExchangeOnlineManagement
    Connect-IPPSSession -UserPrincipalName (Read-Host "Enter Global Admin UPN")
    Connect-ExchangeOnline -UserPrincipalName (Read-Host "Enter Global Admin UPN")

    # Show input dialog and get search criteria
    $searchCriteria = Show-InputBoxDialog -message "Enter search criteria for malicious emails:" -title "Malicious Email Search"

    if ($searchCriteria -eq $null) {
        Write-Host "Operation cancelled by user."
        exit
    }

    # Construct content match query
    $contentMatchQuery = "subject:`"$($searchCriteria.Subject)`" AND sent:$($searchCriteria.SentDate)"
    if ($searchCriteria.From -ne "Enter sender (optional)") {
        $contentMatchQuery += " AND from:$($searchCriteria.From)"
    }
    if ($searchCriteria.To -ne "Enter recipient (optional)") {
        $contentMatchQuery += " AND to:$($searchCriteria.To)"
    }

    # Create a unique name for the compliance search
    $searchName = "MaliciousEmail-" + (Get-Date).ToString("yyyyMMddHHmmss")

    # Create and start the compliance search
    Write-Host "Creating and starting compliance search..."
    New-ComplianceSearch -Name $searchName -ExchangeLocation All -ContentMatchQuery $contentMatchQuery
    Start-ComplianceSearch -Identity $searchName

    # Wait for the search to complete
    do {
        Start-Sleep -Seconds 5
        $searchStatus = (Get-ComplianceSearch -Identity $searchName).Status
        Write-Host "Search status: $searchStatus"
    } while ($searchStatus -ne "Completed")

    # Display search results
    $searchResults = Get-ComplianceSearch -Identity $searchName
    Write-Host "Search completed. Items found: $($searchResults.Items)"

    # Prompt user for confirmation before purging
    $confirmation = Read-Host "Do you want to proceed with purging these items? (Y/N)"
    if ($confirmation -eq 'Y') {
        # Create and start the purge action
        Write-Host "Starting purge action..."
        New-ComplianceSearchAction -SearchName $searchName -Purge -PurgeType $searchCriteria.PurgeType

        # Wait for the purge to complete
        do {
            Start-Sleep -Seconds 5
            $purgeStatus = (Get-ComplianceSearchAction -Identity "${searchName}_Purge").Status
            Write-Host "Purge status: $purgeStatus"
        } while ($purgeStatus -ne "Completed")

        # Display final purge results
        $purgeResults = Get-ComplianceSearchAction -Identity "${searchName}_Purge"
        Write-Host "Purge completed. Results:"
        $purgeResults | Format-List
    }
    else {
        Write-Host "Purge operation cancelled by user."
    }

    # Add sender to blocklist if option was selected
    if ($searchCriteria.BlockSender -and $searchCriteria.From -ne "Enter sender (optional)") {
        $blockConfirmation = Read-Host "Do you want to add the sender $($searchCriteria.From) to the blocklist? (Y/N)"
        if ($blockConfirmation -eq 'Y') {
            Add-SenderToBlocklist $searchCriteria.From
        }
        else {
            Write-Host "Sender blocking cancelled by user."
        }
    }
}
catch {
    Write-Host "An error occurred: $_"
}
finally {
    # Disconnect the sessions
    Get-PSSession | Remove-PSSession
    Disconnect-ExchangeOnline -Confirm:$false
}