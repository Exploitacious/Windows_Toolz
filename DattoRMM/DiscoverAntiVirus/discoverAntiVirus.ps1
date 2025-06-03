#
## Template for Scripting Component Monitors for Datto RMM with PowerShell
# Created by Alex Ivantsov @Exploitacious

# Script Name and Type
$ScriptName = "Check for Primary AV or EDR" # Quick and easy name of Script to help identify
$ScriptType = "Monitoring" # Monitoring // Remediation
$Date = get-date -Format "MM/dd/yyy hh:mm tt"

# What to Write if Alert is Healthy
$Global:AlertHealthy = " | Last Checked $Date" # Define what should be displayed in Datto when monitor is healthy and $Global:AlertMsg is blank.
# There is also another palce to put NO ALERT Healthy messages down below, to try and capture more script info.

## Verify/Elevate to Admin Session. Comment out if not needed the single line below.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

## Datto RMM Variables ## Uncomment only for testing. Otherwise, use Datto Variables. See Explanation Below.
$env:usrUDF = 12 # Which UDF to write to. Leave blank to Skip UDF writing.
#$env:usrString = Example # Datto User Input variable "usrString"

<#
This is a Datto RMM Monitoring Script, used to deliver a result such as "Healthy" or "Not Healthy", in order to trigger the creation of tickets, etc.

To create Variables in Datto RMM Script component, you must use $env variables in the powershell script, simply by matching the name and adding "env:" before them.
For example, in Datto we can use a variable for user input called "usrUDF" and here we use "$env:usrUDF=" to use that variable.

You can use as many of these as you like.

Below you will find all the standard variables to use with Datto RMM to interract with all the the visual, alert and diagnostics cues available from the dashboards.
#># DattoRMM Alert Functions. Don't touch these unless you know what you're doing.
function write-DRMMDiag ($messages) {
    Write-Host  "`n<-Start Diagnostic->"
    foreach ($Message in $Messages) { $Message + ' `' }
    Write-Host '<-End Diagnostic->'
    Write-Host
}
function write-DRMMAlert ($message) {
    Write-Host "`n<-Start Result->"
    Write-Host "STATUS=$message"
    Write-Host '<-End Result->'
}
function genRandString ([int]$length, [string]$chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789') {
    return -join ((1..$length) | ForEach-Object { Get-Random -InputObject $chars.ToCharArray() })
}
# Extra Info and Variables (Leave at default)
$Global:DiagMsg = @() # Running Diagnostic log (diaglog). Use " $Global:DiagMsg += " to append messages to this log for verboseness in the script.
$Global:AlertMsg = @() # Combined Alert message. If left blank, will not trigger Alert status. Use " $Global:AlertMsg += " to append messages to be alerted on in Datto.
$Global:varUDFString = @() # String which will be written to UDF, if UDF Number is defined by $usrUDF in Datto. Use " $Global:varUDFString += " to fill this string.
$ScriptUID = GenRANDString 20 # Generate random UID for script
$Global:DiagMsg += "Script Type: " + $ScriptType
$Global:DiagMsg += "Script Name: " + $ScriptName
$Global:DiagMsg += "Script UID: " + $ScriptUID
$Global:DiagMsg += "Executed On: " + $Date  
##################################
##################################
######## Start of Script #########


# ─────────────────── Bitdefender Check ────────────────────────────────────
function Get-BitdefenderStatus {

    # 1)  Find the CLI -------------------------------------------------------
    $console = $null
    try {
        $console = (Get-ChildItem 'C:\Program Files', 'C:\Program Files (x86)' -Filter product.console.exe `
                -Recurse -ErrorAction SilentlyContinue -Force | Select-Object -First 1).FullName
        if (-not $console) {
            $console = (Get-ChildItem 'C:\Program Files', 'C:\Program Files (x86)' -Filter bduitool.exe `
                    -Recurse -ErrorAction SilentlyContinue -Force | Select-Object -First 1).FullName
        }
    }
    catch { }

    if (-not $console) { return }   # no Bitdefender at all → let wrapper fall back to Defender

    # 2)  Modules we want to query ------------------------------------------
    $modules = @{
        Firewall           = 'Firewall'
        Antimalware        = 'AntimalwareOnAccess'
        NetworkProtection  = 'NetworkProtection'
        AdvancedThreatCtrl = 'AdvancedThreatControl'
        HyperDetect        = 'HyperDetect'
        DeviceControl      = 'DeviceControl'
    }

    # 3)  Ask each one -------------------------------------------------------
    $results = @{}
    foreach ($m in $modules.GetEnumerator()) {

        $cmdArgs = @('/c', $m.Value, 'get', 'config')
        $out = @()
        $exit = 0

        try {
            $out = & $console @cmdArgs 2>&1
            $exit = $LASTEXITCODE
        }
        catch {
            $out = $_.Exception.Message
            $exit = 1
        }

        $joined = ($out -join ' ')
        $status = if ($exit -ne 0 -or $joined -match '(?i)error|failed|terminat') {
            'Error'
        }
        elseif ($joined -match '(?i)\benabled\b') {
            'Enabled'
        }
        elseif ($joined -match '(?i)\bdisabled\b|\boff\b|\binactive\b') {
            'Disabled'
        }
        else {
            'Unknown'
        }

        # shorten the key for nicer variable names
        $key = switch ($m.Key) { 'AntimalwareOnAccess' { 'Antimalware' } Default { $m.Key } }
        $results[$key] = $status
    }

    # 4)  Decide overall health (only these must be ON) ----------------------
    $critical = @('Antimalware', 'Firewall', 'NetworkProtection')
    $modulesOK = $true
    foreach ($c in $critical) {
        if ($results[$c] -ne 'Enabled') { $modulesOK = $false; break }
    }

    # 5)  Build + export summary --------------------------------------------
    $summary = [PSCustomObject]@{
        BD_Antimalware       = $results['Antimalware']
        BD_Firewall          = $results['Firewall']
        BD_NetworkProtection = $results['NetworkProtection']
        BD_ATC               = $results['AdvancedThreatCtrl']
        BD_HyperDetect       = $results['HyperDetect']
        BD_DeviceControl     = $results['DeviceControl']
        BD_ModulesOK         = $modulesOK
        BD_RawOutput         = ($results.GetEnumerator() |
            Sort-Object Name |
            ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '; '
    }

    foreach ($p in $summary.PSObject.Properties) {
        Set-Variable -Name $p.Name -Value $p.Value -Scope 1   # visible to the wrapper
    }
    return $summary
}

# ─────────────────── Windows Defender / MDE Check ─────────────────────
function Get-ProtectionSummary {

    # helper: return the first non-null OnboardingState it can read
    function Get-MDEOnboardingState {
        $regPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status', # modern
            'HKLM:\SOFTWARE\Microsoft\Sense'                                        # legacy fallback
        )
        foreach ($p in $regPaths) {
            try {
                if (Test-Path $p) {
                    $v = (Get-ItemProperty -Path $p -Name OnboardingState -ErrorAction Stop).OnboardingState
                    if ($null -ne $v) { return [int]$v }
                }
            }
            catch { }
        }
        return $null
    }

    # ---------- grab SecurityCenter AV list (ignore if namespace absent) ----------
    $av = @()
    try {
        $av = Get-CimInstance -Namespace root/SecurityCenter2 -Class AntiVirusProduct `
            -ErrorAction Stop |
        Select-Object @{n = 'Name'; e = { $_.displayName } },
        @{n = 'StateHex'; e = { ('{0:X6}' -f $_.productState) } }
    }
    catch [Microsoft.Management.Infrastructure.CimException] {
        if ($_.HResult -eq 0x8004100e) { Write-Verbose 'SecurityCenter2 namespace missing.' }
    }

    # ---------- Sense / MDE detection ----------
    $senseSvc = Get-Service -Name Sense -ErrorAction SilentlyContinue
    $obState = Get-MDEOnboardingState        # null if key not present
    $mdeOn = ($senseSvc -and $senseSvc.Status -eq 'Running' -and ($obState -in 1, 2))

    # ---------- decide the protection level ----------
    if ($mdeOn) {
        $Level = 'Microsoft Defender for Endpoint (full MDE)'
    }
    elseif ($av.Count) {
        $primary = $av[0]
        if ($primary.Name -like '*Defender*') {
            $Level = 'Default Windows Defender (non-MDE)'
        }
        else {
            $Level = "Third-party AV - $($primary.Name)"
        }
    }
    else {
        # last-ditch service probe
        $wd = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
        $Level = if ($wd -and $wd.Status -eq 'Running') {
            'Windows Defender service-level detection'
        }
        else {
            '❌ No Antivirus detected'
        }
    }

    # ---------- surface summary ----------
    $summary = [PSCustomObject]@{
        Level            = $Level
        SenseService     = if ($senseSvc) { $senseSvc.Status } else { 'NotFound' }
        SenseOnboarding  = switch ($obState) { 1 { 'Onboarded' } 2 { 'Pending' } default { 'No' } }
        SecurityCenterAV = if ($av) {
                               ($av | ForEach-Object { "$($_.Name) [0x$($_.StateHex)]" }) -join '; '
        }
        else { 'None' }
    }

    # export to caller's scope for RMM variables
    $summary.PSObject.Properties | ForEach-Object {
        Set-Variable -Name $_.Name -Value $_.Value -Scope 1
    }
    return $summary
}


# ─────────────────── Wrapper / RMM output  ───────────────────────────
function Run-AVHealthCheck {

    # Try Bitdefender first
    $bd = Get-BitdefenderStatus
    if ($bd) {
        $Global:DiagMsg += "Bitdefender detected..."
        $Global:DiagMsg += "BD_Antimalware Module: $BD_Antimalware"
        $Global:DiagMsg += "BD_Firewall Module: $BD_Firewall"
        $Global:DiagMsg += "BD_Network Protection Module: $BD_NetworkProtection"
        $Global:DiagMsg += "BD_Advanced Threat Control Module: $BD_ATC"
        $Global:DiagMsg += "BD_Hyper Detect Module: $BD_HyperDetect"
        $Global:DiagMsg += "BD_Device Control Module: $BD_DeviceControl"

        if (-not $BD_ModulesOK) {
            $Global:DiagMsg += "Discovered Bitdefender installed but critical security services are not enabled."
            $Global:AlertMsg = "1 or more Bitdefender modules disabled. Scrutinize diagnostic log | Last Checked $date"
            $Global:varUDFString = "BD SECURITY SERVICES DISABLED | Last Checked $date"
            return      # stop here – no need to check Defender/MDE
        }
        else {
            $Global:varUDFString = "Bitdefender OK | Last Checked $date"
            return      # stop here – no need to check Defender/MDE
        }
    }

    # No BD – fall back to Defender / MDE
    $def = Get-ProtectionSummary

    $Global:DiagMsg += "Security Center AV: $($def.SecurityCenterAV)"
    $Global:DiagMsg += "Sense Service: $($def.SenseService)"
    $Global:DiagMsg += "MDE Onboarding: $($def.SenseOnboarding)"
    
    if ($def.Level -eq 'Microsoft Defender for Endpoint (full MDE)') {
        $Global:DiagMsg += "Results: Active MDE fully onboarded."
    }
    else {
        $Global:AlertMsg = "ALERT: Insufficient AV/EDR - $($def.Level)"
    }
    
    $Global:varUDFString += "$($def.Level) | Last Checked $date"
}

# ── run it ───────────────────────────────────────────────────────────────────
Run-AVHealthCheck



######## End of Script ###########
##################################
##################################
### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if ($env:usrUDF -ge 1) {    
    if ($Global:varUDFString.length -gt 255) {
        # Write UDF to diaglog
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF :" + $Global:varUDFString 
        # Limit UDF Entry to 255 Characters 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        # Write to diagLog and UDF
        $Global:DiagMsg += " - Writing to UDF $env:usrUDF : " + $Global:varUDFString 
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
### Exit script with proper Datto alerting, diagnostic and API Results.
#######################################################################
if ($Global:AlertMsg) {
    # If your AlertMsg has value, this is how it will get reported.
    $Global:DiagMsg += "Exiting Script with Exit Code 1 (Trigger Alert)"
    write-DRMMAlert $Global:AlertMsg
    write-DRMMDiag $Global:DiagMsg

    # Exit 1 means DISPLAY ALERT
    Exit 1
}
else {
    # If the AlertMsg variable is blank (nothing was added), the script will report healthy status with whatever was defined above.
    $Global:DiagMsg += "Leaving Script with Exit Code 0 (No Alert)"

    ##### You may alter the NO ALERT Exit Message #####
    write-DRMMAlert "Sufficient AV/EDR Found $Global:AlertHealthy"
    write-DRMMDiag $Global:DiagMsg

    # Exit 0 means all is well. No Alert.
    Exit 0
}