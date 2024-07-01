# Malicious Email Search, Purge, and Block Script

## Overview

This PowerShell script automates the process of searching for, purging, and optionally blocking senders of potentially malicious emails from user mailboxes in Microsoft 365. It provides a graphical user interface (GUI) for easy input of search criteria and automates the compliance search, purge operations, and sender blocking.

## Features

- GUI for inputting search criteria
- Automated connection to Security & Compliance Center and Exchange Online
- Creation and execution of compliance search
- Real-time status updates for search and purge operations
- Option to soft delete or hard delete found emails
- Option to add the sender to the tenant's blocklist
- Detailed results reporting

## Requirements

- Windows operating system
- PowerShell 5.1 or later
- ExchangeOnlineManagement module installed
- Global Admin credentials for your Microsoft 365 tenant
- Appropriate permissions in the Security & Compliance Center and Exchange Online

## Installation

1. Ensure you have the ExchangeOnlineManagement module installed. If not, install it using:
   ```powershell
   Install-Module -Name ExchangeOnlineManagement -Force
   ```
2. Save the script as a .ps1 file (e.g., `MaliciousEmailSearchPurgeAndBlock.ps1`) in a location of your choice.

## Usage

1. Open PowerShell as an administrator.
2. Navigate to the directory containing the script.
3. Run the script:
   ```powershell
   .\MaliciousEmailSearchPurgeAndBlock.ps1
   ```
4. When prompted, enter the User Principal Name (UPN) of a Global Admin account (you'll be asked twice, once for Security & Compliance Center and once for Exchange Online).
5. In the GUI that appears, enter the search criteria:
   - Subject (required)
   - Sender email address (optional)
   - Recipient email address (optional)
   - Sent date
   - Purge type (SoftDelete or HardDelete)
   - Check the "Add sender to blocklist" box if you want to block the sender
6. Click 'OK' to start the search process.
7. Review the search results in the PowerShell window.
8. When prompted, confirm whether you want to proceed with the purge operation.
9. If you confirm, the script will execute the purge operation and display the results.
10. If you chose to block the sender, you'll be asked to confirm this action after the purge operation.

## Notes

- The script will create a unique name for each compliance search based on the current date and time.
- Search and purge operations may take some time to complete, depending on the size of your organization and the number of items found.
- The script provides real-time status updates in the PowerShell window.
- After the operation is complete, the PowerShell sessions will be disconnected automatically.
- Adding a sender to the blocklist will prevent future emails from that sender from reaching your organization.

## Caution

- This script performs actions that can permanently delete emails and block senders. Use with caution and ensure you have appropriate backups.
- Always verify the search results before confirming the purge operation.
- Be certain about adding a sender to the blocklist, as it will affect all future communications from that email address.
- It's recommended to test the script in a non-production environment before using it in production.

## Troubleshooting

- If you encounter permission errors, ensure the Global Admin account you're using has the necessary roles assigned in the Security & Compliance Center and Exchange Online.
- If the script fails to connect, check your internet connection and verify that the ExchangeOnlineManagement module is installed correctly.
- For any other issues, review the error messages in the PowerShell window for more information.

## Disclaimer

This script is provided as-is, without any warranties. Always test in a non-production environment before using in a production setting. The user assumes all responsibility for the use of this script.
