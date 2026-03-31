# Quick Script to duplicate a file from a location to every possible desktop environment, and remove everything else that matches an extension.

# --- Configuration ---
$sourceFile = "\\Server\Production\some.file"
$fileName = "some.file" #Copy

# --- Get Potential Desktop Paths ---
$standardDesktop = [System.Environment]::GetFolderPath('Desktop')
$oneDriveDesktop = "$env:USERPROFILE\OneDrive\Desktop"

# Create an array of desktop paths to check, ensuring no duplicates
$desktopPaths = @($standardDesktop, $oneDriveDesktop) | Get-Unique

Write-Host "Checking the following desktop locations:"
$desktopPaths | ForEach-Object { Write-Host "- $_" }

# --- Cleanup and Update ---
foreach ($desktopPath in $desktopPaths) {
    # Check if the directory exists before proceeding
    if (Test-Path $desktopPath -PathType Container) {
        
        $destinationFile = Join-Path -Path $desktopPath -ChildPath $fileName

        # --- Remove any other .accde files from this desktop location ---
        Get-ChildItem -Path $desktopPath -Filter "*.accde" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.FullName -ne $destinationFile) {
                Write-Host "Removing stray file: $($_.FullName)"
                Remove-Item -Path $_.FullName -Force
            }
        }

        # --- Check for and update the primary .accde file ---
        # Scenarios to handle:
        # 1. The destination file doesn't exist.
        # 2. The destination file exists, but the source is newer.

        $needsCopy = $false
        if (-not (Test-Path $destinationFile)) {
            Write-Host "Destination file does not exist at $destinationFile. Queuing for copy."
            $needsCopy = $true
        }
        else {
            # Compare LastWriteTime only if the destination exists
            try {
                $sourceInfo = Get-Item -Path $sourceFile -ErrorAction Stop
                $destInfo = Get-Item -Path $destinationFile -ErrorAction Stop

                if ($sourceInfo.LastWriteTime -gt $destInfo.LastWriteTime) {
                    Write-Host "Source file is newer than $destinationFile. Queuing for update."
                    $needsCopy = $true
                }
                else {
                    Write-Host "File $destinationFile is already up to date."
                }
            }
            catch {
                Write-Warning "Could not compare file times for $destinationFile. Error: $_"
                # You might decide to force a copy here if comparison fails
                # $needsCopy = $true 
            }
        }

        if ($needsCopy) {
            try {
                Write-Host "Copying latest version to $destinationFile..."
                Copy-Item -Path $sourceFile -Destination $destinationFile -Force -ErrorAction Stop
                Write-Host "Copy successful."
            }
            catch {
                Write-Error "Failed to copy $sourceFile to $destinationFile. Error: $_"
            }
        }
    }
    else {
        Write-Host "Directory not found, skipping: $desktopPath"
    }
}

Write-Host "Script execution complete."