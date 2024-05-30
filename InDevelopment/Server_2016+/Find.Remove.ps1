$Path = 'D:\COMPANYDATA\' # Primary start path of where to look >
$Extensions = '*.locky', '*.lnk' # Delete any of these extensions
$FolderPaths = '*Application Data*', '*Start Menu*' # Recursively delete any of these folders and items contained

## Reset variables
$Files = $null
$File = $null
$directories = $null
$directory = $null

Function RemoveFiles {
    foreach ($Extension in $Extensions) {
        $Files = Get-ChildItem -Force $Path -Filter $Extension -Recurse | ForEach-Object { $_.FullName }
        foreach ($File in $Files) {
            Write-Host "Deleting $File"
            Remove-Item $file -Force
        }
    }
}

Function RemoveEmptyFolders {

    #    $tailRecursion = foreach ( $childDirectory in Get-ChildItem $Path -Force -Recurse -Directory ) {
    #        & $tailRecursion -Path $childDirectory.FullName
    #    }

    $directories = Get-ChildItem -Force $Path -Recurse -Directory | Where-Object { (Get-ChildItem $_.FullName -Force -Recurse).Count -eq 0 }
    
    foreach ($directory in $directories) {
        if (!(Get-ChildItem $directory.FullName)) {
            # If the directory is empty, delete it
            Write-Host "Empty Folder" $Directory.FullName
            Remove-Item $directory.FullName -Force
        }
    }
}

Function RemoveFolders {
    foreach ($FolderPath in $FolderPaths) {
        $Folders = Get-ChildItem -Force $Path -Filter $Folderpath -Recurse | ForEach-Object { $_.FullName }
        foreach ($Folder in $Folders) {
            Write-Host "Deleting $Folder"
            Remove-Item $Folder -Recurse -Force
        }
    }
}


### Run Functions

RemoveFolders
RemoveFiles
RemoveEmptyFolders


