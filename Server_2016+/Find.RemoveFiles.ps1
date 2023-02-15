$Path = 'D:\'
$Extension = '*.locky'

Function RemoveEmptyFolders {
    $Directory = Get-ChildItem -Force -LiteralPath $Path -Directory | ForEach-Object { $_.FullName }

    foreach ($childDirectory in $Directory) {

        $EmptyDir = $childDirectory | Where-Object { $_.GetFiles().Count -eq 0 }
       
        if ($EmptyDir) {
            Write-Host "Deleting Empty Folder $EmptyDir" -Verbose
            # Remove-Item -Force -LiteralPath $Path
        }

    }
}

Function RemoveEmptyFolders2 {

    #    $tailRecursion = foreach ( $childDirectory in Get-ChildItem $Path -Force -Recurse -Directory ) {
    #        & $tailRecursion -Path $childDirectory.FullName
    #    }

    $directories = Get-ChildItem $Path -Recurse -Directory | Where-Object { (Get-ChildItem $_.FullName -Recurse).Count -eq 0 }
    
    foreach ($directory in $directories) {
        if (!(Get-ChildItem $directory.FullName)) {
            # If the directory is empty, delete it
            Write-Host "Empty Folder" $Directory.FullName
            # Remove-Item $directory.FullName
        }
    }
}


Function RemoveLockyFiles {
    $LockyFiles = Get-ChildItem $Path -Filter $Extension -Recurse | ForEach-Object { $_.FullName }
    foreach ($LockyFile in $LockyFiles) {
        Write-Host "Deleting $LockyFile"
        # Remove-Item $file
    }
}
### Run Functions

# RemoveLockyFiles
RemoveEmptyFolders2

