<#
.SYNOPSIS
    Collect effective management settings (GPO, LGPO, Intune, security, audit)
    and dump them to C:\Temp\PolicyReports\*.csv

.DESCRIPTION
    Built for Windows PowerShell 5.1.  All functions are defensive-coded:
    • Any failure → warning + empty CSV placeholder
    • Absolutely no parameters required
#>

# ── Global prep ─────────────────────────────────────────────────────────────
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$OutDir = 'C:\Temp\PolicyReports'
if (-not (Test-Path $OutDir)) { New-Item $OutDir -ItemType Directory -Force | Out-Null }
function New-EmptyCsv { @() | Export-Csv -Path $args[0] -NoTypeInformation }

# ── Generic helper (XML → CSV) ──────────────────────────────────────────────
function Write-XmlNodeCsv {
    param([xml]$XmlDoc, [string]$XPath, [string]$CsvPath)
    try {
        $nodes = $XmlDoc.SelectNodes($XPath)
        if ($nodes) {
            $nodes | ForEach-Object {
                $bag = @{}; $_.ChildNodes | ForEach-Object { $bag[$_.Name] = $_.InnerText }
                [pscustomobject]$bag
            } | Export-Csv $CsvPath -NoTypeInformation
        }
        else { New-EmptyCsv $CsvPath }
    }
    catch { Write-Warning "XML dump failed: $_"; New-EmptyCsv $CsvPath }
}

# ── AD RSOP ─────────────────────────────────────────────────────────────────
function Export-GPOResult {
    param([string]$Dir)
    Write-Host 'RSOP (gpresult)'
    $xmlPath = Join-Path $Dir 'GPResult.xml'
    try {
        gpresult /x $xmlPath /f | Out-Null
        [xml]$doc = Get-Content $xmlPath
        Write-XmlNodeCsv $doc '//ComputerResults/AppliedGroupPolicyObjects/GroupPolicyObject' (Join-Path $Dir 'GPOs_Computer.csv')
        Write-XmlNodeCsv $doc '//UserResults/AppliedGroupPolicyObjects/GroupPolicyObject'     (Join-Path $Dir 'GPOs_User.csv')
    }
    catch { Write-Warning "gpresult blew up: $_"; New-EmptyCsv (Join-Path $Dir 'GPOs_Computer.csv'); New-EmptyCsv (Join-Path $Dir 'GPOs_User.csv') }
}

# ── Local GPO ───────────────────────────────────────────────────────────────
function Export-LocalGPO {
    param([string]$Dir)
    Write-Host 'Local GPO'
    $csv = Join-Path $Dir 'LGPO_Effective.csv'
    if (-not (Get-Command LGPO.exe -ErrorAction SilentlyContinue)) {
        Write-Warning 'LGPO.exe not found. Skipping.'
        return (New-EmptyCsv $csv)
    }
    try {
        $backup = Join-Path $Dir 'LGPO_Backup'; LGPO.exe /b $backup | Out-Null
        $txt = Join-Path $Dir 'LGPO_Flat.txt'
        LGPO.exe /parse /m "$backup\Machine\registry.pol" /q >  $txt 2>$null
        LGPO.exe /parse /u "$backup\User\registry.pol"    /q >> $txt 2>$null
        Get-Content $txt | Where-Object { $_ -match '^[HK]' } | ForEach-Object {
            $k, $v = $_ -split '=', 2
            [pscustomobject]@{RegistryPath = $k.Trim(); Value = $v.Trim() }
        } | Export-Csv $csv -NoTypeInformation
    }
    catch { Write-Warning "LGPO export failed: $_"; New-EmptyCsv $csv }
}

# ── Security policy ─────────────────────────────────────────────────────────
function Export-SecurityPolicy {
    param([string]$Dir)
    Write-Host 'Security policy'
    $csv = Join-Path $Dir 'SecurityPolicy.csv'
    try {
        $inf = Join-Path $Dir 'SecPolicy.inf'
        secedit /export /cfg $inf /areas SECURITYPOLICY | Out-Null
        Get-Content $inf | Where-Object { $_ -match '=' } | ForEach-Object {
            $pair = $_ -split '=', 2
            [pscustomobject]@{Setting = $pair[0].Trim(); Value = $pair[1].Trim() }
        } | Export-Csv $csv -NoTypeInformation
    }
    catch { Write-Warning "secedit failed: $_"; New-EmptyCsv $csv }
}

# ── Audit policy ────────────────────────────────────────────────────────────
function Export-AuditPolicy {
    param([string]$Dir)
    Write-Host 'Audit policy'
    $csv = Join-Path $Dir 'AuditPolicy.csv'
    try {
        $raw = AuditPol /get /category:* 2>&1
        $re = '^\s*(?<Cat>.+?)\s{2,}(?<Sub>.+?)\s{2,}(?<Set>Success|Failure|No auditing|Success and Failure)\s*$'
        $raw | Select-String $re | ForEach-Object {
            $m = [regex]::Match($_.Line, $re)
            [pscustomobject]@{
                Category    = $m.Groups['Cat'].Value.Trim()
                Subcategory = $m.Groups['Sub'].Value.Trim()
                Setting     = $m.Groups['Set'].Value.Trim()
            }
        } | Export-Csv $csv -NoTypeInformation
    }
    catch { Write-Warning "auditpol failed: $_"; New-EmptyCsv $csv }
}

# ── Intune CSP registry ─────────────────────────────────────────────────────
function Export-IntuneCSPRegistry {
    param([string]$Dir)
    Write-Host 'Intune CSP registry'
    $devCsv = Join-Path $Dir 'CSP_Device.csv'
    $usrCsv = Join-Path $Dir 'CSP_User.csv'

    try {
        $devKey = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device'
        if (Test-Path $devKey) {
            Get-ChildItem -Recurse $devKey | Get-ItemProperty | Export-Csv $devCsv -NoTypeInformation
        }
        else { New-EmptyCsv $devCsv }
    }
    catch { Write-Warning "Device CSP dump failed: $_"; New-EmptyCsv $devCsv }

    try {
        $usrKey = 'HKCU:\SOFTWARE\Microsoft\PolicyManager\current\device'
        if (Test-Path $usrKey) {
            Get-ChildItem -Recurse $usrKey | Get-ItemProperty | Export-Csv $usrCsv -NoTypeInformation
        }
        else { New-EmptyCsv $usrCsv }
    }
    catch { Write-Warning "User CSP dump failed: $_"; New-EmptyCsv $usrCsv }
}

# ── Intune RSOP (WMI bridge) ────────────────────────────────────────────────
function Export-IntuneWMIResult {
    param([string]$Dir)
    Write-Host 'Intune WMI resultant policy'
    $csv = Join-Path $Dir 'Intune_ResultantPolicies.csv'
    try {
        $ns = 'root\cimv2\mdm\dmmap'
        $classes = Get-CimClass -Namespace $ns | Where-Object CimClassName -Like 'MDM_Policy_Result*'
        $bag = foreach ($cls in $classes) {
            Get-CimInstance -Namespace $ns -ClassName $cls.CimClassName -ErrorAction SilentlyContinue |
            ForEach-Object {
                $parent = $_.ParentID; $instance = $_.InstanceID
                $_.CimInstanceProperties | Where-Object {
                    $_.Name -notmatch 'ParentId|InstanceId|Revision' -and $_.Value
                } | ForEach-Object {
                    [pscustomobject]@{
                        Class      = $cls.CimClassName
                        ParentID   = $parent
                        InstanceID = $instance
                        Policy     = $_.Name
                        Value      = $_.Value
                    }
                }
            }
        }
        if ($bag) { $bag | Export-Csv $csv -NoTypeInformation } else { New-EmptyCsv $csv }
    }
    catch { Write-Warning "Intune WMI query failed: $_"; New-EmptyCsv $csv }
}

# ── Main ────────────────────────────────────────────────────────────────────
Write-Host "`n=== Management snapshot starting ==="
Export-GPOResult          $OutDir
Export-LocalGPO           $OutDir
Export-SecurityPolicy     $OutDir
Export-AuditPolicy        $OutDir
Export-IntuneCSPRegistry  $OutDir
Export-IntuneWMIResult    $OutDir
Write-Host "`nSnapshot complete."
Write-Host "`n=== Parse and Combine Starting ==="

$root = 'C:\Temp\PolicyReports'
$out = Join-Path $root 'MasterPolicySnapshot.csv'
if (-not (Test-Path $root)) { throw "Folder $root not found - run the dump script first." }

# ── quick regex → category map (extend as you like) ──
$catMap = @{
    'Audit'                    = 'AuditPolicy'
    'Password'                 = 'PasswordPolicy'
    'Lockout'                  = 'PasswordPolicy'
    'Se[A-Z]'                  = 'UserRights'
    '\bFirewall\b'             = 'Firewall'
    'BitLocker'                = 'BitLocker'
    'Update'                   = 'WindowsUpdate'
    'Defender'                 = 'Defender'
    'CSP_Device\.Connectivity' = 'CSP.Networking'
    'CSP_Device\.Encryption'   = 'CSP.Encryption'
}

function Get-Category {
    param($name)
    foreach ($pat in $catMap.Keys) { if ($name -match $pat) { return $catMap[$pat] } }
    'Unknown'
}

$bag = @()

# ── 1) AD GPO links ─────────────────────────────────────────────────────────
foreach ($file in 'GPOs_Computer.csv', 'GPOs_User.csv') {
    $path = Join-Path $root $file
    if (Test-Path $path) {

        # determine scope the old-fashioned way
        $scopeForFile = if ($file -match 'Computer') { 'Computer' } else { 'User' }

        Import-Csv $path | ForEach-Object {
            $bag += [pscustomobject]@{
                Layer       = 'AD_GPO'
                Scope       = $scopeForFile
                Category    = 'GPO_Link'
                SettingName = $_.Name
                Value       = 'Linked'
                SourcePath  = $_.Link
                GPOname     = $_.Name
                Notes       = 'GPO linked and applied'
            }
        }
    }
}

# ── 2) Local GPO settings ───────────────────────────────────────────────────
$lgpo = Join-Path $root 'LGPO_Effective.csv'
if (Test-Path $lgpo) {
    Import-Csv $lgpo | ForEach-Object {
        $scope = if ($_.RegistryPath -match 'HKCU') { 'User' } else { 'Computer' }

        $bag += [pscustomobject]@{
            Layer       = 'LGPO'
            Scope       = $scope
            Category    = Get-Category $_.RegistryPath
            SettingName = $_.RegistryPath
            Value       = $_.Value
            SourcePath  = $_.RegistryPath
            GPOname     = 'Local'
            Notes       = ''
        }
    }
}

# ── 3) Security policy ──────────────────────────────────────────────────────
$sec = Join-Path $root 'SecurityPolicy.csv'
if (Test-Path $sec) {
    Import-Csv $sec | ForEach-Object {
        $bag += [pscustomobject]@{
            Layer       = 'SecurityPolicy'
            Scope       = 'Computer'
            Category    = Get-Category $_.Setting
            SettingName = $_.Setting
            Value       = $_.Value
            SourcePath  = 'secedit'
            GPOname     = ''
            Notes       = ''
        }
    }
}

# ── 4) Audit policy ─────────────────────────────────────────────────────────
$audit = Join-Path $root 'AuditPolicy.csv'
if (Test-Path $audit) {
    Import-Csv $audit | ForEach-Object {
        $bag += [pscustomobject]@{
            Layer       = 'AuditPolicy'
            Scope       = 'Computer'
            Category    = 'AuditPolicy'
            SettingName = "$($_.Category)\$($_.Subcategory)"
            Value       = $_.Setting
            SourcePath  = 'auditpol'
            GPOname     = ''
            Notes       = ''
        }
    }
}

# ── 5) CSP registry hives (Device/User) ─────────────────────────────────────
foreach ($file in 'CSP_Device.csv', 'CSP_User.csv') {
    $path = Join-Path $root $file
    if (Test-Path $path) {
        $scope = if ($file -match 'User') { 'User' } else { 'Device' }

        Import-Csv $path | ForEach-Object {
            # grab first "real" property value (skip PS* meta properties)
            $valProp = ($_.psobject.Properties |
                Where-Object Name -notmatch '^PS' |
                Select-Object -First 1).Name
            $val = $_.$valProp

            $bag += [pscustomobject]@{
                Layer       = 'CSP'
                Scope       = $scope
                Category    = Get-Category $_.PSPath
                SettingName = $_.PSChildName
                Value       = $val
                SourcePath  = $_.PSPath
                GPOname     = ''
                Notes       = ''
            }
        }
    }
}

# ── 6) Intune RSOP via WMI bridge ───────────────────────────────────────────
$intune = Join-Path $root 'Intune_ResultantPolicies.csv'
if (Test-Path $intune) {
    Import-Csv $intune | ForEach-Object {
        $bag += [pscustomobject]@{
            Layer       = 'Intune_RSOP'
            Scope       = 'Device'
            Category    = Get-Category $_.Class
            SettingName = $_.Policy
            Value       = $_.Value
            SourcePath  = "$($_.Class)\$($_.Policy)"
            GPOname     = $_.ParentID
            Notes       = ''
        }
    }
}

# ── Output master CSV ───────────────────────────────────────────────────────
$bag | Sort-Object Layer, Scope, Category, SettingName |
Export-Csv $out -NoTypeInformation -Encoding UTF8

Write-Host "`nCombined $($bag.Count) rows -> $out`n"
