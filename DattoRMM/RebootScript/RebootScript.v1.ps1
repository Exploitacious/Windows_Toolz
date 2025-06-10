<#
.SYNOPSIS
    Notifies the user of a pending automatic system reboot due to extended uptime.
    It displays a WPF window with a countdown and provides an option to reboot immediately.

.DESCRIPTION
    This script is designed to run on a user's machine to enforce reboots after a
    prolonged period of uptime, which can help resolve performance issues.

    The script first calculates the system's uptime. It then creates and displays a
    graphical user interface (GUI) window using Windows Presentation Framework (WPF).
    This window informs the user about the uptime and the scheduled reboot.

    The user has two options:
    1. Click "Reboot Now" to restart the computer immediately.
    2. Close the window. If the window is closed, a timer will start, and the
       computer will automatically reboot after the specified delay.

    All user-configurable settings are located in the "User Variables" section.
    This script is self-contained and does not require any external modules beyond
    what is included in a standard PowerShell 5.1 installation.

.AUTHOR
    Alex Ivantsov

.DATE
    June 10, 2025
#>

#------------------------------------------------------------------------------------#
#                                  User Variables                                    #
#          Modify the values in this section to customize the script's behavior.     #
#------------------------------------------------------------------------------------#

# The amount of time, in minutes, the script will wait after the notification is
# closed before forcing a reboot.
[int]$RebootDelayMinutes = 15

# The name of your company or IT department.
[string]$CompanyName = "Umbrella IT Solutions"

# The title that will appear in the top bar of the notification window.
[string]$WindowTitle = "System Reboot Notification"


#------------------------------------------------------------------------------------#
#                                     Functions                                      #
#      The core logic of the script is organized into the functions below.           #
#------------------------------------------------------------------------------------#

function Get-SystemUptime {
    <#
.SYNOPSIS
    Calculates the total time the system has been running since the last boot.
.OUTPUTS
    [System.TimeSpan] An object representing the system's uptime.
#>
    try {
        # Retrieve operating system information using WMI (Windows Management Instrumentation).
        # This object contains properties like the last boot time.
        $osInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop

        # The LastBootUpTime property is a string that needs to be converted to a PowerShell DateTime object.
        $lastBootTime = $osInfo.ConvertToDateTime($osInfo.LastBootUpTime)

        # Calculate the difference between the current time and the last boot time.
        $uptime = (Get-Date) - $lastBootTime

        # Return the calculated uptime as a TimeSpan object.
        return $uptime
    }
    catch {
        # If WMI fails, write an error and return a zero TimeSpan.
        Write-Error "Failed to retrieve system uptime. Error: $($_.Exception.Message)"
        return (New-TimeSpan -Seconds 0)
    }
}

function Show-RebootNotification {
    <#
.SYNOPSIS
    Creates and displays the WPF notification window to the user.
.DESCRIPTION
    This function handles all aspects of the user interface:
    - Loading the necessary .NET assembly for WPF.
    - Building the window and its controls (text block, button).
    - Defining the layout and appearance.
    - Handling the "Reboot Now" button click event.
    - Displaying the window and waiting for user interaction.
#>

    # Load the .NET PresentationFramework assembly. This is required to create and manage WPF UI elements.
    # The -ErrorAction Stop ensures the script will halt if the assembly cannot be loaded.
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop

    # --- Retrieve Information for Display ---
    $username = $env:USERNAME
    $uptime = Get-SystemUptime
    $uptimeFormatted = "{0} days, {1} hours, and {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes

    # --- Define Window Content ---
    $message = @"
Hello $username,

This is a message from your system administrators at $CompanyName.

Your computer has been running for $uptimeFormatted.
To ensure optimal performance and apply important updates, a reboot is required.

Your system is scheduled to reboot automatically in $RebootDelayMinutes minutes.
Please save all your work and close any open applications.

You can click the button below to restart immediately. If you close this window, the automatic reboot will still occur after the timer expires.

Thank you for your cooperation!
"@

    # --- Create and Configure the Main Window ---
    $window = New-Object System.Windows.Window
    $window.Title = $WindowTitle
    $window.Width = 450
    $window.Height = 375
    $window.WindowStartupLocation = 'CenterScreen' # Open the window in the center of the screen.
    $window.Topmost = $true                       # Ensure the window appears on top of all other windows.
    $window.ResizeMode = 'NoResize'               # Prevent the user from resizing the window.

    # --- Create the Layout Panel ---
    # A DockPanel is used to easily arrange elements at the top, bottom, left, or right.
    $dockPanel = New-Object System.Windows.Controls.DockPanel

    # --- Create the Message Text Block ---
    $textBlock = New-Object System.Windows.Controls.TextBlock
    $textBlock.Text = $message
    $textBlock.TextWrapping = "Wrap" # Allows the text to wrap to new lines if it's too long.
    $textBlock.Margin = "15"         # Adds 15 pixels of padding around the text block.

    # Dock the text block to the top of the panel.
    [System.Windows.Controls.DockPanel]::SetDock($textBlock, 'Top')
    $dockPanel.Children.Add($textBlock)

    # --- Create the "Reboot Now" Button ---
    $button = New-Object System.Windows.Controls.Button
    $button.Content = "Reboot Now"
    $button.Width = 120
    $button.Height = 30
    $button.Margin = "0,0,15,15" # Adds margin to the right and bottom for spacing.
    $button.HorizontalAlignment = "Right" # Aligns the button to the right side of its container.

    # Define the action to be performed when the button is clicked.
    $button.Add_Click({
            # Write a host message for logging/debugging purposes.
            Write-Host "User clicked 'Reboot Now'. Initiating immediate system restart."

            # Force the computer to restart. The -Force switch closes applications without warning.
            Restart-Computer -Force
        })

    # Dock the button to the bottom of the panel.
    [System.Windows.Controls.DockPanel]::SetDock($button, 'Bottom')
    $dockPanel.Children.Add($button)

    # --- Finalize and Show Window ---
    # Set the DockPanel as the main content of the window.
    $window.Content = $dockPanel

    # Show the window as a dialog. This is a blocking call, meaning the script
    # will pause here until the user closes the window or clicks the button.
    # The [void] cast suppresses the dialog's return value from being printed to the console.
    [void]$window.ShowDialog()
}


#------------------------------------------------------------------------------------#
#                                  Main Execution                                    #
#             This is the primary logic that runs the script's tasks.                #
#------------------------------------------------------------------------------------#

# Display the notification window to the user.
# The script will pause on this line until the user closes the notification window.
Write-Host "Displaying reboot notification to the user..."
Show-RebootNotification

# Once the notification window is closed, the script continues from here.
Write-Host "Notification window closed by user. Starting the $RebootDelayMinutes minute reboot timer."

# Convert the delay from minutes to seconds for the Start-Sleep cmdlet.
$rebootDelaySeconds = $RebootDelayMinutes * 60

# Wait for the specified amount of time.
Start-Sleep -Seconds $rebootDelaySeconds

# After the wait period, force the computer to reboot.
Write-Host "Timer expired. Forcing system reboot."
Restart-Computer -Force