# PowerShell Module Removal Script

This PowerShell script is designed to forcibly remove a specified module, including handling dependencies, permissions, and stopping relevant processes. Additionally, it can restart PowerShell and Windows Terminal processes to ensure the removal is complete.

## Features

- Checks for and stops processes using the specified module.
- Ensures the user has necessary permissions to delete module files.
- Automatically elevates to run with administrative privileges if not already.
- Restarts PowerShell and Windows Terminal processes after module removal.

## Prerequisites

- PowerShell 5.1 or later.
- Administrative privileges.

## Usage

1. **Download the Script**

   Save the script to a file, for example, `Remove-Module.ps1`.

2. **Run the Script**

   Open PowerShell with administrative privileges and run the script:

   ```powershell
   .\Remove-Module.ps1
   ```

3. **Follow On-Screen Prompts**

   The script will prompt you to enter the name of the module and optionally the version number.
