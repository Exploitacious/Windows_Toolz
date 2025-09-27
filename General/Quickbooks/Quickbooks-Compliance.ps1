<#
.SYNOPSIS
    Disables the automatic update functionality in QuickBooks Desktop.

.DESCRIPTION
    This script is designed to run on a machine with QuickBooks Desktop installed. It performs several actions to prevent QuickBooks from automatically downloading and installing updates.

    The script will:
    1. Terminate the running QuickBooks Update process (qbupdate.exe).
    2. Locate all 'qbchan.dat' files, which control update settings, and modify them to disable background updates.
    3. Remove the startup shortcuts for the 'QuickBooks Update Agent' and 'QuickBooks Web Connector' to prevent them from launching on system boot.
    4. Delete any previously downloaded QuickBooks update installation folders to free up space and prevent pending updates from running.

    This script is self-contained and does not require any external modules or parameters to run.

.AUTHOR
    Alex Ivantsov

.DATE
    06/11/2025
#>

# The root path where Intuit application data is stored.
# The script will search recursively from this point.
[string]$IntuitProgramDataPath = "C:\ProgramData\Intuit"

# The name of the update channel configuration file to search for.
[string]$UpdateChannelFileName = "qbchan.dat"

# The full path to the QuickBooks Update Agent shortcut in the common Startup folder.
[string]$UpdateAgentStartupLink = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\QuickBooks Update Agent.lnk"

# The full path to the QuickBooks Web Connector shortcut in the common Startup folder.
[string]$WebConnectorStartupLink = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\QuickBooks Web Connector.lnk"

# The prefix for QuickBooks download folders that will be removed.
[string]$UpdateDownloadFolderFilter = "DownloadQB*"

Function Get-IniContent {
    <#
.SYNOPSIS
    Reads an INI file and parses it into a structured PowerShell object.
.PARAMETER FilePath
    The full path to the INI file to be read.
.DESCRIPTION
    This function processes a standard INI file line by line. It organizes the contents into an ordered hashtable where top-level keys are the INI sections (e.g., [SectionName]),
    and each section contains another hashtable of its key-value pairs.
    It preserves comments and blank lines by assigning them unique, non-data keys, allowing them to be written back to the file later.
.EXAMPLE
    $iniData = Get-IniContent -FilePath "C:\path\to\config.ini"
    $value = $iniData.MySection.MyKey
.OUTPUTS
    [ordered] A hashtable representing the structure and content of the INI file.
#>
    Param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # Ensure the file exists before attempting to read it.
    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        Write-Error "INI file not found at path: $FilePath"
        return $null
    }

    # Initialize an ordered hashtable to store the INI file content, preserving the order of sections and keys.
    $ini = [ordered]@{}
    
    # Counter for non-key-value lines (comments, blank lines).
    $nonDataLineCount = 0

    # Create a default section for any key-value pairs that appear before the first [section] declaration.
    $currentSectionName = "NO_SECTION"
    $ini[$currentSectionName] = [ordered]@{}

    # Use a switch statement to efficiently process the file line by line with regular expressions.
    switch -regex -file $FilePath {
        # Regex for a section header, e.g., "[SectionName]"
        "^\[(.+)\]$" {
            # This line is a section header.
            # Extract the section name from the match.
            $currentSectionName = $matches[1].Trim()
            # Create a new ordered hashtable for this section.
            $ini[$currentSectionName] = [ordered]@{}
        }

        # Regex for a key-value pair, e.g., "Key = Value"
        "^\s*(.+?)\s*=\s*(.*)" {
            # This line is a key-value pair.
            # Extract the key ($name) and the value from the match.
            $name, $value = $matches[1..2]
            # Add the key-value pair to the current section, trimming any extra whitespace.
            $ini[$currentSectionName][$name.Trim()] = $value.Trim()
        }

        # Default case for lines that are not sections or key-value pairs (e.g., comments, blank lines).
        default {
            # To preserve these lines, we add them to the current section with a unique, generated key.
            # This allows them to be written back to the file in their original position.
            $uniqueKey = "<{0:d4}>" -f $nonDataLineCount++
            $ini[$currentSectionName][$uniqueKey] = $_
        }
    }

    # Return the completed, structured object.
    return $ini
}

Function Set-IniContent {
    <#
.SYNOPSIS
    Writes a structured PowerShell object back to an INI file format.
.PARAMETER IniObject
    The PowerShell object (an ordered hashtable) created by Get-IniContent.
.PARAMETER FilePath
    The full path to the destination INI file. The file will be overwritten.
.DESCRIPTION
    This function takes the structured INI object and rebuilds the INI file content.
    It iterates through the sections and keys, reconstructing the '[SectionName]' headers and 'Key = Value' pairs.
    It also writes back the preserved comments and blank lines to maintain the original file's structure.
.EXAMPLE
    $iniData.MySection.MyKey = "NewValue"
    Set-IniContent -IniObject $iniData -FilePath "C:\path\to\config.ini"
#>
    Param(
        [Parameter(Mandatory = $true)]
        [object]$IniObject,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # Array to build the new file content line by line.
    $fileContent = @()

    # Iterate through each section (top-level key) in the INI object.
    foreach ($sectionName in $IniObject.Keys) {
        # By default, we don't write the "NO_SECTION" header unless it's the only section.
        if ($sectionName -ne 'NO_SECTION' -or $IniObject.Keys.Count -eq 1) {
            # Add a blank line for spacing before adding the new section header, but not for the very first line.
            if ($fileContent.Count -gt 0) {
                $fileContent += ""
            }
            $fileContent += "[$sectionName]"
        }

        # Get the hashtable of keys and values for the current section.
        $sectionContent = $IniObject.$sectionName

        # Iterate through each key within the current section.
        foreach ($key in $sectionContent.Keys) {
            if ($key.StartsWith('<') -and $key.EndsWith('>')) {
                # This is a preserved comment or blank line. Write its original content directly.
                $fileContent += $sectionContent.$key
            }
            else {
                # This is a standard key-value pair. Format it as "Key = Value".
                $fileContent += "$key = $($sectionContent.$key)"
            }
        }
    }

    # Write the newly constructed content to the specified file, overwriting it.
    # Using -Force to ensure read-only files are also updated.
    try {
        $fileContent | Set-Content -Path $FilePath -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to write to INI file: $FilePath. Error: $($_.Exception.Message)"
    }
}


#---------------------------------------------------------------------------------------------
# --- MAIN SCRIPT LOGIC ---
#---------------------------------------------------------------------------------------------

Function Invoke-DisableQuickBooksUpdates {
    <#
.SYNOPSIS
    Executes the full workflow to disable QuickBooks automatic updates.
#>
    
    # --- Step 1: Stop the QuickBooks Update Process ---
    Write-Host "[INFO] Step 1: Attempting to stop the QuickBooks Update process (qbupdate.exe)..." -ForegroundColor Cyan
    $updateProcess = Get-Process -Name "qbupdate" -ErrorAction SilentlyContinue
    if ($null -ne $updateProcess) {
        try {
            $updateProcess | Stop-Process -Force -ErrorAction Stop
            Write-Host "[SUCCESS] The process 'qbupdate.exe' was found and terminated." -ForegroundColor Green
        }
        catch {
            Write-Warning "[WARNING] The process 'qbupdate.exe' was found but could not be terminated. It may require higher privileges."
        }
    }
    else {
        Write-Host "[INFO] The process 'qbupdate.exe' is not currently running." -ForegroundColor Gray
    }
    Write-Host "" # Blank line for spacing

    # --- Step 2: Modify Update Configuration (INI) Files ---
    Write-Host "[INFO] Step 2: Searching for and modifying '$UpdateChannelFileName' files in '$IntuitProgramDataPath'..." -ForegroundColor Cyan
    $iniFiles = Get-ChildItem -Path $IntuitProgramDataPath -Filter $UpdateChannelFileName -Recurse -ErrorAction SilentlyContinue
    
    if ($null -ne $iniFiles) {
        foreach ($file in $iniFiles) {
            Write-Host "[PROCESS] Processing file: $($file.FullName)"
            
            # Read the INI file into a structured object
            $iniObject = Get-IniContent -FilePath $file.FullName
            
            if ($null -eq $iniObject) {
                Write-Warning "[WARNING] Could not parse $($file.FullName), skipping."
                continue
            }
            
            $wasModified = $false
            
            # Iterate through the sections to find and change update settings
            foreach ($sectionKey in $iniObject.Keys) {
                $section = $iniObject.$sectionKey
                
                # *** FIX: Use '.Keys -contains' which is compatible with OrderedDictionary ***
                # Disable background downloads in the 'ChannelInfo' section
                if ($sectionKey -eq "ChannelInfo" -and $section.Keys -contains "BackgroundEnabled") {
                    if ($section.BackgroundEnabled -ne "0") {
                        $section.BackgroundEnabled = "0"
                        Write-Host "  - Set 'BackgroundEnabled' to 0" -ForegroundColor Yellow
                        $wasModified = $true
                    }
                }
                
                # *** FIX: Use '.Keys -contains' which is compatible with OrderedDictionary ***
                # The purpose of changing HotInstall is less documented, but is part of some manual disable procedures.
                # It may relate to preventing silent/hot-patch installations.
                if ($section.Keys -contains "HotInstall") {
                    if ($section.HotInstall -eq "0") {
                        $section.HotInstall = "1"
                        Write-Host "  - Set 'HotInstall' to 1" -ForegroundColor Yellow
                        $wasModified = $true
                    }
                }
            }
            
            # If any changes were made, write the modified object back to the file
            if ($wasModified) {
                Set-IniContent -IniObject $iniObject -FilePath $file.FullName
                Write-Host "[SUCCESS] Successfully modified and saved '$($file.Name)'." -ForegroundColor Green
            }
            else {
                Write-Host "[INFO] No changes were necessary for '$($file.Name)'." -ForegroundColor Gray
            }
        }
    }
    else {
        Write-Warning "[WARNING] No '$UpdateChannelFileName' files were found in the specified path."
    }
    Write-Host "" # Blank line for spacing
    
    # --- Step 3: Remove Startup Links ---
    Write-Host "[INFO] Step 3: Checking for and removing startup links..." -ForegroundColor Cyan
    # Check for and remove the QuickBooks Update Agent link
    if (Test-Path -Path $UpdateAgentStartupLink) {
        try {
            Remove-Item -Path $UpdateAgentStartupLink -Force -ErrorAction Stop
            Write-Host "[SUCCESS] Removed startup link: $UpdateAgentStartupLink" -ForegroundColor Green
        }
        catch {
            Write-Warning "[WARNING] Found startup link but failed to remove it: $UpdateAgentStartupLink"
        }
    }
    else {
        Write-Host "[INFO] Startup link not found (already removed): $UpdateAgentStartupLink" -ForegroundColor Gray
    }
    
    # Check for and remove the QuickBooks Web Connector link
    if (Test-Path -Path $WebConnectorStartupLink) {
        try {
            Remove-Item -Path $WebConnectorStartupLink -Force -ErrorAction Stop
            Write-Host "[SUCCESS] Removed startup link: $WebConnectorStartupLink" -ForegroundColor Green
        }
        catch {
            Write-Warning "[WARNING] Found startup link but failed to remove it: $WebConnectorStartupLink"
        }
    }
    else {
        Write-Host "[INFO] Startup link not found (already removed): $WebConnectorStartupLink" -ForegroundColor Gray
    }
    Write-Host "" # Blank line for spacing

    # --- Step 4: Clean Up Old Download Folders ---
    Write-Host "[INFO] Step 4: Searching for and removing old update download folders..." -ForegroundColor Cyan
    $downloadFolders = Get-ChildItem -Path $IntuitProgramDataPath -Filter $UpdateDownloadFolderFilter -Directory -Recurse -ErrorAction SilentlyContinue
    
    if ($null -ne $downloadFolders) {
        foreach ($folder in $downloadFolders) {
            Write-Host "[PROCESS] Removing downloaded update folder: $($folder.FullName)"
            try {
                Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
                Write-Host "[SUCCESS] Successfully removed folder." -ForegroundColor Green
            }
            catch {
                Write-Warning "[WARNING] Failed to remove folder: $($folder.FullName). It may be in use."
            }
        }
    }
    else {
        Write-Host "[INFO] No update download folders found to clean up." -ForegroundColor Gray
    }
    Write-Host "" # Blank line for spacing
    
    Write-Host "--- QuickBooks Automatic Update Disabler script finished. ---" -ForegroundColor DarkCyan
}

#---------------------------------------------------------------------------------------------
# --- SCRIPT EXECUTION ---
#---------------------------------------------------------------------------------------------

# This calls the main function to start the script's execution.
Invoke-DisableQuickBooksUpdates