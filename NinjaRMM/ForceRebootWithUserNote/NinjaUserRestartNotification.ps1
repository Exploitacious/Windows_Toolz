# Script Title: Forced Reboot with Countdown GUI (Immediate Trigger)
# Description: Run in USER mode. Immediately initiates a scheduled Windows shutdown, then displays a countdown GUI to the user. The user can restart immediately via the button, otherwise, Windows restarts automatically when the timer expires.

# Script Name and Type
$ScriptName = "Forced Reboot with Countdown GUI"
$ScriptType = "Remediation" 
$Date = Get-Date -Format "MM/dd/yyyy hh:mm tt"

## HARD-CODED VARIABLES ##
# Base Temp Path
$BaseDir = "C:\Temp"
$DefaultLogoUrl = "https://d15k2d11r6t6rl.cloudfront.net/pub/bfra/7b3bwo0t/yf6/ipf/oyv/SCREEN_UIT_Brandmark_Stacked_Col%20copy.png"

## CONFIG RMM VARIABLES ### Create the following variables in your NinjaRMM script configuration:
# customFieldName (Text): The name of the Text Custom Field to write the status to.
# rebootTimerMinutes (Number): The countdown timer duration in minutes (Default: 15)
# logoUrlOverride (Text): (Optional) A different URL to use for the logo instead of the hard-coded default.

# Setting Defaults if parameters are missing
if (-not $env:rebootTimerMinutes) { $env:rebootTimerMinutes = 15 }
$LogoUrl = if ($env:logoUrlOverride) { $env:logoUrlOverride } else { $DefaultLogoUrl }

# Cast variables to correct types
[int]$TimerMinutes = $env:rebootTimerMinutes
[int]$TimerSeconds = $TimerMinutes * 60

# What to Write if Alert is Healthy
# In this specific script, "Healthy" means the reboot command was successfully issued.
$Global:AlertHealthy = "Reboot sequence initiated successfully. Timer set for $TimerMinutes minutes. | Last Checked $Date"

# Log/Diagnostic Messaging
function write-RMMDiag ($messages) {
    Write-Host "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
$Global:DiagMsg = @()

# Alert Messaging
function write-RMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
$Global:AlertMsg = @()

# RMM Custom Field.
$Global:customFieldMessage = @()

# Script UID and intro messaging
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
$ScriptUID = GenRANDString 20
$Global:DiagMsg += "Script Type: $ScriptType"
$Global:DiagMsg += "Script Name: $ScriptName"
$Global:DiagMsg += "Script UID: $ScriptUID"
$Global:DiagMsg += "Executed On: $Date"

##################################
##################################
######## Start of Script #########

try {
    # 0. Global TLS & Certificate Fix
    # Force TLS 1.2 (required for modern sites) and Tls11.
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11
    
    # Bypass Certificate Validation (Fixes 'Secure Channel' errors on machines missing updated Root CAs)
    # This is safe here because we are only downloading a public logo image.
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

    # 1. Immediate Fail-Safe Trigger
    # Initiate Windows shutdown timer immediately as a fail-safe.
    $Global:DiagMsg += "Initiating Windows Shutdown Timer for $TimerSeconds seconds."
    Start-Process "shutdown.exe" -ArgumentList "/r /t $TimerSeconds /f /c `"Umbrella IT Solutions: Computer Restart Required`"" -NoNewWindow
    
    # 2. Load Windows Forms and Drawing assemblies
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Net.Http

    # 3. Define the main Form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Umbrella IT Solutions: Computer Restart Required"
    $form.StartPosition = "CenterScreen"
    # Adjusted Window Height to 550px to prevent text cutoff
    $form.Size = New-Object System.Drawing.Size(720, 550)
    $form.TopMost = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.ControlBox = $false # Hides Minimize, Maximize, and Close (X) buttons

    # --- LOGO HANDLING START ---
    $Global:DiagMsg += "Attempting to fetch logo from URL: $LogoUrl"
    $logoLoaded = $false
    $imageStream = $null
    $logoImage = $null

    try {
        # Download image data into memory
        $webClient = New-Object System.Net.WebClient
        
        # Add User-Agent to mimic a real browser (prevents 403 blocks from Wordfence/Cloudflare)
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        
        # Use default credentials for proxy authentication if needed
        $webClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
        $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        
        $imageBytes = $webClient.DownloadData($LogoUrl)
        $imageStream = New-Object System.IO.MemoryStream(, $imageBytes)
        $logoImage = [System.Drawing.Image]::FromStream($imageStream)
        $logoLoaded = $true
        $Global:DiagMsg += "Logo successfully downloaded and loaded into memory."
    }
    catch {
        $Global:DiagMsg += "Warning: Failed to download logo. The GUI will display without it. Error details: $($_.Exception.Message)"
    }

    # Create Top Panel for Logo
    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Dock = "Top"
    
    if ($logoLoaded) {
        # Setting height to 150px to allow room for the logo
        $topPanel.Height = 150 
        $topPanel.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 10) 

        $pictureBox = New-Object System.Windows.Forms.PictureBox
        $pictureBox.Image = $logoImage
        # Zoom mode scales the image to fit within bounds while preserving aspect ratio
        $pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $pictureBox.Dock = "Fill"
        $topPanel.Controls.Add($pictureBox)
    }
    else {
        # Collapse panel if no logo was loaded
        $topPanel.Height = 0
        $topPanel.Visible = $false
    }
    # --- LOGO HANDLING END ---

    # 4. Create "Restart Now" Button (Dock: Bottom)
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Restart Now"
    $okButton.Dock = "Bottom"
    $okButton.Height = 60
    $okButton.BackColor = "DarkRed"
    $okButton.ForeColor = "White"
    $okButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    
    $okButton.Add_Click({
            $Global:DiagMsg += "User clicked 'Restart Now'."
            $form.Tag = "ForceNow"
            $form.Close()
        })
    # Add Bottom control first
    $form.Controls.Add($okButton)

    # Add Top Panel second
    $form.Controls.Add($topPanel)

    # 5. Logic for Visual Countdown & Label (Dock: Fill)
    $Script:SecondsRemaining = $TimerSeconds

    # Create the Label text area
    $label = New-Object System.Windows.Forms.Label
    $label.Dock = "Fill"
    $label.TextAlign = "MiddleCenter"
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    # Add Fill control last to occupy remaining space
    $form.Controls.Add($label)

    # Function to update label text dynamically
    $UpdateLabel = {
        $ts = [timespan]::fromseconds($Script:SecondsRemaining)
        # Format minutes and seconds padding with leading zeros
        $TimeStr = "{0:00}:{1:00}" -f $ts.Minutes, $ts.Seconds
        $label.Text = "Mandatory Maintenance - Reboot Required!`n`nPlease save your work immediately and`nclick the RESTART NOW button.`n`nYour computer will automatically restart in:`n$TimeStr"
    }

    # Initial Label Set
    & $UpdateLabel

    # 6. Setup Timer for the GUI Update
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000 # 1 second tick
    $timer.Add_Tick({
            $Script:SecondsRemaining--
            & $UpdateLabel
        
            # Check for Timeout
            if ($Script:SecondsRemaining -le 0) {
                $timer.Stop()
                $Global:DiagMsg += "Countdown reached zero."
                $form.Tag = "Timeout"
                $form.Close()
            }
        })
    
    # Clean up image resources when form closes
    $form.Add_FormClosed({
            if ($logoImage) { $logoImage.Dispose() }
            if ($imageStream) { $imageStream.Dispose() }
            if ($webClient) { $webClient.Dispose() }
        })

    # Start the Timer and Show Dialog
    $timer.Start()
    $Global:DiagMsg += "Displaying GUI to user..."
    
    # ShowDialog halts script execution until the form is closed
    $form.ShowDialog() | Out-Null

    # 7. Post-GUI Logic
    if ($form.Tag -eq "ForceNow") {
        # User requested immediate reboot, overriding the timer
        $Global:DiagMsg += "User requested immediate restart. Overriding timer..."
        shutdown.exe -a # Abort existing shutdown
        shutdown.exe /r /t 4 # Issue immediate restart in 4 seconds
        $Global:customFieldMessage = "User clicked Restart Now. ($Date)"
    }
    elseif ($form.Tag -eq "Timeout") {
        # Timer ran out.
        $Global:DiagMsg += "Timer expired. Enforcing final reboot command."
        Start-Process "shutdown.exe" -ArgumentList "/r /t 0 /f" -NoNewWindow
        $Global:customFieldMessage = "Reboot timer expired. System restarting. ($Date)"
    }
    else {
        # Form closed unexpectedly. Background timer is still active.
        $Global:DiagMsg += "GUI closed unexpectedly. Background Windows shutdown timer is still active."
        $Global:customFieldMessage = "GUI closed. Background timer remaining. ($Date)"
    }

}
catch {
    $Global:DiagMsg += "An unexpected error occurred: $($_.Exception.Message)"
    $Global:AlertMsg = "Script failed with an unexpected error. See diagnostics for details. | Last Checked $Date"
    $Global:customFieldMessage = "Script failed with an error. ($Date)"
}


######## End of Script ###########
##################################
##################################


# Write the collected information to the specified Custom Field before exiting.
if ($env:customFieldName) {
    $Global:DiagMsg += "Attempting to write '$($Global:customFieldMessage)' to Custom Field '$($env:customFieldName)'."
    try {
        Ninja-Property-Set -Name $env:customFieldName -Value $Global:customFieldMessage
        $Global:DiagMsg += "Successfully updated Custom Field."
    }
    catch {
        $Global:DiagMsg += "Error writing to Custom Field '$($env:customFieldName)': $($_.Exception.Message)"
    }
}
else {
    $Global:DiagMsg += "Custom Field name not provided in RMM variable 'customFieldName'. Skipping update."
}

if ($Global:AlertMsg) {
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-RMMAlert $Global:AlertMsg
    write-RMMDiag $Global:DiagMsg
    Exit 1
}
else {
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"
    write-RMMAlert $Global:AlertHealthy
    write-RMMDiag $Global:DiagMsg
    Exit 0
}