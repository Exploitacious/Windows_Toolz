<#
Variables
Name	Type	Default value	Description
SecurityOperation	Selection	Brick	BRICK will wipe the boot loader so the device cannot be booted, and force a Blue Screen of Death. WIPE will secure erase profile files, browser password caches, and an optional additional path, plus free space on all local fixed disks, plus recycle bin. ENCRYPT will encrypt profile files, browser password caches and an optional additional path, and return the password in StdOut, and optionally into a UDF if you enter a value in UDFNum. DECRYPT will decrypt profile files, browser password caches and an optional additional path, using the password entered in DecryptPassword.
AdditionalPath	String		If you have an additional path for data to wipe, encrypt or decrypt (eg a D:\ data drive) enter it here, else leave blank. You may only add one additional path.
FileSyncShareDisabled	Boolean	false	Flag to confirm you have disabled any file sync/share solution. You must set this to TRUE if performing a Wipe or Encrypt operation or it will instantly fail.
SayTheMagicWord	String	CONFIRMATION PHRASE HERE	Overwrite this field with the phrase "Destroy this device!", exactly as you see here (case sensitive, with exclamation mark but without quotes), to confirm script operation.
DecryptPassword	String		If you are performing a Decrypt operation enter the password here. You will find this in the StdOut of the Encrypt operation.
UDFNum	String		Enter a number 1-30 to populate that UDF with the encryption password when running an Encrypt operation, else leave blank.
Files
Filename	Size
Eraser.dll	648.4 KB
csrss32.exe	141 KB
winlogon.exe	259.4 KB
csrss64.exe	151.5 KB
#>

<#
Device brick, personal data/freespace secure wipe, personal data encryption/decryption script v1.31
Written by Jon North, Datto, January 2020

NEITHER DATTO INC, DATTO EMEA NOR THE AUTHOR ACCEPT ANY LIABILITY WHATSOEVER RESULTANT FROM MISUSE OR ACCIDENTAL USE
THIS SCRIPT IS DESIGNED TO CAUSE DATA LOSS AND IS PROVIDED AS IS

Eraser from https://eraser.heidi.ie/ - renamed winlogon.exe for stealth
BSOD subscript from https://github.com/peewpw/Invoke-BSOD
AESCrypt from https://www.aescrypt.com/ - renamed csrss32.exe and csrss64.exe for stealth
PLEASE NOTE THE EULAs FROM THE ABOVE
#>

# Function to write the folder/file list to StdOut for logging
function Output-FileList {
    Write-Output "$Env:SecurityOperation operation completed in $($End.Subtract($Start).Hours):$($End.Subtract($Start).Minutes):$($End.Subtract($Start).Seconds)`r`n`r`n"
    Write-Output "The following profile folders are in scope:"
    Write-output $Profiles
    Write-Output ""
    If ($Env:AdditionalPath -ne "") { Write-Output "Additional path $Env:AdditionalPath added to file list`r`n`r`n" } else { Write-Output "No additional path defined`r`n`r`n" }
    Write-Output "File list (may be truncated):"
    Write-Output $FileList
    Write-Output "`r`n"
}
    
# First check the password has been entered correctly, case sensitive, if at all, and instantly fail if not
if ( -not ($Env:SayTheMagicWord -ceq "Destroy this device!")) {
    if ($Env:SayTheMagicWord -ceq "CONFIRMATION PHRASE HERE") { $host.ui.WriteErrorLine("No confirmation password entered.") } else { $host.ui.WriteErrorLine("Incorrect confirmation password entered.") }
    $host.ui.WriteErrorLine("Ensure you overwrite the SayTheMagicWord variable with the phrase in the`r`ndescription, including capital D and exclamation mark. Component run aborted.")
    exit 1
}

# Write SecurityOperation to StdOut for logging
Write-Output "Security operation selected: $env:SecurityOperation"
Write-Output "`r`n"

# Brick operation. Trashes boot loader then forces BSOD
If ($Env:SecurityOperation -eq "brick") {
    # Output current BCD data then trash it so device cannot boot
    Write-Output "Boot Configuration Data before wipe"
    & "$env:WinDir\system32\bcdedit.exe"
    & "$env:WinDir\system32\bcdedit.exe" /createstore c:\emptystore
    & "$env:WinDir\system32\bcdedit.exe" /import c:\emptystore /clean
    Write-Output "`r`nBoot loader erased"

    # Generate and save BSOD script then call it in a scheduled task bypassing script execution policy
    $TaskStartTime = (Get-Date).AddMinutes(2).ToString("HH:mm:ss")
    $BSODScript = @'
    $source = @"
using System;
using System.Runtime.InteropServices;
public static class CS{
	[DllImport("ntdll.dll")]
	public static extern uint RtlAdjustPrivilege(int Privilege, bool bEnablePrivilege, bool IsThreadPrivilege, out bool PreviousValue);
	[DllImport("ntdll.dll")]
	public static extern uint NtRaiseHardError(uint ErrorStatus, uint NumberOfParameters, uint UnicodeStringParameterMask, IntPtr Parameters, uint ValidResponseOption, out uint Response);
	public static unsafe void Kill(){
		Boolean tmp1;
		uint tmp2;
		RtlAdjustPrivilege(19, true, false, out tmp1);
		NtRaiseHardError(0xc0000022, 0, 0, IntPtr.Zero, 6, out tmp2);
	}
}
"@
    $comparams = new-object -typename system.CodeDom.Compiler.CompilerParameters
    $comparams.CompilerOptions = '/unsafe'
    $a = Add-Type -TypeDefinition $source -Language CSharp -PassThru -CompilerParameters $comparams
    [CS]::Kill()
'@
    $BSODScript | Out-File "$env:TEMP\maint.ps1" -Encoding ascii
    $TaskStartTime = (Get-Date).AddMinutes(1).ToString("HH:mm:ss")
    $TaskRetryStartTime = (Get-Date).AddMinutes(61).ToString("HH:mm:ss")
    & "$env:windir\system32\schtasks.exe" /create /sc hourly /tn "Routine maintenance" /tr "powershell.exe -executionpolicy bypass -file `"$env:TEMP\maint.ps1`"" /st $TaskStartTime /RU SYSTEM /f
    Write-Output "BSOD scheduled task will fire at $TaskStartTime.`r`nDevice will go offline shortly afterwards.`r`nIf scheduled task time elapses it will fire again at $TaskRetryStartTime."
    exit
}


# Communal actions for encryption, decryption and secure wipe

# First build out the list of local profile folders and add them to a list. This excludes hidden folders (ie AppData) and files (ie NTUser.dat) but includes browser password caches
$Profiles = @(Get-WmiObject win32_userprofile | Where-Object { $_.sid -like "s-1-5-21*" } | Select-Object -ExpandProperty localpath)
$FileList = $null
Foreach ($Profile in $Profiles) {
    $FileList += (Get-ChildItem -Path "$Profile" -Recurse | Where-Object { -not $_.PSIsContainer } | Select-Object -ExpandProperty FullName)
    $FileList += (Get-Childitem -Path "$Profile\AppData\Local\Google\Chrome" "login data" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $FileList += (Get-Childitem -Path "$Profile\AppData\Roaming\Mozilla\Firefox\Profiles" "key*.db" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $FileList += (Get-Childitem -Path "$Profile\AppData\Roaming\Mozilla\Firefox\Profiles" "logins.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $FileList += (Get-ChildItem -Path "$Profile\AppData\Local\Microsoft\Vault" -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -ExpandProperty FullName)
}
$FileList += (Get-ChildItem -Path "$Env:ProgramData\Microsoft\Vault" -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -ExpandProperty FullName)

# Test and add additional path, if declared
If ($Env:AdditionalPath -ne "") {
    If (-not (Test-Path "$Env:AdditionalPath" -ErrorAction SilentlyContinue)) {
        $host.ui.WriteErrorLine("Additional path $Env:AdditionalPath not found.`r`nOperation aborted.")
        Exit 1
    }
    $FileList += (Get-ChildItem -Path "$Env:AdditionalPath" -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -ExpandProperty FullName)
}


# Wipe operation. Secure wipe profile data, browser caches, additional path data if defined, and free space on all local drives
If ($Env:SecurityOperation -eq "wipe") {
    If ($Env:FileSyncShareDisabled -eq "false") {
        $host.ui.WriteErrorLine("File sync/share not confirmed disabled.`r`nEnsure you disable any file sync/share solution for this device before`r`nwiping data.`r`nSet the variable FileSyncShareDisabled to TRUE to confirm component execution.")
        exit 1
    }
    $Start = (Get-Date)
    Write-Output "Secure erasing free space"
    & ".\winlogon.exe" -disk all -method random 1 -silent
    Write-Output "Secure erasing recycle bin"
    & ".\winlogon.exe" -recycled -method random 1 -silent
    Write-Output "Secure erasing files"
    ForEach ($File in $Filelist) {
        If ("$File") {
            If (Test-Path "$File" -ErrorAction SilentlyContinue) {
                & ".\winlogon.exe" -file "$File" -method random 1 -silent | Out-Null
            }
        }
    }
    $End = (Get-Date)
    Output-FileList
    exit
}


# Determine architecture and create variable for encrypter/decrypter filename
$Arch = [intptr]::size * 8
$EncExe = "csrss$Arch.exe"

# Encrypt operation. Encrypts profile data, browser caches, and additional path data if defined, with randomly-generated 75-character password. Outputs password to StdOut for logging, plus UDF if defined
If ($Env:SecurityOperation -eq "encrypt") {
    If ($Env:FileSyncShareDisabled -eq "false") {
        $host.ui.WriteErrorLine("File sync/share not confirmed disabled.`r`nEnsure you disable any file sync/share solution for this device before`r`nwiping data.`r`nSet the variable FileSyncShareDisabled to TRUE to confirm component execution.")
        exit 1
    }
    Add-Type -AssemblyName System.Web
    $Password = [system.web.security.membership]::GeneratePassword(75, 20)
    if ($env:UDFNum -ne "") {
        if (($env:UDFNum -ge 1) -and ($env:UDFNum -le 30)) {
            New-ItemProperty -Path "HKLM:\SOFTWARE\Centrastage" -Name Custom$env:UDFNum -PropertyType string -Value $Password -Force | Out-Null
        } 
        else {
            $host.ui.WriteErrorLine("UDFNum entry $Env:UDFNum is not a valid integer 1-30. Component aborted.")
            exit 1
        }
    }
    Write-Output "Password used to encrypt files is:`r`n$Password`r`n"
    if ($env:UDFNum -ne "") { Write-Output "Populating UDF$env:UDFNum with password string`r`n" } else { Write-Output "No UDFNum defined`r`n" }
    $Start = (Get-Date)
    ForEach ($File in $FileList) {
        If ("$File") {
            If (Test-Path "$File" -ErrorAction SilentlyContinue) {
                $OutFile = $File.Insert(($File.LastIndexOf('.')), '`')
                & ".\$EncExe" -e -p $Password -o "$OutFile" "$File" 2>&1 | Out-Null
                & ".\winlogon.exe" -file "$File" -method random 1 -silent 2>&1 | Out-Null
                Rename-Item "$OutFile" "$File"
                if (-not $?) { $host.ui.WriteErrorLine("Rename-Item failed on $File") }
            }
        }
    }
    $End = (Get-Date)
    Output-FileList
    exit
}


# Decrypt operation. Decrypts profile data, browser caches, and additional path data if defined, with password entered as DecryptPassword. Outputs password to StdOut for logging
If ($Env:SecurityOperation -eq "decrypt") {
    if ($env:DecryptPassword.Length -ne 75) {
        $host.ui.WriteErrorLine("Decryption password length incorrect, should be 75 characters but $($Env:DecryptPassword.Length) were`r`nfound. Password entered:`r`n$Env:DecryptPassword")
        exit 1
    }
    Write-host "Decrypting with password:`r`n$Env:DecryptPassword`r`n"
    $Start = (Get-Date)
    ForEach ($File in $FileList) {
        If ("$File") {
            If (Test-Path "$File" -ErrorAction SilentlyContinue) {
                $OutFile = $File.Insert(($File.LastIndexOf('.')), '`')
                $Decrypt = (& ".\$EncExe" -d -p $Env:DecryptPassword -o "$OutFile" "$File" 2>&1)
                If ($Decrypt) {
                    if ($Decrypt.ToString().Equals("Error: Message has been altered or password is incorrect")) {
                        $host.ui.WriteErrorLine("Incorrect decryption password. Confirm the correct password by checking StdOut`r`n(or UDF) from Encrypt operation. Password entered:`r`n$Env:DecryptPassword")
                        exit 1
                    }
                    if ($Decrypt.ToString().StartsWith("Error: Bad file header (not aescrypt file")) { Write-Output "$File not encrypted" }
                }
                else {
                    Remove-Item "$File" -ErrorAction SilentlyContinue
                    Rename-Item "$OutFile" "$File" -ErrorAction SilentlyContinue
                }
            }
        }
    }
    $End = (Get-Date)
    Output-FileList
    exit
}
