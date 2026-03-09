<#
    .SYNOPSIS
        Robust Browser History Scraper (Chunked Stream Processing)
    
    .DESCRIPTION
        Extracts browser history from Edge, Chrome, Firefox, and IE.
        
        CRITICAL FIXES:
        - Uses Chunked Stream Reading (1MB buffers) to prevent memory hangs on large files.
        - Implements "Overlap" buffering to catch URLs split across chunks.
        - Bypasses file locks by creating shadow copies in Temp.
        - Exports a timeline CSV to C:\Temp\GatherLogs.
        
    .NOTES
        Author:       Alex Ivantsov
        Date:         Wednesday, February 11, 2026
        Compatibility: PowerShell 5.1 (Native / No Modules)
#>

# ==============================================================================
# CONFIGURATION
# ==============================================================================
$LogDir = "C:\Temp\GatherLogs"
$UserRegex = '.'     # Process all users
$SearchTerm = '.'    # Process all URLs matches

# ==============================================================================
# ENGINE
# ==============================================================================

function Get-BrowserHistory {
    $Results = @()
    
    # 1. Setup Regex
    # Matches http/s, ftp, file, etc.
    $UrlPattern = '(http|https|ftp|file)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'
    $Regex = [regex]::new($UrlPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    # 2. Define Targets
    $Targets = @(
        @{ Name = "Edge"; Path = "$env:SystemDrive\Users\*\AppData\Local\Microsoft\Edge\User Data\Default\History" },
        @{ Name = "Chrome"; Path = "$env:SystemDrive\Users\*\AppData\Local\Google\Chrome\User Data\Default\History" },
        @{ Name = "Firefox"; Path = "$env:SystemDrive\Users\*\AppData\Roaming\Mozilla\Firefox\Profiles\*.default*\places.sqlite" }
    )

    # 3. Process File-Based Browsers
    foreach ($Target in $Targets) {
        $Files = Resolve-Path $Target.Path -ErrorAction SilentlyContinue
        
        $FileCounter = 0
        foreach ($File in $Files) {
            $FileCounter++
            $FilePath = $File.Path
            
            # Extract User
            $UserName = ($FilePath -split "\\Users\\")[1].Split("\")[0]
            if ($UserName -notmatch $UserRegex) { continue }

            # File Metadata
            try { $FileTime = (Get-Item $FilePath).LastWriteTime } catch { $FileTime = Get-Date }

            # ---------------------------------------------------------
            # COPY TO TEMP (Bypass Lock)
            # ---------------------------------------------------------
            $TempFile = [System.IO.Path]::GetTempFileName()
            try {
                Copy-Item -Path $FilePath -Destination $TempFile -Force -ErrorAction Stop
                
                # ---------------------------------------------------------
                # CHUNKED STREAM PROCESSING (Prevents Hangs)
                # ---------------------------------------------------------
                $Reader = [System.IO.File]::OpenRead($TempFile)
                $BufferLen = 1024 * 1024 # 1MB Chunk
                $Buffer = New-Object Byte[] $BufferLen
                $Encoding = [System.Text.Encoding]::GetEncoding("ISO-8859-1") # 1-to-1 byte mapping
                
                $Overlap = ""
                $TotalBytes = $Reader.Length
                $ReadBytes = 0
                
                while (($BytesRead = $Reader.Read($Buffer, 0, $BufferLen)) -gt 0) {
                    $ReadBytes += $BytesRead
                    
                    # Update Progress Bar (Per File)
                    $Percent = [math]::Round(($ReadBytes / $TotalBytes) * 100)
                    Write-Progress -Activity "Scanning $($Target.Name) ($FileCounter of $($Files.Count))" -Status "Reading $UserName ($Percent%)" -PercentComplete $Percent

                    # Convert Bytes to String
                    $ChunkText = $Encoding.GetString($Buffer, 0, $BytesRead)
                    
                    # Prepend overlap from previous chunk (to catch split URLs)
                    $ProcessText = $Overlap + $ChunkText
                    
                    # Run Regex on this chunk
                    $Matches = $Regex.Matches($ProcessText)
                    foreach ($Match in $Matches) {
                        if ($Match.Value -match $SearchTerm) {
                            $Results += [PSCustomObject]@{
                                Time_Approx = $FileTime.ToString("yyyy-MM-dd HH:mm:ss")
                                User        = $UserName
                                Browser     = $Target.Name
                                Domain      = ($Match.Value -split '/')[2]
                                FullURL     = $Match.Value.Trim()
                                Source      = $FilePath
                            }
                        }
                    }

                    # Save the last 2000 chars as overlap for the next loop
                    if ($ChunkText.Length -gt 2000) {
                        $Overlap = $ChunkText.Substring($ChunkText.Length - 2000)
                    }
                    else {
                        $Overlap = $ChunkText
                    }
                }
                $Reader.Close()
            }
            catch {
                Write-Warning "Could not process $FilePath : $_"
            }
            finally {
                if ($Reader) { $Reader.Dispose() }
                if (Test-Path $TempFile) { Remove-Item $TempFile -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    # 4. Process Internet Explorer (Registry)
    Write-Progress -Activity "Scanning Registry" -Status "Checking IE TypedURLs"
    $Sids = Get-ChildItem "Registry::HKEY_USERS" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'S-1-5-21' }

    foreach ($SidKey in $Sids) {
        try {
            $SID = $SidKey.PSChildName
            $ObjSID = New-Object System.Security.Principal.SecurityIdentifier($SID)
            $UserName = ($ObjSID.Translate([System.Security.Principal.NTAccount]).Value).Split('\')[1]
        }
        catch { $UserName = $SID }

        if ($UserName -match $UserRegex) {
            $TypedPath = Join-Path $SidKey.PSPath "Software\Microsoft\Internet Explorer\TypedURLs"
            if (Test-Path $TypedPath) {
                Get-ItemProperty $TypedPath | Get-Member -MemberType NoteProperty | ForEach-Object {
                    $Val = (Get-ItemProperty $TypedPath).($_.Name)
                    if ($Val -match 'http' -and $Val -match $SearchTerm) {
                        $Results += [PSCustomObject]@{
                            Time_Approx = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            User        = $UserName
                            Browser     = "IE"
                            Domain      = ($Val -split '/')[2]
                            FullURL     = $Val
                            Source      = "Registry"
                        }
                    }
                }
            }
        }
    }

    Write-Progress -Activity "Scanning" -Completed
    return $Results
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

# 1. Directory Check
if (-not (Test-Path $LogDir)) { 
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null 
    Write-Host "Created Directory: $LogDir" -ForegroundColor Gray
}

# 2. Start Scan
Write-Host "[:] Starting Forensic Browser Scan..." -ForegroundColor Cyan
Write-Host "    Mode: Chunked Stream Processing (Anti-Hang)" -ForegroundColor Gray

$Data = Get-BrowserHistory

# 3. Export
if ($Data.Count -gt 0) {
    $Timestamp = Get-Date -Format "yyyyMMdd-HHmm"
    $CsvPath = "$LogDir\BrowserTimeline_$Timestamp.csv"

    # Sort and Unique to clean up
    $Data | Sort-Object User, FullURL -Unique | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "`n[V] Scan Complete." -ForegroundColor Green
    Write-Host "    Items Found: $($Data.Count)"
    Write-Host "    Exported to: $CsvPath" -ForegroundColor Yellow
}
else {
    Write-Warning "No history items found. Ensure you are running as Admin if scanning other users."
}