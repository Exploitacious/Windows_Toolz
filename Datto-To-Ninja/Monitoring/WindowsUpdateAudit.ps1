<#
Windows Updates interrogation and reporting script
Returns details of installed updates and installation date
For failures, also returns exit code and HRESULT (in hex) for further investigation
Exit codes: 3=Succeeded with errors, 4=Failed; 5=Aborted
Written by Jon North, Datto, May-June 2020
Refactored for ComStore June 2021
#>

# Output current timestamp
$Now = Get-Date 
Write-Output "Query started at $Now`r`n"

# Interrogate WUA API for last check date
$LastCheckForUpdatesDate = (New-Object -ComObject Microsoft.Update.AutoUpdate).Results.LastSearchSuccessDate
Write-Output "Last check for updates was $($LastCheckForUpdatesDate)"

# Interrogate WUA API for last successful update date
$LastInstallUpdatesDate = (New-Object -ComObject Microsoft.Update.AutoUpdate).Results.LastInstallationSuccessDate
Write-Output "Last installation of updates was $LastInstallUpdatesDate`r`n`r`n"

# Get details of updates installed then determine metrics and details for successes and failures
# First declare count and title strings as 0/empty
$UpdatesInstalledSuccess = $UpdatesInstalledFailed = $null
$UpdatesInstalledFailedLookup = $UniqueFailedUpdatesAvailable = @()
$UpdatesInstalledSuccessCount = $UpdatesInstalledFailedCount = $UniqueFailedUpdatesAvailableCount = 0

#Now interrogate WUA API and populate variables
$UpdatesInstalledSearch = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
$UpdatesInstalledCount = $UpdatesInstalledSearch.GetTotalHistoryCount()
if ($UpdatesInstalledCount) {
    $UpdatesInstalled = $UpdatesInstalledSearch.QueryHistory(0, $UpdatesInstalledCount)
    foreach ($Update in $UpdatesInstalled) {
        $Code = $Update.ResultCode
        $OutString = "$($Update.Date) - $($Update.Title)"
        if ($Code -eq 2) { $UpdatesInstalledSuccess += "$OutString`r`n"; $UpdatesInstalledSuccessCount++ }
        if (($Code -eq 3) -or ($Code -eq 4) -or ($Code -eq 5)) {
            $UpdatesInstalledFailed += "$OutString - Exit code $Code, HRESULT 0x$('{0:x}' -f $Update.HResult)`r`n"
            $UpdatesInstalledFailedLookup += @($Update.Title)
            $UpdatesInstalledFailedCount++
        }
    }
}

# Output results to StdOut and UDFs
if ($UpdatesInstalledSuccessCount) { Write-Output "$UpdatesInstalledSuccessCount updates SUCCEEDED:`r`n`r`n$UpdatesInstalledSuccess`r`n" }
else { Write-Output "No updates succeeded`r`n`r`n" }

if ($UpdatesInstalledFailedCount) { Write-Output "$UpdatesInstalledFailedCount updates FAILED.`r`nExit codes: 3=Succeeded with errors; 4=Failed; 5=Aborted`r`n`r`n$UpdatesInstalledFailed`r`n" }
else { Write-Output "No updates failed`r`n`r`n" }

# Interrogate WUA API for details of updates available and output results to StdOut and UDF
$UpdatesAvailable = ((New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()).Search("IsInstalled=0 AND BrowseOnly=0").Updates
if ($UpdatesAvailable.count) {
    $FailedUpdatesAvailable = @()
    $FailedUpdatesAvailableCount = 0
    Write-Output "$($UpdatesAvailable.count) updates are available for install:`r`n"
    foreach ($Update in $UpdatesAvailable) {
        write-host $Update.Title
        foreach ($FailedUpdate in $UpdatesInstalledFailedLookup) {
            if ($Update.Title -eq $FailedUpdate) {
                $FailedUpdatesAvailable += @($FailedUpdate)
                $FailedUpdatesAvailableCount++
            }
        }
    }
    Write-Output "`r`n"
    if ($FailedUpdatesAvailableCount) {
        foreach ($FailedUpdate in $FailedUpdatesAvailable) {
            if (-not ($UniqueFailedUpdatesAvailable.Contains("$FailedUpdate`r`n"))) {
                $UniqueFailedUpdatesAvailable += "$FailedUpdate`r`n"
                $UniqueFailedUpdatesAvailableCount++
            }
        }
        Write-Output "The following available updates previously failed install`r`n$UniqueFailedUpdatesAvailable`r`n`r`n"
    }
}
else { Write-Output "There are no failed updates available for install`r`n" }

if ($env:UDFNum) { New-ItemProperty -Path "HKLM:\SOFTWARE\CentraStage" -Name Custom$env:UDFNum -PropertyType string -Value "Timestamp $($Now | Get-Date -Format "yyyy/MM/dd HH:mm") | Last check $($LastCheckForUpdatesDate | Get-Date -Format "yyyy/MM/dd HH:mm") | Last install $($LastInstallUpdatesDate | Get-Date -Format "yyyy/MM/dd HH:mm") | Successes: $UpdatesInstalledSuccessCount | Failures: $UpdatesInstalledFailedCount | Available: $($UpdatesAvailable.count) | Available previously failed: $($UniqueFailedUpdatesAvailableCount)" -Force >$null }
exit