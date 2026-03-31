<#
.SYNOPSIS
    A comprehensive collection of PowerShell 5.1 system administration, providing functions for logging, software inventory, system information gathering, and more.

.DESCRIPTION
    This script is a collection of robust functions designed to operate in a standard PowerShell 5.1 environment without external modules.
    It provides capabilities for writing to the Windows Event Log, checking for pending reboots, querying installed software, managing files,
    and gathering detailed system information. The script is structured to be self-contained and executable without parameters,
    performing an initial setup of a custom event log source upon execution.

.AUTHOR
    Alex Ivantsov

.DATE
    06/10/2025
#>

#--------------------------------------------------------------------------------
# --- User-Configurable Variables ---
# Modify the values in this section to suit your environment.
#--------------------------------------------------------------------------------

# The name of the Event Log source to be created and used for logging by this script.
$Global:RMMEventSource = "UniversalRMM_Script"

# The directory where this script is located. This path is determined automatically.
# The script expects '7za.exe' (7-Zip command-line executable) to be present in this directory for compression functions.
$Global:UniversalRMMPath = $PSScriptRoot

# --- End of User-Configurable Variables ---


#--------------------------------------------------------------------------------
# --- Logging and Event Management Functions ---
#--------------------------------------------------------------------------------

Function Write-LogMessage {
  <#
    .SYNOPSIS
        Writes a message to a specified Windows Event Log, handling large messages by splitting them.
    .PARAMETER Message
        The string message to write to the event log.
    .PARAMETER LogName
        The name of the event log (e.g., "Application", "UniversalRMM").
    .PARAMETER EventSource
        The source of the event.
    .PARAMETER EventID
        The ID for the event.
    .PARAMETER IsError
        A switch to indicate if the log entry should be an Error type. Defaults to Information.
    #>
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$LogName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EventSource,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [int]$EventID,

    [switch]$IsError
  )

  # Set the type of Event entry that will be written.
  if ($IsError.IsPresent) {
    $entryType = [System.Diagnostics.EventLogEntryType]::Error 
  }
  else {
    $entryType = [System.Diagnostics.EventLogEntryType]::Information
  }
    
  # The maximum size for an event log message is approximately 32KB. We use 30,000 characters as a safe limit.
  $maxMessageLength = 30000
  $startPosition = 0
    
  # Loop through the message and write it in chunks if it's too long.
  while ($startPosition -lt $Message.Length) {
    $length = [System.Math]::Min($maxMessageLength, $Message.Length - $startPosition)
    $currentChunk = $Message.Substring($startPosition, $length)
        
    Write-EventLog -LogName $LogName `
      -Source $EventSource `
      -EntryType $entryType `
      -EventID $EventID `
      -Message $currentChunk
        
    $startPosition += $maxMessageLength
  }
}

Function New-RMMEventSource {
  <#
    .SYNOPSIS
        Ensures the custom event log and source exist for script logging.
    .PARAMETER Source
        The name of the event source to create.
    #>
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Source
  )
    
  $logName = "UniversalRMM"

  # Check if the log and source already exist.
  if (-not ([System.Diagnostics.EventLog]::Exists($logName) -and [System.Diagnostics.EventLog]::SourceExists($Source))) {
    try {
      # Create the new event log source.
      New-EventLog -LogName $logName -Source $Source -ErrorAction Stop
            
      # Set the maximum size of the custom event log to 1GB.
      Limit-EventLog -LogName $logName -MaximumSize 1GB -ErrorAction SilentlyContinue

      Write-LogMessage -LogName $logName `
        -Message "Setting Up Windows Event Log Source '$($Source)'...`r`nEvent Log Source registered successfully. Continuing." `
        -EventSource $Source `
        -EventID 0
    }
    catch {
      # If creation fails, write a critical error and exit.
      Write-Error "Unable to set up '$($logName)' Event Log Source. Please run this script as an Administrator. Critical Error."
      # Exit with a non-zero exit code to indicate failure.
      Exit 1
    }
  }
}

Function Write-EVLog {
  <#
    .SYNOPSIS
        A wrapper function for Write-LogMessage that uses predefined Event IDs based on message type.
    .PARAMETER Message
        The message to be logged.
    .PARAMETER IsError
        Switch to log the message as an error.
    .PARAMETER TriggerAutomation
        Switch to indicate the log entry is intended to trigger an automated response (uses a higher Event ID).
    #>
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,
        
    [switch]$IsError,
        
    [switch]$TriggerAutomation
  )
    
  # Determine the Event ID based on the switches provided.
  $eventId = 5 # Default informational
  if ($IsError.IsPresent -and $TriggerAutomation.IsPresent) {
    $eventId = 20 # Automation-triggered error
  }
  elseif ($TriggerAutomation.IsPresent) {
    $eventId = 30 # Automation-triggered information
  }
  elseif ($IsError.IsPresent) {
    $eventId = 10 # Standard error
  }
    
  # Write the message to the log using the global event source.
  Write-LogMessage -LogName "UniversalRMM" -EventSource $Global:RMMEventSource -EventID $eventId -Message $Message -IsError:$IsError
}

#--------------------------------------------------------------------------------
# --- System Information and Status Functions ---
#--------------------------------------------------------------------------------

Function Test-IsAdmin {
  <#
    .SYNOPSIS
        Checks if the current session is running with Administrator privileges.
    .OUTPUTS
        [bool] True if running as admin, otherwise false.
    #>
  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

Function Test-FreeSpace {
  <#
    .SYNOPSIS
        Checks if the system drive has a minimum amount of free space.
    .PARAMETER MinimumAvailableDiskSpaceInGB
        The minimum required free disk space in Gigabytes.
    .OUTPUTS
        [bool] True if there is enough free space, otherwise false.
    #>
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [int]$MinimumAvailableDiskSpaceInGB
  )
    
  try {
    $systemDrive = $env:SystemDrive
    $driveInfo = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$($systemDrive)'" -ErrorAction Stop
    $freeSpaceGB = $driveInfo.FreeSpace / 1GB
        
    return $freeSpaceGB -ge $MinimumAvailableDiskSpaceInGB
  }
  catch {
    Write-Warning "Could not retrieve disk space information for drive $($env:SystemDrive)."
    return $false
  }
}

Function Test-SystemArchitecture {
  <#
    .SYNOPSIS
        Determines the operating system architecture.
    .OUTPUTS
        [string] "64-bit" or "32-bit".
    #>
  if ([System.Environment]::Is64BitOperatingSystem) {
    return "64-bit"
  }
  else {
    return "32-bit"
  }
}

Function Test-IsServer {
  <#
    .SYNOPSIS
        Checks if the operating system is a Windows Server edition.
    .OUTPUTS
        [bool] True if the OS is a server, otherwise false.
    #>
  return (Get-WmiObject -Class Win32_OperatingSystem).ProductType -ne 1
}

Function Test-RebootPending {
  <#
    .SYNOPSIS
        Checks for various common indicators that a system reboot is pending.
        Sourced and reworked from the 'Test-PendingReboot' PowerShell Gallery module for PS 5.1 compatibility.
    .OUTPUTS
        [bool] True if a reboot is pending, otherwise false.
    #>
    
  # Helper function to check if a registry key exists.
  function Test-RegistryKey($Key) {
    return Test-Path -Path $Key -ErrorAction SilentlyContinue
  }

  # Helper function to check if a registry value is present and not null/empty.
  function Test-RegistryValueNotNull($Key, $Value) {
    $property = Get-ItemProperty -Path $Key -Name $Value -ErrorAction SilentlyContinue
    return -not [System.String]::IsNullOrEmpty($property.$($Value))
  }

  # An array of script blocks, each performing a specific check for a pending reboot.
  $rebootChecks = @(
    { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' },
    { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' },
    { Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations' },
    {
      $updateExeVolatile = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Updates' -Name 'UpdateExeVolatile' -ErrorAction SilentlyContinue
      if ($updateExeVolatile) { return $updateExeVolatile.UpdateExeVolatile -ne 0 } else { return $false }
    },
    { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttemps' }
  )

  # Execute each check. If any return true, a reboot is pending.
  foreach ($test in $rebootChecks) {
    if (& $test) {
      Write-Verbose "Pending reboot detected by check: $($test.ToString())"
      return $true
    }
  }

  return $false
}


#--------------------------------------------------------------------------------
# --- Software, Service, and Patch Management Functions ---
#--------------------------------------------------------------------------------

Function Get-InstalledSoftware {
  <#
    .SYNOPSIS
        Retrieves a list of installed software from the registry for all users.
        This function is significantly faster and more comprehensive than Get-WmiObject Win32_Product.
    .DESCRIPTION
        Requires administrative privileges to scan all user profiles. It queries both 32-bit and 64-bit registry hives
        for machine-wide and user-specific installations.
    .OUTPUTS
        An array of objects, each representing an installed application.
    #>
  [CmdletBinding()]
  Param()

  if (-not (Test-IsAdmin)) {
    Write-Warning "Finding all user applications requires administrative privileges. Results may be incomplete."
  }
    
  # Define registry paths for software uninstall information.
  $registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )
    
  # Use the pipeline to efficiently gather results from machine-level installations.
  $installedApps = Get-ItemProperty -Path $registryPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and !$_.SystemComponent }

  # To get user-level installs, we need to check each user's registry hive.
  $userProfiles = Get-WmiObject Win32_UserProfile | Where-Object { $_.SID -like "S-1-5-21-*" -and $_.Special -eq $false }
    
  foreach ($profile in $userProfiles) {
    $sid = $profile.SID
    # If the user's hive is loaded, we can query it directly.
    if (Test-Path "Registry::HKEY_USERS\$($sid)") {
      $userRegistryPaths = @(
        "Registry::HKEY_USERS\$($sid)\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "Registry::HKEY_USERS\$($sid)\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
      )
      $installedApps += Get-ItemProperty $userRegistryPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and !$_.SystemComponent }
    }
  }
    
  # Return a unique list of applications, sorted by name.
  return $installedApps | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, UninstallString | Sort-Object DisplayName | Get-Unique -AsString
}

Function Test-InstalledSoftware {
  <#
    .SYNOPSIS
        Checks if a specific application is installed.
    .PARAMETER ApplicationName
        The display name of the application to search for. Wildcards are not supported, exact match only.
    .OUTPUTS
        [bool] True if the application is found, otherwise false.
    #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName
  )

  # Get all software and check if the specified application exists in the list.
  $allSoftware = Get-InstalledSoftware
  foreach ($app in $allSoftware) {
    if ($app.DisplayName -eq $ApplicationName) {
      return $true
    }
  }
    
  return $false
}

Function Install-MSI {
  <#
    .SYNOPSIS
        Installs an MSI package silently.
    .PARAMETER FilePath
        The full path to the .msi file.
    .PARAMETER AdditionalParams
        An array of any additional command-line arguments for msiexec.
    .PARAMETER OutputLog
        A switch to output the contents of the MSI log file upon completion.
    #>
  Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,
        
    [String[]]$AdditionalParams,
        
    [Switch]$OutputLog
  )
    
  if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
    Write-Error "MSI file not found at path: $FilePath"
    return
  }
    
  $fileInfo = Get-Item -Path $FilePath
  $dateStamp = Get-Date -Format "yyyyMMddTHHmmss"
  $logFile = Join-Path -Path $Global:UniversalRMMPath -ChildPath ("{0}-{1}.log" -f $fileInfo.BaseName, $dateStamp)
    
  # Standard arguments for a silent, unattended MSI installation.
  $msiArguments = @(
    "/i",
        ('"{0}"' -f $fileInfo.FullName),
    "/qn",
    "/norestart",
    "/L*v",
        ('"{0}"' -f $logFile)
  )

  # Add any extra parameters provided by the user.
  if ($AdditionalParams) {
    $msiArguments += $AdditionalParams
  }
    
  # Execute the installer and wait for it to complete.
  $process = Start-Process "msiexec.exe" -ArgumentList $msiArguments -Wait -PassThru -NoNewWindow
    
  Write-Host "MSI installation process completed with exit code: $($process.ExitCode)"
    
  if ($OutputLog.IsPresent -and (Test-Path $logFile)) {
    Write-Host "--- MSI Log Contents for $($fileInfo.Name) ---"
    Get-Content $logFile
    Write-Host "--- End of Log ---"
  }
}

Function Test-ServiceRunning {
  <#
    .SYNOPSIS
        Checks if a specific Windows service is running.
    .PARAMETER ServiceName
        The name of the service to check.
    .OUTPUTS
        [bool] True if the service exists and is running, otherwise false.
    #>
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName
  )
    
  try {
    $service = Get-Service -Name $ServiceName -ErrorAction Stop
    return $service.Status -eq 'Running'
  }
  catch {
    # This will catch errors from Get-Service if the service doesn't exist.
    return $false
  }
}

Function Test-KBInstalled {
  <#
    .SYNOPSIS
        Checks if a specific Windows Update (KB article) is installed.
    .PARAMETER HotfixID
        The ID number of the KB article (e.g., '5005101').
    .OUTPUTS
        [bool] True if the hotfix is installed, otherwise false.
    #>
  param (
    [Parameter(Mandatory = $true)]
    [string]$HotfixID
  )

  # The HotfixID might be passed with or without "KB". Standardize it.
  $kbID = if ($HotfixID.StartsWith("KB")) { $HotfixID } else { "KB$($HotfixID)" }
    
  # Get-Hotfix is the most reliable way to check for installed updates.
  return [boolean](Get-Hotfix -Id $kbID -ErrorAction SilentlyContinue)
}

#--------------------------------------------------------------------------------
# --- File and Network Operations ---
#--------------------------------------------------------------------------------

Function Set-MaximumTLS {
  <#
    .SYNOPSIS
        Configures the current PowerShell session to use the highest available TLS protocol version.
    .DESCRIPTION
        This is necessary on older systems (like Windows 7/Server 2008 R2) to communicate with modern web servers
        that require TLS 1.2 or higher.
    #>
    
  # Set the security protocol by attempting to add newer protocols sequentially.
  # This approach ensures the highest possible protocol is enabled for the session.
  $protocols = @(
    'Tls12',
    'Tls11',
    'Tls',
    'Ssl3'
  )
    
  # The value is a bitmask, so we add them together.
  $securityProtocol = 0
  foreach ($protocol in $protocols) {
    try {
      $securityProtocol = $securityProtocol -bor [System.Net.SecurityProtocolType]::$protocol
    }
    catch {}
  }

  [System.Net.ServicePointManager]::SecurityProtocol = $securityProtocol
}

Function New-FileDownload {
  <#
    .SYNOPSIS
        Downloads a file from a URL to a local path.
    .PARAMETER Url
        The URL of the file to download.
    .PARAMETER LocalFilePath
        The full local path where the file should be saved.
    .OUTPUTS
        [bool] True on success, false on failure.
    #>
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Url,
        
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$LocalFilePath
  )
    
  # Ensure modern TLS protocols are enabled for the web request.
  Set-MaximumTLS
    
  $webClient = New-Object System.Net.WebClient
  try {
    Write-Verbose "Downloading from '$Url' to '$LocalFilePath'..."
    $webClient.DownloadFile($Url, $LocalFilePath)
        
    if (Test-Path -Path $LocalFilePath) {
      Write-Verbose "File downloaded successfully."
      return $true
    }
    else {
      Write-Warning "File download failed. The local file was not created."
      return $false
    }
  }
  catch {
    Write-Error "An error occurred during download: $($_.Exception.Message)"
    return $false
  }
  finally {
    # Dispose of the web client object to free up resources.
    $webClient.Dispose()
  }
}

Function Compress-7Zip {
  <#
    .SYNOPSIS
        Compresses a file or directory using 7-Zip.
    .DESCRIPTION
        This function requires '7za.exe' to be in the script's execution directory ($Global:UniversalRMMPath).
    .PARAMETER OutputFile
        The full path for the output archive (e.g., 'C:\archive.7z').
    .PARAMETER Source
        The full path to the file or directory to compress.
    .OUTPUTS
        [bool] True on success, false on failure.
    #>
  param (
    [Parameter(Mandatory = $true)]
    [string]$OutputFile,
        
    [Parameter(Mandatory = $true)]
    [string]$Source
  )
    
  $sevenZipPath = Join-Path -Path $Global:UniversalRMMPath -ChildPath "7za.exe"
  if (-not (Test-Path $sevenZipPath)) {
    Write-Error "7za.exe not found in '$($Global:UniversalRMMPath)'. Aborting compression."
    return $false
  }
    
  # 'a' command = add to archive
  $arguments = @("a", "-y", "`"$OutputFile`"", "`"$Source`"")
    
  Start-Process -FilePath $sevenZipPath -ArgumentList $arguments -NoNewWindow -Wait
    
  return Test-Path -Path $OutputFile
}

#--------------------------------------------------------------------------------
# --- Main Execution Block ---
# This code runs when the script is executed.
#--------------------------------------------------------------------------------

# Main function to orchestrate the script's execution.
function Start-ScriptExecution {
  Write-Host "--- Universal RMM Script Initializing ---"
    
  # Check for administrative privileges, as they are required for setup.
  if (-not (Test-IsAdmin)) {
    Write-Warning "This script requires administrator privileges to create the Event Log source."
    Write-Warning "Some functions may not work correctly without elevation."
  }

  # Ensure the required Event Log source for this script exists.
  Write-Host "Verifying Event Log source '$($Global:RMMEventSource)'..."
  New-RMMEventSource -Source $Global:RMMEventSource
  Write-Host "Event Log source setup is complete."
    
  # --- Example Usage ---
  # The following section demonstrates how to use the functions in this script.
    
  # Example 1: Log a startup message.
  Write-Host "Logging a script startup message to the event log."
  Write-EVLog -Message "UniversalRMM script started successfully. System architecture: $(Test-SystemArchitecture). Admin context: $(Test-IsAdmin)."
    
  # Example 2: Check for pending reboot status and log the result.
  Write-Host "Checking for pending system reboot..."
  if (Test-RebootPending) {
    $rebootMsg = "A system reboot is pending. It is recommended to reboot before performing software installations."
    Write-Warning $rebootMsg
    Write-EVLog -Message $rebootMsg -IsError # Log as an error for visibility.
  }
  else {
    $rebootMsg = "No pending reboot detected."
    Write-Host $rebootMsg
    Write-EVLog -Message $rebootMsg
  }
    
  # Example 3: List installed applications (optional, can be slow and verbose).
  # Write-Host "Retrieving list of installed software..."
  # $software = Get-InstalledSoftware
  # Write-Host "Found $($software.Count) applications."
  # $software | Format-Table DisplayName, DisplayVersion, Publisher -AutoSize
    
  Write-Host "--- Script Execution Finished ---"
}

# --- Trigger the main execution logic ---
Start-ScriptExecution