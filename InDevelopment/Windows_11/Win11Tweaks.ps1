  ## Customise Taskbar
    
    # Set the chat icon to be hidden
    Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name "TaskbarMn" -Value 0
    
    # Set the widget icon to be hidden
    Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name "TaskbarDa" -Value 0
    
    # Set the task view icon to be hidden
    Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name "ShowTaskViewButton" -Value 0
    
    # Moves the Taskbar to left
    $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $Al = "TaskbarAl" # Shifts Start Menu Left
    $value = "0"
    New-ItemProperty -Path $registryPath -Name $Al -Value $value -PropertyType DWORD -Force -ErrorAction Ignore
    
    
    ## Uninstall consumer Teams app
    
    $installedApps = Get-AppxPackage
    
    if ($installedApps -eq $null) {
        Write-Output "No apps are installed on the system."
    }
    else {
        $teamsApp = $installedApps | Where-Object {$_.Name -eq "MicrosoftTeams"}
    
        if ($teamsApp -eq $null) {
            Write-Output "The Microsoft Teams app is not installed on the system."
        }
        else {
            Remove-AppxPackage -Package $teamsApp.PackageFullName
        }
    }
    
    
    ## Remove Win11 right-click menu
    
    New-Item -Path HKCU:\Software\Classes\CLSID -Name "{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -ItemType "Key"
    New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Name "InprocServer32" -ItemType "Key"
    Set-ItemProperty "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(Default)" -Value ""
