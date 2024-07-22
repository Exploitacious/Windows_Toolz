# Disk Health Remediation Script

## Overview

This PowerShell script is designed to perform comprehensive disk health checks and remediation on Windows systems. It's particularly useful for IT administrators and support technicians who need to diagnose and address disk-related issues.

## Features

- Checks System Event Logs for disk-related events
- Performs disk space analysis
- Checks file system integrity
- Analyzes S.M.A.R.T. data for physical disks
- Schedules CheckDisk (chkdsk) if necessary
- Runs System File Checker (SFC) and Deployment Image Servicing and Management (DISM) tools
- Provides detailed logging of all operations

## Requirements

- Windows operating system (Windows 10 or later recommended)
- PowerShell 5.1 or later
- Administrative privileges

## Usage

1. Open PowerShell as an administrator.
2. Navigate to the directory containing the script.
3. Run the script:

```powershell
.\DiskHealthRemediation.ps1
```

## Use In Datto RMM

1. Create New Script in Datto RMM
2. Paste in the script contents
3. Set permission level and script type
4. Save and run on a device, or add to a policy

## Output

The script provides real-time output to the console and also generates a detailed log. Key information includes:

- Disk-related system events
- Disk space usage
- File system status
- S.M.A.R.T. data analysis
- Results of SFC and DISM operations
