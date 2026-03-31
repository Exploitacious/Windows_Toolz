<#
.SYNOPSIS
    A script to clean a specified directory by removing targeted files, folders, and any resulting empty subdirectories. This was used to clean up old ransomware files from user directories.

.DESCRIPTION
    This PowerShell 5.1 script performs a three-stage cleanup operation on a designated path.
    1. It recursively deletes folders whose names match specified patterns.
    2. It recursively deletes files with specified extensions.
    3. It recursively deletes all empty folders that remain.
    The script is designed to run without parameters and provides detailed console output for all actions taken.

.NOTES
    Author:  Alex Ivantsov
    Date:    2025-06-10
    Version: 1.0
#>

#------------------------------------------------------------------------------------#
#                                                                                    #
#                           --- USER VARIABLES ---                                   #
#          Please modify the variables below to match your requirements.             #
#                                                                                    #
#------------------------------------------------------------------------------------#

# The top-level directory where the cleanup operation will start.
$TargetRootPath = 'D:\COMPANYDATA\'

# An array of file extensions to delete. The script will find and delete any file ending with these extensions.
# Example: '*.locky', '*.tmp', '*.log'
$FileExtensionsToDelete = @(
    '*.locky',
    '*.lnk'
)

# An array of folder name patterns to delete. Any folder matching these patterns (including all its contents) will be deleted.
# The wildcard character (*) can be used for pattern matching.
# Example: '*Temp*', '*Cache*'
$FolderPatternsToDelete = @(
    '*Application Data*',
    '*Start Menu*'
)


#------------------------------------------------------------------------------------#
#                                                                                    #
#                          --- SCRIPT FUNCTIONS ---                                  #
#      The core logic of the script is contained within these functions.             #
#                                                                                    #
#------------------------------------------------------------------------------------#

Function Remove-TargetedFolders {
    <#
.SYNOPSIS
    Recursively finds and deletes folders that match the specified patterns.
#>
    param (
        # The path to start the search from.
        [string]$SearchPath,
        # An array of folder name patterns to delete.
        [string[]]$FolderPatterns
    )

    Write-Host "--- Starting Targeted Folder Removal ---" -ForegroundColor Yellow

    # Loop through each folder pattern provided by the user.
    foreach ($Pattern in $FolderPatterns) {
        Write-Host "Searching for folders matching pattern: '$Pattern'"

        # Get all directories that match the current pattern, recursively. The -Force switch includes hidden items.
        $FoldersToDelete = Get-ChildItem -Path $SearchPath -Filter $Pattern -Recurse -Directory -Force -ErrorAction SilentlyContinue

        if ($null -eq $FoldersToDelete) {
            Write-Host "No folders found matching '$Pattern'."
            continue
        }

        # Loop through each found folder and attempt to delete it.
        foreach ($Folder in $FoldersToDelete) {
            try {
                Write-Host "DELETING FOLDER: $($Folder.FullName)"
                # Remove the folder and all of its contents (-Recurse).
                Remove-Item -Path $Folder.FullName -Recurse -Force
            }
            catch {
                # If an error occurs (e.g., permissions issue), write an error message to the console.
                Write-Warning "Could not delete folder: $($Folder.FullName). Error: $($_.Exception.Message)"
            }
        }
    }

    Write-Host "--- Finished Targeted Folder Removal ---`n" -ForegroundColor Green
}

Function Remove-TargetedFiles {
    <#
.SYNOPSIS
    Recursively finds and deletes files that match the specified extensions.
#>
    param (
        # The path to start the search from.
        [string]$SearchPath,
        # An array of file extensions to delete.
        [string[]]$FileExtensions
    )

    Write-Host "--- Starting Targeted File Removal ---" -ForegroundColor Yellow

    # Loop through each file extension provided by the user.
    foreach ($Extension in $FileExtensions) {
        Write-Host "Searching for files with extension: '$Extension'"

        # Get all files matching the current extension, recursively. The -Force switch includes hidden items.
        $FilesToDelete = Get-ChildItem -Path $SearchPath -Filter $Extension -Recurse -File -Force -ErrorAction SilentlyContinue

        if ($null -eq $FilesToDelete) {
            Write-Host "No files found with extension '$Extension'."
            continue
        }

        # Loop through each found file and attempt to delete it.
        foreach ($File in $FilesToDelete) {
            try {
                Write-Host "DELETING FILE: $($File.FullName)"
                Remove-Item -Path $File.FullName -Force
            }
            catch {
                # If an error occurs (e.g., file in use), write an error message to the console.
                Write-Warning "Could not delete file: $($File.FullName). Error: $($_.Exception.Message)"
            }
        }
    }

    Write-Host "--- Finished Targeted File Removal ---`n" -ForegroundColor Green
}

Function Remove-EmptySubdirectories {
    <#
.SYNOPSIS
    Recursively finds and deletes all empty subdirectories within a given path.
#>
    param (
        # The path to start the search from.
        [string]$SearchPath
    )

    Write-Host "--- Starting Empty Subdirectory Removal ---" -ForegroundColor Yellow

    # Get all subdirectories, including hidden ones.
    # Sort them by the length of their full path in descending order.
    # This ensures that child directories are processed before their parents, allowing parent folders to become empty and then be deleted in the same run.
    $AllDirectories = Get-ChildItem -Path $SearchPath -Recurse -Directory -Force -ErrorAction SilentlyContinue | Sort-Object { $_.FullName.Length } -Descending

    if ($null -eq $AllDirectories) {
        Write-Host "No subdirectories found to process."
    }
    else {
        # Loop through each directory.
        foreach ($Directory in $AllDirectories) {
            try {
                # Check if the directory is empty (contains no files or folders).
                # We check the FullName property because the object might be stale after a previous deletion.
                if (Test-Path -Path $Directory.FullName -PathType Container) {
                    if ((Get-ChildItem -Path $Directory.FullName -Force).Count -eq 0) {
                        Write-Host "DELETING EMPTY: $($Directory.FullName)"
                        Remove-Item -Path $Directory.FullName -Force
                    }
                }
            }
            catch {
                # If an error occurs, write a warning message to the console.
                Write-Warning "Could not process directory: $($Directory.FullName). Error: $($_.Exception.Message)"
            }
        }
    }

    Write-Host "--- Finished Empty Subdirectory Removal ---`n" -ForegroundColor Green
}


#------------------------------------------------------------------------------------#
#                                                                                    #
#                           --- SCRIPT EXECUTION ---                                 #
#         The script will now execute the functions in a logical order.              #
#                                                                                    #
#------------------------------------------------------------------------------------#

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "      Directory Cleanup Script Initialized"
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Target Path: $TargetRootPath `n"

# First, check if the root path actually exists before proceeding.
if (-not (Test-Path -Path $TargetRootPath -PathType Container)) {
    Write-Error "The specified Target Root Path does not exist or is not a directory: $TargetRootPath"
}
else {
    # STAGE 1: Delete specific folders and their contents.
    Remove-TargetedFolders -SearchPath $TargetRootPath -FolderPatterns $FolderPatternsToDelete

    # STAGE 2: Delete specific files based on their extension.
    Remove-TargetedFiles -SearchPath $TargetRootPath -FileExtensions $FileExtensionsToDelete

    # STAGE 3: Clean up any empty folders that were left behind or already existed.
    Remove-EmptySubdirectories -SearchPath $TargetRootPath

    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "             Cleanup Script Completed"
    Write-Host "==================================================" -ForegroundColor Cyan
}