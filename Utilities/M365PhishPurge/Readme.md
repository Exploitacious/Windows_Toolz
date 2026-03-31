# M365 Phish Purge

## Overview

The M365 Phish Purge script is an automated solution designed to search and remove malicious emails from Microsoft 365 mailboxes using the Compliance Center. This script provides a graphical user interface (GUI) for specifying search criteria and includes functionalities for purging emails and adding senders to a blocklist.

## Features

- **GUI for Search Criteria**: A user-friendly GUI allows users to input search criteria, including email subject, sender, recipient, sent date, and purge type.
- **Search and Purge**: Automates the process of searching for emails that match the specified criteria and purging them.
- **Add to Blocklist**: Option to add the sender to the blocklist to prevent future malicious emails.
- **Logging**: Detailed logging of actions taken by the script, with the log file displayed at the end of the script execution.
- **Compliance**: Integrates with Microsoft 365 Compliance Center and Exchange Online for secure and effective email management.

## Requirements

- PowerShell 5.1 or later
- Microsoft 365 Global Admin credentials
- Modules: `ExchangeOnlineManagement`, `AIPService`
- An account with Conditional Access (CA) bypassed if the device is not registered in Azure/Intune

## Installation

1. Download the script and place it in a desired directory.
2. Ensure that the required PowerShell modules are installed:
   ```powershell
   Install-Module -Name ExchangeOnlineManagement
   Install-Module -Name AIPService
   ```

## Usage

1. Run the script from a PowerShell console with administrative privileges:

```powershell
   .\M365PhishPurge.ps1
```

2. Enter the Global Admin credentials for the M365 Tenant when prompted.
3. Follow the GUI to input search criteria for malicious emails.
4. Confirm the search and purge operations as prompted.
5. Optionally, add senders to the blocklist.
6. View the log file at the end of the script execution for a detailed summary of actions taken.
