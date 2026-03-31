#Get Variables 
$Sleep_Plugged_In = $env:Sleep_Plugged_In
$Sleep_Battery = $env:Sleep_Battery
$Hibernate_Plugged_In = $env:Hibernate_Plugged_In
$Hibernate_Battery = $env:Hibernate_Battery
$Disk_Plugged_In = $env:Disk_Plugged_In
$Disk_Battery = $env:Disk_Battery
$Display_Plugged_in = $env:Display_Plugged_in
$Display_Battery = $env:Display_Battery
$Lid_Close_Action_Plugged_In = $env:Lid_Close_Action_Plugged_In
$Revert_Last_Settings = $env:Revert_Last_Settings

#Get GUID of active plan
$GUID = (((Get-CimInstance -classname Win32_PowerPlan -Namespace "root\cimv2\power" | where {$_.IsActive -eq "true"}).InstanceID) -split("\\"))[1]
#Cut {} off of string at beginning and end of GUID
$GUID = $GUID.Substring(1, $GUID.Length-2)

#Get a list of all options for this plan
$Options = powercfg -query $GUID
$index = 0


#Set Functions
function GetCurrent ($Type, $Name, $indexOffset)
{
   For($i=0; $i -lt $Options.Length; $i++)
   {
      $line = $Options[$i]
      if($line.ToLower() -like "*$Type*")
      {
        $index = $i
        break
      }        
   }

$value = $Options[$index +$indexOffset]
$value = $value.Substring($value.IndexOf(":")+2) 
$value = ($value.Split() | % {[Convert]::ToInt64($_,16)})/60

     if ($value - [math]::floor($value) -gt 0)
     {
        $value = $value * 60
        $value = [math]::Round($value) 
     }

Set-ItemProperty -Path HKLM:\SOFTWARE\CentraStage -Name $Name  -Value $Value
echo "$name set to $value"
}


function Revert ($Name, $Text, $pwrcfg)
{
     powercfg.exe -x $pwrcfg (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).$Name
     $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).$Name
     echo "$Text reverted back to $value minutes."
}

#Revert Settings
if ($Revert_Last_Settings -eq 1)
{
    Revert "SleepPluggedIn" "Sleep plugged in" "standby-timeout-ac"
    Revert "SleepBattery" "Sleep on battery" "standby-timeout-dc"

    Revert "HibernatePluggedIn" "Hibernate plugged in" "hibernate-timeout-ac"
    Revert "HibernateBattery" "Hibernate on battery" "hibernate-timeout-dc"

    Revert "DiskPluggedIn" "Disk shut down plugged in" "disk-timeout-ac"
    Revert "DiskBattery" "Disk shut down on battery" "disk-timeout-dc"

    Revert "DisplayPluggedIn" "Display off plugged in" "monitor-timeout-ac"
    Revert "DisplayBattery" "Display off on battery" "monitor-timeout-dc"

    powercfg.exe -setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).LidactionPluggedIn
    $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).LidactionPluggedIn
    if ($value -eq 0) { $lidclosetrans = "Do Nothing"}
    if ($value -eq 1) { $lidclosetrans = "Sleep"}
    if ($value -eq 2) { $lidclosetrans = "Hibernate"}
    if ($value -eq 3) { $lidclosetrans = "Shutdown"}
    echo "Lid close action plugged in reverted back to $lidclosetrans."
    exit 0

}

#Display Current Settings
echo "Current Settings `n-------------------------------------"
GetCurrent "sleep after" "sleepPluggedIn" 6
GetCurrent "sleep after" "sleepBattery" 7

GetCurrent "hibernate after" "HibernatePluggedIn"6
GetCurrent "hibernate after" "HibernateBattery" 7

GetCurrent "Turn off hard disk after" "DiskPluggedIn"6
GetCurrent "Turn off hard disk after" "DiskBattery" 7

GetCurrent "Turn off Display After" "DisplayPluggedIn" 6
GetCurrent "Turn off Display After" "DisplayBattery" 7

GetCurrent "Lid close action" "LidactionPluggedIn" 10


#Update Settings with new values
"`nUpdated Settings `n-------------------------------------"


if ($Sleep_Plugged_In -eq "")
{
    powercfg.exe -x standby-timeout-ac (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).SleepPluggedIn
    $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).SleepPluggedIn
    echo "Sleep plugged in kept at $value minutes."
}
else
{
    powercfg.exe -x standby-timeout-ac $Sleep_Plugged_In
    echo "Sleep plugged in changed to $Sleep_Plugged_In minutes."

}


if ($Sleep_Battery -eq "")
{
    powercfg.exe -x standby-timeout-dc (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).SleepBattery
    $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).SleepBattery
    echo "Sleep on battery kept at $value minutes."
}
else
{
    powercfg.exe -x standby-timeout-dc $Sleep_Battery
    echo "Sleep on battery changed to $Sleep_Battery minutes."
}

if ($Hibernate_Plugged_In -eq "")
{
     powercfg.exe -x hibernate-timeout-ac (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).HibernatePluggedIn
     $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).HibernatePluggedIn
     echo "Hibernate plugged in kept at $value minutes."
}
else
{

   powercfg.exe -x hibernate-timeout-ac ($Hibernate_Plugged_In)
   echo "Hibernate plugged in changed to $Hibernate_Plugged_In minutes."
}

if ($Hibernate_Battery -eq "")
{
    powercfg.exe -x hibernate-timeout-dc (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).HibernateBattery
    $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).HibernateBattery
    echo "Hibernate on battery kept at $value minutes."
}
else
{
    powercfg.exe -x hibernate-timeout-dc ($Hibernate_Battery)
    echo "Hibernate on battery changed to $Hibernate_Battery minutes."
}

if ($Disk_Plugged_In -eq "")
{
    powercfg.exe -x disk-timeout-ac (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).DiskPluggedIn
    $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).DiskPluggedIn
    echo "Disk shutdown plugged in kept at $value minutes."

}
else
{
    powercfg.exe -x disk-timeout-ac $Disk_Plugged_In
    echo "Disk shutdown plugged in changed to $Disk_Plugged_In minutes."
}

if ($Disk_Battery -eq "")
{
    powercfg.exe -x disk-timeout-dc (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).DiskBattery
    $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).DiskBattery
    echo "Disk Shutdown on battery kept at $value minutes."
}
else
{
    powercfg.exe -x disk-timeout-dc $Disk_Battery
    echo "Disk Shutdown on battery changed to $Disk_Battery minutes."
}

if ($Display_Plugged_in -eq "")
{
    powercfg.exe -x monitor-timeout-ac (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).DisplayPluggedIn
    $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).DisplayPluggedIn
    echo "Display off plugged in kept at $value minutes."
}
else
{
    powercfg.exe -x monitor-timeout-ac $Display_Plugged_in
    echo "Display off plugged in changed to $Display_Plugged_In minutes."
}


if ($Display_Battery -eq "")
{
    powercfg.exe -x monitor-timeout-dc (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).DisplayBattery
    $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).DisplayBattery
    echo "Display off on battery kept at $value minutes."
}
else
{
    powercfg.exe -x monitor-timeout-dc $Display_Battery
    echo "Display off on battery changed to $Display_Battery minutes."
}

if ($Lid_Close_Action_Plugged_In -eq "a")
{
    powercfg.exe -setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).LidactionPluggedIn
    $value = (Get-ItemProperty HKLM:\SOFTWARE\CentraStage).LidactionPluggedIn
    if ($value -eq 0) { $lidclosetrans = "Do Nothing"}
    if ($value -eq 1) { $lidclosetrans = "Sleep"}
    if ($value -eq 2) { $lidclosetrans = "Hibernate"}
    if ($value -eq 3) { $lidclosetrans = "Shutdown"}
    echo "Lid close action plugged in kept on $lidclosetrans."
}
else
{
    powercfg.exe -setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 $Lid_Close_Action_Plugged_In
    if ($Lid_Close_Action_Plugged_In -eq 0) { $lidclosetrans = "Do Nothing"}
    if ($Lid_Close_Action_Plugged_In -eq 1) { $lidclosetrans = "Sleep"}
    if ($Lid_Close_Action_Plugged_In -eq 2) { $lidclosetrans = "Hibernate"}
    if ($Lid_Close_Action_Plugged_In -eq 3) { $lidclosetrans = "Shutdown"}
    echo "Lid close action plugged in changed to $lidclosetrans."
}