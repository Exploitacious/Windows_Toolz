function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End Diagnostic->'
} 
function write-DRRMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}
$FailingThreshold = $ENV:FailingThreshold

$WinSatStatus = (Get-CimInstance Win32_WinSAT).WinSATAssessmentState
if ($WinSatStatus -ne "1") {
    write-DRRMAlert "WinSAT has not run or contains invalid data. No score is available for this device. Attempting to run the assessment now..."
    winsat formal
    exit 1
}
 
$WinSatResults = Get-CimInstance Win32_WinSAT | Select-Object CPUScore, DiskScore, GraphicsScore, MemoryScore, WinSPRLevel
 
$WinSatHealth = foreach ($Result in $WinSatResults) {
    if ($Result.CPUScore -lt $FailingThreshold) { "CPU Score is $($result.CPUScore). This is less than $FailingThreshold" }
    if ($Result.DiskScore -lt $FailingThreshold) { "Disk Score is $($result.Diskscore). This is less than $FailingThreshold" }
    if ($Result.GraphicsScore -lt $FailingThreshold) { "Graphics Score is $($result.GraphicsScore). This is less than $FailingThreshold" }
    if ($Result.MemoryScore -lt $FailingThreshold) { "RAM Score is $($result.MemoryScore). This is less than $FailingThreshold" }
    if ($Result.WinSPRLevel -lt $FailingThreshold) { "Average WinSPR Score is $($result.winsprlevel). This is less than $FailingThreshold" }
}
if (!$WinSatHealth) {
    write-DRRMAlert "Healthy."
    write-DRMMDiag ($WinSatHealth, $WinSatResults)
}
else {
    write-DRRMAlert "Not Healthy."
    write-DRMMDiag ($WinSatHealth, $WinSatResults)
    exit 1
}

#############################################

function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End Diagnostic->'
} 
function write-DRRMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}
$FailingThreshold = $ENV:FailingThreshold

$WinSatStatus = (Get-CimInstance Win32_WinSAT).WinSATAssessmentState
if ($WinSatStatus -ne "1") {
    write-DRRMAlert "WinSAT has not run or contains invalid data. No score is available for this device."
    exit 1
}
 
$WinSatResults = Get-CimInstance Win32_WinSAT | Select-Object CPUScore, DiskScore, GraphicsScore, MemoryScore, WinSPRLevel
 
$WinSatHealth = foreach ($Result in $WinSatResults) {
    if ($Result.CPUScore -lt $FailingThreshold) { "CPU Score is $($result.CPUScore). This is less than $FailingThreshold" }
    if ($Result.DiskScore -lt $FailingThreshold) { "Disk Score is $($result.Diskscore). This is less than $FailingThreshold" }
    if ($Result.GraphicsScore -lt $FailingThreshold) { "Graphics Score is $($result.GraphicsScore). This is less than $FailingThreshold" }
    if ($Result.MemoryScore -lt $FailingThreshold) { "RAM Score is $($result.MemoryScore). This is less than $FailingThreshold" }
    if ($Result.WinSPRLevel -lt $FailingThreshold) { "Average WinSPR Score is $($result.winsprlevel). This is less than $FailingThreshold" }
}
if (!$WinSatHealth) {
    write-DRRMAlert "Healthy."
    write-DRMMDiag ($WinSatHealth, $WinSatResults)
}
else {
    write-DRRMAlert "Not Healthy."
    write-DRMMDiag ($WinSatHealth, $WinSatResults)
    exit 1
}


###########################################


function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End Diagnostic->'
} 

function write-DRMMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}


$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.3") {
    write-DRRMAlert "Unsupported OS. Only Server 2012R2 and up are supported."
    exit 1
}
$ExpectedIndex = $ENV:StabilityIndex
$ExpectedTimetoRun = (get-date).AddDays(-1)
$Metrics = Get-CimInstance -ClassName win32_reliabilitystabilitymetrics | Select-Object -First 1
$Records = Get-CimInstance -ClassName win32_reliabilityRecords | Where-Object { $_.TimeGenerated -ge $Metrics.StartMeasurementDate }
 
$CombinedMetrics = [PSCustomObject]@{
    SystemStabilityIndex = $Metrics.SystemStabilityIndex
    'Start Date'         = $Metrics.StartMeasurementDate
    'End Date'           = $Metrics.EndMeasurementDate
    'Stability Records'  = $Records
}

if ($CombinedMetrics.SystemStabilityIndex -eq $null) {
    write-DRMMAlert "Null - No System Stability Index score could be calculated for this device."
}
elseif ($CombinedMetrics.SystemStabilityIndex -lt $ExpectedIndex) { 
    write-DRMMAlert "Unhealthy - The system stability index is lower than expected. This computer might not be performing in an optimal state. SRI: $($Metrics.SystemStabilityIndex)"
    write-DRMMDiag  $CombinedMetrics.'Stability Records'
    exit 1
}
else {
    write-DRMMAlert "Healthy"
}
 
if ($CombinedMetrics.'Start Date' -lt $ExpectedTimetoRun) {
    write-DRMMAlert "The system stability index has not been updated since $($CombinedMetrics.'Start Date'). This could indicate an issue with event logging or WMI."
    exit 1
}