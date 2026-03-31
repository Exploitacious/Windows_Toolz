$registryChanges = @(
    @{ Path = "HKLM:\SOFTWARE\Policies\Google\Chrome"; Name = "NativeHostsExecutablesLaunchDirectly" },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "NativeHostsExecutablesLaunchDirectly" }
)

foreach ($reg in $registryChanges) {
    # Create Path if missing
    if (-not (Test-Path $reg.Path)) {
        New-Item -Path $reg.Path -Force | Out-Null
        Write-Host "Created Key: $($reg.Path)"
    }
    
    # Set Value
    try {
        New-ItemProperty -Path $reg.Path -Name $reg.Name -Value 1 -PropertyType DWORD -Force | Out-Null
        Write-Host "Set $($reg.Name) to 1 in $($reg.Path)"
    }
    catch {
        Write-Error "Failed to set $($reg.Name) in $($reg.Path): $($_.Exception.Message)"
    }
}