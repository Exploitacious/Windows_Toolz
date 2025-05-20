<#
.SYNOPSIS
    Wipes every Windows event log (yes, Security too)

.DESCRIPTION
    • Enables SeSecurityPrivilege for the Security log.
    • Disables every channel (/e:false) + sets retention overwrite (/rt:false)
      **quietly** (/q:true) so no “[y/n]” appears.  
    • Clears each log.  
    • Re-enables channels that were originally enabled.
#>

# ─── 1. Self-elevate ───────────────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath (Get-Process -Id $PID).Path `
        -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"" `
        -Verb runas
    exit
}

# ─── 2. Enable SeSecurityPrivilege ────────────────────────────────────────
if (-not ('Priv' -as [type])) {

    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Priv {
  [DllImport("advapi32.dll", SetLastError=true)]
  static extern bool OpenProcessToken(IntPtr p, uint acc, out IntPtr tok);
  [DllImport("advapi32.dll", SetLastError=true)]
  static extern bool LookupPrivilegeValue(string s, string n, out LUID id);
  [DllImport("advapi32.dll", SetLastError=true)]
  static extern bool AdjustTokenPrivileges(IntPtr tok,bool d,ref TOKEN_PRIVILEGES nP,uint l,
                                           IntPtr p,IntPtr l2);

  struct LUID { public uint LowPart; public int HighPart; }
  struct TOKEN_PRIVILEGES { public uint Count; public LUID Luid; public uint Attr; }

  public static void Enable(string priv){
    const uint ADJ=0x20, QRY=0x8, ENABLE=0x2;
    IntPtr tok; LUID id; TOKEN_PRIVILEGES tp;
    if(!OpenProcessToken(System.Diagnostics.Process.GetCurrentProcess().Handle,ADJ|QRY,out tok))
        throw new System.ComponentModel.Win32Exception();
    if(!LookupPrivilegeValue(null,priv,out id))
        throw new System.ComponentModel.Win32Exception();
    tp.Count=1; tp.Luid=id; tp.Attr=ENABLE;
    if(!AdjustTokenPrivileges(tok,false,ref tp,0,IntPtr.Zero,IntPtr.Zero))
        throw new System.ComponentModel.Win32Exception();
  }
}
"@
}

[Priv]::Enable('SeSecurityPrivilege')

# ─── 3. Obliterate & re-enable ────────────────────────────────────────────
Write-Host 'Enumerating and CLEARING ALL LOGS...' -Foreground Cyan
$logs = wevtutil el

foreach ($log in $logs) {
    try {
        # Ensure retention won't block deletion & disable channel quietly
        wevtutil sl "$log" /rt:false /e:false /q:true 2>$null
        Write-Host "   Clearing [$log]" -Foreground DarkGray
        wevtutil cl "$log" 2>$null

        # Immediately re-enable collection
        wevtutil sl "$log" /e:true /q:true 2>$null
    }
    catch {
        Write-Warning "   ! $log - $($_.Exception.Message)"
    }
}

Write-Host "`nAll logs wiped and re-enabled." -Foreground Green

# ─── 4. Sanity-check the Big Three ────────────────────────────────────────
Get-WinEvent -ListLog Security, System, Application |
Select-Object LogName, RecordCount | Format-Table -AutoSize

Write-Host
write-host "Launching the Baseline Configurator"
.\BaselineSettings.ps1