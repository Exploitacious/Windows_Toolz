# Windows Optimization Scripts

This collection of PowerShell scripts is designed to optimize and customize Windows 10 and 11 for business environments. Each script focuses on specific aspects of system configuration and maintenance.

## Scripts Overview

### 1. Windows System-wide Customization

**Purpose**: Optimizes Windows 10/11 for business environments by modifying system-wide settings.

**Key Functions**:

- Enhances privacy and security settings
- Disables telemetry and data collection
- Customizes UI and UX settings to be more like Windows 10 with classic elements
- Optimizes system performance
- Configures Windows features
- Applies specific Windows optimizations

### 2. Windows User-Specific Customization

**Purpose**: Optimizes Windows 10/11 user settings without requiring administrative privileges.

**Key Functions**:

- Enhances privacy and security settings
- Disables telemetry and data collection
- Customizes UI and UX settings
- Optimizes system performance
- Removes pre-installed bloatware
- Installs specified applications using Winget
- Updates PowerShell modules and Windows
- Creates a first-time logon script for all new user profiles

### 3. Winget Application Installation

**Purpose**: Automates the installation of applications using Winget package manager.

**Key Functions**:

- Installs Winget Auto-Update (WAU)
- Installs a predefined list of applications using Winget
- Handles both Microsoft Store apps and traditional Windows applications

### 4. PowerShell Module and Windows Update

**Purpose**: Updates PowerShell modules and runs Windows Updates.

**Key Functions**:

- Configures PowerShell Gallery and NuGet
- Updates existing PowerShell modules
- Installs new specified PowerShell modules
- Runs Windows Updates
- Ensures Microsoft Update service is registered and active

### 5. Windows Bloatware Removal

**Purpose**: Removes pre-installed bloatware from Windows systems.

**Key Functions**:

- Removes specified AppX packages for all users and from provisioned packages
- Uninstalls specified MSI-based applications
- Handles both Windows 10 and Windows 11 bloatware

### Usage

## One-Liner to Launch in Powershell or CMD (Run as Admin)

curl -L cleanup.umbrellaitgroup.com -o cleanup.cmd && cleanup.cmd

## Caution

These scripts make significant changes to your Windows installation. It's recommended to:

- Review each script before running to ensure it aligns with your organization's policies.
- Test in a controlled environment before deploying to production systems.
- Create a system restore point or backup before running these scripts.

## Customization

Each script contains lists or sections that can be easily modified to suit your specific needs:

- Application lists in the Winget installation script
- Bloatware lists in the removal script
- Registry modifications in the customization scripts

Modify these sections as needed for your environment.

# Windows Appx Bloatware Perma-Uninstall List

- See "Bloatware" Variable for full list.
- To add or remove bloatware apps from this list, simply add then in quotes with wildcard \* symbols.
- To make sure they'll be picked up and removed, test them on a machine by running: get-appxpackage -name _appName_

# Per-User first-time logon script to clean up user interface

- Make sure you download BOTH the FirstLogon.bat file and DebloatScript-HKCU.ps1 into the same directory as the main System Debloat Script.
- A copy of the Bat and HKCU will be placed in C:\Windows\FirstUserLogon and ran every time a user logs in for the FIRST TIME ONLY.
- This 'mini' script cleans up the user interface and removes some of the clutter that Windows 10 likes to throw at you.

### More Information

1Click-1Line-Launcher: The entry point that downloads and sets up the other scripts.
Main-Stager: Orchestrates the execution of other scripts in the correct order.
Various optimization scripts: Handle system-wide and user-specific customizations, bloatware removal, application installation, and Windows updates.
