# Splash ASCII Banner
$splash = @'
__        ___         _____                 _     _                
\ \      / (_)_ __   | ____|_   _____ _ __ | |_  | |    ___   __ _ 
 \ \ /\ / /| | '_ \  |  _| \ \ / / _ \ '_ \| __| | |   / _ \ / _` |
  \ V  V / | | | | | | |___ \ V /  __/ | | | |_  | |__| (_) | (_| |
 __\_/\_/  |_|_| |_| |_____| \_/ \___|_| |_|\__| |_____\___/ \__, |
|  \/  | __ _ _ __   __ _  __ _  ___ _ __                    |___/ 
| |\/| |/ _` | '_ \ / _` |/ _` |/ _ \ '__|                         
| |  | | (_| | | | | (_| | (_| |  __/ |                            
|_|  |_|\__,_|_| |_|\__,_|\__, |\___|_|                            
                          |___/                                                                                                          
'@

# Map choices to filenames
$scriptMap = @{
    "1" = "Gather-LogsToTimeLine.ps1"
    "2" = "Parse-LogsToTimeLine.ps1"
    "3" = "BaselineSettings.ps1"
    "4" = "ClearWindowsEventLog.ps1"
}

# Main Loop
do {
    Clear-Host
    Write-Host $splash -ForegroundColor Cyan

    # Script Selector Menu
    $menu = @"
[ 1 ]  Gather all available Windows Event Logs and Parse them
[ 2 ]  Parse, Merge and De-dupe gathered logs
[ 3 ]  Audit Event Log Baseline Settings and Remediate
[ 4 ]  DANGER: Clear all Windows Event Logs and re-apply Baseline Settings
[ X ]  Exit

Once you exit the manager script, you can simply type 'ls' to see the scripts available, or
type '.\EventLogLauncher.ps1' to re-launch the Event Log Manager.

Select an option (1-4 or X to quit):
"@
    Write-Host $menu -NoNewline
    $choice = Read-Host

    if ($scriptMap.ContainsKey($choice)) {
        $scriptToRun = Join-Path -Path $PSScriptRoot -ChildPath $scriptMap[$choice]
        
        if (Test-Path $scriptToRun) {
            Write-Host "`n Running $($scriptMap[$choice])..." -ForegroundColor Green
            powershell.exe -ExecutionPolicy Bypass -NoExit -Command "& {`"$scriptToRun`"}"
            Write-Host "`n Script completed. Press Enter to return to menu..." -ForegroundColor Yellow
            Read-Host
        }
        else {
            Write-Host "`n Script not found: $($scriptMap[$choice])" -ForegroundColor Red
            Read-Host "`nPress Enter to return to menu..."
        }
    }
    elseif ($choice -eq 'X' -or $choice -eq 'x') {
        Write-Host "`n Exiting Event Log Manager..." -ForegroundColor Cyan
        break
    }
    else {
        Write-Host "`n Invalid selection. Please choose 1-4 or X to quit." -ForegroundColor Red
        Read-Host "`nPress Enter to return to menu..."
    }

} while ($true)
