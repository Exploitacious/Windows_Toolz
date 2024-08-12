# System Reboot Notification Script

This PowerShell script displays a notification to all logged-on users, asking them to close all their programs and reboot their machine. The notification includes the username of the logged-in user, the system's uptime, and a button to immediately reboot the system. If the user does not click the button, the system will automatically reboot after 15 minutes.

## Features

- Displays a modern notification window using WPF.
- Shows the logged-in user's name.
- Displays the system's current uptime.
- Provides a "Reboot Now" button for immediate reboot.
- Automatically reboots the system after a 15-minute countdown if no action is taken.

## Requirements

- Windows PowerShell 5.1
- Windows Presentation Foundation (WPF) support (available by default on most modern Windows systems)

## How It Works

1. **Notification Display:**

   - The script creates a WPF window with a message that includes the username and system uptime.
   - The message informs the user that the system will reboot in 15 minutes and prompts them to save their work.

2. **Immediate Reboot Option:**

   - The window includes a "Reboot Now" button that allows the user to immediately initiate the reboot.

3. **Automatic Reboot:**
   - If the user does not click the "Reboot Now" button, the script waits for 15 minutes and then automatically reboots the system.
