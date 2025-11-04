function Get-BitDefenderThreatState {
    <#
    .SYNOPSIS
        Checks for new BitDefender threats from quarantine and scan logs.
    .DESCRIPTION
        Integrates service status, quarantine DB, and scan log XML checks.
        The function is stateful, mirroring the MDE check. It reads a list of
        previously detected threat IDs from an RMM custom field and only
        returns $true if a *new*, previously unlogged threat is found.
        It then writes the list of current and all known threats back to the field.
    .RETURNS
        [bool] $true if a *new* threat is found, $false otherwise.
    #>
    param (
        [string]$ThreatDetailsField,
        [string]$BitDefenderServiceName = 'EndpointSecurityService',
        [string]$SqliteDllPath = 'C:\ProgramData\System.Data.SQLite.dll',
        # !!! You MUST change this URI to your self-hosted DLL location !!!
        [string]$SqliteDllUri = 'https://YOUR_HOST/path/to/System.Data.SQLite.dll',
        [string]$QuarantineDBPath = 'C:\Program Files\Bitdefender\Endpoint Security\Quarantine\cache.db',
        [string]$ScanLogPath = 'C:\Program Files\Bitdefender\Endpoint Security\logs\system'
    )

    $Global:DiagMsg += ""
    $Global:DiagMsg += "--- Starting BitDefender Threat Check ---"

    # --- 1. Check Service Status ---
    $bdService = Get-Service -Name $BitDefenderServiceName -ErrorAction SilentlyContinue
    if (-not $bdService -or $bdService.Status -ne 'Running') {
        $Global:DiagMsg += "CRITICAL: BitDefender service '$BitDefenderServiceName' is not running or not found. Status: $($bdService.Status). Halting threat check."
        # Return $false because no *new threat* was found, but the diag log shows the critical issue.
        return $false
    }
    $Global:DiagMsg += "BitDefender service '$BitDefenderServiceName' is running."

    # --- 2. Get Existing Threat Data from RMM ---
    if (-not $ThreatDetailsField) {
        $Global:DiagMsg += "RMM variable 'ThreatDetailsField' is not set. Skipping threat check."
        return $false
    }

    $existingThreatData = $null
    try {
        # This assumes a function 'Ninja-Property-Get' exists, per your example.
        $propertyObject = Ninja-Property-Get -Name $ThreatDetailsField -ErrorAction SilentlyContinue
        
        $targetObject = $null
        if ($null -ne $propertyObject) {
            if ($propertyObject -is [array]) {
                if ($propertyObject.Count -gt 0) { $targetObject = $propertyObject[0] }
            }
            else {
                $targetObject = $propertyObject
            }

            if ($null -ne $targetObject) {
                if ($targetObject -is [string]) {
                    $existingThreatData = $targetObject
                }
                elseif ($targetObject.GetType().GetProperty('Value')) {
                    $existingThreatData = $targetObject.Value
                }
            }
        }
    }
    catch {
        $Global:DiagMsg += "Error reading threat data from '$ThreatDetailsField': $($_.Exception.Message). Assuming no previous detections."
    }

    $previousThreatIDs = @{}
    if ($existingThreatData -match "Previously Detected: ([\w\d,\-:_\\.)]+)") {
        $matches[1].Split(',') | ForEach-Object { $previousThreatIDs[$_] = $true }
        $Global:DiagMsg += "Found $($previousThreatIDs.Count) previously detected threat IDs."
    }
    else {
        $Global:DiagMsg += "No previous threat data found in field."
    }

    # --- 3. Initialize Variables ---
    $currentDetections = @()
    $newThreatDetails = @()
    $currentThreatIDs = @{} # Use a hashtable for a unique list of IDs
    $newThreatFound = $false

    # --- 4. Check Quarantine ---
    $Global:DiagMsg += "Checking BitDefender Quarantine DB at '$QuarantineDBPath'..."
    try {
        # Download SQLite DLL if it doesn't exist
        if (-not (Test-Path $SqliteDllPath)) {
            $Global:DiagMsg += "SQLite DLL not found. Downloading from '$SqliteDllUri'..."
            Invoke-WebRequest -Uri $SqliteDllUri -UseBasicParsing -OutFile $SqliteDllPath -ErrorAction Stop
        }

        # Load DLL
        Add-Type -Path $SqliteDllPath -ErrorAction Stop

        # Connect and Query
        $con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
        $con.ConnectionString = "Data Source=$QuarantineDBPath"
        $con.Open()
        $sql = $con.CreateCommand()
        $sql.CommandText = "select * from entries"
        $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
        $data = New-Object System.Data.DataSet
        [void]$adapter.Fill($data)
        $sql.Dispose()
        $con.Close()

        $Global:DiagMsg += "Successfully queried $($data.Tables.rows.count) quarantine entries."

        foreach ($row in $Data.Tables.rows) {
            # Create a unique, repeatable ID for this specific threat event
            $threatIDString = "Quar_$($row.path)_$($row.threat)_$($row.quartime)"
            $currentThreatIDs[$threatIDString] = $true

            $quarTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($row.quartime))
            
            # Check if this ID is new
            if (-not $previousThreatIDs.ContainsKey($threatIDString)) {
                $newThreatFound = $true
                $Global:DiagMsg += " !!! New Quarantine Threat detected !!! ID: $threatIDString"
            }

            # Add details for RMM field
            $newThreatDetails += "-----"
            $newThreatDetails += "Time: $($quarTime.ToString('yyyy-MM-dd HH:mm:ss')) (Quarantined)"
            $newThreatDetails += "ThreatID: $threatIDString"
            $newThreatDetails += "Threat: $($row.threat)"
            $newThreatDetails += "Path: $($row.path)"
        }
    }
    catch {
        $Global:DiagMsg += "Failed to check BitDefender Quarantine: $($_.Exception.Message)"
    }

    # --- 5. Check Scan Logs ---
    $Global:DiagMsg += "Checking BitDefender Scan Logs in '$ScanLogPath'..."
    try {
        $latestScanFile = Get-ChildItem $ScanLogPath -Recurse -Filter "*.xml" | Sort-Object -Property LastWriteTime | Select-Object -Last 1
        
        if (-not $latestScanFile) {
            throw "Could not find any scan log XML files."
        }
        
        $Global:DiagMsg += "Found latest scan log: $($latestScanFile.Name) (Time: $($latestScanFile.LastWriteTime))"
        [xml]$LastScanResult = Get-Content -Path $latestScanFile.FullName -Raw

        # Robustly sum properties (handles $null, single value, or array)
        $ScanResults = [PSCustomObject]@{
            Scanned       = @($LastScanResult.ScanSession.ScanSummary.TypeSummary.Scanned).ForEach([int]) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            Infected      = @($LastScanResult.ScanSession.ScanSummary.TypeSummary.Infected).ForEach([int]) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            suspicious    = @($LastScanResult.ScanSession.ScanSummary.TypeSummary.suspicious).ForEach([int]) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            Disinfected   = @($LastScanResult.ScanSession.ScanSummary.TypeSummary.Disinfected).ForEach([int]) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            Deleted       = @($LastScanResult.ScanSession.ScanSummary.TypeSummary.deleted).ForEach([int]) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            Moved         = @($LastScanResult.ScanSession.ScanSummary.TypeSummary.moved).ForEach([int]) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            Moved_reboot  = @($LastScanResult.ScanSession.ScanSummary.TypeSummary.moved_reboot).ForEach([int]) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            Delete_reboot = @($LastScanResult.ScanSession.ScanSummary.TypeSummary.delete_reboot).ForEach([int]) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            Renamed       = @($LastScanResult.ScanSession.ScanSummary.TypeSummary.renamed).ForEach([int]) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        }

        # Check if any "bad" category has a count greater than 0
        $Alertresult = $ScanResults.psobject.Properties | 
        Where-Object { $_.Name -ne 'Scanned' -and $_.Value -gt 0 }

        if ($Alertresult) {
            $Global:DiagMsg += "Latest scan log shows active issues."
            # Create a unique ID for this specific scan log event
            $threatIDString = "Scan_$($latestScanFile.LastWriteTime.Ticks)"
            $currentThreatIDs[$threatIDString] = $true

            if (-not $previousThreatIDs.ContainsKey($threatIDString)) {
                $newThreatFound = $true
                $Global:DiagMsg += " !!! New Bad Scan Log detected !!! ID: $threatIDString"
            }

            # Add details for RMM field
            $scanDetails = ($ScanResults | Format-List | Out-String).Trim()
            $newThreatDetails += "-----"
            $newThreatDetails += "Time: $($latestScanFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) (Scan Log)"
            $newThreatDetails += "ThreatID: $threatIDString"
            $newThreatDetails += "LogFile: $($latestScanFile.Name)"
            $newThreatDetails += $scanDetails
        }
        else {
            $Global:DiagMsg += "Latest scan log is clean."
        }
    }
    catch {
        $Global:DiagMsg += "Failed to check BitDefender Scan Logs: $($_.Exception.Message)"
    }

    # --- 6. Build and Write New Custom Field Value ---
    
    # 1. Combine all known IDs (old and new) to create the new "memory".
    $allKnownThreatIDs = $previousThreatIDs
    $currentThreatIDs.Keys | ForEach-Object { $allKnownThreatIDs[$_] = $true }

    # 2. Build the "Previously Detected" string from this complete list.
    $idListArray = $allKnownThreatIDs.keys | Select-Object -Unique | Sort-Object
    $idListString = $idListArray -join ','

    # 3. Initialize the new custom field value.
    $newCustomFieldValue = ""
    if ($allKnownThreatIDs.Count -gt 0) {
        $newCustomFieldValue = "Previously Detected: $idListString"
    }

    # 4. Append the details of *currently active* threats.
    if ($newThreatDetails.Count -gt 0) {
        $threatDetailsString = $newThreatDetails -join [Environment]::NewLine
        
        if ([string]::IsNullOrEmpty($newCustomFieldValue)) {
            $newCustomFieldValue = $threatDetailsString
        }
        else {
            $newCustomFieldValue = ($newCustomFieldValue, $threatDetailsString) -join [Environment]::NewLine
        }
    }
    # 5. Handle the "No threats" case.
    elseif ($allKnownThreatIDs.Count -eq 0) {
        $newCustomFieldValue = "No active threats detected. Last Checked: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }
    # If $newThreatDetails.Count is 0 but $allKnownThreatIDs.Count > 0,
    # the field will just contain the "Previously Detected: ..." line, preserving the memory.

    try {
        # Use .Trim() to remove any potential leading/trailing whitespace
        # This assumes a function 'Ninja-Property-Set' exists, per your example.
        Ninja-Property-Set -Name $ThreatDetailsField -Value $newCustomFieldValue.Trim()
        $Global:DiagMsg += "Successfully updated threat details field '$ThreatDetailsField'."
    }
    catch {
        $Global:DiagMsg += "Failed to write to threat detail field '$ThreatDetailsField': $($_.Exception.Message)"
    }

    $Global:DiagMsg += "--- BitDefender Threat Check Finished ---"
    return $newThreatFound
}

# --- EXAMPLE USAGE ---
#
# 1. Make sure $Global:DiagMsg is initialized
# $Global:DiagMsg = "Script run at $(Get-Date)"
#
# 2. Get the RMM field name
# $rmmField = $env:detectedThreatDetailsFieldName
#
# 3. Define your DLL download link
# $dllUrl = "https://your-server.com/System.Data.SQLite.dll"
#
# 4. Run the function
# $isNewThreat = Get-BitDefenderThreatState -ThreatDetailsField $rmmField -SqliteDllUri $dllUrl
#
# 5. (RMM logic) If $isNewThreat is $true, create an alert.
# if ($isNewThreat) {
#     Write-Output "New BitDefender threat found! Check RMM field '$rmmField'."
# }
#
# 6. (RMM logic) Write $Global:DiagMsg to the script output/log.
# Write-Output $Global:DiagMsg
#