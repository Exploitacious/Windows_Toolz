# QuickBooks Management Scripts

This document provides instructions for a collection of PowerShell scripts designed to gather information, install, and manage QuickBooks Desktop installations.

---

## Get QuickBooks System Data

This script scans the system to find a QuickBooks Desktop installation and collects detailed information about it, such as version, edition, year, and file paths. It also checks if the QuickBooks Tool Hub is installed and outputs all data into a single PowerShell object.

### How to Use

1.  Save the script as a `.ps1` file (e.g., `Get-QuickBooksData.ps1`).
2.  Open PowerShell and navigate to the directory where you saved the script.
3.  Run the script by typing `.\Get-QuickBooksData.ps1` and pressing Enter.
4.  The script will run without any input and display the collected data in the console.

---

## Interactive QuickBooks Desktop Installer

This script provides a menu-driven interface to download and silently install specific versions of QuickBooks Desktop and the QuickBooks Tool Hub. It can be used for workstation or server setups and allows for the input of a license key or the use of an evaluation key.

### How to Use

1.  (Optional) Edit the script to add or remove QuickBooks versions from the configuration list.
2.  Save the script as a `.ps1` file (e.g., `Install-QuickBooks.ps1`).
3.  Right-click the script and select **Run with PowerShell**. The script requires administrator privileges.
4.  Follow the on-screen menu prompts to select the desired installation type and QuickBooks version.

---

## Disable QuickBooks Automatic Updates

This script systematically disables the automatic update feature in QuickBooks Desktop. It works by terminating the update process, modifying configuration files, removing startup links, and deleting previously downloaded update packages.

### How to Use

1.  Save the script as a `.ps1` file (e.g., `Disable-QBUpdates.ps1`).
2.  Right-click the script and select **Run with PowerShell**. The script requires administrator privileges to modify system files.
3.  The script will run automatically and display its progress in the console. No user input is needed.
