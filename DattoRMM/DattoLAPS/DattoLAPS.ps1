# Datto RMM Local Admin Password Solution

<#

EXPLANATION:
This PowerShell script is designed to manage local administrator passwords on machines, specifically for environments using Datto RMM (Remote Monitoring and Management). It performs the following tasks:

1. **Password Generation**: It generates a new, random password for the local administrator account. The password is 25 characters long by default and includes a mix of uppercase letters, lowercase letters, numbers, and symbols. This complexity is customizable through environmental variables.

2. **Local Administrator Account Management**:
   - If the specified local administrator account exists, the script updates its password with the newly generated one.
   - If the account does not exist, the script creates it with the generated password and adds it to the local Administrators group.
   - It ensures that the password for this account never expires and that the account is enabled.

3. **Security and Logging**:
   - The script sets the account description to include the last password rotation date for tracking purposes.
   - It can optionally write the username, new password, and the password set date to a User-Defined Field (UDF) in the Datto RMM dashboard for administrative purposes. This is controlled by an environmental variable (`$env:usrUDF`).

4. **Error Handling**: The script includes basic error handling to catch specific exceptions, such as when the user is not found or other unspecified errors occur. It advises running the script with administrative privileges to avoid permission issues.

5. **Environmental Variables**: The script uses several environmental variables to allow customization without modifying the script directly. These include variables for the local admin username (`$env:LAUserName`), password length (`$env:Length`), character sets to include in the password (`$env:Sets`), and the UDF index for storing the password in Datto RMM (`$env:usrUDF`).

6. **Registry Modification**: For environments utilizing Datto RMM, it updates a registry key with the new password information, ensuring that this critical data can be securely accessed and managed from the Datto RMM dashboard.

This script is a powerful tool for IT administrators looking to automate the rotation of local administrator passwords across their managed devices, enhancing security by ensuring that these critical accounts are not left with default or easily guessable passwords.


Script to run on each machine that needs to have it's local admin password rotated, and create the specified local admin account if it does not exist.
Each time the script runs it will check for the Local Admin account and generate a password. Specify the interval of running by your RMM or trigger it manually.
Password will print into StdOut as well as your specified UDF (Datto RMM). Each password will be a randomly generated 25 character length, mixed and contain a variation of letters, symbols and numbers. 

Created originally by https://www.winreflection.com/account-password-rotation-randomly-generated-v2/
Chopped up and retrofitted to work with Datto RMM by Alex Ivantsov https://github.com/exploitacious

Set the Variable $env:LAUserName to be your specified local admin account name.
Set the variable $env:Length in the Function GenLAPString for the length of the password
Set the variable $env:Sets to include the following character sets. (Remove a letter to exclude coresponding set)
    U: Uppercase Letters
    L: Lowercase Letters
    N: Numbers
    S: Symbols
Set the variable $env:usrUDF for the specified UDF where to write your LAP in the dashboard

#>

# Environemntal Variables # Blank out for Datto RMM Inputs

# $env:LAUserName = "UmbrellaLA"
# $env:Length = 25
# $env:Sets = "ULNS"
# $env:usrUDF = 1

Function GenLAPString ([Int]$CharLength, [Char[]]$CharSets = "ULNS") {
    
    $Chars = @()
    $TokenSet = @()
    
    If (!$TokenSets) {
        $Global:TokenSets = @{
            U = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                # Upper case
            L = [Char[]]'abcdefghijklmnopqrstuvwxyz'                                # Lower case
            N = [Char[]]'0123456789'                                                # Numerals
            S = [Char[]]'!"#%&()*+,-./:;<=>?@[\]^_{}~'                             # Symbols
        }
    }

    $CharSets | ForEach-Object {
        $Tokens = $TokenSets."$_" | ForEach-Object { If ($Exclude -cNotContains $_) { $_ } }
        If ($Tokens) {
            $TokensSet += $Tokens
            If ($_ -cle [Char]"Z") { $Chars += $Tokens | Get-Random }             #Character sets defined in upper case are mandatory
        }
    }

    While ($Chars.Count -lt $CharLength) { $Chars += $TokensSet | Get-Random }
    ($Chars | Sort-Object { Get-Random }) -Join ""                                #Mix the (mandatory) characters and output string
};


$ObjLocalUser = $null
$Passwd = GenLAPString $env:Length $env:Sets
$PasswdSecStr = ConvertTo-SecureString $Passwd -AsPlainText -Force

# Action!

try {
    $ObjLocalUser = Get-LocalUser $env:LAUserName -ErrorAction Stop

    Add-LocalGroupMember -Group Administrators -Member $env:LAUserName -ErrorAction SilentlyContinue

    Set-LocalUser $env:LAUserName -Password $PasswdSecStr -PasswordNeverExpires $true

    if ((Get-LocalUser -Name $env:LAUserName).Enabled) {
    }
    else {
        Enable-LocalUser $env:LAUserName
    }
}
catch [Microsoft.PowerShell.Commands.UserNotFoundException] {
    New-LocalUser $env:LAUserName -Password $PasswdSecStr -FullName $env:LAUserName -PasswordNeverExpires
    Add-LocalGroupMember -Group Administrators -Member $env:LAUserName
}
catch {
    Write-Error "An unspecifed error has occurred. Verify you are running script as admin."
    Exit 1 
}

$LastChangeDateVar = Get-LocalUser $env:LAUserName | Select-Object PasswordLastSet
$DateSet = $LastChangeDateVar.PasswordLastSet
$varUDFString = ".\$env:LAUserName  ||  $PassWd  ||  Set On $DateSet"

Set-LocalUser $env:LAUserName -Description "LAPS by DRMM Last rotation: $DateSet"

# Results (If Needed for Troubleshooting. Otherwise, don't enable printing of the cleartext PW. 
# Write-Host $varUDFString

if ($env:usrUDF -ge 1) {    
    if ($varUDFString.length -gt 255) {
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString.substring(0, 255)) -Force
    }
    else {
        Set-ItemProperty -Path "HKLM:\Software\CentraStage" -Name custom$env:usrUDF -Value $($varUDFString) -Force
    }
}
else {
    Write-Host "- Not writing data to a UDF."
}

Exit 0