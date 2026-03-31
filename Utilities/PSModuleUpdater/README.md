# Module Standalone Updater

This PowerShell script updates all existing modules and installs the latest versions of the Microsoft 365 Management PowerShell modules.

## Features

- **Update Existing Modules**: Ensures all currently installed PowerShell modules are up to date.
- **Install New Modules**: Installs the latest versions of essential Microsoft 365 management modules.

## Requirements

- **PowerShell Version**: PowerShell 5.1 or later.
- **Administrative Privileges**: Required to install or update modules.

## Usage Instructions

1. **Open PowerShell**: Run PowerShell as an administrator.
2. **Execute the Script**: Run the script by typing `.\PSModuleUpdater.ps1` in the PowerShell window.
3. **Follow the Prompts**: The script will prompt you to confirm if you want to install, update, and clean up all PowerShell modules. Type `Y` or `yes` to proceed.
4. **Review the Output**: The script will display the status of each module installation or update. Check for any errors or issues.
5. **Re-run if Necessary**: If there are any issues, re-run the script as needed until all modules are correctly installed and up to date.

## Notes

- **Module List**: The script handles a predefined list of Microsoft 365 management modules, but will also detect and update all installed modules.
- **Error Handling**: If any module fails to install or update, the script provides error messages to help troubleshoot the issue.

## Contact

Created by Alex Ivantsov (@Exploitacious)
