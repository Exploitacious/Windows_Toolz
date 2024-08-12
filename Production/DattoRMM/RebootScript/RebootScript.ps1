Add-Type -AssemblyName PresentationFramework

# Function to get the system uptime
function Get-SystemUptime {
    $os = Get-WmiObject -Class Win32_OperatingSystem
    $uptime = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)
    return $uptime
}

# Function to show a WPF window notification
function Show-WpfNotification {
    # Get the username and system uptime
    $username = $env:USERNAME
    $uptime = Get-SystemUptime
    $uptimeFormatted = "{0} days, {1} hours, {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes

    # Define the message content
    $message = "Hello $username,`n`nUmbrella IT Solutions here! Your system administrators.`nYour machine has been up for $uptimeFormatted!`nWe believe you may be experiencing some performance issues which can be resolved by simply rebooting. `n`nYour system will automatically reboot in 15 minutes. Please save your work, close all programs, and click the Reboot Now button.`n`nIf you close out of this window, the system will still reboot in 15 minutes, so it is better to do it now!`nThanks for your understanding and have a great rest of your day! "

    # Create the WPF window
    $window = New-Object System.Windows.Window
    $window.Title = "Umbrella IT Reboot Notification"
    $window.Width = 425
    $window.Height = 350
    $window.Topmost = $true

    # Create a DockPanel layout
    $dockPanel = New-Object System.Windows.Controls.DockPanel
    $dockPanel.LastChildFill = $true

    # Create a TextBlock for the message
    $textBlock = New-Object System.Windows.Controls.TextBlock
    $textBlock.Text = $message
    $textBlock.TextWrapping = "Wrap"
    $textBlock.Margin = "10"
    [System.Windows.Controls.DockPanel]::SetDock($textBlock, 'Top')
    $dockPanel.Children.Add($textBlock)

    # Create a Button to reboot immediately
    $button = New-Object System.Windows.Controls.Button
    $button.Content = "Reboot Now"
    $button.Width = 100
    $button.Height = 30
    $button.Margin = "10"
    $button.HorizontalAlignment = "Right"
    $button.VerticalAlignment = "Bottom"
    $button.Add_Click({
            # Reboot the system immediately when the button is clicked
            Restart-Computer -Force
        })
    [System.Windows.Controls.DockPanel]::SetDock($button, 'Bottom')
    $dockPanel.Children.Add($button)

    # Set the DockPanel as the content of the window
    $window.Content = $dockPanel

    # Show the window
    $window.ShowDialog()
}

# Show the notification
Show-WpfNotification

# Wait for 15 minutes before rebooting automatically
Start-Sleep -Seconds 900

# Reboot the system
Restart-Computer -Force
