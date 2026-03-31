

#    $AllGPOs = Get-GPO -All | Get-GPOReport -ReportType html
#
#For (GPO in $AllGPOs){
#    Write-Host "Exported a GPO"
#    }


$GPOInfo = Get-GPO -All
$GpoName = $GPOInfo.DisplayName

ForEach ($GPO in $GPOInfo) {
    Get-GPOReport -Name "$GpoName" -ReportType Html | Out-File C:\Temp\CurrentGPOs\$GPOName.html
}

Get-GPOReport -Name